CREATE DATABASE projects;
USE projects;

CREATE TABLE customers(
 customer_id INT PRIMARY KEY,
 signup_date DATE,
 device_type VARCHAR(20),
 traffic_source VARCHAR(20));

CREATE TABLE products(
 product_id INT PRIMARY KEY,
 category VARCHAR(50),
 price FLOAT,
 brand VARCHAR(50));

CREATE TABLE events(
 event_id INT PRIMARY KEY,
 customer_id INT,
 product_id INT,
 event_type VARCHAR(30),
 event_time DATETIME);

CREATE TABLE orders(
 order_id INT PRIMARY KEY,
 customer_id INT,
 product_id INT,
 order_value FLOAT,
 purchase_time DATETIME);
 
SHOW VARIABLES LIKE 'secure_file_priv';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/events.csv'
INTO TABLE events
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

select * from customers;
select * from events;
select * from orders;
select * from products;

## Row Counts

SELECT 'customers' AS table_name, COUNT(*) AS rows_count FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'events', COUNT(*) FROM events
UNION ALL
SELECT 'orders', COUNT(*) FROM orders;


## Quantifying Null values

-- Customers
SELECT
  SUM(customer_id IS NULL) AS null_customer_id,
  SUM(device_type IS NULL) AS null_device_type,
  SUM(traffic_source IS NULL) AS null_traffic_source
FROM customers;

-- Products
SELECT
  SUM(product_id IS NULL) AS null_product_id,
  SUM(category IS NULL) AS null_category,
  SUM(price IS NULL OR price <= 0) AS invalid_price
FROM products;

-- Events
SELECT
  SUM(event_id IS NULL) AS null_event_id,
  SUM(customer_id IS NULL) AS null_customer_id,
  SUM(product_id IS NULL) AS null_product_id,
  SUM(event_type IS NULL) AS null_event_type,
  SUM(event_time IS NULL) AS null_event_time
FROM events;

-- Orders
SELECT
  SUM(order_id IS NULL) AS null_order_id,
  SUM(customer_id IS NULL) AS null_customer_id,
  SUM(order_value IS NULL OR order_value <= 0) AS invalid_order_value,
  SUM(purchase_time IS NULL) AS null_purchase_time
FROM orders;

## Duplicates Checking

-- Duplicate customers (same signup + device + source)
SELECT signup_date, device_type, traffic_source, COUNT(*) AS cnt
FROM customers
GROUP BY signup_date, device_type, traffic_source
HAVING COUNT(*) > 1
LIMIT 10;

-- Duplicate products
SELECT category, price, COUNT(*) AS cnt
FROM products
GROUP BY category, price
HAVING COUNT(*) > 1
LIMIT 10;

-- Duplicate events (same user, product, type, time)
SELECT customer_id, product_id, event_type, event_time, COUNT(*) AS cnt
FROM events
GROUP BY customer_id, product_id, event_type, event_time
HAVING COUNT(*) > 1
LIMIT 10;

-- Duplicate orders
SELECT customer_id, product_id, order_value, purchase_time, COUNT(*) AS cnt
FROM orders
GROUP BY customer_id, product_id, order_value, purchase_time
HAVING COUNT(*) > 1
LIMIT 10;

## Funnel Validity checks

-- Purchases without checkout
SELECT COUNT(DISTINCT customer_id) AS purchase_without_checkout
FROM events
WHERE event_type = 'purchase'
AND customer_id NOT IN 
(SELECT customer_id FROM events WHERE event_type = 'begin_checkout');

-- Checkout without cart
SELECT COUNT(DISTINCT customer_id) AS checkout_without_cart
FROM events
WHERE event_type = 'begin_checkout'
AND customer_id NOT IN 
(SELECT customer_id FROM events WHERE event_type = 'add_to_cart');

## Data Cleaning

CREATE TABLE events_clean AS
SELECT * FROM 
(SELECT *,
ROW_NUMBER() OVER (PARTITION BY customer_id, product_id, event_type, event_time ORDER BY event_id) AS rn
FROM events) t
WHERE rn = 1
AND event_type IS NOT NULL;

CREATE TABLE orders_clean AS
SELECT * FROM (SELECT *,
ROW_NUMBER() OVER (PARTITION BY customer_id, order_value, purchase_time ORDER BY order_id) AS rn
FROM orders) t
WHERE rn = 1
AND order_value IS NOT NULL
AND order_value > 0;

CREATE TABLE customers_clean AS
SELECT DISTINCT customer_id,
signup_date,
device_type,
COALESCE(traffic_source, 'unknown') AS traffic_source
FROM customers;

CREATE TABLE products_clean AS
SELECT DISTINCT
product_id,
COALESCE(category, 'unknown') AS category,
price,
brand
FROM products
WHERE price IS NOT NULL AND price > 0;

SELECT 'customers_clean' AS table_name, COUNT(*) FROM customers_clean
UNION ALL
SELECT 'products_clean', COUNT(*) FROM products_clean
UNION ALL
SELECT 'events_clean', COUNT(*) FROM events_clean
UNION ALL
SELECT 'orders_clean', COUNT(*) FROM orders_clean;

## Ordered event timestamps per customer

WITH event_times AS 
(SELECT customer_id,
MIN(CASE WHEN event_type = 'view_product' THEN event_time END) AS view_time,
MIN(CASE WHEN event_type = 'add_to_cart' THEN event_time END) AS cart_time,
MIN(CASE WHEN event_type = 'begin_checkout' THEN event_time END) AS checkout_time,
MIN(CASE WHEN event_type = 'purchase' THEN event_time END) AS purchase_time
FROM events_clean
GROUP BY customer_id)
SELECT * FROM event_times
LIMIT 10;

## The time-validated funnel view

CREATE OR REPLACE VIEW funnel_ordered AS
WITH event_times AS 
(SELECT customer_id,
MIN(CASE WHEN event_type = 'view_product' THEN event_time END) AS view_time,
MIN(CASE WHEN event_type = 'add_to_cart' THEN event_time END) AS cart_time,
MIN(CASE WHEN event_type = 'begin_checkout' THEN event_time END) AS checkout_time,
MIN(CASE WHEN event_type = 'purchase' THEN event_time END) AS purchase_time
FROM events_clean
GROUP BY customer_id)
SELECT customer_id, view_time IS NOT NULL AS viewed,
cart_time IS NOT NULL AND cart_time > view_time AS carted,
checkout_time IS NOT NULL AND checkout_time > cart_time AS checkout,
purchase_time IS NOT NULL AND purchase_time > checkout_time AS purchased
FROM event_times;

## Conversions

SELECT SUM(viewed) AS views,
SUM(carted) AS carts,
SUM(checkout) AS checkouts,
SUM(purchased) AS purchases,
ROUND(SUM(carted)*100.0/SUM(viewed),2) AS view_to_cart_pct,
ROUND(SUM(checkout)*100.0/SUM(carted),2) AS cart_to_checkout_pct,
ROUND(SUM(purchased)*100.0/SUM(checkout),2) AS checkout_to_purchase_pct
FROM funnel_ordered;

## Revenue Baseline

SELECT COUNT(*) AS total_orders,
ROUND(SUM(order_value),2) AS total_revenue,
ROUND(AVG(order_value),2) AS avg_order_value
FROM orders_clean;

## Stage wise Drop offs

SELECT SUM(viewed - carted) AS drop_after_view,
SUM(carted - checkout) AS drop_after_cart,
SUM(checkout - purchased) AS drop_after_checkout
FROM funnel_ordered;

## Revenue at Risk

SELECT ROUND(SUM(viewed - carted) * (SELECT AVG(order_value) FROM orders_clean),2) AS revenue_risk_after_view,
ROUND(SUM(carted - checkout) * (SELECT AVG(order_value) FROM orders_clean),2) AS revenue_risk_after_cart,
ROUND(SUM(checkout - purchased) * (SELECT AVG(order_value) FROM orders_clean),2) AS revenue_risk_after_checkout
FROM funnel_ordered;

## Funnel by Device

SELECT c.device_type,
COUNT(*) AS users,
SUM(f.purchased) AS buyers,
ROUND(SUM(f.purchased)*100.0/COUNT(*),2) AS conversion_pct
FROM funnel_ordered f JOIN customers_clean c
ON f.customer_id = c.customer_id
GROUP BY c.device_type
ORDER BY conversion_pct;

## View → Cart by CATEGORY

WITH views AS (SELECT f.customer_id, p.category
FROM funnel_ordered f
JOIN events_clean e ON f.customer_id = e.customer_id
JOIN products_clean p ON e.product_id = p.product_id
WHERE e.event_type = 'view_product')
SELECT category,
COUNT(DISTINCT customer_id) AS viewers,
COUNT(DISTINCT CASE WHEN customer_id IN 
(SELECT customer_id FROM funnel_ordered WHERE carted = 1) 
THEN customer_id END) AS cart_users,
ROUND(COUNT(DISTINCT CASE WHEN customer_id IN 
(SELECT customer_id FROM funnel_ordered WHERE carted = 1) 
THEN customer_id END) * 100.0 / COUNT(DISTINCT customer_id),2) AS view_to_cart_pct
FROM views
GROUP BY category
ORDER BY view_to_cart_pct;

## View → Cart by Price Band

WITH views AS 
(SELECT f.customer_id, p.price
FROM funnel_ordered f
JOIN events_clean e ON f.customer_id = e.customer_id
JOIN products_clean p ON e.product_id = p.product_id
WHERE e.event_type = 'view_product')
SELECT CASE
WHEN price < 500 THEN 'Low'
WHEN price BETWEEN 500 AND 2000 THEN 'Mid'
ELSE 'High'
END AS price_band,
COUNT(DISTINCT customer_id) AS viewers,
COUNT(DISTINCT CASE WHEN customer_id IN 
(SELECT customer_id FROM funnel_ordered WHERE carted = 1) 
THEN customer_id END) AS cart_users,
ROUND(COUNT(DISTINCT CASE WHEN customer_id IN 
(SELECT customer_id FROM funnel_ordered WHERE carted = 1) 
THEN customer_id END) * 100.0 / COUNT(DISTINCT customer_id),2) AS view_to_cart_pct
FROM views
GROUP BY price_band
ORDER BY view_to_cart_pct;