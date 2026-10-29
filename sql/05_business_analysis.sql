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
-- Completed: 113,559 orders, Net Sales = 144,195,838.50,
--   Profit = 59,758,469.03, tax = 9.54% of Net Sales,
--   shipping = 1.75% of Net Sales, and 81.40% of total Net Sales.
-- Returned: 9,462 orders, Net Sales = 13,172,674.79,
--   Profit = 6,925,597.40, tax = 9.64%, shipping = 1.60%,
--   and 7.44% of total Net Sales.
-- Cancelled: 8,398 orders, Net Sales = 11,356,479.77,
--   Profit = 5,974,148.36, tax = 9.62%, shipping = 1.64%,
--   and 6.41% of total Net Sales.
-- Pending: 6,697 orders, Net Sales = 8,409,270.68,
--   Profit = 3,488,180.97, tax = 9.42%, shipping = 1.79%,
--   and 4.75% of total Net Sales.

-- Takeaway:
-- Completed orders account for 81.40% of total recorded Net Sales
-- and contribute the largest share of recorded profit.
-- Returned, Cancelled, and Pending orders together account for
-- 18.60% of total recorded Net Sales. Tax and shipping percentages
-- are relatively consistent across all four order statuses.
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

