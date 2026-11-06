/*
=================================================
    BUSINESS ANALYSIS
=================================================
Sources:
- analytics.sales: order-level measures (sales, profit, orders, returns, delivery)
- analytics.order_items: product-level analysis only
- analytics.customers, analytics.products: attributes

Rules:
- Never sum order-level columns after joining sales to order_items.
- Group by product_category and product_subcategory together.
- Net Sales = net_sales, Profit = profit (dataset definitions, no data dictionary).
- Delivery and rating analysis uses Completed orders only.

Each query: business question, result, takeaway (finding only if the data shows it).
*/

-- Q1. By order_status in analytics.sales, how many orders are there, what are net_sales 
-- and profit, and what share of net_sales is tax and shipping?
-- Scope: all order statuses (recorded values, not realized revenue)

-- Result:
-- Orders: Completed 113,559 | Returned 9,462 | Cancelled 8,398 | Pending 6,697
-- Net Sales share: Completed 81.40% | Returned 7.44% | Cancelled 6.41% | Pending 4.75%
-- Profit share: Completed 78.48% | Returned 9.10% | Cancelled 7.85% | Pending 4.58%
-- Tax is 9.42% to 9.64% and shipping 1.60% to 1.79% of Net Sales across statuses
-- (Completed: 9.54% and 1.75%, about 11.3% combined).

-- Takeaway:
-- Completed orders hold 81.40% of recorded Net Sales and 78.48% of recorded Profit.
-- The other 18.60% of Net Sales sits in Returned, Cancelled and Pending orders,
-- so Net Sales as defined includes amounts that may not have been realized.
-- About 11% of Net Sales is tax and shipping, and that share is stable across statuses.
SELECT
	order_status,
	COUNT(*) AS total_orders,
	SUM(net_sales) AS total_net_sales,
	SUM(profit) AS total_profit,
	ROUND(
		100.0 * SUM(tax_amount) / NULLIF(SUM(net_sales), 0), 
		2 ) 
	AS tax_pct_of_net_sales,
	ROUND(
		100.0 * SUM(shipping_cost) / NULLIF(SUM(net_sales), 0), 
		2)
	AS shipping_pct_of_net_sales,
	ROUND(
		100.0 * SUM(net_sales) / NULLIF((SELECT SUM(net_sales) FROM analytics.sales),0),
		2)
	AS net_sales_pct_of_total,
	ROUND(
		100.0 * SUM(profit) / NULLIF((SELECT SUM(profit) FROM analytics.sales),0),
		2)
	AS profit_pct_of_total
FROM analytics.sales
GROUP BY order_status
ORDER BY total_orders DESC;

-- Q2. How do monthly Net Sales and Profit change over time?
-- Scope: all order statuses (recorded values, not realized revenue)
-- Result:
-- Highest month: 2021-12 (Net Sales 4,900,970.07). Lowest: 2021-02 (1,905,413.15).
-- By Net Sales, December ranks 1 within its year in 5 of 5 years, November ranks 2
-- in 5 of 5, and February ranks 12 in 5 of 5.
-- All ten November and December months are above 4.2M. The highest other month is 3.22M (2021-08).
-- Profit-to-Net-Sales: 32.3% to 33.6% in Nov and Dec, 39.5% to 40.4% in July,
-- about 45% in September, and 47.1% to 47.9% in all other months.
-- Discount as % of gross sales: about 30% in Nov and Dec, about 22% in July,
-- about 14% in September, and 9.4% to 10.2% otherwise.
-- Product cost as % of gross sales: 51% to 52% in every month.

-- Takeaway:
-- Finding: Net Sales peak in November and December and are lowest in February every year.
-- Finding: The profit ratio falls in the months with deeper discounts. 
-- Product cost stays at 51% to 52% of gross sales, so the discount drives the ratio.
-- Open question: why discounts are deeper in those months, and whether they lift orders
-- (July orders are not higher than June or August). Not explained by this data.
SELECT
	DATE_TRUNC('month', order_date)::DATE AS year_month,
	COUNT(*) AS total_orders,
	SUM(net_sales) AS total_net_sales,
	SUM(profit) AS total_profit,
	ROUND(100.0 * SUM(profit) / NULLIF(SUM(net_sales), 0),2) AS profit_to_net_sales_pct,
	ROUND(100.0 * SUM(discount_amount) / NULLIF(SUM(gross_sales),0),2) AS discount_to_gross_pct,
	ROUND(100.0 * SUM(product_cost) / NULLIF(SUM(gross_sales),0),2) AS product_cost_to_gross_pct,
	RANK() OVER (
		PARTITION BY EXTRACT(YEAR FROM (DATE_TRUNC('month', order_date)::DATE))
		ORDER BY SUM(net_sales) DESC
	) AS rank_in_year
FROM analytics.sales
GROUP BY year_month
ORDER BY year_month;

-- Q2a. How do Net Sales, Profit and orders change year over year?
-- Scope: all order statuses (recorded values, not realized revenue)
-- Result:
-- Orders: 27,554 (2021), 27,564, 27,632, 27,768, 27,598 (2025).
-- Net Sales YoY: -1.11%, +0.57%, -0.17%, -1.06%. Profit YoY: -1.03%, +0.53%, +0.30%, -1.18%.
-- 2025 vs 2021: Net Sales -1.77%, orders +0.16%.

-- Takeaway:
-- Finding: no sustained growth or decline. Annual changes stay within about 1.2%
-- and switch between positive and negative with no consistent direction.
-- Implication for the dashboard: YoY will look flat, so seasonality is the main time pattern.
WITH yearly AS (
	SELECT
		EXTRACT(YEAR FROM order_date)::INT AS order_year,
		COUNT(*) AS total_orders,
		SUM(net_sales) AS total_net_sales,
		SUM(profit) AS total_profit
	FROM analytics.sales
	GROUP BY EXTRACT(YEAR FROM order_date)::INT
),
with_prev AS (
	SELECT 
		*,
		LAG(total_net_sales) OVER (ORDER BY order_year) AS prev_net_sales,
		LAG(total_profit) OVER (ORDER BY order_year) AS prev_total_profit
	FROM yearly
)
SELECT
	order_year,
	total_orders,
	total_net_sales,
	total_profit,
	ROUND(
		100.0 * (total_net_sales - prev_net_sales) / prev_net_sales
	, 2) AS yoy_net_pct,
	ROUND(
		100.0 * (total_profit - prev_total_profit) / prev_total_profit
	, 2) AS yoy_profit_pct
FROM with_prev
ORDER BY order_year;

-- Q3. Which product categories and subcategories generate the most
-- sales and profit?
-- Scope: Completed orders only (status filter via analytics.sales)
-- Basis: analytics.order_items line amounts (order_items 
-- total ran ~8.6% above analytics.sales across all statuses, see data_quality_log)

-- Result:
-- Top 3 by Net Sales and by Profit: Electronics - Smartphones (6,288,254.76 | 2,155,209.03),
-- Electronics - TVs (5,732,863.02 | 1,824,234.32), Electronics - Smart Watches (5,207,071.59 | 1,659,470.85).
-- Highest margin: Grocery - Snacks (60.74%). Lowest: Electronics - Tablets (30.42%).
-- All 8 Electronics subcategories have margins of 30.42% to 34.27% (margin ranks 110 to 120 of 120).
-- Washing Machines are top 10 by Profit (rank 10) but not by Net Sales (rank 15).
-- Gaming Consoles are top 10 by Net Sales (rank 10) but not by Profit (rank 11).
-- Every subcategory has at least 1,369 order lines.

-- Takeaway:
-- Finding: the largest subcategories by Net Sales and Profit are Electronics, and they have the
-- lowest margins, so Net Sales rank and margin rank point in opposite directions.
-- Caveat: margin = Profit / Net Sales, and both include tax and shipping.
-- Open question: why Electronics margins are lower (not explained by this data).
SELECT
	p.product_category,
	p.product_subcategory,
	COUNT(*) AS order_line_count,
	COUNT(DISTINCT o.order_id) AS distinct_order_count,
	SUM(o.net_sales) AS total_net_sales,
	SUM(o.profit) AS total_profit,
	ROUND(100.0 * SUM(o.profit) / SUM(o.net_sales),2)  AS profit_margin,
	RANK() OVER (
		ORDER BY SUM(o.net_sales) DESC
	) AS net_sales_rank,
	RANK() OVER (
		ORDER BY SUM(o.profit) DESC
	) AS profit_rank,
	RANK() OVER (
		ORDER BY ROUND(100.0 * SUM(o.profit) / SUM(o.net_sales),2) DESC
	) AS profit_margin_rank
FROM analytics.products AS p
INNER JOIN analytics.order_items AS o
	ON p.product_id = o.product_id
INNER JOIN analytics.sales AS s
	ON o.order_id = s.order_id
WHERE s.order_status = 'Completed'
GROUP BY p.product_category, p.product_subcategory
ORDER BY net_sales_rank;

-- Q4. Can is_repeat_customer or customer_order_count be used to separate repeat from one-time customers?
-- Scope: all order statuses (a customer counts every order, including Cancelled and Pending)

-- Q4a. How many orders does each customer have?
-- Result: 24,911 customers and 138,116 orders. 524 customers (2.10%) have exactly 1 order.
-- The rest have 2 to 19 orders. 3,942 customers have 6 orders and 4,288 have 5, the most common counts.
-- The 334 FALSE rows in is_repeat_customer do not match the 524 one-order customers.
WITH per_customer AS (
	SELECT
		customer_id,
		COUNT(*) AS order_count
	FROM analytics.sales
	GROUP BY customer_id
)
SELECT
	order_count,
	COUNT(*) AS customers
FROM per_customer
GROUP BY order_count
ORDER BY order_count;

-- Q4b. Is customer_order_count constant within each customer?
-- Result: 0 rows, so every customer has the same customer_order_count on all of their rows.
SELECT
	customer_id,
	COUNT(DISTINCT customer_order_count) AS distinct_order_count
FROM analytics.sales
GROUP BY customer_id
HAVING COUNT(DISTINCT customer_order_count) > 1;

-- Q4c. Does customer_order_count equal the actual number of orders per customer?
-- Result: stored minus actual is 0 for 15,487 customers (62.2%) and above 0 for 9,424 (37.8%):
-- +1 for 7,367, +2 for 1,732, +3 for 288, +4 for 35, +5 for 2. It is never below the actual count.
-- Cause unknown.

-- Takeaway:
-- Decision: define repeat customers from the actual order count (1 order = one-time, 2 or more = repeat).
-- customer_order_count and is_repeat_customer are kept as reported fields and not used here.
WITH per_customer AS (
	SELECT
		customer_id,
		COUNT(*) AS actual_orders,
		MAX(customer_order_count) AS stored_count
	FROM analytics.sales
	GROUP BY customer_id
)
SELECT
	stored_count - actual_orders AS diff,
	COUNT(*) AS customers
FROM per_customer
GROUP BY stored_count - actual_orders
ORDER BY diff;

-- Q4d. How do customers compare by order frequency, and does value rise with it?
-- Scope: all order statuses. Customers are grouped by actual order count (see Q4c).

-- Result:
-- One-time customers: 524 (2.10%) with 0.38% of Net Sales. The other 24,387 customers (97.90%) hold 99.62%.
-- Net Sales per customer: 1,270.86 (1 order) | 4,229.89 (2-4) | 8,300.28 (5-9) | 13,827.93 (10+).
-- Net Sales per order: 1,270.86 | 1,286.40 | 1,281.59 | 1,281.69 (within 1.2% across bands).
-- Profit-to-Net-Sales: 44.12% (1 order) and 42.90% to 43.01% in the other bands.
-- The 5-9 band is the largest: 14,807 customers and 69.38% of Net Sales.

-- Takeaway:
-- Finding: Net Sales per order is about the same in every band, so customer value rises with
-- order frequency, not with order size.
-- Caveat: only 524 customers are one-time, so that band's ratios (including 44.12%) are less reliable.
WITH per_customer AS (
	SELECT
		customer_id,
		COUNT(*) AS order_count,
		SUM(net_sales) AS net_sales,
		SUM(profit) AS profit
	FROM analytics.sales
	GROUP BY customer_id
),
banded AS (
	SELECT
		*,
		CASE
			WHEN order_count = 1 THEN '1. one order'
			WHEN order_count BETWEEN 2 AND 4 THEN '2. 2-4 orders'
			WHEN order_count BETWEEN 5 AND 9 THEN '3. 5-9 orders'
			ELSE '4. 10 or more orders'
		END AS order_band
	FROM per_customer
)
SELECT
	order_band,
	COUNT(*) AS customers,
	SUM(order_count) AS orders,
	SUM(net_sales) AS total_net_sales,
	SUM(profit) AS total_profit,
	ROUND(SUM(net_sales) / COUNT(*), 2) AS net_sales_per_customer,
	ROUND(SUM(net_sales) / SUM(order_count), 2) AS net_sales_per_order,
	ROUND(100.0 * SUM(profit) / NULLIF(SUM(net_sales), 0), 2) AS profit_to_net_sales_pct,
	ROUND(100.0 * SUM(net_sales) / SUM(SUM(net_sales)) OVER (), 2) AS net_sales_share_pct
FROM banded
GROUP BY order_band
ORDER BY order_band;

-- Q5a. Do customer attributes agree between analytics.sales and analytics.customers?
-- Scope: all order rows in analytics.sales (138,116), joined on customer_id.
-- Result: 0 rows differ in customer_segment, customer_age, gender, customer_city, customer_state,
-- customer_country, region or customer_postal_code.
-- Takeaway: either table can supply customer attributes. Q5 uses analytics.sales so totals tie back to Q1.
SELECT
	COUNT(*) FILTER (WHERE s.customer_segment IS DISTINCT FROM c.customer_segment) AS segment_mismatch,
	COUNT(*) FILTER (WHERE s.customer_age IS DISTINCT FROM c.customer_age) AS age_mismatch,
	COUNT(*) FILTER (WHERE s.gender IS DISTINCT FROM c.gender) AS gender_mismatch,
	COUNT(*) FILTER (WHERE s.customer_city IS DISTINCT FROM c.customer_city) AS city_mismatch,
	COUNT(*) FILTER (WHERE s.customer_state IS DISTINCT FROM c.customer_state) AS state_mismatch,
	COUNT(*) FILTER (WHERE s.customer_country IS DISTINCT FROM c.customer_country) AS country_mismatch,
	COUNT(*) FILTER (WHERE s.region IS DISTINCT FROM c.region) AS region_mismatch,
	COUNT(*) FILTER (WHERE s.customer_postal_code IS DISTINCT FROM c.customer_postal_code) AS postal_code_mismatch
FROM analytics.sales AS s
INNER JOIN analytics.customers AS c
	ON s.customer_id = c.customer_id;

-- Q5. Which customer segments hold the most value?
-- Scope: all order statuses, with Completed-only Net Sales shown alongside.

-- Result:
-- Net Sales share: Consumer 54.87% | Premium 24.99% | VIP 10.11% | Business 10.03%.
-- Customers: Consumer 13,585 | Premium 6,275 | VIP 2,536 | Business 2,515 (24,911 in total).
-- Net Sales per customer: 7,054.95 to 7,155.02. Per order: 1,274.10 to 1,289.13.
-- Orders per customer: 5.48 to 5.57.
-- Profit-to-Net-Sales: Consumer 44.05% | Business 43.82% | VIP 41.15% | Premium 41.06%.
-- Discount as % of gross sales: Premium 20.23% | VIP 20.20% | Business 15.78% | Consumer 15.55%.
-- On Completed-only Net Sales the ranking is the same (Consumer 54.98% | Premium 24.86% | VIP 10.14% | Business 10.02%).

-- Takeaway:
-- Finding: segment totals follow the number of customers. Net Sales per customer and per order differ by
-- about 1.4% and 1.2% across segments, so VIP and Premium are not higher value per customer here.
-- Finding: Premium and VIP are discounted about 4.5 points deeper, and their profit ratio is about 3 points
-- lower. This follows largely from the discount, because profit = gross - discount + tax - cost.
-- Open question: why Premium and VIP are discounted more. Not explained by this data.
SELECT
	customer_segment,
	COUNT(DISTINCT customer_id) AS total_customer,
	COUNT(*) AS total_orders,
	SUM(net_sales) AS total_net_sales,
	SUM(profit) AS total_profit,
	ROUND(SUM(net_sales) / COUNT(DISTINCT customer_id),2) AS net_sales_per_customer,
	ROUND(SUM(net_sales) / COUNT(*),2) AS net_sales_per_order,
	ROUND(SUM(profit) * 100.0 / NULLIF(SUM(net_sales),0),2) AS profit_pct_of_net_sales,
	ROUND(SUM(net_sales) * 100 / SUM(SUM(net_sales)) OVER (),2) AS share_pct_of_net_sales,
	ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT customer_id),2) AS orders_per_customer,
	ROUND(SUM(discount_amount) * 100.0 / NULLIF(SUM(gross_sales),0),2) AS discount_to_gross_pct,
	SUM(net_sales) FILTER (WHERE order_status = 'Completed') AS completed_only_net_sales
FROM analytics.sales
GROUP BY customer_segment
ORDER BY total_net_sales DESC;

-- Q6a. Where are returns and cancellations concentrated?
-- Scope: all orders. Rates are % of orders in each group. Overall: Returned 6.85%, Cancelled 6.08%.

-- Result:
-- By segment: Returned (Consumer 6.84% | Business 7.06% | VIP 6.69% | Premium 6.85%), 
--   Cancelled (Consumer 6.02% | Business 6.00% | VIP 6.25% | Premium 6.18%).
-- By channel: Returned (Marketplace 6.93% | Mobile App 6.91% | Social Media 6.41% | Website 6.87%), 
--   Cancelled (Marketplace 6.19% | Mobile App 6.02% | Social Media 6.03% | Website 6.12%).
-- Segment x channel (16 groups): Returned 5.72% to 7.40%, Cancelled 5.67% to 6.73%.

-- Takeaway:
-- Finding: Returned and Cancelled rates are close to the overall 6.85% and 6.08% in every segment
-- and channel (segments 6.69% to 7.06% and 6.00% to 6.25%).
-- Observation: Social Media has the lowest return rate (6.41%) against 6.87% to 6.93% elsewhere.
-- Check its order count in the output. A gap of about 0.4 points on a group of ~30,000 orders is
-- larger than chance alone would usually produce. Cause unknown, and not tested.
-- Caveat: the 16-group grid has small groups, so gaps of about 1 point are within chance.
SELECT
	customer_segment,
	sales_channel,
	COUNT(*) AS total_orders,
	COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned_orders,
	COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled_orders,
	ROUND(COUNT(*) FILTER (WHERE order_status = 'Returned') * 100.0 / COUNT(*),2) AS returned_rate,
	ROUND(COUNT(*) FILTER (WHERE order_status = 'Cancelled') * 100.0 / COUNT(*),2) AS cancelled_rate
FROM analytics.sales
GROUP BY GROUPING SETS (
	(customer_segment, sales_channel),
	(customer_segment),
	(sales_channel),
	()
)
ORDER BY 
	GROUPING(customer_segment),
	GROUPING(sales_channel);

-- Q6b. How do ratings and order value differ by delivery status?
-- Scope: Completed orders only (113,559). Returned, Cancelled and Pending orders have no delivery data.

-- Result:
-- Orders: On Time 86,916 | Delayed 16,886 | Early 9,757.
-- Average rating: Early 4.02 | On Time 3.73 | Delayed 3.22.
-- Net Sales per order: Early 1,275.48 | Delayed 1,270.58 | On Time 1,268.99.

-- Takeaway:
-- Finding: later delivery is associated with lower ratings (Delayed 3.22 vs On Time 3.73 vs Early 4.02).
-- Finding: order value is about the same across delivery statuses, so the rating gap is not an order-size effect.
-- Caveat: association only. The data does not show that delays cause the lower ratings.
SELECT
	delivery_status,
	COUNT(*) AS total_orders,
	ROUND(AVG(customer_rating),2) AS avg_customer_rating,
	ROUND(SUM(net_sales) / COUNT(*),2) AS net_sales_per_order
FROM analytics.sales
WHERE order_status = 'Completed'
GROUP BY delivery_status
ORDER BY net_sales_per_order;

-- Q6c. Does delivery_status agree with delivery_days versus estimated_delivery_days?
-- Scope: Completed orders only (113,559).
-- Result: On Time and Delayed labels match the days comparison for every order
-- (Delayed = 1 to 4 days late, Early = 1 to 2 days early, On Time = 0).
-- 511 orders (0.45%) are labeled Early but were delivered on the estimated day (difference 0).
-- Takeaway:
-- Finding: delivery_status matches the days comparison for 99.55% of Completed orders.
-- Open question: why 511 orders are labeled Early with no day difference. Not explained by this data.
WITH status AS (
	SELECT
		delivery_status,
	 	CASE 
			WHEN delivery_days > estimated_delivery_days THEN 'Delayed'
			WHEN delivery_days < estimated_delivery_days THEN 'Early'
			WHEN delivery_days = estimated_delivery_days THEN 'On Time'
		END AS expected_delivery_status,
		delivery_days - estimated_delivery_days AS day_difference
	FROM analytics.sales
	WHERE order_status = 'Completed'
)
SELECT
	delivery_status,
	expected_delivery_status,
	COUNT(*) AS total_orders,
	MIN(day_difference) AS min_day_difference,
	MAX(day_difference) AS max_day_difference
FROM status
GROUP BY 
	delivery_status,
	expected_delivery_status
ORDER BY total_orders DESC;

