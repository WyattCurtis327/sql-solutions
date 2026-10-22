"""Run the Snowflake pattern queries and check them against README.md.

The files under sql/ and data/ are Snowflake SQL. DuckDB does not implement
every function, so snowflake_to_duckdb() rewrites only these constructs
before execution:

- TIMESTAMP_NTZ -> TIMESTAMP
- IFF( -> IF(
- DATEADD('day', n, date_expr) -> (date_expr + (n)::INT)
- TO_CHAR(value, snowflake_format) -> STRFTIME(value, duckdb_format)
  Format tokens: YYYY->%Y, MM->%m, DD->%d, HH24->%H, MI->%M, SS->%S

Everything else (DATEDIFF, COUNT_IF, QUALIFY, :: casts, YEAR, DATE_TRUNC,
WITH RECURSIVE) runs as written.

Usage:
    python sql/test_duckdb.py          # compare results to README tables
    python sql/test_duckdb.py --dump   # print rendered source and output tables
"""

from __future__ import annotations

import pathlib
import re
import sys
from datetime import date, datetime
from decimal import Decimal

import duckdb

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Pattern number -> load script, query, and source-table SELECTs whose
# column order and sort match the README source tables.
PATTERNS = [
    {
        "n": 1,
        "data": "data/01_customers.sql",
        "query": "sql/01_dedup.sql",
        "sources": [("customers", "SELECT * FROM customers ORDER BY customer_id")],
    },
    {
        "n": 2,
        "data": "data/02_scores.sql",
        "query": "sql/02_running_total.sql",
        "sources": [("scores", "SELECT * FROM scores ORDER BY score_id")],
    },
    {
        "n": 3,
        "data": "data/03_hosts.sql",
        "query": "sql/03_yoy_growth.sql",
        "sources": [("hosts", "SELECT * FROM hosts ORDER BY host_id")],
    },
    {
        "n": 4,
        "data": "data/04_logins.sql",
        "query": "sql/04_gaps_islands.sql",
        "sources": [("logins", "SELECT * FROM logins ORDER BY login_id")],
    },
    {
        "n": 5,
        "data": "data/05_events.sql",
        "query": "sql/05_sessionization.sql",
        "sources": [("events", "SELECT * FROM events ORDER BY event_id")],
    },
    {
        "n": 6,
        "data": "data/06_funnel.sql",
        "query": "sql/06_funnel.sql",
        "sources": [
            ("users", "SELECT * FROM users ORDER BY user_id"),
            ("events", "SELECT * FROM events ORDER BY event_id"),
        ],
    },
    {
        "n": 7,
        "data": "data/07_transactions.sql",
        "query": "sql/07_retention_cohorts.sql",
        "sources": [("transactions", "SELECT * FROM transactions ORDER BY transaction_id")],
    },
    {
        "n": 8,
        "data": "data/08_sales.sql",
        "query": "sql/08_top_n_per_group.sql",
        "sources": [("sales", "SELECT * FROM sales ORDER BY sale_id")],
    },
    {
        "n": 9,
        "data": "data/09_sales.sql",
        "query": "sql/09_pivot.sql",
        "sources": [("sales", "SELECT * FROM sales ORDER BY sale_id")],
    },
    {
        "n": 10,
        "data": "data/10_employees.sql",
        "query": "sql/10_self_join.sql",
        "sources": [("employees", "SELECT * FROM employees ORDER BY employee_id")],
    },
    {
        "n": 11,
        "data": "data/11_employees.sql",
        "query": "sql/11_recursive_hierarchy.sql",
        "sources": [("employees", "SELECT * FROM employees ORDER BY employee_id")],
    },
    {
        "n": 12,
        "data": "data/12_customer_visits.sql",
        "query": "sql/12_moving_average.sql",
        "sources": [("customer_visits", "SELECT * FROM customer_visits ORDER BY visit_id")],
    },
]


def _split_top_level_args(text: str) -> list[str]:
    args = []
    depth = 0
    start = 0
    for i, ch in enumerate(text):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            args.append(text[start:i])
            start = i + 1
    args.append(text[start:])
    return args


def _replace_dateadd(sql: str) -> str:
    """DATEADD('day', n, d) -> (d + (n)::INT), which DuckDB accepts."""
    needle = "DATEADD("
    out = []
    i = 0
    upper = sql.upper()
    while True:
        j = upper.find(needle, i)
        if j < 0:
            out.append(sql[i:])
            return "".join(out)
        out.append(sql[i:j])
        k = j + len(needle)
        depth = 1
        while k < len(sql) and depth:
            if sql[k] == "(":
                depth += 1
            elif sql[k] == ")":
                depth -= 1
            k += 1
        if depth != 0:
            raise ValueError("unbalanced DATEADD(")
        args = _split_top_level_args(sql[j + len(needle) : k - 1])
        if len(args) != 3:
            raise ValueError(f"DATEADD expected 3 arguments, got {len(args)}")
        part = args[0].strip().strip("'\"").lower()
        if part != "day":
            raise ValueError(f"DuckDB shim only rewrites DATEADD day, got {part!r}")
        out.append(f"({args[2].strip()} + ({args[1].strip()})::INT)")
        i = k


def snowflake_to_duckdb(sql: str) -> str:
    """Rewrite the few Snowflake constructs DuckDB does not accept."""
    sql = sql.replace("TIMESTAMP_NTZ", "TIMESTAMP")
    sql = re.sub(r"\bIFF\s*\(", "IF(", sql)
    sql = _replace_dateadd(sql)

    def repl_format(match: re.Match) -> str:
        fmt = match.group(1)
        fmt = (
            fmt.replace("YYYY", "%Y")
            .replace("HH24", "%H")
            .replace("MM", "%m")
            .replace("DD", "%d")
            .replace("MI", "%M")
            .replace("SS", "%S")
        )
        return "'" + fmt + "'"

    sql = re.sub(r"'((?:YYYY|MM|DD|HH24|MI|SS|[-: ])+)'", repl_format, sql)
    sql = re.sub(r"\bTO_CHAR\s*\(", "STRFTIME(", sql)
    return sql


def split_statements(sql: str) -> list[str]:
    lines = []
    for line in sql.splitlines():
        if "--" in line:
            line = line[: line.index("--")]
        lines.append(line)
    return [part.strip() for part in "\n".join(lines).split(";") if part.strip()]


def render_cell(value) -> str:
    """Render a query cell the same way the README tables do."""
    if value is None:
        return "NULL"
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return format(value, "f")
    if isinstance(value, float):
        return f"{value:.2f}"
    return str(value)


def markdown_table(headers: list[str], rows: list[list[str]]) -> str:
    widths = [len(header) for header in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    def fmt(cells: list[str]) -> str:
        return "| " + " | ".join(cell.ljust(widths[i]) for i, cell in enumerate(cells)) + " |"

    separator = "| " + " | ".join("-" * width for width in widths) + " |"
    return "\n".join([fmt(headers), separator, *[fmt(row) for row in rows]])


def run_select(con, sql: str):
    cur = con.execute(sql)
    headers = [col[0] for col in cur.description]
    rows = [[render_cell(value) for value in row] for row in cur.fetchall()]
    return headers, rows


def load_pattern(con, pattern: dict) -> None:
    script = (ROOT / pattern["data"]).read_text()
    for statement in split_statements(snowflake_to_duckdb(script)):
        con.execute(statement)


def query_sql(pattern: dict) -> str:
    return snowflake_to_duckdb((ROOT / pattern["query"]).read_text())


def execute_pattern(pattern: dict):
    con = duckdb.connect()
    load_pattern(con, pattern)
    sources = []
    for table, select in pattern["sources"]:
        headers, rows = run_select(con, select)
        sources.append((table, headers, rows))
    headers, rows = run_select(con, query_sql(pattern))
    con.close()
    return sources, headers, rows


def parse_markdown_table(text: str) -> tuple[list[str], list[list[str]]]:
    lines = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("|"):
            lines.append(stripped)
        elif lines:
            break
    if len(lines) < 2:
        raise ValueError("markdown table not found")
    header = [cell.strip() for cell in lines[0].strip("|").split("|")]
    rows = []
    for line in lines[2:]:
        rows.append([cell.strip() for cell in line.strip("|").split("|")])
    return header, rows


def section_for(readme: str, number: int) -> str:
    pattern = re.compile(rf"^### {number}\. .*$", re.M)
    match = pattern.search(readme)
    if not match:
        raise AssertionError(f"README is missing a section heading for pattern {number}")
    start = match.start()
    nxt = re.search(r"^#{2,3} ", readme[match.end() :], re.M)
    end = match.end() + nxt.start() if nxt else len(readme)
    return readme[start:end]


def sql_fence(section: str) -> str:
    match = re.search(r"```sql\n(.*?)```", section, re.S)
    if not match:
        raise AssertionError("README section has no ```sql fence")
    return match.group(1).strip()


def tables_after(section: str, marker: str) -> list[tuple[list[str], list[list[str]]]]:
    """Parse every markdown table that follows marker, until the next bold label or fence."""
    idx = section.find(marker)
    if idx < 0:
        raise AssertionError(f"missing marker {marker!r}")
    rest = section[idx + len(marker) :]
    tables = []
    position = 0
    while True:
        fence = rest.find("```", position)
        nxt = rest.find("\n**", position)
        stop_at = len(rest)
        for candidate in (fence, nxt):
            if candidate >= 0:
                stop_at = min(stop_at, candidate)
        window = rest[position:stop_at]
        line_start = window.find("|")
        if line_start < 0:
            break
        header, rows = parse_markdown_table(window[line_start:])
        tables.append((header, rows))
        # Advance past this table in `rest`.
        consumed = window[line_start:].splitlines()
        table_len = 0
        seen = 0
        for line in consumed:
            if line.strip().startswith("|"):
                seen += 1
                table_len += len(line) + 1
            elif seen:
                break
            else:
                table_len += len(line) + 1
        position += line_start + table_len
    if not tables:
        raise AssertionError(f"no markdown table after {marker!r}")
    return tables


def compare_table(label: str, expected_header, expected_rows, actual_header, actual_rows, failures):
    if expected_header != actual_header or expected_rows != actual_rows:
        failures.append(
            f"{label}\n"
            f"expected:\n{markdown_table(expected_header, expected_rows)}\n"
            f"actual:\n{markdown_table(actual_header, actual_rows)}"
        )


def check() -> int:
    readme = (ROOT / "README.md").read_text()
    failures = []
    for pattern in PATTERNS:
        section = section_for(readme, pattern["n"])
        file_sql = (ROOT / pattern["query"]).read_text().strip()
        try:
            fenced = sql_fence(section)
        except AssertionError as exc:
            failures.append(f"pattern {pattern['n']}: {exc}")
            continue
        if fenced != file_sql:
            failures.append(
                f"pattern {pattern['n']}: README SQL does not match {pattern['query']}"
            )

        sources, headers, rows = execute_pattern(pattern)
        output_marker = "**Output dataset:**"
        try:
            source_tables = []
            # Each source label is its own marker, followed by one table.
            for table, _, _ in sources:
                marker = f"**Source dataset:** `{table}`"
                found = tables_after(section, marker)
                if len(found) != 1:
                    raise AssertionError(f"{table} should have one source table, found {len(found)}")
                source_tables.append(found[0])
            output_tables = tables_after(section, output_marker)
        except AssertionError as exc:
            failures.append(f"pattern {pattern['n']}: {exc}")
            continue

        if len(output_tables) != 1:
            failures.append(f"pattern {pattern['n']}: expected one output table")
            continue

        for (table, actual_header, actual_rows), (expected_header, expected_rows) in zip(
            sources, source_tables
        ):
            compare_table(
                f"pattern {pattern['n']} source {table}",
                expected_header,
                expected_rows,
                actual_header,
                actual_rows,
                failures,
            )
        expected_header, expected_rows = output_tables[0]
        compare_table(
            f"pattern {pattern['n']} output",
            expected_header,
            expected_rows,
            headers,
            rows,
            failures,
        )
        if not any(item.startswith(f"pattern {pattern['n']} ") or item.startswith(f"pattern {pattern['n']}:") for item in failures):
            print(f"ok  pattern {pattern['n']}")

    if failures:
        print("\n\n".join(failures))
        print(f"\n{len(failures)} check(s) failed")
        return 1
    print(f"all {len(PATTERNS)} patterns match README.md")
    return 0


def dump() -> None:
    for pattern in PATTERNS:
        print(f"\n## pattern {pattern['n']}")
        sources, headers, rows = execute_pattern(pattern)
        for table, source_headers, source_rows in sources:
            print(f"\n**Source dataset:** `{table}`\n")
            print(markdown_table(source_headers, source_rows))
        print("\n**Output dataset:**\n")
        print(markdown_table(headers, rows))


if __name__ == "__main__":
    if "--dump" in sys.argv:
        dump()
    else:
        sys.exit(check())
