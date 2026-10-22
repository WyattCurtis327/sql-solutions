-- Two genders. Bob and Charlie share a day; score_id is the tiebreak
-- (Snowflake has no ctid).
CREATE OR REPLACE TABLE scores (
    score_id INTEGER,
    player_name VARCHAR,
    gender VARCHAR,
    day INTEGER,
    score_points INTEGER
);

INSERT INTO scores (score_id, player_name, gender, day, score_points) VALUES
    (1, 'Ava',     'F', 1, 10),
    (2, 'Bea',     'F', 2, 20),
    (3, 'Cleo',    'F', 3, 15),
    (4, 'Bob',     'M', 1, 15),
    (5, 'Charlie', 'M', 1, 12),
    (6, 'Ed',      'M', 2, 18),
    (7, 'Dee',     'F', 4, 25),
    (8, 'Gus',     'M', 3, 22);
