# Findings

Running list of results supported by the data. Each links to a query in `sql/05_business_analysis.sql`.

## Supported by the data
- **Q1:** Completed orders hold 81.40% of recorded Net Sales and 78.48% of Profit. About 11% of Net Sales is tax and shipping, stable across statuses.
- **Q2:** Net Sales peak in November and December and are lowest in February in all five years.
- **Q2:** Discounts reach about 30% of gross sales in Nov and Dec (about 22% in July, about 14% in September, 9.4% to 10.2% otherwise). Profit-to-Net-Sales falls from about 47% to about 33% in Nov and Dec. Product cost stays at 51% to 52% of gross sales.
- **Q2a:** No sustained growth or decline. Orders stay within 27,554 to 27,768 and Net Sales change by at most 1.2% per year.
- **Q3:** Smartphones, TVs and Smart Watches lead Net Sales and Profit (Completed orders). All 8 Electronics subcategories have the lowest margins (30.42% to 34.27%), while Grocery - Snacks has the highest (60.74%).
- **Q4:** 97.90% of customers (24,387) placed 2 or more orders. Net Sales per order is about the same across order-count bands (1,271 to 1,286), so customer value follows order frequency, not order size.
- **Q5:** Segment Net Sales follow segment size (Consumer 54.87%). Net Sales per customer and per order are within about 1.5% across segments, so VIP and Premium are not higher value per customer. Premium and VIP are discounted about 4.5 points deeper (about 20% of gross sales vs about 15.6%).
- **Q6a:** Returned and Cancelled rates stay close to the overall 6.85% and 6.08% in every segment and channel.
- **Q6b:** Among Completed orders, ratings fall with later delivery (Early 4.02, On Time 3.73, Delayed 3.22). Order value is about the same in all three statuses.

## Open questions
- Why are discounts deeper in November, December, July, and September, and do they lead to higher order volumes? (July orders are not higher than those in June or August.)
- Why are profit margins in Electronics lower than in other categories?
- Why do Premium and VIP customers receive higher discounts?
- Why are 511 completed orders labeled as “Early” when there is no difference in the estimated delivery date?

## Limitations
- No data dictionary. Meanings of `net_sales`, `tax_amount`, `shipping_cost` and `profit` are inferred from arithmetic. `profit` includes tax.
- `order_items` totals run about 8.6% above `analytics.sales`, cause unknown, so product-level results use a different basis.
- `is_repeat_customer` and `customer_order_count` don't match actual orders (the count is up to 5 above the actual for 37.8% of customers), so repeat customers are defined from actual order counts.
- Delivery and rating analysis covers the 113,559 Completed orders only.
- 511 Completed orders (5.2% of the Early group) are labeled Early but were delivered on the estimated day. Delivery results use `delivery_status` as given.
- Delivery and rating results cover the 113,559 Completed orders only.