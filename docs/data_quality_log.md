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
| Numeric ranges (17 numeric columns) | No impossible values. Age 18 to 74, quantity 1 to 24, rating 1.6 to 5.0, all money columns positive except profit (1,296 negative rows, min -1,281.59) and profit_margin_percentage (1,295 negative, 1 zero from a -0.01 profit rounding). Zeros in delivery, discount, shipping and loyalty-point columns. All non-Completed orders earn 0 loyalty points. | Keep all values. Negative profit is plausible as real losses, to be confirmed in Step 5. | Complete |
| Date and time validity | All order_date values match YYYY-MM-DD and all order_time values HH:MM:SS (0 mismatches). Casts to DATE and TIME succeed for all rows. order_date runs 2021-01-01 to 2025-12-31, matching dataset_statistics. | Convert to DATE and TIME in the analytics layer. | Complete |
| Does net_sales = gross_sales - discount_amount + tax_amount + shipping_cost? | Yes for all 138,116 rows (0 mismatches at 2 decimals). net_sales includes tax and shipping. | None needed. Decide later whether Total Sales means net_sales or gross_sales minus discount. | Complete |
| Does profit = net_sales - product_cost - shipping_cost? | Yes for all 138,116 rows (0 mismatches, max gap is floating-point noise). Equivalent to gross_sales - discount_amount + tax_amount - product_cost, so profit includes tax. | Use profit as given for now. Decide in the analytics layer whether to recompute profit excluding tax. | Complete |
| Does profit_margin_percentage = profit / net_sales * 100? | Yes for all 138,116 rows. One row differs only by a rounding tie (stored 26.67, recomputed 26.675). | None needed. | Complete |

## raw.order_items

| Check | Finding | Decision | Status |
|---|---|---|---|
| Is (`order_id`, `product_id`) unique? | No. 397,569 total rows, 138,116 distinct order_id, 397,482 distinct pairs. 87 pairs appear exactly twice (87 surplus rows, reconciles with the gap) | Not unique. See rows below for investigation and decision. | Complete |
| Are repeated-pair rows identical? | Confirmed with SQL: all 87 repeated pairs (each appearing twice) differ in at least one non-key column. None are exact copies. | None are exact copies. See next row for handling. | Complete |
| Why do 87 (order_id, product_id) pairs repeat? | All 87 pairs appear exactly twice and none are identical rows. unit_price is the same within every pair. quantity differs in 71 pairs, discount_percentage in 84. The 1 pair matching on quantity, unit_price and discount_percentage still differs by more than 3 in tax_amount, shipping_cost, net_sales and profit. | Not duplicates. Keep all rows. Cause of repetition unknown (likely separate lines, not proven). | Complete |
| Does gross_sales = quantity * unit_price (rounded to 2 dp)? | Yes for all 397,569 rows. 0 mismatches (NULL-safe check using IS DISTINCT FROM). | None needed. gross_sales is consistent with quantity and unit_price. | Complete |
| NULLs, blanks and placeholders | 0 NULLs in all 12 columns. 0 matches in the 2 text columns (order_id, product_id) for empty, whitespace-only, N/A, NA, NULL, UNKNOWN, NONE. | None needed. | Complete |
| Numeric ranges (10 numeric columns) | No impossible values. Quantity 1 to 5, prices and sales amounts positive. Negative profit in 5,426 rows. discount_percentage is a fraction (0 to 0.6). 33 rows have a non-zero discount_percentage but a zero discount_amount. | Keep all values. Check profit and discount consistency in Step 5. | Complete |

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
| sales table and dataset_statistics | Row count vs file name | 138,116 rows loaded and the file name says 150k. Matches Total Transactions in dataset_statistics (observation). | Treat dataset_statistics as reference only. Validate other stats during profiling. | Open |
| dataset_statistics, product_catalog, order_items | Total Products Used | Stat says 138,116, equal to Total Transactions. product_catalog has 1,175 products (observation, not yet tested against order_items). | Verify against order_items during cross-table checks | Open |