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

-- Check row count and order uniqueness
SELECT
	COUNT(*) AS row_count,
	COUNT(DISTINCT order_id) AS unique_id
FROM analytics.sales;

-- Check converted values and flags
SELECT
	COUNT(*) FILTER (WHERE order_date IS NULL) AS null_order_date,
	COUNT(*) FILTER (WHERE order_time IS NULL) AS null_order_time,
	COUNT(*) FILTER (WHERE is_repeat_customer IS NULL) AS null_repeat_flags,
	COUNT(*) FILTER (WHERE has_campaign) AS campaign_count,
	COUNT(*) FILTER (WHERE has_coupon) AS coupon_count
FROM analytics.sales;

-- Check financial totals
SELECT
	SUM(net_sales) AS total_net_sales,
	SUM(profit) AS total_profit
FROM analytics.sales;


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

-- Check row count and repeated pairs
SELECT
	COUNT(*) AS row_count,
	COUNT(DISTINCT order_id) AS distinct_order_id,
	COUNT(DISTINCT (order_id, product_id)) AS distinct_pairs
FROM analytics.order_items;

-- Verify shipping-cost rounding
SELECT
	COUNT(*) AS rows_with_more_than_2_decimals
FROM analytics.order_items
WHERE shipping_cost IS DISTINCT FROM ROUND(shipping_cost, 2);

-- Verify NULLs
SELECT
	COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
	COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
	COUNT(*) FILTER (WHERE shipping_cost IS NULL) AS null_shipping_cost
FROM analytics.order_items;




	
	