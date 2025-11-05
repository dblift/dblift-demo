-- DBLift Demo - Functions
-- Description: Utility functions
-- Repeatable migration

-- Function to calculate order total
CREATE OR REPLACE FUNCTION calculate_order_total(p_order_id INTEGER)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    v_total DECIMAL(10, 2);
BEGIN
    SELECT COALESCE(SUM(line_total), 0)
    INTO v_total
    FROM order_items
    WHERE order_id = p_order_id;
    
    RETURN v_total;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_order_total IS 'Calculate total amount for an order';

-- Function to check stock availability
CREATE OR REPLACE FUNCTION check_stock_availability(p_product_id INTEGER, p_quantity INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    v_current_stock INTEGER;
BEGIN
    SELECT quantity_in_stock
    INTO v_current_stock
    FROM products
    WHERE id = p_product_id AND is_active = TRUE;
    
    RETURN v_current_stock >= p_quantity;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION check_stock_availability IS 'Check if product has sufficient stock';

-- Function to update product stock
CREATE OR REPLACE FUNCTION update_product_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE products
        SET quantity_in_stock = quantity_in_stock - NEW.quantity
        WHERE id = NEW.product_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE products
        SET quantity_in_stock = quantity_in_stock + OLD.quantity
        WHERE id = OLD.product_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_product_stock IS 'Trigger function to update product stock on order changes';

-- Create trigger
DROP TRIGGER IF EXISTS trg_update_product_stock ON order_items;
CREATE TRIGGER trg_update_product_stock
    AFTER INSERT OR UPDATE OR DELETE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_product_stock();

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_updated_at_column IS 'Automatically update updated_at timestamp';

-- Create triggers for updated_at
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

