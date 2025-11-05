-- DBLift Demo - Views
-- Description: Database views for reporting
-- Repeatable migration - will be re-executed if content changes

-- Active products view
CREATE OR REPLACE VIEW v_active_products AS
SELECT 
    p.id,
    p.sku,
    p.name,
    p.price,
    p.quantity_in_stock,
    c.name AS category_name,
    CASE 
        WHEN p.quantity_in_stock <= p.reorder_level THEN 'LOW_STOCK'
        WHEN p.quantity_in_stock = 0 THEN 'OUT_OF_STOCK'
        ELSE 'IN_STOCK'
    END AS stock_status
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
WHERE p.is_active = TRUE;

COMMENT ON VIEW v_active_products IS 'Active products with stock status';

-- Customer order summary
CREATE OR REPLACE VIEW v_customer_order_summary AS
SELECT 
    c.id AS customer_id,
    c.contact_name,
    c.contact_email,
    COUNT(DISTINCT o.id) AS total_orders,
    SUM(o.total_amount) AS total_spent,
    MAX(o.order_date) AS last_order_date,
    AVG(o.total_amount) AS avg_order_value
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.contact_name, c.contact_email;

COMMENT ON VIEW v_customer_order_summary IS 'Customer lifetime value and order statistics';

-- Order details view (with line items)
CREATE OR REPLACE VIEW v_order_details AS
SELECT 
    o.id AS order_id,
    o.order_number,
    o.order_date,
    o.status,
    c.contact_name AS customer_name,
    c.contact_email AS customer_email,
    oi.id AS item_id,
    p.name AS product_name,
    p.sku AS product_sku,
    oi.quantity,
    oi.unit_price,
    oi.discount_percent,
    oi.line_total
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id;

COMMENT ON VIEW v_order_details IS 'Complete order information with line items';

-- User activity summary
CREATE OR REPLACE VIEW v_user_activity AS
SELECT 
    u.id AS user_id,
    u.username,
    u.email,
    COUNT(DISTINCT us.id) AS session_count,
    MAX(us.last_activity) AS last_activity,
    COUNT(DISTINCT n.id) AS notification_count,
    COUNT(DISTINCT n.id) FILTER (WHERE n.read = FALSE) AS unread_notifications
FROM users u
LEFT JOIN user_sessions us ON u.id = us.user_id
LEFT JOIN notifications n ON u.id = n.user_id
GROUP BY u.id, u.username, u.email;

COMMENT ON VIEW v_user_activity IS 'User activity and notification summary';

