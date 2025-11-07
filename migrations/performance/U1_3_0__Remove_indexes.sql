-- DBLift Demo - Remove Performance Indexes (Undo)
-- Description: Drops performance optimization indexes
-- Tags: performance, optimization, undo

-- Drop indexes added in V1_3_0__Add_indexes.sql
DROP INDEX IF EXISTS idx_products_search;
DROP INDEX IF EXISTS idx_orders_recent;
DROP INDEX IF EXISTS idx_products_low_stock;
DROP INDEX IF EXISTS idx_products_category_active;
DROP INDEX IF EXISTS idx_orders_customer_date;
DROP INDEX IF EXISTS idx_orders_customer_status;


