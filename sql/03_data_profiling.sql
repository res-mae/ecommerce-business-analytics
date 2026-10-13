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

-- order_items: Check one pair having the same quantity, unit price, and discount_percentage
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

