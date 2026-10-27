# Data Quality Log

## All raw tables

| Check | Finding | Decision | Status |
|---|---|---|---|
| Row count after import | product_catalog 1,175; customer_master 25,000; order_items 397,569; ecommerce_sales_customer_analytics_150k 138,116; dataset_statistics 1. All match the source CSV row counts | No cleaning at raw layer | Complete |
| ID format | customer_id (CUST-XXXXXX), product_id (PROD-XXXXXX) and order_id (ORD-XXXXXX) each match a single pattern in every table where they appear, with 0 mismatches | None needed. | Complete |

## raw.ecommerce_sales_customer_analytics_150k

| Check | Finding | Decision | Status |
|---|---|---|---|
| Is `order_id` unique? | Yes. 138,116 total rows, 138,116 distinct order_id | Use `order_id` as the key | Complete |
| NULL counts per column (46 columns) | 37 columns have 0 NULLs, including all money columns and order_id. 9 columns have NULLs: delivery_days, estimated_delivery_days, customer_rating, review_sentiment, customer_review (24,557 each, ~17.8%); return_status, return_reason (128,654 each, ~93.1%); campaign_name (83,233, ~60.3%); coupon_code (110,502, ~80.0%). | NULL patterns investigated in the rows below. | Complete |
| Do delivery_days, estimated_delivery_days, customer_rating, review_sentiment, customer_review go missing together? | Yes. 24,557 rows have all five NULL, equal to each column's individual NULL count (17.8% of rows). | See next row | Complete |
| What do the 24,557 all-NULL rows have in common? | They are exactly the non-Completed orders: Cancelled 8,398 (6.08%), Pending 6,697 (4.85%), Returned 9,462 (6.85%), all with delivery_status = 'Cancelled'. Completed orders (113,559) have delivery_status On Time 86,916, Delayed 16,886, Early 9,757 and no NULLs in these fields. Cancelled and Returned shares match dataset_statistics. | Structural NULLs. Do not impute. Limit delivery and rating analysis to Completed orders. | Complete |
| Are return_status and return_reason filled only for Returned orders? | Yes. All 9,462 Returned rows have both, 0 rows in other statuses have either, 0 rows with only one filled, 0 blank strings. | Structural NULLs (not returned). Do not impute. | Complete |
| Do campaign_name and coupon_code NULLs look like a data problem? | campaign_name is NULL on 60.3% of rows and coupon_code on 80.0%. No blank or placeholder values in either column. The coupon_code NULL rate is 79.72% with a campaign and 80.19% without, so the two columns look independent. Likely mean no campaign and no coupon, but not proven. | Keep as NULL in raw. Label only in the analytics layer if needed. | Complete |
| Blank and placeholder values in text columns | 0 matches in all 29 text columns for empty or whitespace-only strings and for N/A, NA, NULL, UNKNOWN, NONE. | None needed. | Complete |
| Casing, spelling and out-of-place values in categorical columns | 16 categorical columns reviewed by skimming distinct values with counts (91 values). No casing variants, typos or out-of-place values found. | None needed. | Complete |
| Do status fields make business sense? | All 9,462 Returned and all 6,697 Pending orders have delivery_status = 'Cancelled' and no delivery days. A return normally follows a delivery (observation, cause unknown). | Use delivery_status and delivery_days only for Completed orders. Do not analyze returns against delivery delay. | Complete |
| Numeric ranges (17 numeric columns) | No impossible values. Age 18 to 74, quantity 1 to 24, rating 1.6 to 5.0, all money columns positive except profit (1,296 negative rows, min -1,281.59) and profit_margin_percentage (1,295 negative, 1 zero from a -0.01 profit rounding). Zeros in delivery, discount, shipping and loyalty-point columns. All non-Completed orders earn 0 loyalty points. | Keep all values. Negative profit is plausible as real losses, confirmed in Step 5. | Complete |
| Date and time validity | All order_date values match YYYY-MM-DD and all order_time values HH:MM:SS (0 mismatches). Casts to DATE and TIME succeed for all rows. order_date runs 2021-01-01 to 2025-12-31, matching dataset_statistics. | Convert to DATE and TIME in the analytics layer. | Complete |
| Does net_sales = gross_sales - discount_amount + tax_amount + shipping_cost? | Yes for all 138,116 rows (0 mismatches at 2 decimals). net_sales includes tax and shipping. | None needed. Decide later whether Total Sales means net_sales or gross_sales minus discount. | Complete |
| Does profit = net_sales - product_cost - shipping_cost? | Yes for all 138,116 rows (0 mismatches, max gap is floating-point noise). Equivalent to gross_sales - discount_amount + tax_amount - product_cost, so profit includes tax. | Use profit as given for now. Decide in the analytics layer whether to recompute profit excluding tax. | Complete |
| Does profit_margin_percentage = profit / net_sales * 100? | Yes for all 138,116 rows. One row differs only by a rounding tie (stored 26.67, recomputed 26.675). | None needed. | Complete |
| Time coverage | All 60 months present (2021-01 to 2025-12). Monthly orders range from 1,565 to 3,592 with no sharp drops or spikes (skimmed). | MoM and YoY analysis supported at monthly level. | Complete |
| Decimal precision of money columns | 8 columns have more than 2 decimals in 18.7% to 24.7% of rows: gross_sales 29,195, discount_amount 25,885, tax_amount 29,335, shipping_cost 34,081, net_sales 29,433, product_cost 29,457, profit 29,735, customer_lifetime_value 29,963. profit_margin_percentage has none. Extra digits are floating-point noise (largest gap 0.000000000004 across all 8 columns). | Round these 8 columns to 2 decimals in the analytics layer. | Complete |

## raw.order_items

| Check | Finding | Decision | Status |
|---|---|---|---|
| Is (`order_id`, `product_id`) unique? | No. 397,569 total rows, 138,116 distinct order_id, 397,482 distinct pairs. 87 pairs appear exactly twice (87 surplus rows, reconciles with the gap) | Not unique. See rows below for investigation and decision. | Complete |
| Are repeated-pair rows identical? | Confirmed with SQL: all 87 repeated pairs (each appearing twice) differ in at least one non-key column. None are exact copies. | None are exact copies. See next row for handling. | Complete |
| Why do 87 (order_id, product_id) pairs repeat? | All 87 pairs appear exactly twice and none are identical rows. unit_price is the same within every pair. quantity differs in 71 pairs, discount_percentage in 84. The 1 pair matching on quantity, unit_price and discount_percentage still differs by more than 3 in tax_amount, shipping_cost, net_sales and profit. | Not duplicates. Keep all rows. Cause of repetition unknown (likely separate lines, not proven). | Complete |
| Does gross_sales = quantity * unit_price (rounded to 2 dp)? | Yes for all 397,569 rows. 0 mismatches (NULL-safe check using IS DISTINCT FROM). | None needed. gross_sales is consistent with quantity and unit_price. | Complete |
| NULLs, blanks and placeholders | 0 NULLs in all 12 columns. 0 matches in the 2 text columns (order_id, product_id) for empty, whitespace-only, N/A, NA, NULL, UNKNOWN, NONE. | None needed. | Complete |
| Numeric ranges (10 numeric columns) | No impossible values. Quantity 1 to 5, prices and sales amounts positive. Negative profit in 5,426 rows. discount_percentage is a fraction (0 to 0.6). 33 rows have a non-zero discount_percentage but a zero discount_amount. | Keep all values. Check profit and discount consistency in Step 5. | Complete |
| Does net_sales = gross_sales - discount_amount + tax_amount + shipping_cost? | Yes for all 397,569 rows (0 mismatches, max gap is floating-point noise). | None needed. | Complete |
| Does profit = net_sales - product_cost - shipping_cost? | Yes for all 397,569 rows (0 mismatches, max gap is floating-point noise). Same formula as the sales table, so profit includes tax. | Use profit as given for now. Decide in the analytics layer whether to recompute profit excluding tax. | Complete |
| Does discount_amount = gross_sales * discount_percentage? | Yes for all 397,569 rows at 2 decimals. Max gap 0.005, consistent with rounding. 33 rows have a non-zero discount_percentage but a zero discount_amount, all explained by rounding (largest unrounded discount 0.00496). | None needed. discount_percentage can be used as given. | Complete |
| Decimal precision of numeric columns | shipping_cost has more than 2 decimals in 51,654 rows (13.0%). discount_percentage has up to 16 decimals in 343,632 rows and is a continuous fraction. Rounding it to 2 decimals would break the discount formula on 341,223 rows (85.8%). The other 7 money columns have none. | Round shipping_cost to 2 decimals. Keep discount_percentage at full precision. | Complete |

## raw.customer_master

| Check | Finding | Decision | Status |
|---|---|---|---|
| Is `customer_id` unique? | Yes. 25,000 total rows, 25,000 distinct customer_id | Use `customer_id` as the key | Complete |
| NULL counts per column (11 columns) | 0 NULLs in all 11 columns (25,000 rows) | None needed. | Complete |
| Blank and placeholder values in text columns | 0 matches in all 9 text columns for empty or whitespace-only strings and for N/A, NA, NULL, UNKNOWN, NONE | None needed. | Complete |
| Casing, spacing and out-of-place values in categorical columns | No casing or spacing variants in 6 columns (gender, customer_segment, customer_city, customer_state, customer_country, region). Value lists for gender, customer_segment, customer_state, customer_country and region skimmed, with no spelling problems or out-of-place values found. | None needed. | Complete |
| Numeric ranges (2 numeric columns) | No impossible values. customer_age 18 to 74, customer_acquisition_cost 5.01 to 79.99, no zeros or negatives. | None needed. | Complete |

## raw.product_catalog

| Check | Finding | Decision | Status |
|---|---|---|---|
| Is `product_id` unique? | Yes. 1,175 total rows, 1,175 distinct product_id | Use `product_id` as the key | Complete |
| NULLs, blanks and placeholders | 0 NULLs in all 9 columns. 0 matches in the 6 text columns for empty, whitespace-only, N/A, NA, NULL, UNKNOWN, NONE. | None needed. | Complete |
| Casing, spacing and out-of-place values in categorical columns | No casing or spacing variants in brand (144 values), product_category (15), product_subcategory (117) and supplier (10). Value lists for product_category and supplier skimmed, with no spelling problems or out-of-place values found. | None needed. | Complete |
| Does each product_subcategory belong to one product_category? | 117 distinct subcategories but 120 distinct category/subcategory pairs. Storage (Home & Kitchen, Office Supplies), Watches (Fashion, Jewelry) and Furniture (Baby & Kids, Home & Kitchen) each appear under 2 categories. Pairings look plausible on a skim. | Subcategory alone is not a valid key. Always group by category and subcategory together. | Complete |
| Numeric ranges (3 numeric columns) | No impossible values. unit_price 6.31 to 1,482.95, product_cost 1.97 to 993.63, product_rating 2.5 to 4.9. No zeros or negatives. | None needed. | Complete |

## raw.dataset_statistics

| Check | Finding | Decision | Status |
|---|---|---|---|
| Typing of columns | Single-row reference file. Numeric columns typed NUMERIC, columns with `$`, `%` or a range string loaded as TEXT | See assumptions_and_decisions.md | Complete |
| NULLs, blanks and placeholders | 0 NULLs in all 11 columns. 0 matches in the 6 text columns for empty, whitespace-only, N/A, NA, NULL, UNKNOWN, NONE. | None needed. | Complete |

## Cross-table checks

| Tables | Check | Finding | Decision | Status |
|---|---|---|---|---|
| sales table, order_items | Do both tables cover the same orders? | Yes. 0 sales orders without line items and 0 order_items rows without a sales order (138,116 orders in each). | None needed. Orders can be linked on order_id. | Complete |
| sales table, order_items | Do order totals in the sales table equal the SUM of order_items per order? | No for 11,226 of 138,116 orders (8.13%). quantity and gross_sales mismatch on exactly the same orders. In every mismatching order, the order_items quantity exceeds the sales table quantity (difference 1 to 31, average about 5.95). The other 126,890 orders match on every column. Cause not known. | Use the sales table for order-level metrics and order_items for product-level analysis only. See the reconciliation row below. | Complete |
| sales table, order_items, dataset_statistics | Which table reconciles with the reference totals? | sales matches dataset_statistics exactly on revenue (net_sales, 177,134,263.74) and profit (76,146,395.76). order_items totals are higher (192,398,877.29 and 82,698,038.55, about +8.6%), consistent with 11,226 orders where order_items quantity exceeds the sales table. Cause not known. | Use the sales table for order-level metrics. Use order_items only for product-level analysis, with the gap documented. | Complete |
| sales table, dataset_statistics | Do the reference statistics match the sales table? | Yes. Total Transactions 138,116, Total Customers 24,911, Total Revenue (net_sales), Total Profit, Average Order Value 1,282.50, Average Rating 3.68 (Completed orders only), Return Rate 6.85% and Cancellation Rate 6.08% all match. The 150k in the file name is a rounded label. Total Products Used is the exception (see next row). | Treat dataset_statistics as consistent with the sales table. | Complete |
| dataset_statistics, order_items, product_catalog | Total Products Used | Stat says 138,116, equal to Total Transactions. order_items has 1,175 distinct product_id, the same count as product_catalog. The stat does not measure distinct products. | Ignore this stat. Use the 1,175 from the data. | Complete |
| order_items, product_catalog, sales table, customer_master | Orphan keys (fact to dimension) | 0 order_items rows with a product_id missing from product_catalog. 0 sales rows with a customer_id missing from customer_master. | None needed. Tables can be joined on product_id and customer_id without losing rows. | Complete |
| customer_master, sales table | Customers without orders (reverse orphan check) | 89 customers in customer_master have no orders (25,000 - 24,911). 0 products in product_catalog without order lines. | Keep the 89 in the raw layer. Count active customers from the sales table. Decide in the model whether to include them in the customer dimension. | Complete |

## Analytics-layer validation

### analytics.sales

| Check | Finding | Decision | Status |
|---|---|---|---|
| SQL table creation and row count | Created `analytics.sales` from `raw.ecommerce_sales_customer_analytics_150k`. 138,116 rows loaded, matching the raw table. | Preserve one row per order. Raw table remains unchanged. | Complete |
| Order uniqueness | 138,116 rows and 138,116 distinct `order_id` values. | Retain `order_id` as the order-level key. | Complete |
| Date and time conversions | `order_date` converted to DATE and `order_time` converted to TIME. Both columns have 0 NULLs after conversion. | Use proper date/time types for analysis. | Complete |
| Boolean conversion | `is_repeat_customer` converted from TEXT to BOOLEAN, with 0 NULLs after conversion. | Use the Boolean field in analytics. | Complete |
| Campaign and coupon flags | `has_campaign` has 54,883 TRUE rows; `has_coupon` has 27,614 TRUE rows. | Keep the original nullable fields and use Boolean flags to identify non-NULL campaign and coupon values. | Complete |
| Monetary rounding | The 8 planned monetary columns were rounded to 2 decimal places during insertion. `profit_margin_percentage` was left unchanged. | Apply the documented precision decisions in the analytics layer. | Complete |
| Financial total validation | Total `net_sales` = 177,134,263.74; total `profit` = 76,146,395.76. Both match the expected totals from raw profiling and `dataset_statistics`. | Use `analytics.sales` for order-level financial analysis. | Complete |
| Date range, decimals, boolean counts and structure | `order_date` runs 2021-01-01 to 2025-12-31. 0 rows with more than 2 decimals in the 8 rounded columns. `is_repeat_customer` has 137,782 TRUE and 334 FALSE. The table has 48 columns (46 source plus 2 flags) with DATE, TIME and BOOLEAN types as intended. | Use `analytics.sales` as the cleaned order-level table. | Complete |

### analytics.order_items

| Check | Finding | Decision | Status |
|---|---|---|---|
| SQL table creation and row count | Created `analytics.order_items` from `raw.order_items`. 397,569 rows loaded. | Preserve all source rows. Raw table remains unchanged. | Complete |
| Order and product-pair counts | 138,116 distinct orders and 397,482 distinct `(order_id, product_id)` pairs across 397,569 rows. | Preserve repeated order-product pairs; do not impose uniqueness on the pair. | Complete |
| Shipping-cost rounding | 0 rows have `shipping_cost` values differing from `ROUND(shipping_cost, 2)`. | Round shipping cost to two decimal places in the analytics layer. | Complete |
| NULL validation | 0 NULLs in `order_id`, `product_id`, and `shipping_cost`. | No additional cleaning needed for these checks. | Complete |
| Totals, precision and structure | Total `net_sales` 192,398,877.29 and `profit` 82,698,038.55, identical to raw, so the documented 8.6% gap against `analytics.sales` is unchanged. `discount_percentage` kept at full precision (343,632 rows with more than 2 decimals, same as raw). The table has 12 columns. | Use `analytics.order_items` for product-level analysis only. | Complete |

### analytics.customers

| Check | Expected result | Status |
|---|---|---|
| Table creation | Created from `raw.customer_master` | Complete |
| Row count | 25,000 rows | Complete |
| Customer ID uniqueness | 25,000 distinct customer IDs | Complete |
| NULL customer IDs | 0 | Complete |
| Source preservation | All 11 source columns and all source rows preserved | Complete |
| Rows, keys and structure | 25,000 rows, 25,000 distinct `customer_id`, 0 NULL IDs. 11 columns, same as `raw.customer_master`. Includes the 89 customers with no orders. | None needed. Count active customers from `analytics.sales`. | Complete |

No additional cleaning or transformations were required. All 25,000 customer records were retained, including the 89 customers who have no orders in the sales data.

### analytics.products

| Check | Expected result | Status |
|---|---|---|
| Table creation | Created from `raw.product_catalog` | Complete |
| Row count | 1,175 rows | Complete |
| Product ID uniqueness | 1,175 distinct product IDs | Complete |
| NULL product IDs | 0 | Complete |
| Source preservation | All 9 source columns and all source rows preserved | Complete |
| Rows, keys and structure | 1,175 rows, 1,175 distinct `product_id`, 0 NULL IDs. 9 columns, same as `raw.product_catalog`. | Group by category and subcategory together, since 3 subcategories appear under 2 categories. | Complete |

No additional cleaning or transformations were required. All 1,175 product records were retained, and category and subcategory values were preserved because some subcategories appear under multiple categories.

### Analytics-layer relationships

| Check | Finding | Decision | Status |
|---|---|---|---|
| Fact-to-dimension keys | 0 `analytics.sales` rows with a `customer_id` missing from `analytics.customers`. 0 `analytics.order_items` rows with a `product_id` missing from `analytics.products`. | Tables can be joined on `customer_id` and `product_id` without losing rows. | Complete |
| Sales and order_items coverage | 0 `order_items` rows without a sales order and 0 sales orders without line items (138,116 orders in each). | Link on `order_id`, but never sum order-level columns after the join. | Complete |
| Customers without orders | 89 customers in `analytics.customers` have no orders in `analytics.sales`. | Keep them in the dimension. Count active customers from `analytics.sales`. | Complete |
