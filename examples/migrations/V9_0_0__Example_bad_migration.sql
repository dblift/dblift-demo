-- DBLift Demo - Example Bad Migration
-- This migration intentionally contains validation errors for CI/CD demo
-- DO NOT USE IN PRODUCTION

-- Violation 1: Table without primary ke
-- Violation 2: Missing audit columns (created_at, updated_at, created_by)
CREATE TABLE bad_example_table (
    name VARCHAR(100),
    description TEXT
);

-- Violation 3: INSERT without column list (relies on source order)
INSERT INTO bad_example_table SELECT username, email FROM users;

-- Violation 4: DELETE without WHERE clause
DELETE FROM bad_example_table;

-- Violation 5: No comment on table
-- Violation 6: Column naming not snake_case
CREATE TABLE AnotherBadTable (
    ID INTEGER PRIMARY KEY,
    UserName VARCHAR(50),
    EmailAddress VARCHAR(100)
);

