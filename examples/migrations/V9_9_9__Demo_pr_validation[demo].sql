-- DBLift Demo - Example migration to trigger PR validation failures
-- Intentionally violates multiple validation rules to showcase the workflow.

CREATE TABLE pr_validation_demo (
    id SERIAL,
    DemoName VARCHAR(100),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    payload JSONB
);

-- Missing primary key constraint
-- Mixed-case column names (breaks naming rules)
-- Missing NOT NULL / default audit values

INSERT INTO pr_validation_demo
SELECT id, username, created_at, updated_at, NULL
FROM users;

DELETE FROM pr_validation_demo;

