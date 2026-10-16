/*
=================================================
    STEP 1: STRUCTURE AND VOLUME
=================================================

Completed during raw loading (see docs/data_quality_log.md).
Row counts: product_catalog 1,175 | customer_master 25,000 |
            order_items 397,569 | sales 138,116 | dataset_statistics 1

*/

/*
=================================================
    STEP 2: GRAIN AND KEYS
=================================================
*/
-- product_catalog 
-- Is product_id unique? 
-- Result: 1,175 rows, 1,175 distinct product_id -> unique
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT product_id) AS distinct_products
FROM raw.product_catalog;

-- customer_master
-- Is customer_id unique? 
-- Result: 25,000 rows, 25,000 distinct customer_id -> unique
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT customer_id) AS distinct_customers
FROM raw.customer_master;

-- order_items 
-- Is (order_id, product_id) unique?
-- Result: 397,569 rows, 138,116 distinct order_id, 397,482 distinct pairs -> NOT unique (87 surplus rows)
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT order_id) AS distinct_orders,
	COUNT(DISTINCT (order_id, product_id)) AS distinct_order_product_pairs
FROM raw.order_items;

-- ecommerce_sales_customer_analytics_150k 
-- Is order_id unique?
-- Result: 138,116 rows, 138,116 distinct order_id -> unique
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT order_id) AS distinct_orders
FROM raw.ecommerce_sales_customer_analytics_150k;

/*
=================================================
    STEP 2b: order_items REPEATED PAIRS
=================================================
*/
-- order_items 
-- Surplus (order_id, product_id) pairs
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

-- order_items 
-- How many of the pairs are fully identical?
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

-- order_items
-- Which columns differ on each pair?
-- Result: from a 5-pair sample, unit_price is the same; quantity, discount and the other money columns differ
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

-- order_items
-- How do the columns differ?
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

-- order_items
-- Check one pair having the same quantity, unit_price, and discount_percentage
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

/*
=================================================
    STEP 3: COMPLETENESS
=================================================
*/

/*
=================================================
ecommerce_sales_customer_analytics_150k
=================================================
*/

-- ecommerce_sales_customer_analytics_150k
-- Which columns contain NULLs and how many each?
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

-- generated from information_schema.columns, used for the query below
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

-- ecommerce_sales_customer_analytics_150k
-- Do the five 24,557-NULL columns go missing on the same rows? 
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

-- ecommerce_sales_customer_analytics_150k
-- For those 24,557 rows, how do they distribute across order_status and delivery_status?
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

-- ecommerce_sales_customer_analytics_150k
-- Whole-table counts for each delivery_status.
-- Result: On Time 86,916 | Cancelled 24,557 | Delayed 16,886 | Early 9,757 (total 138,116)
SELECT 
	delivery_status,
	COUNT(*) as total_rows
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY delivery_status
ORDER BY COUNT(*) DESC;

-- ecommerce_sales_customer_analytics_150k
-- Whole-table counts for each order_status.
-- Result: Completed 113,559 | Returned 9,462 | Cancelled 8,398 | Pending 6,697 (total 138,116)
SELECT 
	order_status,
	COUNT(*) as total_rows
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY order_status
ORDER BY COUNT(*) DESC;

-- ecommerce_sales_customer_analytics_150k
-- Whole-table counts for each order_status and each delivery_status.
-- Result: Completed -> On Time 86,916 | Delayed 16,886 | Early 9,757
--         Returned, Cancelled, Pending -> always delivery_status Cancelled (9,462 | 8,398 | 6,697)
SELECT 
	delivery_status,
	order_status,
	COUNT(*) as total_rows
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY delivery_status, order_status
ORDER BY COUNT(*) DESC;

-- ecommerce_sales_customer_analytics_150k
-- Are return_status and return_reason filled only for Returned orders?
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

-- ecommerce_sales_customer_analytics_150k
-- Does the coupon_code NULL rate differ between rows with and without a campaign_name?
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

-- ecommerce_sales_customer_analytics_150k
-- Check for blanks and placeholders in text columns
-- Result: 0 matches in all 29 text columns for empty or whitespace-only strings
-- and for N/A, NA, NULL, UNKNOWN, NONE (case-insensitive, whole value only).

-- generated from information_schema.columns, used for the query below
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

/*
==========================================================
customer_master
==========================================================
*/

-- customer_master
-- Which columns contain NULLs and how many each?
-- Result: 0 NULLs in all 11 columns (25,000 rows)
SELECT  
	COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_nulls, 
	COUNT(*) FILTER (WHERE customer_name IS NULL) AS customer_name_nulls, 
	COUNT(*) FILTER (WHERE customer_age IS NULL) AS customer_age_nulls, 
	COUNT(*) FILTER (WHERE gender IS NULL) AS gender_nulls, 
	COUNT(*) FILTER (WHERE customer_segment IS NULL) AS customer_segment_nulls, 
	COUNT(*) FILTER (WHERE customer_city IS NULL) AS customer_city_nulls, 
	COUNT(*) FILTER (WHERE customer_state IS NULL) AS customer_state_nulls, 
	COUNT(*) FILTER (WHERE customer_country IS NULL) AS customer_country_nulls, 
	COUNT(*) FILTER (WHERE region IS NULL) AS region_nulls, 
	COUNT(*) FILTER (WHERE customer_postal_code IS NULL) AS customer_postal_code_nulls, 
	COUNT(*) FILTER (WHERE customer_acquisition_cost IS NULL) AS customer_acquisition_cost_nulls 
FROM raw.customer_master;

-- customer_master
-- Check for blanks and placeholders in text columns
-- Result: 0 matches in all 9 text columns (empty, whitespace-only, N/A, NA, NULL, UNKNOWN, NONE)
SELECT 
	COUNT(*) FILTER (WHERE customer_id ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_id_invalid, 
	COUNT(*) FILTER (WHERE customer_name ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_name_invalid, 
	COUNT(*) FILTER (WHERE gender ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS gender_invalid, 
	COUNT(*) FILTER (WHERE customer_segment ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_segment_invalid, 
	COUNT(*) FILTER (WHERE customer_city ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_city_invalid, 
	COUNT(*) FILTER (WHERE customer_state ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_state_invalid, 
	COUNT(*) FILTER (WHERE customer_country ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_country_invalid, 
	COUNT(*) FILTER (WHERE region ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS region_invalid, 
	COUNT(*) FILTER (WHERE customer_postal_code ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS customer_postal_code_invalid 
FROM raw.customer_master;

/*
==========================================================
product_catalog
==========================================================
*/

-- product_catalog
-- Which columns contain NULLs and how many each?
-- Result: 0 NULLs in all 9 columns (1,175 rows)
SELECT 
	COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_nulls, 
	COUNT(*) FILTER (WHERE product_name IS NULL) AS product_name_nulls, 
	COUNT(*) FILTER (WHERE product_category IS NULL) AS product_category_nulls, 
	COUNT(*) FILTER (WHERE product_subcategory IS NULL) AS product_subcategory_nulls, 
	COUNT(*) FILTER (WHERE brand IS NULL) AS brand_nulls, 
	COUNT(*) FILTER (WHERE supplier IS NULL) AS supplier_nulls, 
	COUNT(*) FILTER (WHERE unit_price IS NULL) AS unit_price_nulls, 
	COUNT(*) FILTER (WHERE product_cost IS NULL) AS product_cost_nulls, 
	COUNT(*) FILTER (WHERE product_rating IS NULL) AS product_rating_nulls 
FROM raw.product_catalog;

-- product_catalog
-- Check for blanks and placeholders in text columns
-- Result: 0 matches in all 6 text columns (empty, whitespace-only, N/A, NA, NULL, UNKNOWN, NONE)
SELECT 
	COUNT(*) FILTER (WHERE product_id ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS product_id_invalid, 
	COUNT(*) FILTER (WHERE product_name ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS product_name_invalid, 
	COUNT(*) FILTER (WHERE product_category ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS product_category_invalid, 
	COUNT(*) FILTER (WHERE product_subcategory ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS product_subcategory_invalid, 
	COUNT(*) FILTER (WHERE brand ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS brand_invalid, 
	COUNT(*) FILTER (WHERE supplier ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS supplier_invalid 
FROM raw.product_catalog;

/*
==========================================================
order_items
==========================================================
*/

-- order_items
-- Which columns contain NULLs and how many each?
-- Result: 0 NULLs in all 12 columns (397,569 rows)
SELECT 
	COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_nulls, 
	COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_nulls, 
	COUNT(*) FILTER (WHERE quantity IS NULL) AS quantity_nulls, 
	COUNT(*) FILTER (WHERE unit_price IS NULL) AS unit_price_nulls, 
	COUNT(*) FILTER (WHERE discount_percentage IS NULL) AS discount_percentage_nulls, 
	COUNT(*) FILTER (WHERE discount_amount IS NULL) AS discount_amount_nulls, 
	COUNT(*) FILTER (WHERE gross_sales IS NULL) AS gross_sales_nulls, 
	COUNT(*) FILTER (WHERE tax_amount IS NULL) AS tax_amount_nulls, 
	COUNT(*) FILTER (WHERE shipping_cost IS NULL) AS shipping_cost_nulls, 
	COUNT(*) FILTER (WHERE net_sales IS NULL) AS net_sales_nulls, 
	COUNT(*) FILTER (WHERE product_cost IS NULL) AS product_cost_nulls, 
	COUNT(*) FILTER (WHERE profit IS NULL) AS profit_nulls 
FROM raw.order_items;

-- order_items
-- Check for blanks and placeholders in text columns
-- Result: 0 matches in order_id and product_id (empty, whitespace-only, N/A, NA, NULL, UNKNOWN, NONE)
SELECT 
	COUNT(*) FILTER (WHERE order_id ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS order_id_invalid, 
	COUNT(*) FILTER (WHERE product_id ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS product_id_invalid 
FROM raw.order_items;

/*
==========================================================
dataset_statistics
==========================================================
*/

-- dataset_statistics
-- Which columns contain NULLs and how many each?
-- Result: 0 NULLs in all 11 columns (1 row)
SELECT 
	COUNT(*) FILTER (WHERE total_transactions IS NULL) AS total_transactions_nulls, 
	COUNT(*) FILTER (WHERE total_columns IS NULL) AS total_columns_nulls, 
	COUNT(*) FILTER (WHERE total_customers IS NULL) AS total_customers_nulls, 
	COUNT(*) FILTER (WHERE total_products_used IS NULL) AS total_products_used_nulls, 
	COUNT(*) FILTER (WHERE date_range IS NULL) AS date_range_nulls, 
	COUNT(*) FILTER (WHERE total_revenue IS NULL) AS total_revenue_nulls, 
	COUNT(*) FILTER (WHERE total_profit IS NULL) AS total_profit_nulls, 
	COUNT(*) FILTER (WHERE average_order_value IS NULL) AS average_order_value_nulls, 
	COUNT(*) FILTER (WHERE average_rating IS NULL) AS average_rating_nulls, 
	COUNT(*) FILTER (WHERE return_rate IS NULL) AS return_rate_nulls, 
	COUNT(*) FILTER (WHERE cancellation_rate IS NULL) AS cancellation_rate_nulls 
FROM raw.dataset_statistics;

-- dataset_statistics
-- Check for blanks and placeholders in text columns
-- Result: 0 matches in all 6 text columns (empty, whitespace-only, N/A, NA, NULL, UNKNOWN, NONE)
SELECT 
	COUNT(*) FILTER (WHERE date_range ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS date_range_invalid, 
	COUNT(*) FILTER (WHERE total_revenue ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS total_revenue_invalid, 
	COUNT(*) FILTER (WHERE total_profit ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS total_profit_invalid, 
	COUNT(*) FILTER (WHERE average_order_value ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS average_order_value_invalid, 
	COUNT(*) FILTER (WHERE return_rate ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS return_rate_invalid, 
	COUNT(*) FILTER (WHERE cancellation_rate ~* E'^\\s*$|^\\s*(N/A|NA|NULL|UNKNOWN|NONE)\\s*$') AS cancellation_rate_invalid 
FROM raw.dataset_statistics;


/*
=================================================
    STEP 4: VALIDITY
=================================================
*/

/*
=================================================
ecommerce_sales_customer_analytics_150k
=================================================
*/

-- ecommerce_sales_customer_analytics_150k
-- Casing variants, spelling inconsistencies, or values that don't fit
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

-- ecommerce_sales_customer_analytics_150k
-- Check length of order_id and customer_id 
-- Result: every order_id has length 10 and every customer_id has length 11 (138,116 rows each)
SELECT
	'order_id' AS column_name,
	LENGTH(order_id) AS id_length,
	COUNT(*) AS total_rows
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY LENGTH(order_id)
UNION ALL
SELECT
	'customer_id' AS column_name,
	LENGTH(customer_id) AS id_length,
	COUNT(*) AS total_rows
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY LENGTH(customer_id);

-- ecommerce_sales_customer_analytics_150k
-- Check order_id matches ORD-XXXXXX (6 digits) and customer_id matches CUST-XXXXXX (6 digits)
-- Patterns inferred from sample values, then confirmed by this check
-- Result: 0 mismatches in both columns
SELECT
	COUNT(*) FILTER (WHERE order_id !~ '^ORD-[0-9]{6}$') AS order_id_mismatches,
	COUNT(*) FILTER (WHERE customer_id !~ '^CUST-[0-9]{6}$') AS customer_id_mismatches
FROM raw.ecommerce_sales_customer_analytics_150k;

-- ecommerce_sales_customer_analytics_150k
-- Min, max, zeros and negatives for the 17 numeric columns
-- Result: no impossible values. Negatives only in profit (1,296) and profit_margin_percentage (1,295).
-- Zeros in delivery_days (6,674), estimated_delivery_days (5,794), discount_amount (17,864),
-- shipping_cost (377), loyalty_points_earned (24,562), loyalty_points_redeemed (27,155).

-- generated from information_schema.columns, used for the query below
SELECT
	string_agg(
		format(
			$sql$
SELECT
	%L AS column_name,
	MIN(%I) AS min_value,
	MAX(%I) AS max_value,
	COUNT(*) FILTER (WHERE %I = 0) AS zero_values,
	COUNT(*) FILTER (WHERE %I < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			$sql$,
			column_name,
			column_name,
			column_name,
			column_name,
			column_name
		),
E'\nUNION ALL\n'
	) 
FROM information_schema.columns
WHERE table_schema = 'raw'
	AND table_name = 'ecommerce_sales_customer_analytics_150k'
	AND data_type = 'numeric';

SELECT
	'customer_age' AS column_name,
	MIN(customer_age) AS min_value,
	MAX(customer_age) AS max_value,
	COUNT(*) FILTER (WHERE customer_age = 0) AS zero_values,
	COUNT(*) FILTER (WHERE customer_age < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'delivery_days' AS column_name,
	MIN(delivery_days) AS min_value,
	MAX(delivery_days) AS max_value,
	COUNT(*) FILTER (WHERE delivery_days = 0) AS zero_values,
	COUNT(*) FILTER (WHERE delivery_days < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'estimated_delivery_days' AS column_name,
	MIN(estimated_delivery_days) AS min_value,
	MAX(estimated_delivery_days) AS max_value,
	COUNT(*) FILTER (WHERE estimated_delivery_days = 0) AS zero_values,
	COUNT(*) FILTER (WHERE estimated_delivery_days < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'customer_rating' AS column_name,
	MIN(customer_rating) AS min_value,
	MAX(customer_rating) AS max_value,
	COUNT(*) FILTER (WHERE customer_rating = 0) AS zero_values,
	COUNT(*) FILTER (WHERE customer_rating < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'loyalty_points_earned' AS column_name,
	MIN(loyalty_points_earned) AS min_value,
	MAX(loyalty_points_earned) AS max_value,
	COUNT(*) FILTER (WHERE loyalty_points_earned = 0) AS zero_values,
	COUNT(*) FILTER (WHERE loyalty_points_earned < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'loyalty_points_redeemed' AS column_name,
	MIN(loyalty_points_redeemed) AS min_value,
	MAX(loyalty_points_redeemed) AS max_value,
	COUNT(*) FILTER (WHERE loyalty_points_redeemed = 0) AS zero_values,
	COUNT(*) FILTER (WHERE loyalty_points_redeemed < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'quantity' AS column_name,
	MIN(quantity) AS min_value,
	MAX(quantity) AS max_value,
	COUNT(*) FILTER (WHERE quantity = 0) AS zero_values,
	COUNT(*) FILTER (WHERE quantity < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'gross_sales' AS column_name,
	MIN(gross_sales) AS min_value,
	MAX(gross_sales) AS max_value,
	COUNT(*) FILTER (WHERE gross_sales = 0) AS zero_values,
	COUNT(*) FILTER (WHERE gross_sales < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'discount_amount' AS column_name,
	MIN(discount_amount) AS min_value,
	MAX(discount_amount) AS max_value,
	COUNT(*) FILTER (WHERE discount_amount = 0) AS zero_values,
	COUNT(*) FILTER (WHERE discount_amount < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'tax_amount' AS column_name,
	MIN(tax_amount) AS min_value,
	MAX(tax_amount) AS max_value,
	COUNT(*) FILTER (WHERE tax_amount = 0) AS zero_values,
	COUNT(*) FILTER (WHERE tax_amount < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'shipping_cost' AS column_name,
	MIN(shipping_cost) AS min_value,
	MAX(shipping_cost) AS max_value,
	COUNT(*) FILTER (WHERE shipping_cost = 0) AS zero_values,
	COUNT(*) FILTER (WHERE shipping_cost < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'net_sales' AS column_name,
	MIN(net_sales) AS min_value,
	MAX(net_sales) AS max_value,
	COUNT(*) FILTER (WHERE net_sales = 0) AS zero_values,
	COUNT(*) FILTER (WHERE net_sales < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'product_cost' AS column_name,
	MIN(product_cost) AS min_value,
	MAX(product_cost) AS max_value,
	COUNT(*) FILTER (WHERE product_cost = 0) AS zero_values,
	COUNT(*) FILTER (WHERE product_cost < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'profit' AS column_name,
	MIN(profit) AS min_value,
	MAX(profit) AS max_value,
	COUNT(*) FILTER (WHERE profit = 0) AS zero_values,
	COUNT(*) FILTER (WHERE profit < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'profit_margin_percentage' AS column_name,
	MIN(profit_margin_percentage) AS min_value,
	MAX(profit_margin_percentage) AS max_value,
	COUNT(*) FILTER (WHERE profit_margin_percentage = 0) AS zero_values,
	COUNT(*) FILTER (WHERE profit_margin_percentage < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'customer_lifetime_value' AS column_name,
	MIN(customer_lifetime_value) AS min_value,
	MAX(customer_lifetime_value) AS max_value,
	COUNT(*) FILTER (WHERE customer_lifetime_value = 0) AS zero_values,
	COUNT(*) FILTER (WHERE customer_lifetime_value < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k
			
UNION ALL

SELECT
	'customer_order_count' AS column_name,
	MIN(customer_order_count) AS min_value,
	MAX(customer_order_count) AS max_value,
	COUNT(*) FILTER (WHERE customer_order_count = 0) AS zero_values,
	COUNT(*) FILTER (WHERE customer_order_count < 0) AS negative_values
FROM raw.ecommerce_sales_customer_analytics_150k;

-- ecommerce_sales_customer_analytics_150k
-- Row where profit_margin_percentage = 0
-- Result: 1 row, profit -0.01, net_sales 214.13, product_cost 214.02.
-- Margin rounds to 0.00, so the zero is a rounding effect (explains 1,295 vs 1,296 negatives).
SELECT
	profit,
	net_sales,
	product_cost
FROM raw.ecommerce_sales_customer_analytics_150k
WHERE profit_margin_percentage = 0;

-- ecommerce_sales_customer_analytics_150k
-- Zero loyalty_points_earned by order_status
-- Result: Cancelled 8,398 | Pending 6,697 | Returned 9,462 | Completed 5.
-- All non-Completed orders earn 0 points (24,557). 5 Completed rows also have 0.
SELECT
	order_status,
	COUNT(*) FILTER (WHERE loyalty_points_earned = 0) AS zero_points_rows,
	COUNT(*) AS total_rows
FROM raw.ecommerce_sales_customer_analytics_150k
GROUP BY order_status
ORDER BY order_status;

-- ecommerce_sales_customer_analytics_150k
-- Check order_date (YYYY-MM-DD) and order_time (HH:MM:SS) format, and date range
-- Result: 0 format mismatches. order_date runs 2021-01-01 to 2025-12-31, matching dataset_statistics.
SELECT
	COUNT(*) FILTER (WHERE order_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS date_mismatches,
	COUNT(*) FILTER (WHERE order_time !~ '^[0-9]{2}:[0-9]{2}:[0-9]{2}$') AS time_mismatches,
	MIN(order_date) AS min_order_date,
	MAX(order_date) AS max_order_date
FROM raw.ecommerce_sales_customer_analytics_150k;

-- ecommerce_sales_customer_analytics_150k
-- Cast order_date to DATE and order_time to TIME
-- Result: all casts succeed. order_date 2021-01-01 to 2025-12-31, order_time 00:00:00 to 23:59:59.
SELECT
	MIN(order_date::DATE) AS min_order_date,
	MAX(order_date::DATE) AS max_order_date,
	MIN(order_time::TIME) AS min_order_time,
	MAX(order_time::TIME) AS max_order_time
FROM raw.ecommerce_sales_customer_analytics_150k;

/*
=================================================
customer_master
=================================================
*/

-- customer_master
-- Casing and whitespace variants in categorical columns
-- Result: distinct_values = distinct_normalized for all 6 columns (gender, customer_segment,
-- customer_city, customer_state, customer_country, region), so no casing or spacing variants
SELECT
	'gender' AS column_name,
	COUNT(DISTINCT gender) AS distinct_values,
	COUNT(DISTINCT LOWER(TRIM(gender))) AS distinct_normalized
FROM raw.customer_master
UNION ALL
SELECT
	'customer_segment' AS column_name,
	COUNT(DISTINCT customer_segment) AS distinct_values,
	COUNT(DISTINCT LOWER(TRIM(customer_segment))) AS distinct_normalized
FROM raw.customer_master
UNION ALL
SELECT
	'customer_city' AS column_name,
	COUNT(DISTINCT customer_city) AS distinct_values,
	COUNT(DISTINCT LOWER(TRIM(customer_city))) AS distinct_normalized
FROM raw.customer_master
UNION ALL
SELECT
	'customer_state' AS column_name,
	COUNT(DISTINCT customer_state) AS distinct_values,
	COUNT(DISTINCT LOWER(TRIM(customer_state))) AS distinct_normalized
FROM raw.customer_master
UNION ALL
SELECT
	'customer_country' AS column_name,
	COUNT(DISTINCT customer_country) AS distinct_values,
	COUNT(DISTINCT LOWER(TRIM(customer_country))) AS distinct_normalized
FROM raw.customer_master
UNION ALL
SELECT
	'region' AS column_name,
	COUNT(DISTINCT region) AS distinct_values,
	COUNT(DISTINCT LOWER(TRIM(region))) AS distinct_normalized
FROM raw.customer_master
ORDER BY column_name;

-- customer_master
-- Distinct values with counts for low-cardinality columns
-- Result: gender, customer_segment, customer_state, customer_country and region skimmed.
-- No casing or spelling variants, tiny groups or out-of-place values found.
SELECT 
	'gender' AS column_name,
	gender AS value,
	COUNT(*) AS row_count 
FROM raw.customer_master
GROUP BY gender
UNION ALL
SELECT 
	'customer_segment' AS column_name,
	customer_segment AS value,
	COUNT(*) AS row_count 
FROM raw.customer_master
GROUP BY customer_segment
UNION ALL
SELECT 
	'customer_state' AS column_name,
	customer_state AS value,
	COUNT(*) AS row_count 
FROM raw.customer_master
GROUP BY customer_state
UNION ALL
SELECT 
	'customer_country' AS column_name,
	customer_country AS value,
	COUNT(*) AS row_count 
FROM raw.customer_master
GROUP BY customer_country
UNION ALL
SELECT 
	'region' AS column_name,
	region AS value,
	COUNT(*) AS row_count 
FROM raw.customer_master
GROUP BY region
ORDER BY column_name, row_count DESC;

-- customer_master
-- Check length of customer_id
-- Result: every customer_id has length 11 (25,000 rows)
SELECT
	LENGTH(customer_id) AS id_length,
	COUNT(*) AS total_rows
FROM raw.customer_master
GROUP BY LENGTH(customer_id);

-- customer_master
-- Check customer_id matches the pattern CUST-XXXXXX (6 digits)
-- Patterns inferred from sample values, then confirmed by this check
-- Result: 0 mismatches, so all customer_id values follow the same format
SELECT
	COUNT(*) FILTER (WHERE customer_id !~ '^CUST-[0-9]{6}$') AS format_mismatches
FROM raw.customer_master;

-- customer_master
-- Min, max, zeros and negatives for customer_age and customer_acquisition_cost
-- Result: no impossible values. Age 18 to 74, acquisition cost 5.01 to 79.99, no zeros or negatives.
SELECT
	'customer_age' AS column_name,
	MIN(customer_age) AS min_value,
	MAX(customer_age) AS max_value,
	COUNT(*) FILTER (WHERE customer_age = 0) AS zero_values,
	COUNT(*) FILTER (WHERE customer_age < 0) AS negative_values
FROM raw.customer_master
			
UNION ALL

SELECT
	'customer_acquisition_cost' AS column_name,
	MIN(customer_acquisition_cost) AS min_value,
	MAX(customer_acquisition_cost) AS max_value,
	COUNT(*) FILTER (WHERE customer_acquisition_cost = 0) AS zero_values,
	COUNT(*) FILTER (WHERE customer_acquisition_cost < 0) AS negative_values
FROM raw.customer_master;

/*
=================================================
product_catalog
=================================================
*/

-- product_catalog
-- Casing and whitespace variants in categorical columns
-- Result: distinct_values = distinct_normalized for all 4 columns
-- (brand 144, product_category 15, product_subcategory 117, supplier 10), so no casing or spacing variants
SELECT 
	'product_category' AS column_name,
	COUNT(DISTINCT product_category) AS distinct_values,
	COUNT(DISTINCT LOWER(TRIM(product_category))) AS distinct_normalized
FROM raw.product_catalog
UNION ALL
SELECT 
	'product_subcategory' AS column_name,
	COUNT(DISTINCT product_subcategory) AS distinct_values,
	COUNT(DISTINCT LOWER(TRIM(product_subcategory))) AS distinct_normalized
FROM raw.product_catalog
UNION ALL
SELECT 
	'brand' AS column_name,
	COUNT(DISTINCT brand) AS distinct_values,
	COUNT(DISTINCT LOWER(TRIM(brand))) AS distinct_normalized
FROM raw.product_catalog
UNION ALL
SELECT 
	'supplier' AS column_name,
	COUNT(DISTINCT supplier) AS distinct_values,
	COUNT(DISTINCT LOWER(TRIM(supplier))) AS distinct_normalized
FROM raw.product_catalog
ORDER BY column_name;

-- product_catalog 
-- Distinct values with counts for product_category and supplier
-- Result: 15 categories and 10 suppliers skimmed. No spelling variants or out-of-place values found.
SELECT
	'product_category' AS column_name,
	product_category AS value,
	COUNT(*) AS row_count
FROM raw.product_catalog
GROUP BY product_category
UNION ALL
SELECT
	'supplier' AS column_name,
	supplier AS value,
	COUNT(*) AS row_count
FROM raw.product_catalog
GROUP BY supplier
ORDER BY column_name, 
		row_count DESC;	

-- product_catalog
-- Which categories do the shared subcategories appear under?
-- Result: Storage (Home & Kitchen, Office Supplies), Watches (Fashion, Jewelry),
-- Furniture (Baby & Kids, Home & Kitchen). Pairings look plausible (skimmed).
SELECT 
	product_subcategory,
	STRING_AGG(DISTINCT product_category, ', ') AS categories
FROM raw.product_catalog
GROUP BY product_subcategory
HAVING COUNT(DISTINCT product_category) > 1
ORDER BY product_subcategory DESC;

-- product_catalog
-- Check length of product_id
-- Result: every product_id has length 11 (1,175 rows)
SELECT
	LENGTH(product_id) AS id_length,
	COUNT(*) AS total_rows
FROM raw.product_catalog
GROUP BY LENGTH(product_id);

-- product_catalog
-- Check product_id matches the pattern PROD-XXXXXX (6 digits)
-- Patterns inferred from sample values, then confirmed by this check
-- Result: 0 mismatches, so all product_id values follow the same format
SELECT
	COUNT(*) FILTER (WHERE product_id !~ '^PROD-[0-9]{6}$') AS format_mismatches
FROM raw.product_catalog;

-- product_catalog
-- Min, max, zeros and negatives for unit_price, product_cost and product_rating
-- Result: no impossible values. unit_price 6.31 to 1,482.95, product_cost 1.97 to 993.63,
-- product_rating 2.5 to 4.9. No zeros or negatives.
SELECT
	'unit_price' AS column_name,
	MIN(unit_price) AS min_value,
	MAX(unit_price) AS max_value,
	COUNT(*) FILTER (WHERE unit_price = 0) AS zero_values,
	COUNT(*) FILTER (WHERE unit_price < 0) AS negative_values
FROM raw.product_catalog
			
UNION ALL

SELECT
	'product_cost' AS column_name,
	MIN(product_cost) AS min_value,
	MAX(product_cost) AS max_value,
	COUNT(*) FILTER (WHERE product_cost = 0) AS zero_values,
	COUNT(*) FILTER (WHERE product_cost < 0) AS negative_values
FROM raw.product_catalog
			
UNION ALL

SELECT
	'product_rating' AS column_name,
	MIN(product_rating) AS min_value,
	MAX(product_rating) AS max_value,
	COUNT(*) FILTER (WHERE product_rating = 0) AS zero_values,
	COUNT(*) FILTER (WHERE product_rating < 0) AS negative_values
FROM raw.product_catalog;

/*
=================================================
order_items
=================================================
*/

-- order_items
-- Check length of order_id and product_id
-- Result: every order_id has length 10 and every product_id has length 11 (397,569 rows each)
SELECT
	'order_id' AS column_name,
	LENGTH(order_id) AS id_length,
	COUNT(*) AS total_rows
FROM raw.order_items
GROUP BY LENGTH(order_id)
UNION ALL
SELECT
	'product_id' AS column_name,
	LENGTH(product_id) AS id_length,
	COUNT(*) AS total_rows
FROM raw.order_items
GROUP BY LENGTH(product_id);

-- order_items
-- Check order_id matches ORD-XXXXXX and product_id matches PROD-XXXXXX (6 digits each)
-- Patterns inferred from sample values, then confirmed by this check
-- Result: 0 mismatches in both columns
SELECT
	COUNT(*) FILTER (WHERE order_id !~ '^ORD-[0-9]{6}$') AS order_id_mismatches,
	COUNT(*) FILTER (WHERE product_id !~ '^PROD-[0-9]{6}$') AS product_id_mismatches
FROM raw.order_items;

-- order_items
-- Min, max, zeros and negatives for the 10 numeric columns
-- Result: no impossible values. Negatives only in profit (5,426). discount_percentage is a fraction (0 to 0.6).
-- Zeros in discount_amount (51,509), discount_percentage (51,476), shipping_cost (4,505), profit (2).
SELECT
	'quantity' AS column_name,
	MIN(quantity) AS min_value,
	MAX(quantity) AS max_value,
	COUNT(*) FILTER (WHERE quantity = 0) AS zero_values,
	COUNT(*) FILTER (WHERE quantity < 0) AS negative_values
FROM raw.order_items
			
UNION ALL

SELECT
	'unit_price' AS column_name,
	MIN(unit_price) AS min_value,
	MAX(unit_price) AS max_value,
	COUNT(*) FILTER (WHERE unit_price = 0) AS zero_values,
	COUNT(*) FILTER (WHERE unit_price < 0) AS negative_values
FROM raw.order_items
			
UNION ALL

SELECT
	'discount_percentage' AS column_name,
	MIN(discount_percentage) AS min_value,
	MAX(discount_percentage) AS max_value,
	COUNT(*) FILTER (WHERE discount_percentage = 0) AS zero_values,
	COUNT(*) FILTER (WHERE discount_percentage < 0) AS negative_values
FROM raw.order_items
			
UNION ALL

SELECT
	'discount_amount' AS column_name,
	MIN(discount_amount) AS min_value,
	MAX(discount_amount) AS max_value,
	COUNT(*) FILTER (WHERE discount_amount = 0) AS zero_values,
	COUNT(*) FILTER (WHERE discount_amount < 0) AS negative_values
FROM raw.order_items
			
UNION ALL

SELECT
	'gross_sales' AS column_name,
	MIN(gross_sales) AS min_value,
	MAX(gross_sales) AS max_value,
	COUNT(*) FILTER (WHERE gross_sales = 0) AS zero_values,
	COUNT(*) FILTER (WHERE gross_sales < 0) AS negative_values
FROM raw.order_items
			
UNION ALL

SELECT
	'tax_amount' AS column_name,
	MIN(tax_amount) AS min_value,
	MAX(tax_amount) AS max_value,
	COUNT(*) FILTER (WHERE tax_amount = 0) AS zero_values,
	COUNT(*) FILTER (WHERE tax_amount < 0) AS negative_values
FROM raw.order_items
			
UNION ALL

SELECT
	'shipping_cost' AS column_name,
	MIN(shipping_cost) AS min_value,
	MAX(shipping_cost) AS max_value,
	COUNT(*) FILTER (WHERE shipping_cost = 0) AS zero_values,
	COUNT(*) FILTER (WHERE shipping_cost < 0) AS negative_values
FROM raw.order_items
			
UNION ALL

SELECT
	'net_sales' AS column_name,
	MIN(net_sales) AS min_value,
	MAX(net_sales) AS max_value,
	COUNT(*) FILTER (WHERE net_sales = 0) AS zero_values,
	COUNT(*) FILTER (WHERE net_sales < 0) AS negative_values
FROM raw.order_items
			
UNION ALL

SELECT
	'product_cost' AS column_name,
	MIN(product_cost) AS min_value,
	MAX(product_cost) AS max_value,
	COUNT(*) FILTER (WHERE product_cost = 0) AS zero_values,
	COUNT(*) FILTER (WHERE product_cost < 0) AS negative_values
FROM raw.order_items
			
UNION ALL

SELECT
	'profit' AS column_name,
	MIN(profit) AS min_value,
	MAX(profit) AS max_value,
	COUNT(*) FILTER (WHERE profit = 0) AS zero_values,
	COUNT(*) FILTER (WHERE profit < 0) AS negative_values
FROM raw.order_items;

/*
=================================================
    STEP 5: INTERNAL CONSISTENCY
=================================================
*/

/*
=================================================
ecommerce_sales_customer_analytics_150k
=================================================
*/

-- ecommerce_sales_customer_analytics_150k
-- Does net_sales = gross_sales - discount_amount + tax_amount + shipping_cost (2 decimals)?
-- Result: 0 mismatches across 138,116 rows.
SELECT
	COUNT(*) AS total_rows,
	COUNT(*) FILTER (WHERE
		ROUND(net_sales, 2) IS DISTINCT FROM
		ROUND(gross_sales - discount_amount + tax_amount + shipping_cost, 2)
	) AS net_sales_mismatches
FROM raw.ecommerce_sales_customer_analytics_150k;

-- ecommerce_sales_customer_analytics_150k
-- Largest absolute gap between net_sales and gross_sales - discount_amount + tax_amount + shipping_cost
-- Result: 0.000000000004197 (floating-point noise), so the formula holds exactly.
SELECT
	MAX(ABS(net_sales - (gross_sales - discount_amount + tax_amount + shipping_cost)))
FROM raw.ecommerce_sales_customer_analytics_150k;

-- ecommerce_sales_customer_analytics_150k
-- Does profit = net_sales - product_cost - shipping_cost (2 decimals)?
-- Result: 0 mismatches across 138,116 rows. Max absolute gap 0.0000000000025 (floating-point noise).
-- Equivalent to gross_sales - discount_amount + tax_amount - product_cost, so profit includes tax.
SELECT
	COUNT(*) AS total_rows,
	COUNT(*) FILTER (WHERE
		ROUND(profit, 2) IS DISTINCT FROM
		ROUND(net_sales - product_cost - shipping_cost, 2)
	) AS profit_mismatches
FROM raw.ecommerce_sales_customer_analytics_150k;

SELECT 
	MAX(ABS(profit - (net_sales - product_cost - shipping_cost)))
FROM raw.ecommerce_sales_customer_analytics_150k;

-- ecommerce_sales_customer_analytics_150k
-- Does profit_margin_percentage = profit / net_sales * 100 (2 decimals)?
-- Result: 1 mismatch in 138,116 rows. Stored 26.67 vs recomputed 26.675, a rounding tie.
-- Max absolute gap 0.005, consistent with 2-decimal rounding.
SELECT
	COUNT(*) AS total_rows,
	COUNT(*) FILTER (WHERE
		ROUND(profit_margin_percentage, 2) IS DISTINCT FROM
		ROUND(profit / net_sales * 100.0, 2)
	) AS profit_mismatches
FROM raw.ecommerce_sales_customer_analytics_150k;

SELECT 
	MAX(ABS(profit_margin_percentage - (profit / net_sales * 100.0)))
FROM raw.ecommerce_sales_customer_analytics_150k;

SELECT order_id, profit, net_sales, profit_margin_percentage,
       profit / net_sales * 100.0 AS recomputed
FROM raw.ecommerce_sales_customer_analytics_150k
WHERE ROUND(profit_margin_percentage, 2) IS DISTINCT FROM ROUND(profit / net_sales * 100.0, 2);

/*
=================================================
order_items
=================================================
*/

-- order_items
-- Does net_sales = gross_sales - discount_amount + tax_amount + shipping_cost (2 decimals)?
-- Result: 0 mismatches across 397,569 rows. Max absolute gap 0.000000000000003 (floating-point noise).
SELECT
	COUNT(*) AS total_rows,
	COUNT(*) FILTER (WHERE
		ROUND(net_sales, 2) IS DISTINCT FROM
		ROUND(gross_sales - discount_amount + tax_amount + shipping_cost, 2)
	) AS net_sales_mismatches
FROM raw.order_items;

SELECT
	MAX(ABS(net_sales - (gross_sales - discount_amount + tax_amount + shipping_cost)))
FROM raw.order_items;

-- order_items
-- Does profit = net_sales - product_cost - shipping_cost (2 decimals)?
-- Result: 0 mismatches across 397,569 rows. Max absolute gap 0.000000000000003 (floating-point noise).
-- Equivalent to gross_sales - discount_amount + tax_amount - product_cost, so profit includes tax here too.
SELECT
	COUNT(*) AS total_rows,
	COUNT(*) FILTER (WHERE
		ROUND(profit, 2) IS DISTINCT FROM
		ROUND(net_sales - product_cost - shipping_cost, 2)
	) AS profit_mismatches
FROM raw.order_items;

SELECT 
	MAX(ABS(profit - (net_sales - product_cost - shipping_cost)))
FROM raw.order_items;

-- order_items
-- Does discount_amount = gross_sales * discount_percentage (2 decimals)?
-- Result: 0 mismatches across 397,569 rows. Max absolute gap 0.005, consistent with 2-decimal rounding.
SELECT
	COUNT(*) AS total_rows,
	COUNT(*) FILTER (WHERE
		ROUND(discount_amount,2) IS DISTINCT FROM
		ROUND(gross_sales * discount_percentage, 2)
	) AS discount_mismatches
FROM raw.order_items;

SELECT
	MAX(ABS(discount_amount - (gross_sales * discount_percentage)))
FROM raw.order_items;

-- order_items
-- Rows with discount_percentage > 0 but discount_amount = 0
-- Result: 33 rows. Largest unrounded discount is 0.00496 (below 0.005), so the amount rounds to 0.00.
SELECT 
	MAX(gross_sales * discount_percentage) AS max_unrounded_discount
FROM raw.order_items
WHERE discount_percentage > 0 AND discount_amount = 0;

/*
=================================================
customer_master
=================================================
*/

-- customer_master
-- How many rows have gross_sales different from quantity * unit_price?
-- Result: 0 -> gross_sales is consistent across all 397,569 rows
SELECT 
	COUNT(*) AS mismatches
FROM raw.order_items
WHERE ROUND(gross_sales,2) IS DISTINCT FROM ROUND(quantity * unit_price, 2);

/*
=================================================
    STEP 6: CROSS-TABLE INTEGRITY
=================================================
*/

-- sales vs order_items
-- Sales orders with no line items in order_items
-- Result: 0
SELECT
	COUNT(*)
FROM raw.ecommerce_sales_customer_analytics_150k AS s
WHERE NOT EXISTS (
	SELECT 1 
	FROM raw.order_items AS o
	WHERE o.order_id = s.order_id
);

-- order_items vs sales
-- order_items rows whose order_id is not in the sales table
-- Result: 0. Both tables cover the same 138,116 orders.
SELECT
	COUNT(*)
FROM raw.order_items AS o
WHERE NOT EXISTS (
	SELECT 1 
	FROM raw.ecommerce_sales_customer_analytics_150k AS s
	WHERE o.order_id = s.order_id
);

-- sales vs order_items
-- Compare order-level totals in the sales table with SUMs of order_items per order
-- Result (138,116 orders): mismatches quantity 11,226 | gross_sales 11,226 | tax_amount 11,226 |
-- net_sales 11,226 | product_cost 11,226 | profit 11,226 | shipping_cost 11,204 | discount_amount 9,799.
-- 126,890 orders (91.9%) match on every column.
WITH item_totals AS (
	SELECT
		order_id,
		SUM(quantity) AS total_quantity,
		ROUND(SUM(discount_amount),2) AS total_discount,
		ROUND(SUM(gross_sales),2) AS total_gross,
		ROUND(SUM(tax_amount),2) AS total_tax,
		ROUND(SUM(shipping_cost),2) AS total_shipping,
		ROUND(SUM(net_sales),2) AS total_net,
		ROUND(SUM(product_cost),2) AS total_product_cost,
		ROUND(SUM(profit),2) AS total_profit
	FROM raw.order_items
	GROUP BY order_id
)
SELECT 
	COUNT(*) AS total_orders,
	COUNT(*) FILTER(WHERE i.total_quantity IS DISTINCT FROM s.quantity) AS quantity_mismatch,
	COUNT(*) FILTER(WHERE ROUND(i.total_discount,2) IS DISTINCT FROM ROUND(s.discount_amount,2)) AS discount_mismatch,
	COUNT(*) FILTER(WHERE ROUND(i.total_gross,2) IS DISTINCT FROM ROUND(s.gross_sales,2)) AS gross_mismatch,
	COUNT(*) FILTER(WHERE ROUND(i.total_tax,2) IS DISTINCT FROM ROUND(s.tax_amount,2)) AS tax_mismatch,
	COUNT(*) FILTER(WHERE ROUND(i.total_shipping,2) IS DISTINCT FROM ROUND(s.shipping_cost,2)) AS shipping_mismatch,
	COUNT(*) FILTER(WHERE ROUND(i.total_net,2) IS DISTINCT FROM ROUND(s.net_sales,2)) AS net_mismatch,
	COUNT(*) FILTER(WHERE ROUND(i.total_product_cost,2) IS DISTINCT FROM ROUND(s.product_cost,2)) AS product_cost_mismatch,
	COUNT(*) FILTER(WHERE ROUND(i.total_profit,2) IS DISTINCT FROM ROUND(s.profit,2)) AS profit_mismatch
FROM item_totals AS i
INNER JOIN raw.ecommerce_sales_customer_analytics_150k AS s
	ON i.order_id = s.order_id;

-- sales vs order_items
-- Do the same orders mismatch on quantity and gross_sales?
-- Result: yes/yes 11,226 | no/no 126,890. No order mismatches on only one of the two.
WITH item_totals AS (
	SELECT
		order_id,
		SUM(quantity) AS total_quantity,
		ROUND(SUM(gross_sales),2) AS total_gross
	FROM raw.order_items
	GROUP BY order_id
)
SELECT 
	CASE 
		WHEN i.total_quantity IS DISTINCT FROM s.quantity THEN 'yes'
		ELSE 'no'
	END AS quantity_mismatch,
	CASE 
		WHEN ROUND(i.total_gross,2) IS DISTINCT FROM ROUND(s.gross_sales,2) THEN 'yes'
		ELSE 'no'
	END AS gross_mismatch,
	COUNT(*) AS total_rows
FROM item_totals AS i
INNER JOIN raw.ecommerce_sales_customer_analytics_150k AS s
	ON i.order_id = s.order_id
GROUP BY quantity_mismatch, gross_mismatch
ORDER BY total_rows DESC;