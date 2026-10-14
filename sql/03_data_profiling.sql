-- STEP 1: STRUCTURE AND VOLUME
-- Completed during raw loading (see docs/data_quality_log.md).
-- Row counts: product_catalog 1,175 | customer_master 25,000 |
--             order_items 397,569 | sales 138,116 | dataset_statistics 1


-- STEP 2: GRAIN AND KEYS
-- product_catalog: is product_id unique? 
-- Result: 1,175 rows, 1,175 distinct product_id -> unique
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT product_id) AS distinct_products
FROM raw.product_catalog;

-- customer_master: is customer_id unique? 
-- Result: 25,000 rows, 25,000 distinct customer_id -> unique
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT customer_id) AS distinct_customers
FROM raw.customer_master;

-- order_items: is (order_id, product_id) unique?
-- Result: 397,569 rows, 138,116 distinct order_id, 397,482 distinct pairs -> NOT unique (87 surplus rows)
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT order_id) AS distinct_orders,
	COUNT(DISTINCT (order_id, product_id)) AS distinct_order_product_pairs
FROM raw.order_items;

-- ecommerce_sales_customer_analytics_150k: is order_id unique?
-- Result: 138,116 rows, 138,116 distinct order_id -> unique
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT order_id) AS distinct_orders
FROM raw.ecommerce_sales_customer_analytics_150k;

-- STEP 2b: ORDER_ITEMS REPEATED PAIRS
-- order_items: surplus (order_id, product_id) pairs
-- Result: rows_per_pair = 2, 87 repeated pairs, 87 surplus rows (reconciles with the gap)
WITH pair AS (
    SELECT
        order_id,
        product_id,
        COUNT(*) AS rows_per_pair
    FROM raw.order_items
    GROUP BY order_id, product_id
    HAVING COUNT(*) > 1
)
SELECT
    rows_per_pair,
    COUNT(*) AS repeated_pairs,
    SUM(rows_per_pair - 1) AS surplus_rows
FROM pair
GROUP BY rows_per_pair
ORDER BY rows_per_pair;

-- order_items: how many of the pairs are fully identical?
-- Result: distinct_entries = 2 for all 87 pairs -> none are exact copies
WITH pair AS (
	SELECT
		order_id,
		product_id,
		COUNT(*) AS rows_per_pair,
		COUNT(DISTINCT ROW(
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
		)) AS distinct_entries
	FROM raw.order_items
	GROUP BY order_id, product_id
	HAVING COUNT(*) > 1
)
SELECT
	distinct_entries,
	COUNT(*) AS pair_count
FROM pair
GROUP BY distinct_entries
ORDER BY pair_count DESC;

-- order_items: which columns differ on each pair?
-- from a 5-pair sample
-- Result: in the sample, unit_price is the same; quantity, discount and the other money columns differ
WITH pair AS (
    SELECT
        order_id,
        product_id
    FROM raw.order_items
    GROUP BY order_id, product_id
    HAVING COUNT(*) > 1
)
SELECT o.*
FROM pair AS p
INNER JOIN raw.order_items AS o
	ON p.order_id = o.order_id AND p.product_id = o.product_id
ORDER BY p.order_id, p.product_id
LIMIT 10;

-- order_items: how do the columns differ?
-- Result (quantity / unit_price / discount_pct differs -> pairs):
-- yes/no/yes -> 69 | no/no/yes -> 15 | yes/no/no -> 2 | no/no/no -> 1  (total 87)
WITH pair AS (
	SELECT
		order_id,
		product_id,
		COUNT(DISTINCT quantity) > 1 AS is_quantity_distinct,
		COUNT(DISTINCT unit_price) > 1 AS is_unit_price_distinct,
		COUNT(DISTINCT discount_percentage) > 1 AS is_discount_pct_distinct
	FROM raw.order_items
	GROUP BY order_id, product_id
	HAVING COUNT(*) > 1
)
SELECT 
	is_quantity_distinct, 
	is_unit_price_distinct, 
	is_discount_pct_distinct,
	COUNT(*) AS total_rows
FROM pair
GROUP BY is_quantity_distinct, 
		is_unit_price_distinct, 
		is_discount_pct_distinct
ORDER BY COUNT(*) DESC;

-- order_items: Check one pair having the same quantity, unit_price, and discount_percentage
-- Result: 2 rows; tax_amount, shipping_cost, net_sales and profit differ by more than 3 each
WITH pair AS (
	SELECT
		order_id,
		product_id,
		COUNT(DISTINCT quantity) > 1 AS is_quantity_distinct,
		COUNT(DISTINCT unit_price) > 1 AS is_unit_price_distinct,
		COUNT(DISTINCT discount_percentage) > 1 AS is_discount_pct_distinct
	FROM raw.order_items
	GROUP BY order_id, product_id
	HAVING COUNT(*) > 1
)
SELECT o.*
FROM pair AS p
INNER JOIN raw.order_items AS o
ON p.order_id = o.order_id AND p.product_id = o.product_id
WHERE NOT is_quantity_distinct
	AND NOT is_unit_price_distinct
	AND NOT is_discount_pct_distinct;

-- order_items: how many rows have gross_sales different from quantity * unit_price?
-- Result: 0 -> gross_sales is consistent across all 397,569 rows
SELECT 
	COUNT(*)
FROM raw.order_items
WHERE ROUND(gross_sales,2) IS DISTINCT FROM ROUND(quantity * unit_price, 2);


-- STEP 3: COMPLETENESS
-- ecommerce_sales_customer_analytics_150k: which columns contain NULLs and how many each?
-- generated from information_schema.columns
SELECT
    'SELECT ' ||
    string_agg(
        format(
            'COUNT(*) FILTER (WHERE %I IS NULL) AS %I',
            column_name,
            column_name || '_nulls'
        ),
        ', '
    ) ||
    ' FROM raw.ecommerce_sales_customer_analytics_150k;'
FROM information_schema.columns
WHERE table_schema = 'raw'
  AND table_name = 'ecommerce_sales_customer_analytics_150k';

-- Result (138,116 rows; 37 other columns have 0 NULLs):
-- delivery_days            24,557 (17.8%)
-- estimated_delivery_days  24,557 (17.8%)
-- customer_rating          24,557 (17.8%)
-- review_sentiment         24,557 (17.8%)
-- customer_review          24,557 (17.8%)
-- return_status           128,654 (93.1%)
-- return_reason           128,654 (93.1%)
-- campaign_name            83,233 (60.3%)
-- coupon_code             110,502 (80.0%)
SELECT 
	COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_nulls, 
	COUNT(*) FILTER (WHERE order_date IS NULL) AS order_date_nulls, 
	COUNT(*) FILTER (WHERE order_time IS NULL) AS order_time_nulls, 
	COUNT(*) FILTER (WHERE order_status IS NULL) AS order_status_nulls, 
	COUNT(*) FILTER (WHERE sales_channel IS NULL) AS sales_channel_nulls, 
	COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_nulls, 
	COUNT(*) FILTER (WHERE customer_name IS NULL) AS customer_name_nulls, 
	COUNT(*) FILTER (WHERE customer_age IS NULL) AS customer_age_nulls, 
	COUNT(*) FILTER (WHERE gender IS NULL) AS gender_nulls, 
	COUNT(*) FILTER (WHERE customer_segment IS NULL) AS customer_segment_nulls, 
	COUNT(*) FILTER (WHERE customer_type IS NULL) AS customer_type_nulls, 
	COUNT(*) FILTER (WHERE customer_city IS NULL) AS customer_city_nulls, 
	COUNT(*) FILTER (WHERE customer_state IS NULL) AS customer_state_nulls, 
	COUNT(*) FILTER (WHERE customer_country IS NULL) AS customer_country_nulls, 
	COUNT(*) FILTER (WHERE region IS NULL) AS region_nulls, 
	COUNT(*) FILTER (WHERE customer_postal_code IS NULL) AS customer_postal_code_nulls, 
	COUNT(*) FILTER (WHERE payment_method IS NULL) AS payment_method_nulls, 
	COUNT(*) FILTER (WHERE payment_status IS NULL) AS payment_status_nulls, 
	COUNT(*) FILTER (WHERE currency IS NULL) AS currency_nulls, 
	COUNT(*) FILTER (WHERE shipping_method IS NULL) AS shipping_method_nulls, 
	COUNT(*) FILTER (WHERE warehouse IS NULL) AS warehouse_nulls, 
	COUNT(*) FILTER (WHERE delivery_days IS NULL) AS delivery_days_nulls, 
	COUNT(*) FILTER (WHERE estimated_delivery_days IS NULL) AS estimated_delivery_days_nulls, 
	COUNT(*) FILTER (WHERE delivery_status IS NULL) AS delivery_status_nulls, 
	COUNT(*) FILTER (WHERE return_status IS NULL) AS return_status_nulls, 
	COUNT(*) FILTER (WHERE return_reason IS NULL) AS return_reason_nulls, 
	COUNT(*) FILTER (WHERE customer_rating IS NULL) AS customer_rating_nulls, 
	COUNT(*) FILTER (WHERE review_sentiment IS NULL) AS review_sentiment_nulls, 
	COUNT(*) FILTER (WHERE customer_review IS NULL) AS customer_review_nulls, 
	COUNT(*) FILTER (WHERE marketing_channel IS NULL) AS marketing_channel_nulls, 
	COUNT(*) FILTER (WHERE campaign_name IS NULL) AS campaign_name_nulls, 
	COUNT(*) FILTER (WHERE coupon_code IS NULL) AS coupon_code_nulls, 
	COUNT(*) FILTER (WHERE loyalty_points_earned IS NULL) AS loyalty_points_earned_nulls, 
	COUNT(*) FILTER (WHERE loyalty_points_redeemed IS NULL) AS loyalty_points_redeemed_nulls, 
	COUNT(*) FILTER (WHERE quantity IS NULL) AS quantity_nulls, 
	COUNT(*) FILTER (WHERE gross_sales IS NULL) AS gross_sales_nulls, 
	COUNT(*) FILTER (WHERE discount_amount IS NULL) AS discount_amount_nulls, 
	COUNT(*) FILTER (WHERE tax_amount IS NULL) AS tax_amount_nulls, 
	COUNT(*) FILTER (WHERE shipping_cost IS NULL) AS shipping_cost_nulls, 
	COUNT(*) FILTER (WHERE net_sales IS NULL) AS net_sales_nulls, 
	COUNT(*) FILTER (WHERE product_cost IS NULL) AS product_cost_nulls, 
	COUNT(*) FILTER (WHERE profit IS NULL) AS profit_nulls, 
	COUNT(*) FILTER (WHERE profit_margin_percentage IS NULL) AS profit_margin_percentage_nulls, 
	COUNT(*) FILTER (WHERE customer_lifetime_value IS NULL) AS customer_lifetime_value_nulls, 
	COUNT(*) FILTER (WHERE is_repeat_customer IS NULL) AS is_repeat_customer_nulls, 
	COUNT(*) FILTER (WHERE customer_order_count IS NULL) AS customer_order_count_nulls 
FROM raw.ecommerce_sales_customer_analytics_150k;

-- ecommerce_sales_customer_analytics_150k: Do the five 24,557-NULL columns go missing on the same rows? 
-- delivery_days, estimated_delivery_days, customer_rating, review_sentiment, customer_review
-- Result: 24,557
SELECT
	COUNT(*) AS rows_all_five_null
FROM raw.ecommerce_sales_customer_analytics_150k
WHERE delivery_days IS NULL AND 
	estimated_delivery_days IS NULL AND
	customer_rating IS NULL AND 
	review_sentiment IS NULL AND
	customer_review IS NULL;

-- ecommerce_sales_customer_analytics_150k: for those 24,557 rows, how do they distribute across order_status and delivery_status?
-- Result (pct = % of all 138,116 rows): 
-- delivery_status | order_status | rows   | pct
-- Cancelled       | Cancelled    | 8,398  | 6.08
-- Cancelled       | Pending      | 6,697  | 4.85
-- Cancelled       | Returned     | 9,462  | 6.85
SELECT
	delivery_status,
	order_status,
	COUNT(*) AS total_rows,
	ROUND(
		(100.0 * COUNT(*) / (SELECT COUNT(*) FROM raw.ecommerce_sales_customer_analytics_150k))
		, 2) 
	AS pct_of_all_rows
FROM raw.ecommerce_sales_customer_analytics_150k
WHERE delivery_days IS NULL AND 
	estimated_delivery_days IS NULL AND
	customer_rating IS NULL AND 
	review_sentiment IS NULL AND
	customer_review IS NULL
GROUP BY 
	delivery_status, 
	order_status
ORDER BY total_rows DESC;

-- ecommerce_sales_customer_analytics_150k: Whole-table counts for each delivery_status.
-- Result: On Time 86,916 | Cancelled 24,557 | Delayed 16,886 | Early 9,757 (total 138,116)
SELECT 
	delivery_status,
	COUNT(*) as total_rows
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY delivery_status
ORDER BY COUNT(*) DESC;

-- ecommerce_sales_customer_analytics_150k: Whole-table counts for each order_status.
-- Result: Completed 113,559 | Returned 9,462 | Cancelled 8,398 | Pending 6,697 (total 138,116)
SELECT 
	order_status,
	COUNT(*) as total_rows
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY order_status
ORDER BY COUNT(*) DESC;

-- ecommerce_sales_customer_analytics_150k: Whole-table counts for each order_status and each delivery_status.
-- Result: Completed -> On Time 86,916 | Delayed 16,886 | Early 9,757
--         Returned, Cancelled, Pending -> always delivery_status Cancelled (9,462 | 8,398 | 6,697)
SELECT 
	delivery_status,
	order_status,
	COUNT(*) as total_rows
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY delivery_status, order_status
ORDER BY COUNT(*) DESC;

-- ecommerce_sales_customer_analytics_150k: Are return_status and return_reason filled only for Returned orders?
-- Result: only Returned orders (9,462) have return_status and return_reason filled; 0 rows with only one filled; 0 blank strings
SELECT
    order_status,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE return_status IS NOT NULL) AS return_status_filled,
    COUNT(*) FILTER (WHERE return_reason IS NOT NULL) AS return_reason_filled,
    COUNT(*) FILTER (WHERE (return_status IS NULL) <> (return_reason IS NULL)) AS only_one_filled,
    COUNT(*) FILTER (WHERE TRIM(return_status) = '' OR TRIM(return_reason) = '') AS blank_strings
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY order_status
ORDER BY total_rows DESC;

-- ecommerce_sales_customer_analytics_150k: Does the coupon_code NULL rate differ between rows with and without a campaign_name?
-- Result: coupon_code NULL rate is 79.72% with a campaign (54,883 rows) and 80.19% without (83,233 rows)
-- -> the two columns look independent
SELECT
    campaign_name IS NULL AS campaign_is_null,
    COUNT(*) AS total_rows,
    ROUND(
        COUNT(*) FILTER (WHERE coupon_code IS NULL)::NUMERIC / COUNT(*) * 100.0
        , 2
    ) AS null_coupon_pct
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY campaign_name IS NULL
ORDER BY campaign_is_null;

-- ecommerce_sales_customer_analytics_150k: Check for blanks and placeholders in text columns
-- generated from information_schema.columns
SELECT 
	'SELECT ' ||
	string_agg (
		format(
			'COUNT(*) FILTER (WHERE %I ~* %L) AS %I',
			column_name,
			'^\s*$|^\s*(N/A|NA|NULL|UNKNOWN|NONE)\s*$',
			column_name || '_invalid'
		), 
		', '
	) ||
	' FROM raw.ecommerce_sales_customer_analytics_150k;'
FROM information_schema.columns
WHERE table_schema = 'raw' 
	AND table_name = 'ecommerce_sales_customer_analytics_150k'
	AND data_type = 'text';

-- Result: 0 matches in all 29 text columns for empty or whitespace-only strings
-- and for N/A, NA, NULL, UNKNOWN, NONE (case-insensitive, whole value only).
SELECT 
	COUNT(*) FILTER (WHERE order_id ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS order_id_invalid, 
	COUNT(*) FILTER (WHERE order_date ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS order_date_invalid, 
	COUNT(*) FILTER (WHERE order_time ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS order_time_invalid, 
	COUNT(*) FILTER (WHERE order_status ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS order_status_invalid, 
	COUNT(*) FILTER (WHERE sales_channel ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS sales_channel_invalid, 
	COUNT(*) FILTER (WHERE customer_id ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_id_invalid, 
	COUNT(*) FILTER (WHERE customer_name ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_name_invalid, 
	COUNT(*) FILTER (WHERE gender ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS gender_invalid, 
	COUNT(*) FILTER (WHERE customer_segment ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_segment_invalid, 
	COUNT(*) FILTER (WHERE customer_type ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_type_invalid, 
	COUNT(*) FILTER (WHERE customer_city ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_city_invalid, 
	COUNT(*) FILTER (WHERE customer_state ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_state_invalid, 
	COUNT(*) FILTER (WHERE customer_country ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_country_invalid, 
	COUNT(*) FILTER (WHERE region ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS region_invalid, 
	COUNT(*) FILTER (WHERE customer_postal_code ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_postal_code_invalid, 
	COUNT(*) FILTER (WHERE payment_method ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS payment_method_invalid, 
	COUNT(*) FILTER (WHERE payment_status ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS payment_status_invalid, 
	COUNT(*) FILTER (WHERE currency ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS currency_invalid, 
	COUNT(*) FILTER (WHERE shipping_method ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS shipping_method_invalid, 
	COUNT(*) FILTER (WHERE warehouse ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS warehouse_invalid, 
	COUNT(*) FILTER (WHERE delivery_status ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS delivery_status_invalid, 
	COUNT(*) FILTER (WHERE return_status ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS return_status_invalid, 
	COUNT(*) FILTER (WHERE return_reason ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS return_reason_invalid, 
	COUNT(*) FILTER (WHERE review_sentiment ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS review_sentiment_invalid, 
	COUNT(*) FILTER (WHERE customer_review ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_review_invalid, 
	COUNT(*) FILTER (WHERE marketing_channel ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS marketing_channel_invalid, 
	COUNT(*) FILTER (WHERE campaign_name ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS campaign_name_invalid, 
	COUNT(*) FILTER (WHERE coupon_code ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS coupon_code_invalid, 
	COUNT(*) FILTER (WHERE is_repeat_customer ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS is_repeat_customer_invalid 
FROM raw.ecommerce_sales_customer_analytics_150k;

-- ecommerce_sales_customer_analytics_150k: Casing variants, spelling inconsistencies, or values that don't fit
-- Result: 91 distinct values across 16 categorical columns.
-- Skimmed for casing variants, spelling differences, tiny groups and values that don't fit the column.
-- None found. review_sentiment has a NULL group (24,557 rows) from non-Completed orders.
SELECT 
	'order_status' AS column_name,
	order_status AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY order_status
UNION ALL
SELECT 
	'sales_channel' AS column_name,
	sales_channel AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY sales_channel
UNION ALL
SELECT 
	'customer_segment' AS column_name,
	customer_segment AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY customer_segment
UNION ALL
SELECT 
	'customer_type' AS column_name,
	customer_type AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY customer_type
UNION ALL
SELECT 
	'gender' AS column_name,
	gender AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY gender
UNION ALL
SELECT 
	'region' AS column_name,
	region AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY region
UNION ALL
SELECT 
	'customer_country' AS column_name,
	customer_country AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY customer_country
UNION ALL
SELECT 
	'payment_method' AS column_name,
	payment_method AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY payment_method
UNION ALL
SELECT 
	'payment_status' AS column_name,
	payment_status AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY payment_status
UNION ALL
SELECT 
	'currency' AS column_name,
	currency AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY currency
UNION ALL
SELECT 
	'shipping_method' AS column_name,
	shipping_method AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY shipping_method
UNION ALL
SELECT 
	'warehouse' AS column_name,
	warehouse AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY warehouse
UNION ALL
SELECT 
	'delivery_status' AS column_name,
	delivery_status AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY delivery_status
UNION ALL
SELECT 
	'review_sentiment' AS column_name,
	review_sentiment AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY review_sentiment
UNION ALL
SELECT 
	'marketing_channel' AS column_name,
	marketing_channel AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY marketing_channel
UNION ALL
SELECT 
	'is_repeat_customer' AS column_name,
	is_repeat_customer AS value,
	COUNT(*) AS row_count 
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY is_repeat_customer
ORDER BY column_name, row_count DESC;