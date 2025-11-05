-- DBLift Demo - Seed Data
-- Populate tables with sample data for demonstrations

-- Seed users
INSERT INTO users (username, email, first_name, last_name, password_hash) VALUES
    ('john.doe', 'john.doe@example.com', 'John', 'Doe', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5ztC7L8Q7aKy6'),
    ('jane.smith', 'jane.smith@example.com', 'Jane', 'Smith', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5ztC7L8Q7aKy6'),
    ('bob.johnson', 'bob.johnson@example.com', 'Bob', 'Johnson', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5ztC7L8Q7aKy6'),
    ('alice.williams', 'alice.williams@example.com', 'Alice', 'Williams', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5ztC7L8Q7aKy6'),
    ('charlie.brown', 'charlie.brown@example.com', 'Charlie', 'Brown', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5ztC7L8Q7aKy6')
ON CONFLICT DO NOTHING;

-- Seed categories
INSERT INTO categories (name, description, parent_id) VALUES
    ('Electronics', 'Electronic devices and accessories', NULL),
    ('Computers', 'Desktop and laptop computers', 1),
    ('Mobile Devices', 'Smartphones and tablets', 1),
    ('Books', 'Physical and digital books', NULL),
    ('Clothing', 'Apparel and accessories', NULL),
    ('Accessories', 'Computer accessories', 2)
ON CONFLICT DO NOTHING;

-- Seed products
INSERT INTO products (category_id, sku, name, description, price, cost, quantity_in_stock, reorder_level) VALUES
    (2, 'COMP-001', 'Dell XPS 15', '15-inch high-performance laptop with Intel i7', 1299.99, 900.00, 50, 10),
    (2, 'COMP-002', 'MacBook Pro 16"', '16-inch laptop with M2 Pro chip', 2399.99, 1800.00, 30, 5),
    (2, 'COMP-003', 'Lenovo ThinkPad X1', 'Business laptop with excellent keyboard', 1599.99, 1100.00, 40, 10),
    (3, 'MOB-001', 'iPhone 15 Pro', 'Latest flagship smartphone from Apple', 999.99, 700.00, 100, 20),
    (3, 'MOB-002', 'Samsung Galaxy S24', 'Android flagship with AI features', 899.99, 650.00, 80, 20),
    (3, 'MOB-003', 'iPad Air', 'Versatile tablet for work and play', 599.99, 450.00, 60, 15),
    (4, 'BOOK-001', 'Clean Code', 'A Handbook of Agile Software Craftsmanship', 49.99, 20.00, 200, 50),
    (4, 'BOOK-002', 'Design Patterns', 'Elements of Reusable Object-Oriented Software', 54.99, 22.00, 150, 40),
    (4, 'BOOK-003', 'The Pragmatic Programmer', 'Your Journey to Mastery', 44.99, 18.00, 180, 45),
    (6, 'ACC-001', 'Wireless Mouse', 'Ergonomic wireless mouse', 29.99, 12.00, 300, 50),
    (6, 'ACC-002', 'Mechanical Keyboard', 'RGB mechanical gaming keyboard', 129.99, 60.00, 120, 30),
    (6, 'ACC-003', 'USB-C Hub', 'Multi-port USB-C adapter', 49.99, 20.00, 200, 40)
ON CONFLICT (sku) DO NOTHING;

-- Seed customers
INSERT INTO customers (user_id, company_name, contact_name, contact_email, phone, city, state, country) VALUES
    (2, 'Acme Corp', 'Jane Smith', 'jane.smith@acme.com', '555-0101', 'New York', 'NY', 'USA'),
    (3, NULL, 'Bob Johnson', 'bob.johnson@example.com', '555-0102', 'Los Angeles', 'CA', 'USA'),
    (4, 'TechStart Inc', 'Alice Williams', 'alice@techstart.com', '555-0103', 'San Francisco', 'CA', 'USA'),
    (5, 'Innovation Labs', 'Charlie Brown', 'charlie@innovationlabs.com', '555-0104', 'Seattle', 'WA', 'USA')
ON CONFLICT DO NOTHING;

-- Seed orders
INSERT INTO orders (customer_id, order_number, order_date, status, total_amount) VALUES
    (1, 'ORD-2024-001', '2024-01-15 10:30:00', 'delivered', 1349.98),
    (1, 'ORD-2024-002', '2024-02-01 14:20:00', 'shipped', 999.99),
    (2, 'ORD-2024-003', '2024-02-10 09:15:00', 'confirmed', 2449.98),
    (3, 'ORD-2024-004', '2024-02-15 16:45:00', 'pending', 899.99),
    (4, 'ORD-2024-005', '2024-02-20 11:00:00', 'delivered', 179.97)
ON CONFLICT (order_number) DO NOTHING;

-- Seed order items
INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_percent, line_total) VALUES
    (1, 1, 1, 1299.99, 0, 1299.99),
    (1, 7, 1, 49.99, 0, 49.99),
    (2, 4, 1, 999.99, 0, 999.99),
    (3, 2, 1, 2399.99, 0, 2399.99),
    (3, 7, 1, 49.99, 0, 49.99),
    (4, 5, 1, 899.99, 0, 899.99),
    (5, 10, 2, 29.99, 0, 59.98),
    (5, 11, 1, 129.99, 10, 116.99)
ON CONFLICT DO NOTHING;

-- Seed user preferences
INSERT INTO user_preferences (user_id, theme, language, timezone, email_notifications) VALUES
    (1, 'dark', 'en', 'America/New_York', true),
    (2, 'light', 'en', 'America/New_York', true),
    (3, 'auto', 'en', 'America/Los_Angeles', false),
    (4, 'dark', 'en', 'America/Los_Angeles', true),
    (5, 'light', 'en', 'America/Los_Angeles', true)
ON CONFLICT DO NOTHING;

-- Seed notifications
INSERT INTO notifications (user_id, type, channel, title, message, read) VALUES
    (2, 'success', 'in_app', 'Order Confirmed', 'Your order ORD-2024-001 has been confirmed', true),
    (2, 'info', 'email', 'Order Shipped', 'Your order ORD-2024-002 has been shipped', false),
    (3, 'success', 'in_app', 'Order Confirmed', 'Your order ORD-2024-003 has been confirmed', true),
    (4, 'info', 'in_app', 'New Product Available', 'Check out our latest arrivals', false)
ON CONFLICT DO NOTHING;

