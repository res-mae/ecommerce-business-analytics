# Findings

Running list of results supported by the data. Each links to a query in `sql/05_business_analysis.sql`.

## Supported by the data
- **Q1:** Completed orders hold 81.40% of recorded Net Sales and 78.48% of Profit. About 11% of Net Sales is tax and shipping, stable across statuses.
- **Q2:** Net Sales peak in November and December and are lowest in February in all five years.
- **Q2:** Discounts reach about 30% of gross sales in Nov and Dec (about 22% in July, about 14% in September, 9.4% to 10.2% otherwise). Profit-to-Net-Sales falls from about 47% to about 33% in Nov and Dec. Product cost stays at 51% to 52% of gross sales.
- **Q2a:** No sustained growth or decline. Orders stay within 27,554 to 27,768 and Net Sales change by at most 1.2% per year.
- **Q3:** Smartphones, TVs and Smart Watches lead Net Sales and Profit (Completed orders). All 8 Electronics subcategories have the lowest margins (30.42% to 34.27%), while Grocery - Snacks has the highest (60.74%).
- **Q4:** 97.90% of customers (24,387) placed 2 or more orders. Net Sales per order is about the same across order-count bands (1,271 to 1,286), so customer value follows order frequency, not order size.

## Open questions
- Why discounts are deeper in Nov, Dec, Jul and Sep, and whether they lift orders (July orders are not higher than June or August).
- Why Electronics margins are lower than other categories.

## Limitations
- No data dictionary. Meanings of `net_sales`, `tax_amount`, `shipping_cost` and `profit` are inferred from arithmetic. `profit` includes tax.
- `order_items` totals run about 8.6% above `analytics.sales`, cause unknown, so product-level results use a different basis.
- `customer_order_count` is up to 5 above the actual order count for 37.8% of customers, cause unknown, so repeat customers are defined from actual orders.