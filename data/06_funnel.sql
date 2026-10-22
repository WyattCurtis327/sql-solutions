-- Stages are independent thresholds, not a nested path.
-- User 3 purchases once (convert) without reaching 5 events (engage).
-- User 2 reaches 5 events without a purchase. User 5 signs up only.
CREATE OR REPLACE TABLE users (
    user_id INTEGER,
    signup_date DATE
);

INSERT INTO users (user_id, signup_date) VALUES
    (1, DATE '2024-01-01'),
    (2, DATE '2024-01-02'),
    (3, DATE '2024-01-03'),
    (4, DATE '2024-01-04'),
    (5, DATE '2024-01-05');

CREATE OR REPLACE TABLE events (
    event_id INTEGER,
    user_id INTEGER,
    event_type VARCHAR,
    event_date DATE
);

INSERT INTO events (event_id, user_id, event_type, event_date) VALUES
    (1,  1, 'view',     DATE '2024-01-02'),
    (2,  1, 'view',     DATE '2024-01-02'),
    (3,  1, 'click',    DATE '2024-01-03'),
    (4,  1, 'click',    DATE '2024-01-03'),
    (5,  1, 'purchase', DATE '2024-01-04'),
    (6,  2, 'view',     DATE '2024-01-02'),
    (7,  2, 'view',     DATE '2024-01-02'),
    (8,  2, 'view',     DATE '2024-01-03'),
    (9,  2, 'view',     DATE '2024-01-03'),
    (10, 2, 'view',     DATE '2024-01-04'),
    (11, 3, 'purchase', DATE '2024-01-05'),
    (12, 4, 'click',    DATE '2024-01-06'),
    (13, 4, 'click',    DATE '2024-01-06');
