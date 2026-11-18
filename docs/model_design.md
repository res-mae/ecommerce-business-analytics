# Model Design

Design of the Power BI semantic model, built from the cleaned `analytics` tables.
Facts, relationships and measure rules follow the grain of each table and the decisions in `assumptions_and_decisions.md`.

## 1. Tables

| Table | Role | Grain | Key | Rows |
|---|---|---|---|---|
| `analytics.sales` | Fact (order header) | One row per order | `order_id` | 138,116 |
| `analytics.order_items` | Fact (order line) | One row per order line | None. `(order_id, product_id)` repeats for 87 pairs, so it is not unique | 397,569 |
| `analytics.customers` | Dimension | One row per customer | `customer_id` | 25,000 |
| `analytics.products` | Dimension | One row per product | `product_id` | 1,175 |
| `analytics.dates` | Dimension | One row per day | `date` | 1,826 |

## 2. Relationships

![Power BI model](images/model_diagram.png)

Crow's foot notation. Each marker shows how many rows of the table at that end a row on the other side relates to. Key columns only.

| From (one) | To (many) | Dimension end | Fact end | Evidence |
|---|---|---|---|---|
| `customers[customer_id]` | `sales[customer_id]` | Exactly one | Zero or many | 0 sales rows without a customer. 89 customers have no orders |
| `dates[date]` | `sales[order_date]` | Exactly one | Zero or many | All order dates fall in 2021-01-01 to 2025-12-31 |
| `sales[order_id]` | `order_items[order_id]` | Exactly one | One or many | 0 orders without lines, 0 lines without an order |
| `products[product_id]` | `order_items[product_id]` | Exactly one | Zero or many | 0 lines without a product. A catalog can hold unsold products |

All relationships are single-direction, one-to-many. Power BI does not enforce optionality, so the diagram documents the data.

### Verified in Power BI

Load (Import mode): sales 138,116 | order_items 397,569 | customers 25,000 | products 1,175 | dates 1,826 rows, matching the SQL counts.
All four relationships exist in `relationships.tmdl`, and the Model view shows them as many-to-one, active, single direction. `dates[date]` to `sales[order_date]` was created manually, the other three were auto-detected.

## 3. Rules that prevent double-counting

1. **Order-level measures use `sales` only.** Net Sales, Profit, orders, AOV, returns, cancellations and delivery are all measured on `analytics.sales`, which reconciles with `dataset_statistics`.
2. **Product-level measures use `order_items` only**, and sum line-level columns. `analytics.order_items` totals run about 8.6% above `analytics.sales` (cause unknown), so the two bases are never shown in the same visual or added together.
3. **Never sum order-level columns across the order-line relationship.** A product or category slicer filters `order_items` and does not filter `sales`, so sales measures do not respond to it.
4. **Name measures by source**, for example `Net Sales (orders)` and `Net Sales (items)`. The headline figure is `Net Sales (orders, Completed)`. `Net Sales (orders)` is the all-status reconciliation base.
5. **Group products by `product_category` and `product_subcategory` together.** Three subcategory names (Storage, Watches, Furniture) appear under two categories each.
6. **Count active customers with a distinct count of `sales[customer_id]`**, not rows in `customers`, which includes 89 customers who never ordered.

## 4. Columns to hide or avoid

| Table | Columns | Reason |
|---|---|---|
| `sales` | `customer_segment`, `customer_age`, `gender`, `customer_city`, `customer_state`, `customer_country`, `region`, `customer_postal_code` | Duplicates of `customers`. Use the `customers` columns for slicers (Q5a showed they agree) |
| `sales` | `is_repeat_customer`, `customer_order_count` | They do not match actual orders (Q4). Repeat customers are defined from actual order counts |
| `sales` | `order_id` (as a slicer) | High cardinality |
| `order_items` | `order_id` | Used only for the relationship |

### Model settings applied in Power BI

- `analytics dates` is marked as the date table (`dataCategory: Time`, `date` set as key). `month_name` is sorted by `month_number`; the test visual showed January to December.
- Hidden columns: 11 in `sales` (8 customer duplicates, `is_repeat_customer`, `customer_order_count`, `order_id`) and 1 in `order_items` (`order_id`), as listed in section 4. Hidden columns remain usable in DAX.
- The status share donut on the Executive Overview does not cross-filter other visuals (Edit interactions set to None). Before this change, clicking the Returned slice changed Active Customers.
- The all-status headline measures (`Net Sales (orders)`, `Profit (orders)`, `Orders`, `AOV`) are hidden in the model and kept for reconciliation and as the base of the rates and time-intelligence measures.
- Auto date/time is disabled (Options > Current File).

## 5. Measures

Defined in DAX. Net Sales and Profit are dataset-defined measures with no data dictionary, and `profit` includes tax.

| Measure | Definition | Source |
|---|---|---|
| Net Sales (orders) | `SUM('analytics sales'[net_sales])` | `sales` |
| Profit (orders) | `SUM('analytics sales'[profit])` | `sales` |
| Product Sales (orders) | `SUM('analytics sales'[gross_sales]) - SUM('analytics sales'[discount_amount])` | `sales` |
| Profit % of Net Sales | `DIVIDE([Profit (orders)], [Net Sales (orders)])` | `sales` |
| Orders | `DISTINCTCOUNT('analytics sales'[order_id])` | `sales` |
| Active Customers | `DISTINCTCOUNT('analytics sales'[customer_id])` | `sales` |
| AOV | `DIVIDE([Net Sales (orders)], [Orders])` | `sales` |
| Discount % of Gross Sales | `DIVIDE(SUM('analytics sales'[discount_amount]), SUM('analytics sales'[gross_sales]))` | `sales` |
| Return Rate | Returned orders divided by orders | `sales` |
| Cancellation Rate | Cancelled orders divided by orders | `sales` |
| Net Sales (items) | `SUM('analytics order_items'[net_sales])` | `order_items` |
| Profit (items) | `SUM('analytics order_items'[profit])` | `order_items` |
| Net Sales (orders, Completed) | `CALCULATE(SUM('analytics sales'[net_sales]), 'analytics sales'[order_status] = "Completed")` | `sales` |
| Profit (orders, Completed) | Same pattern on `profit` | `sales` |
| Orders (Completed) | `CALCULATE(DISTINCTCOUNT('analytics sales'[order_id]), 'analytics sales'[order_status] = "Completed")` | `sales` |
| AOV (Completed) | `DIVIDE([Net Sales (orders, Completed)], [Orders (Completed)])` | `sales` |
| Net Sales PY / PM (orders) | `CALCULATE([Net Sales (orders)], SAMEPERIODLASTYEAR(...))` / `DATEADD(..., -1, MONTH)`, all statuses | `sales` |
| Net Sales YoY % / MoM % (orders) | `DIVIDE(current - prior, prior)`, all statuses | `sales` |
| Profit % of Net Sales (items) | `DIVIDE([Profit (items)], [Net Sales (items)])` | `order_items` |
| Net Sales per Customer (orders) | `DIVIDE([Net Sales (orders)], [Active Customers])` | `sales` |

Reference values to test against: Net Sales 177,134,263.74, Profit 76,146,395.76, Orders 138,116, Active Customers 24,911, AOV 1,282.50, Return Rate 6.85%, Cancellation Rate 6.08%.

### Measure tests

- Net Sales (orders) = 177,134,263.74 (matches reference, Decimal number type, shown with 2 decimals)
- Profit (orders) = 76,146,395.76 (matches reference)
- Orders = 138,116 (matches reference)
- Active Customers = 24,911 (matches reference; counted from `sales`, `customers` has 25,000 rows including 89 who never ordered)
- AOV = 1,282.50 (matches reference)
- Net Sales PY (orders) (all statuses): Dec 2022 = 4,900,970.07 (equals Dec 2021 Net Sales); 2021 rows blank
- Net Sales YoY % (orders) (all statuses): 2022 -1.11%, 2023 +0.57%, 2024 -0.17%, 2025 -1.06% (match Q2a); 2021 blank. A first version divided by current-year Net Sales and gave 100% for 2021; fixed by dividing by PY
- Net Sales PM (orders) (all statuses): Mar 2021 = 1,905,413.15 (equals Feb 2021 Net Sales); Jan 2021 blank
- Net Sales MoM % (orders) (all statuses): Feb 2021 -19.75%, Mar 2021 +44.50%, Apr 2021 -10.31%, May 2021 +3.13% (checked by hand); Jan 2021 blank
- Return Rate = 6.85%, Cancellation Rate = 6.08% (match reference)
- Profit % of Net Sales matches the hand calculation 76,146,395.76 / 177,134,263.74 (about 43%)
- Net Sales (items) = 192,398,877.29, Profit (items) = 82,698,038.55 (match order_items totals, all statuses)
- Product Sales (orders) = 157,143,214.06 and Discount % of Gross Sales = 17.28% (match saved SQL query in sql/04)
- Net Sales (orders, Completed) = 144,195,838.50 (Completed orders)
- Orders (Completed) = 113,559 (matches Completed count from profiling)
- Profit (orders, Completed) = 59,758,469.03 (matches saved SQL sum on analytics.sales, order_status = 'Completed')
- AOV (Completed) = 1,269.79 (Net Sales (orders, Completed) / Orders (Completed); matches hand calculation)
- Status share of recorded Net Sales (donut, all statuses): Completed 81.40%, Returned 7.44%, Cancelled 6.41%, Pending 4.75% (sum 100.00%; Completed share matches 144,195,838.50 / 177,134,263.74; the other three match the Q1 summary, which was not re-run)
- Net Sales (items), Completed (page filter on sales[order_status]) = 156,796,214.63 (matches saved SQL join of order_items to sales)
- Profit (items), Completed (page filter) = 65,164,085.25 (matches the same saved SQL)
- Profit % of Net Sales (items), Completed (page filter) = 41.56% overall; Electronics 32.58%, Grocery 54.10% (match saved SQL by category; Net Sales and Profit sums match the page totals)
- Net Sales (items) by category, Completed: Electronics 33,486,763.01, Jewelry 20,795,540.76, Home Appliances 20,295,041.26 (match saved SQL)
- Subcategory Performance table (Completed, items basis): 120 rows; Smartphones 6,288,254.76 / 2,155,209.03 / 34.27%, TVs 5,732,863.02 / 1,824,234.32 / 31.82%, Smart Watches 5,207,071.59 / 1,659,470.85 / 31.87% (match Q3)
- Net Sales (orders) by customer segment (all statuses): Consumer 97,201,007.90, Premium 44,269,794.13, VIP 17,903,164.81, Business 17,760,296.90 (sum 177,134,263.74; shares match Q5, which was not re-run)
- Net Sales per Customer (orders) by segment (all statuses): Consumer 7,155.02, Business 7,061.75, VIP 7,059.61, Premium 7,054.95 (the range matches Q5, 7,054.95 to 7,155.02)
- Customers by Type (all statuses): Repeat 24,387, One-time 524 (sum 24,911 = Active Customers; matches Q4a and the customer_type SQL check)

## 6. Scope rules for reports

- **Order status:** headline measures on the Executive Overview use Completed orders only (assumed business rule, decision 2026-11-16). Rates and Active Customers use all statuses. The all-status measures are kept for reconciliation with `dataset_statistics`, and the figures are recorded values, not realized revenue.
- **Product and category pages:** Completed orders only, through the `sales` to `order_items` relationship (decision 2026-11-03).
- **Repeat vs one-time customers:** defined from actual order counts in `analytics.sales` (1 order = one-time).
- **Customer Behavior page:** all order statuses (recorded values), stated in a footnote. Return Rate and Cancellation Rate need all orders as the denominator, because Completed orders contain no returns or cancellations.

## 7. Decisions

| Decision | Choice | Reason |
|---|---|---|
| Date table | Build `analytics.dates` in SQL | Reproducible, consistent with the rest of the project. Turn off Power BI auto date/time |
| `sales` to `order_items` relationship | Keep it, single direction | Lets Completed-only filters reach product visuals. The risk is cross-filter mistakes, handled by the rules in section 3 |

## 8. Pages

1. **Executive Overview:** Completed orders only, scope in a footnote. Active Customers and one status share donut use all statuses. Return Rate and Cancellation Rate are not on this page; the rates are on Customer Behavior.
2. **Product and Sales Performance:** Completed orders, order-line basis (page filter). Cards, Net Sales and Profit % of Net Sales by category, subcategory table (120 rows). Footnote states the basis and the gap to order-level totals.
3. **Customer Behavior:** all order statuses (recorded values, stated in a footnote). Return Rate and Cancellation Rate cards, Net Sales and Net Sales per Customer by segment, Customers by Type (repeat vs one-time, from `customer_type`).

## 9. Known limitations

- No data dictionary. Meanings of `net_sales`, `tax_amount`, `shipping_cost` and `profit` are inferred from arithmetic.
- `analytics.order_items` and `analytics.sales` do not reconcile (about 8.6%, cause unknown).
- Delivery and rating analysis covers Completed orders only.
- Net Sales and Profit include tax and shipping.
- Discounts and delivery are analyzed in SQL but not shown on the dashboard.
- The Completed headline is an assumed business rule (decision 2026-11-16).