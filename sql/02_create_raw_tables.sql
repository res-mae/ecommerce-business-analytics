-- Raw tables mirror the source CSVs. No cleaning is done at this layer.

-- Source: data/raw/product_catalog.csv
CREATE TABLE raw.product_catalog (
	product_id TEXT,
	product_name TEXT,
	product_category TEXT,
	product_subcategory TEXT,
	brand TEXT,
	supplier TEXT,
	unit_price NUMERIC,
	product_cost NUMERIC,
	product_rating NUMERIC
);

-- Source: data/raw/customer_master.csv
CREATE TABLE raw.customer_master (
	customer_id TEXT,
	customer_name TEXT,
	customer_age NUMERIC,
	gender TEXT,
	customer_segment TEXT,
	customer_city TEXT,
	customer_state TEXT,
	customer_country TEXT,
	region TEXT,
	customer_postal_code TEXT,
	customer_acquisition_cost NUMERIC
);

-- Source: data/raw/order_items.csv
CREATE TABLE raw.order_items (
	order_id TEXT,
	product_id TEXT,
	quantity NUMERIC,
	unit_price NUMERIC,
	discount_percentage NUMERIC,
	discount_amount NUMERIC,
	gross_sales NUMERIC,
	tax_amount NUMERIC,
	shipping_cost NUMERIC,
	net_sales NUMERIC,
	product_cost NUMERIC,
	profit NUMERIC
);

-- Source: data/raw/ecommerce_sales_customer_analytics_150k.csv
CREATE TABLE raw.ecommerce_sales_customer_analytics_150k (
	order_id TEXT,
	order_date TEXT,
	order_time TEXT,
	order_status TEXT,
	sales_channel TEXT,
	customer_id TEXT,
	customer_name TEXT,
	customer_age NUMERIC,
	gender TEXT,
	customer_segment TEXT,
	customer_type TEXT,
	customer_city TEXT,
	customer_state TEXT,
	customer_country TEXT,
	region TEXT,
	customer_postal_code TEXT,
	payment_method TEXT,
	payment_status TEXT,
	currency TEXT,
	shipping_method TEXT,
	warehouse TEXT,
	delivery_days NUMERIC,
	estimated_delivery_days NUMERIC,
	delivery_status TEXT,
	return_status TEXT,
	return_reason TEXT,
	customer_rating NUMERIC,
	review_sentiment TEXT,
	customer_review TEXT,
	marketing_channel TEXT,
	campaign_name TEXT,
	coupon_code TEXT,
	loyalty_points_earned NUMERIC,
	loyalty_points_redeemed NUMERIC,
	quantity NUMERIC,
	gross_sales NUMERIC,
	discount_amount NUMERIC,
	tax_amount NUMERIC,
	shipping_cost NUMERIC,
	net_sales NUMERIC,
	product_cost NUMERIC,
	profit NUMERIC,
	profit_margin_percentage NUMERIC,
	customer_lifetime_value NUMERIC,
	is_repeat_customer TEXT,
	customer_order_count NUMERIC
);

-- Source: data/raw/dataset_statistics.csv
CREATE TABLE raw.dataset_statistics (
	total_transactions NUMERIC,
	total_columns NUMERIC,
	total_customers NUMERIC,
	total_products_used NUMERIC,
	date_range TEXT,
	total_revenue TEXT,
	total_profit TEXT,
	average_order_value TEXT,
	average_rating NUMERIC,
	return_rate TEXT,
	cancellation_rate TEXT
);
