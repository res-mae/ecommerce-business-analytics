-- Builds analytics.sales from raw.ecommerce_sales_customer_analytics_150k.
-- Applies the decisions in docs/cleaning_plan.md. Raw is never modified.

DROP TABLE IF EXISTS analytics.sales;

CREATE TABLE analytics.sales (
	order_id                   TEXT,
	order_date                 DATE,
	order_time                 TIME,
	order_status               TEXT,
	sales_channel              TEXT,
	customer_id                TEXT,
	customer_name              TEXT,
	customer_age               NUMERIC,
	gender                     TEXT,
	customer_segment           TEXT,
	customer_type              TEXT,
	customer_city              TEXT,
	customer_state             TEXT,
	customer_country           TEXT,
	region                     TEXT,
	customer_postal_code       TEXT,
	payment_method             TEXT,
	payment_status             TEXT,
	currency                   TEXT,
	shipping_method            TEXT,
	warehouse                  TEXT,
	delivery_days              NUMERIC,
	estimated_delivery_days    NUMERIC,
	delivery_status            TEXT,
	return_status              TEXT,
	return_reason              TEXT,
	customer_rating            NUMERIC,
	review_sentiment           TEXT,
	customer_review            TEXT,
	marketing_channel          TEXT,
	campaign_name              TEXT,
	coupon_code                TEXT,
	loyalty_points_earned      NUMERIC,
	loyalty_points_redeemed    NUMERIC,
	quantity                   NUMERIC,
	gross_sales                NUMERIC,
	discount_amount            NUMERIC,
	tax_amount                 NUMERIC,
	shipping_cost              NUMERIC,
	net_sales                  NUMERIC,
	product_cost               NUMERIC,
	profit                     NUMERIC,
	profit_margin_percentage   NUMERIC,
	customer_lifetime_value    NUMERIC,
	is_repeat_customer         BOOLEAN,
	customer_order_count       NUMERIC,
	has_campaign               BOOLEAN,
	has_coupon                 BOOLEAN
);

INSERT INTO analytics.sales (
	order_id,
	order_date,
	order_time,
	order_status,
	sales_channel,
	customer_id,
	customer_name,
	customer_age,
	gender,
	customer_segment,
	customer_type,
	customer_city,
	customer_state,
	customer_country,
	region,
	customer_postal_code,
	payment_method,
	payment_status,
	currency,
	shipping_method,
	warehouse,
	delivery_days,
	estimated_delivery_days,
	delivery_status,
	return_status,
	return_reason,
	customer_rating,
	review_sentiment,
	customer_review,
	marketing_channel,
	campaign_name,
	coupon_code,
	loyalty_points_earned,
	loyalty_points_redeemed,
	quantity,
	gross_sales,
	discount_amount,
	tax_amount,
	shipping_cost,
	net_sales,
	product_cost,
	profit,
	profit_margin_percentage,
	customer_lifetime_value,
	is_repeat_customer,
	customer_order_count,
	has_campaign,
	has_coupon
)
SELECT 
	order_id,
	order_date::DATE,
	order_time::TIME,
	order_status,
	sales_channel,
	customer_id,
	customer_name,
	customer_age,
	gender,
	customer_segment,
	customer_type,
	customer_city,
	customer_state,
	customer_country,
	region,
	customer_postal_code,
	payment_method,
	payment_status,
	currency,
	shipping_method,
	warehouse,
	delivery_days,
	estimated_delivery_days,
	delivery_status,
	return_status,
	return_reason,
	customer_rating,
	review_sentiment,
	customer_review,
	marketing_channel,
	campaign_name,
	coupon_code,
	loyalty_points_earned,
	loyalty_points_redeemed,
	quantity,
	ROUND(gross_sales,2),
	ROUND(discount_amount,2),
	ROUND(tax_amount,2),
	ROUND(shipping_cost,2),
	ROUND(net_sales,2),
	ROUND(product_cost,2),
	ROUND(profit,2),
	profit_margin_percentage,
	ROUND(customer_lifetime_value,2),
	CASE
		WHEN LOWER(is_repeat_customer) = 'true' THEN TRUE
		WHEN LOWER(is_repeat_customer) = 'false' THEN FALSE
	END,
	customer_order_count,
	campaign_name IS NOT NULL,
	coupon_code IS NOT NULL
FROM raw.ecommerce_sales_customer_analytics_150k;

-- analytics.sales: Check row count and order uniqueness
-- Result: 138116 row_count, 138116 unique_id
SELECT
	COUNT(*) AS row_count,
	COUNT(DISTINCT order_id) AS unique_id
FROM analytics.sales;

-- analytics.sales: Check converted values and flags
-- Result: 0 NULL for order_date, order_time, and is_repeat_customer
-- 54883 TRUE count for has_campaign and 27614 for has_coupon
SELECT
	COUNT(*) FILTER (WHERE order_date IS NULL) AS null_order_date,
	COUNT(*) FILTER (WHERE order_time IS NULL) AS null_order_time,
	COUNT(*) FILTER (WHERE is_repeat_customer IS NULL) AS null_repeat_flags,
	COUNT(*) FILTER (WHERE has_campaign) AS campaign_count,
	COUNT(*) FILTER (WHERE has_coupon) AS coupon_count
FROM analytics.sales;

-- analytics.sales: Check financial totals
-- Result: 177134263.74 total_net_sales, 76146395.76 total_profit
SELECT
	SUM(net_sales) AS total_net_sales,
	SUM(profit) AS total_profit
FROM analytics.sales;

-- analytics.sales: order_date range
-- Result: 2021-01-01 to 2025-12-31
SELECT
	MIN(order_date) AS min_order_date,
	MAX(order_date) AS max_order_date
FROM analytics.sales;

-- analytics.sales: money columns with more than 2 decimals
-- Result: 0 in all 8 columns
SELECT
	COUNT(*) FILTER (WHERE gross_sales IS DISTINCT FROM ROUND(gross_sales,2)) AS gross_sales_diff,
	COUNT(*) FILTER (WHERE discount_amount IS DISTINCT FROM ROUND(discount_amount,2)) AS discount_amount_diff,
	COUNT(*) FILTER (WHERE tax_amount IS DISTINCT FROM ROUND(tax_amount,2)) AS tax_amount_diff,
	COUNT(*) FILTER (WHERE shipping_cost IS DISTINCT FROM ROUND(shipping_cost,2)) AS shipping_cost_diff,
	COUNT(*) FILTER (WHERE net_sales IS DISTINCT FROM ROUND(net_sales,2)) AS net_sales_diff,
	COUNT(*) FILTER (WHERE product_cost IS DISTINCT FROM ROUND(product_cost,2)) AS product_cost_diff,
	COUNT(*) FILTER (WHERE profit IS DISTINCT FROM ROUND(profit,2)) AS profit_diff,
	COUNT(*) FILTER (WHERE customer_lifetime_value IS DISTINCT FROM ROUND(customer_lifetime_value,2)) AS customer_lifetime_value_diff
FROM analytics.sales;

-- analytics.sales: is_repeat_customer counts
-- Result: true 137782 | false 334
SELECT 
	is_repeat_customer,
	COUNT(*) AS total_rows
FROM analytics.sales
GROUP BY is_repeat_customer;

-- analytics.sales: column count and data types
-- Result: 48 columns
SELECT
	column_name,
	data_type,
	ordinal_position
FROM information_schema.columns
WHERE table_schema = 'analytics'
	AND table_name = 'sales'
ORDER BY ordinal_position;


-- Builds analytics.order_items from raw.order_items.
-- Applies the decisions in docs/cleaning_plan.md. Raw is never modified.

DROP TABLE IF EXISTS analytics.order_items;

CREATE TABLE analytics.order_items (
	order_id               TEXT,
	product_id             TEXT,
	quantity               NUMERIC,
	unit_price             NUMERIC,
	discount_percentage    NUMERIC,
	discount_amount        NUMERIC,
	gross_sales            NUMERIC,
	tax_amount             NUMERIC,
	shipping_cost          NUMERIC,
	net_sales              NUMERIC,
	product_cost           NUMERIC,
	profit                 NUMERIC
);

INSERT INTO analytics.order_items (
	order_id,
	product_id,
	quantity,
	unit_price,
	discount_percentage,
	discount_amount,
	gross_sales,
	tax_amount,
	shipping_cost,
	net_sales,
	product_cost,
	profit
)
SELECT
	order_id,
	product_id,
	quantity,
	unit_price,
	discount_percentage,
	discount_amount,
	gross_sales,
	tax_amount,
	ROUND(shipping_cost,2),
	net_sales,
	product_cost,
	profit
FROM raw.order_items;

-- analytics.order_items: Check row count and repeated pairs
-- Result: row_count 397569 | distinct order_id 138116 | distinct pairs 397482
SELECT
	COUNT(*) AS row_count,
	COUNT(DISTINCT order_id) AS distinct_order_id,
	COUNT(DISTINCT (order_id, product_id)) AS distinct_pairs
FROM analytics.order_items;

-- analytics.order_items: Verify shipping-cost rounding
-- Result: 0 rows with more than 2 decimals
SELECT
	COUNT(*) AS rows_with_more_than_2_decimals
FROM analytics.order_items
WHERE shipping_cost IS DISTINCT FROM ROUND(shipping_cost, 2);

-- analytics.order_items: Verify NULLs
-- Result: 0 in all 3 columns
SELECT
	COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
	COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
	COUNT(*) FILTER (WHERE shipping_cost IS NULL) AS null_shipping_cost
FROM analytics.order_items;

-- analytics.order_items: Total net sales and profit
-- Result: total net sales 192398877.29 | total profit 82698038.55
SELECT
	SUM(net_sales) AS total_net_sales,
	SUM(profit) AS total_profit
FROM analytics.order_items;

-- analytics.order_items: discount_percentage decimal places
-- Result: 343,632 rows differ from ROUND(discount_percentage, 2), same as raw, so full precision was kept.
SELECT
	COUNT(*) FILTER (WHERE discount_percentage IS DISTINCT FROM ROUND(discount_percentage,2)) AS total_rows
FROM analytics.order_items;

-- analytics.order_items: column count and data types
-- Result: 12 columns, same as raw.order_items
SELECT
	column_name,
	data_type,
	ordinal_position
FROM information_schema.columns
WHERE table_schema = 'analytics'
	AND table_name = 'order_items'
ORDER BY ordinal_position;


-- Builds analytics.customers from raw.customer_master.
-- Preserves all source rows and columns. Raw is never modified.

DROP TABLE IF EXISTS analytics.customers;

CREATE TABLE analytics.customers (
	customer_id                  TEXT,
	customer_name                TEXT,
	customer_age                 NUMERIC,
	gender                       TEXT,
	customer_segment             TEXT,
	customer_city                TEXT,
	customer_state               TEXT,
	customer_country             TEXT,
	region                       TEXT,
	customer_postal_code         TEXT,
	customer_acquisition_cost    NUMERIC
);

INSERT INTO analytics.customers (
	customer_id,
	customer_name,
	customer_age,
	gender,
	customer_segment,
	customer_city,
	customer_state,
	customer_country,
	region,
	customer_postal_code,
	customer_acquisition_cost
)
SELECT 
	customer_id,
	customer_name,
	customer_age,
	gender,
	customer_segment,
	customer_city,
	customer_state,
	customer_country,
	region,
	customer_postal_code,
	customer_acquisition_cost
FROM raw.customer_master;

-- analytics.customers: Verify customer table
-- Result: row count 25000 | distinct_customer_id 25000 | 0 null
SELECT
	COUNT(*) AS row_count,
	COUNT(DISTINCT customer_id) AS distinct_customer_id,
	COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id
FROM analytics.customers;

-- analytics.customers: column count and data types
-- Result: 11 columns, same as raw.customer_master
SELECT
	column_name,
	data_type,
	ordinal_position
FROM information_schema.columns
WHERE table_schema = 'analytics'
	AND table_name = 'customers'
ORDER BY ordinal_position;


-- Builds analytics.products from raw.product_catalog.
-- Preserves all source rows and columns. Raw is never modified.

DROP TABLE IF EXISTS analytics.products;

CREATE TABLE analytics.products (
	product_id            TEXT,
	product_name          TEXT,
	product_category      TEXT,
	product_subcategory   TEXT,
	brand                 TEXT,
	supplier              TEXT,
	unit_price            NUMERIC,
	product_cost          NUMERIC,
	product_rating        NUMERIC
);

INSERT INTO analytics.products (
	product_id,
	product_name,
	product_category,
	product_subcategory,
	brand,
	supplier,
	unit_price,
	product_cost,
	product_rating
)
SELECT
	product_id,
	product_name,
	product_category,
	product_subcategory,
	brand,
	supplier,
	unit_price,
	product_cost,
	product_rating
FROM raw.product_catalog;

-- analytics.products: Verify product table
-- Result: row count 1175 | distinct product_id 1175 | 0 null
SELECT
	COUNT(*) AS row_count,
	COUNT(DISTINCT product_id) AS distinct_product_id,
	COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id
FROM analytics.products;

-- analytics.products: column count and data types
-- Result: 9 columns, same as raw.product_catalog
SELECT
	column_name,
	data_type,
	ordinal_position
FROM information_schema.columns
WHERE table_schema = 'analytics'
	AND table_name = 'products'
ORDER BY ordinal_position;


---- analytics cross table check.

-- analytics.sales.customer_id with no match in analytics.customers
-- Result: 0
SELECT
	COUNT(*)
FROM analytics.sales s
WHERE NOT EXISTS (
	SELECT 1
	FROM analytics.customers c
	WHERE s.customer_id = c.customer_id
);

-- analytics.order_items.product_id with no match in analytics.products
-- Result: 0
SELECT
	COUNT(*)
FROM analytics.order_items o
WHERE NOT EXISTS (
	SELECT 1
	FROM analytics.products p
	WHERE o.product_id = p.product_id
);

-- analytics.order_items.order_id with no match in analytics.sales
-- Result: 0
SELECT
	COUNT(*)
FROM analytics.order_items o
WHERE NOT EXISTS (
	SELECT 1
	FROM analytics.sales s
	WHERE o.order_id = s.order_id
);

-- analytics.sales.order_id with no match in analytics.order_items
-- Result: 0
SELECT
	COUNT(*)
FROM analytics.sales s
WHERE NOT EXISTS (
	SELECT 1
	FROM analytics.order_items o
	WHERE o.order_id = s.order_id
);

-- analytics.customers with no orders in analytics.sales
-- Result: 89
SELECT
	COUNT(*)
FROM analytics.customers c
WHERE NOT EXISTS (
	SELECT 1
	FROM analytics.sales s
	WHERE c.customer_id = s.customer_id
);
