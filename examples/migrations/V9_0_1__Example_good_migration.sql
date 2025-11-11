-- DBLift Demo - Example Good Migration
-- This migration follows all validation rules
-- Description: Create example table with proper structure

-- ✅ Has primary key
-- ✅ Has audit columns
-- ✅ Has table comment
-- ✅ Proper naming conventions
CREATE TABLE good_example_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);

CREATE INDEX idx_good_example_status ON good_example_table(status);

COMMENT ON TABLE good_example_table IS 'Example table demonstrating best practices';

-- ✅ Explicit column list (no SELECT *)
INSERT INTO good_example_table (name, description, created_by)
SELECT username, email, 'migration'
FROM users
WHERE id < 100;

-- ✅ DELETE with WHERE clause
DELETE FROM good_example_table 
WHERE created_at < CURRENT_DATE - INTERVAL '1 year';

