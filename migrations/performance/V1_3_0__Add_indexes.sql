-- DBLift Demo - Performance Indexes
-- Description: Additional indexes for query optimization
-- Tags: performance, optimization

-- Composite indexes for common queries
CREATE INDEX idx_orders_customer_status ON orders(customer_id, status);
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date DESC);
CREATE INDEX idx_products_category_active ON products(category_id, is_active) WHERE is_active = TRUE;

-- Partial indexes for frequently queried subsets
CREATE INDEX idx_orders_recent ON orders(order_date) 
WHERE order_date > CURRENT_DATE - INTERVAL '90 days';

CREATE INDEX idx_products_low_stock ON products(quantity_in_stock) 
WHERE quantity_in_stock <= reorder_level;

-- Full-text search indexes (PostgreSQL specific)
CREATE INDEX idx_products_search ON products USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '')));

COMMENT ON INDEX idx_products_search IS 'Full-text search index for product name and description';

