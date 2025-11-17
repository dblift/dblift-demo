-- DBLift Demo - Remove Orders (Undo)
-- Description: Rollback order management tables
-- Tags: core, orders

-- Drop in reverse order of creation
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TYPE IF EXISTS order_status;

-- Note: This is a demonstration undo migration
-- In production, ensure data is backed up before rollback

