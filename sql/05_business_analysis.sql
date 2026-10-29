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

-- Result:
-- Completed orders account for 81.40% of total recorded Net Sales.
-- Returned, Cancelled, and Pending orders account for the remaining
-- 18.60%.

-- Takeaway:
-- Completed orders contribute the largest share of recorded Net Sales
-- and Profit. Financial values for non-Completed orders should not
-- automatically be interpreted as realized revenue or retained profit.
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
	AS net_sales_pct_of_total
FROM analytics.sales
GROUP BY order_status
ORDER BY total_orders DESC;

-- Q2. How do monthly Net Sales and Profit change over time?
-- Result:
-- December has the highest Net Sales in each of the five years, while
-- February has the lowest. November and December occupy the top 10
-- year-month periods by Net Sales.

-- Takeaway:
-- The recurring year-end peak and February slowdown may inform inventory,
-- staffing, and marketing plans. Further analysis is needed to explain
-- the underlying causes and differences in Profit performance.
SELECT
	DATE_TRUNC('month', order_date) AS year_month,
	COUNT(*) AS total_orders,
	SUM(net_sales) AS total_net_sales,
	SUM(profit) AS total_profit
FROM analytics.sales
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date);

-- Q2a. Which year-month periods have the highest Net Sales?
-- Supporting query: Returns the 10 year-month periods with the highest
-- recorded Net Sales.
SELECT
	DATE_TRUNC('month', order_date) AS year_month,
	COUNT(*) AS total_orders,
	SUM(net_sales) AS total_net_sales,
	SUM(profit) AS total_profit
FROM analytics.sales
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY total_net_sales DESC
LIMIT 10;

-- Q2b. Which year-month periods have the lowest Net Sales?
-- Supporting query: Returns the 10 year-month periods with the lowest
-- recorded Net Sales.
SELECT
	DATE_TRUNC('month', order_date) AS year_month,
	COUNT(*) AS total_orders,
	SUM(net_sales) AS total_net_sales,
	SUM(profit) AS total_profit
FROM analytics.sales
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY total_net_sales
LIMIT 10;

-- Q2c. Which calendar months have the highest and lowest average monthly Net Sales and Profit across 2021–2025?
-- Result:
-- December has the highest average monthly Net Sales (4,659,691.51)
-- and Profit (1,535,276.05) across 2021–2025. February has the lowest
-- average for both measures.

-- Takeaway:
-- These averages reinforce the seasonal pattern observed in the monthly
-- results and can help guide planning. The underlying causes still need
-- further investigation.
WITH monthly_totals AS (
	SELECT
		DATE_TRUNC('month', order_date) AS year_month,
		COUNT(*) AS total_orders,
		SUM(net_sales) AS total_net_sales,
		SUM(profit) AS total_profit
	FROM analytics.sales
	GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
	EXTRACT('month' FROM year_month) AS month,
	ROUND(AVG(total_orders),2) AS avg_orders,
	ROUND(AVG(total_net_sales),2) AS avg_net_sales,
	ROUND(AVG(total_profit),2) AS avg_profit
FROM monthly_totals
GROUP BY EXTRACT('month' FROM year_month)
ORDER BY avg_net_sales DESC;

-- Q3. Which product categories and subcategories generate the most
-- sales and profit?

-- Result:
-- Electronics - Smartphones ranks first by both Net Sales (7,651,215.85)
-- and recorded Profit (2,747,675.09). Electronics - TVs ranks second in both.
-- Grocery - Snacks has the highest recorded profit margin among
-- the category/subcategory combinations (61.74%), while Electronics -
-- Tablets has the lowest (32.18%).
-- Home Appliances - Washing Machines appears in the top 10 by Profit
-- but not by Net Sales.

-- Takeaway:
-- Smartphones and TVs lead in total recorded financial contribution,
-- while margin rankings highlight different aspects of performance.
-- High total Profit does not necessarily mean a high profit margin;
-- further analysis could investigate the differences.

-- Top 10 product combinations by Net Sales
SELECT
	p.product_category,
	p.product_subcategory,
	COUNT(*) AS order_line_count,
	COUNT(DISTINCT o.order_id) AS distinct_order_count,
	SUM(o.net_sales) AS total_net_sales,
	SUM(o.profit) AS total_profit
FROM analytics.products AS p
INNER JOIN analytics.order_items AS o
	ON p.product_id = o.product_id
GROUP BY p.product_category, p.product_subcategory
ORDER BY total_net_sales DESC
LIMIT 10;

-- Top 10 product combinations by Profit
SELECT
	p.product_category,
	p.product_subcategory,
	COUNT(*) AS order_line_count,
	COUNT(DISTINCT o.order_id) AS distinct_order_count,
	SUM(o.net_sales) AS total_net_sales,
	SUM(o.profit) AS total_profit
FROM analytics.products AS p
INNER JOIN analytics.order_items AS o
	ON p.product_id = o.product_id
GROUP BY p.product_category, p.product_subcategory
ORDER BY total_profit DESC
LIMIT 10;

-- Top 10 product combinations by profit margin
SELECT
	p.product_category,
	p.product_subcategory,
	COUNT(*) AS order_line_count,
	COUNT(DISTINCT o.order_id) AS distinct_order_count,
	ROUND(100.0 * SUM(o.profit) / SUM(o.net_sales),2)  AS profit_margin
FROM analytics.products AS p
INNER JOIN analytics.order_items AS o
	ON p.product_id = o.product_id
GROUP BY p.product_category, p.product_subcategory
ORDER BY profit_margin DESC
LIMIT 10;

-- Bottom 10 product combinations by profit margin
SELECT
	p.product_category,
	p.product_subcategory,
	COUNT(*) AS order_line_count,
	COUNT(DISTINCT o.order_id) AS distinct_order_count,
	ROUND(100.0 * SUM(o.profit) / SUM(o.net_sales),2)  AS profit_margin
FROM analytics.products AS p
INNER JOIN analytics.order_items AS o
	ON p.product_id = o.product_id
GROUP BY p.product_category, p.product_subcategory
ORDER BY profit_margin
LIMIT 10;
