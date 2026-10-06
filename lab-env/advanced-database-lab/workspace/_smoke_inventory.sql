DROP TABLE IF EXISTS inventory;
CREATE TABLE inventory (
  item_id   SERIAL PRIMARY KEY,
  item_name VARCHAR(100) NOT NULL,
  quantity  INT DEFAULT 0,
  price     NUMERIC(10,2)
);
INSERT INTO inventory (item_name, quantity, price) VALUES
  ('Laptop', 15, 1299.99),
  ('Wireless Mouse', 50, 24.95),
  ('Mechanical Keyboard', 29, 89.50);
SELECT count(*) AS rows_inserted, sum(quantity) AS total_qty, sum(quantity*price) AS total_value FROM inventory;
