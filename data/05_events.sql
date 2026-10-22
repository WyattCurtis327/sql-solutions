-- Gaps of 10, 30, 31, 29, and >30 minutes. A gap of exactly 30 minutes stays
-- in the session; 31 minutes starts a new one. User 303 has a single event.
CREATE OR REPLACE TABLE events (
    event_id INTEGER,
    user_id INTEGER,
    event_type VARCHAR,
    event_timestamp TIMESTAMP_NTZ
);

INSERT INTO events (event_id, user_id, event_type, event_timestamp) VALUES
    (1,  101, 'page_view', TIMESTAMP '2024-01-15 09:00:00'),
    (2,  101, 'click',     TIMESTAMP '2024-01-15 09:10:00'),
    (3,  101, 'page_view', TIMESTAMP '2024-01-15 09:40:00'),
    (4,  101, 'click',     TIMESTAMP '2024-01-15 10:11:00'),
    (5,  101, 'purchase',  TIMESTAMP '2024-01-15 10:20:00'),
    (6,  101, 'page_view', TIMESTAMP '2024-01-15 12:00:00'),
    (7,  202, 'page_view', TIMESTAMP '2024-01-15 09:00:00'),
    (8,  202, 'click',     TIMESTAMP '2024-01-15 09:29:00'),
    (9,  202, 'page_view', TIMESTAMP '2024-01-15 10:00:00'),
    (10, 303, 'page_view', TIMESTAMP '2024-01-16 08:00:00');
