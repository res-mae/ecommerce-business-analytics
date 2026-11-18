# Findings

Results supported by the data. Each links to a query in `sql/05_business_analysis.sql`, a tested measure or `notebooks/01_eda.ipynb`.
Scope tags: [all statuses] = recorded values of all four order statuses. [Completed] = Completed orders only.
All findings are descriptive associations. No causal claims are made.

## Brief questions and where they are answered

| Brief question | SQL / notebook | Dashboard page |
|---|---|---|
| 1. Sales, profit and orders over time | Q2, Q2a | Executive Overview |
| 2. Products and categories | Q3, Q3a | Product and Sales Performance |
| 3. Repeat vs one-time customers | Q4a to Q4d, customer_type | Customer Behavior |
| 4. Customer segments | Q5, Q5a | Customer Behavior |
| 5. Returns, cancellations, discounts, delivery | Q1, Q2, Q5, Q6a, Q6b, Q6c | Customer Behavior (return and cancellation rates). Discounts and delivery are in SQL only |
| 6. Actions | Recommendations | None |

## Supported by the data

- **Q1 [all statuses]:** Completed orders hold 81.40% of recorded Net Sales and 78.48% of Profit. About 11% of Net Sales is tax and shipping, stable across statuses.
- **Q2 [all statuses]:** Net Sales peak in November and December and are lowest in February in all five years.
- **Q2 [all statuses]:** Discounts reach about 30% of gross sales in Nov and Dec (about 22% in July, about 14% in September, 9.4% to 10.2% otherwise). Profit-to-Net-Sales is lower in those months (32.3% to 33.6% in Nov and Dec vs 47.1% to 47.9% in the other months, July and September in between). Product cost stays at 51% to 52% of gross sales. Association only.
- **Q2a [all statuses]:** No sustained growth or decline. Orders stay within 27,554 to 27,768. Net Sales change by at most 1.11% per year and Profit by at most 1.18%, with no consistent direction.
- **Q3 [Completed, order_items basis]:** Smartphones, TVs and Smart Watches lead Net Sales and Profit. All 8 Electronics subcategories are among the lowest margins (30.42% to 34.27%, margin ranks 110 to 120 of 120). Grocery - Snacks is highest (60.74%).
- **Q3a [Completed, order_items basis]:** By category, Electronics is first in Net Sales (33,486,763.01) and lowest in Profit % of Net Sales (32.58%). Grocery is highest (54.10%). Both measures include tax and shipping.
- **Q4 [all statuses]:** Of 24,911 customers with orders, 524 are one-time and 24,387 (97.90%) are repeat (`customer_type`). Net Sales per order is about the same across order-count bands (1,271 to 1,286), so higher per-customer Net Sales goes with more orders, not larger orders. This follows largely from arithmetic. Band widths differ (2-4 spans 3 order counts, 5-9 spans 5), so band shares reflect width as well as behavior.
- **Q5 [all statuses]:** Segment Net Sales follow segment size (Consumer 54.87%, Premium 24.99%, VIP 10.11%, Business 10.03%). Net Sales per customer and per order differ by about 1.4% and 1.2% across segments, so VIP and Premium are not higher value per customer. Premium and VIP are discounted about 4.5 points deeper (about 20% of gross sales vs 15.55% to 15.78%), with a profit ratio about 3 points lower.
- **Q6a [all statuses]:** Returned and Cancelled rates stay close to the overall 6.85% and 6.08% in every segment and channel (segments 6.69% to 7.06% and 6.00% to 6.25%).
- **Q6b [Completed]:** Ratings fall with later delivery (Early 4.02, On Time 3.73, Delayed 3.22). Order value is about the same in all three statuses. Association only.
- **EDA [all statuses]:** Net Sales per order is right-skewed (median 950.76, mean 1,282.50, max 16,218.00). Per-order averages in Q4 to Q6b are means, so they are pulled up by large orders.
- **EDA [all statuses, Completed for delivery]:** Median Net Sales per order is 943 to 960 across segments and 934 to 945 across delivery statuses, so the "about the same per order" findings hold on medians.
- **EDA [all statuses]:** Discounts shift as a whole by period (median per order: Nov-Dec 29.5%, July 21.3%, September 14.1%, other eight months 9.8%). The share of orders with no discount stays about 12.9% in every period. 67.0% of orders discounted above 20% fall in Nov-Dec, which hold 24.3% of orders.
- **EDA [all statuses]:** Premium and VIP orders are discounted more even in the eight months without seasonal discounting (median 11.7% and 12.1% vs 8.9% and 9.0%).

## Open questions

- Why are discounts deeper in November, December, July and September, and do they lift order volume? (July orders are not higher than June or August.)
- Why are Electronics margins lower than in other categories?
- Why are Premium and VIP discounted more?
- Why are 511 Completed orders labeled Early with no day difference?
- Why are Returned and Cancelled orders larger on average with a higher profit ratio?
- Why do order_items totals run about 8.6% above analytics.sales (11,226 orders where item quantity exceeds order quantity)?

## Limitations

- No data dictionary. Meanings of `net_sales`, `tax_amount`, `shipping_cost` and `profit` are inferred from arithmetic. `profit` and `net_sales` include tax and shipping.
- `order_items` totals run about 8.6% above `analytics.sales` across all statuses (about 8.7% for Completed), cause unknown. Product-level results use the order_items basis and are never combined with order-level figures.
- `is_repeat_customer` and `customer_order_count` do not match actual orders (the count is up to 5 above the actual for 37.8% of customers). Repeat customers are defined from actual order counts.
- Delivery and rating analysis covers the 113,559 Completed orders only. Returned, Cancelled and Pending orders have no delivery or rating data, so the data cannot show whether returns or cancellations go with lower ratings.
- 511 Completed orders (5.2% of the Early group) are labeled Early but were delivered on the estimated day. Delivery results use `delivery_status` as given.
- Return reasons exist only for the 9,462 Returned orders and were not analyzed. No cancellation reason column exists.
- The dashboard headline (Completed orders only) is an assumed business rule (decision 2026-11-16). No real stakeholder was involved. Completed is a working proxy for realized sales, not proven.
- Day-level coverage of orders was not checked, only months.
- Discounts and delivery are not shown on the dashboard.