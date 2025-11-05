-- DBLift Demo - Simulate Schema Drift
-- This script makes manual changes to demonstrate drift detection

-- Add columns not in migrations
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
ALTER TABLE users ADD COLUMN IF NOT EXISTS department VARCHAR(50);

-- Create an unmanaged table
CREATE TABLE IF NOT EXISTS temp_imports (
    id SERIAL PRIMARY KEY,
    data JSONB,
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Drop an index
DROP INDEX IF EXISTS idx_users_email;

-- Modify a column (add default)
ALTER TABLE products ALTER COLUMN is_active SET DEFAULT FALSE;

-- Add an unmanaged constraint
ALTER TABLE customers 
ADD CONSTRAINT IF NOT EXISTS chk_email_format 
CHECK (contact_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$');

-- Create unmanaged view
CREATE OR REPLACE VIEW v_unmanaged_report AS
SELECT u.username, COUNT(o.id) as order_count
FROM users u
LEFT JOIN customers c ON u.id = c.user_id
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY u.username;

-- Add comment
COMMENT ON TABLE temp_imports IS 'Temporary table for data imports (not managed by migrations)';

