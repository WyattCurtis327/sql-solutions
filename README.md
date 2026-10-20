# SQL Solutions: 12 SQL Patterns for Data Interviews

PostgreSQL solutions for the 12 patterns in the video
**["Master SQL using 12 SQL Patterns for Data Interviews"](https://youtu.be/cGtPup-EwrM) by Darshil Parmar**.
All credit for the problems, patterns and teaching goes to the original creator. This repo is an unofficial companion write-up.

> **Note: reconstructed code.** The video has no repo or posted code, and the code on screen couldn't be read as text. Every query here was **rebuilt from the narration**. Each one was checked against the example data and outputs read out in the video. Literal values that are never spoken out loud are **assumptions**:
> - `06_funnel.sql`: the stage labels `'signup'`, `'activate'`, `'engage'`, `'convert'`, the `stage` column name and the `'purchase'` event value
> - `05_sessionization.sql`: the `TO_CHAR` separators (`-` and space). Only "year month day hh24:mi:ss" was spoken.
> - `09_pivot.sql`: the capitalisation of the region values (`'North'`, `'South'`, ...)

## Patterns

| # | Pattern | File |
|---|---------|------|
| 1 | Deduplication (ROW_NUMBER) | `sql/01_dedup.sql` |
| 2 | Running total | `sql/02_running_total.sql` |
| 3 | Year-over-year growth (LAG) | `sql/03_yoy_growth.sql` |
| 4 | Gaps and islands | `sql/04_gaps_islands.sql` |
| 5 | Sessionization | `sql/05_sessionization.sql` |
| 6 | Funnel analysis | `sql/06_funnel.sql` |
| 7 | Retention cohorts | `sql/07_retention_cohorts.sql` |
| 8 | Top-N per group | `sql/08_top_n_per_group.sql` |
| 9 | Pivot (conditional aggregation) | `sql/09_pivot.sql` |
| 10 | Self join (employee to manager) | `sql/10_self_join.sql` |
| 11 | Recursive hierarchy (WITH RECURSIVE) | `sql/11_recursive_hierarchy.sql` |
| 12 | 7-day moving average | `sql/12_moving_average.sql` |

## How to run

The scripts target **PostgreSQL**. Load the example tables from the video, then run a file:

```bash
psql -d yourdb -f sql/01_dedup.sql
```

### Tested in DuckDB
`sql/test_duckdb.py` loads the example data from the video into DuckDB and runs all 12 queries (tested on DuckDB 1.5.5). All 12 reproduce the outputs shown in the video. The test needs two swaps for DuckDB, and it applies them on its own:
- `ctid` → `rowid`
- `TO_CHAR(...)` → `strftime(...)`

```bash
pip install duckdb
cd sql && python test_duckdb.py
```

## License
The MIT [LICENSE](LICENSE) covers this repo's own write-up and reconstructed code only. It doesn't cover the original video or its course material, which belong to their creator.
