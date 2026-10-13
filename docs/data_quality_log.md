# Data Quality Log

| Table | Check | Finding | Decision | Status |
|---|---|---|---|---|
| raw (all five tables) | Row count after import | product_catalog 1,175; customer_master 25,000; order_items 397,569; ecommerce_sales_customer_analytics_150k 138,116; dataset_statistics 1. All match the source CSV row counts | No cleaning at raw layer | Complete |
| raw.ecommerce_sales_customer_analytics_150k | Row count vs file name | 138,116 rows loaded; file name says 150k. Matches Total Transactions in dataset_statistics (observation) | Treat dataset_statistics as reference only; validate other stats during profiling | Open |
| raw.dataset_statistics | Total Products Used | Stat says 138,116, equal to Total Transactions; product_catalog has 1,175 products (observation, not yet tested against order_items) | Verify against order_items during cross-table checks | Open |
| raw.dataset_statistics | Row count | 1 | None yet | Complete |
| raw.product_catalog | Is `product_id` unique? | Yes. 1,175 total rows, 1,175 distinct product_id | Use `product_id` as the key | Complete |
| raw.customer_master | Is `customer_id` unique? | Yes. 25,000 total rows, 25,000 distinct customer_id | Use `customer_id` as the key | Complete |
| raw.order_items | Is (`order_id`, `product_id`) unique? | No. 397,569 total rows, 138,116 distinct order_id, 397,482 distinct pairs. 87 pairs appear exactly twice (87 surplus rows, reconciles with the gap) | Not unique; see rows below for investigation and decision | Complete |
| raw.ecommerce_sales_customer_analytics_150k | Is `order_id` unique? | Yes. 138,116 total rows, 138,116 distinct order_id | Use `order_id` as the key | Complete |
| raw.order_items | Are repeated-pair rows identical? | Confirmed with SQL: all 87 repeated pairs (each appearing twice) differ in at least one non-key column; none are exact copies. | None are exact copies; see next row for handling | Complete |
| raw.order_items | Why do 87 (order_id, product_id) pairs repeat? | All 87 pairs appear exactly twice; none are identical rows. unit_price is the same within every pair. quantity differs in 71 pairs, discount_percentage in 84. The 1 pair matching on quantity, unit_price and discount_percentage still differs by more than 3 in tax_amount, shipping_cost, net_sales and profit. | Not duplicates. Keep all rows. Cause of repetition unknown (likely separate lines, not proven) | Complete |
| raw.order_items | Does gross_sales = quantity * unit_price (rounded to 2 dp)? | Yes for all 397,569 rows; 0 mismatches (NULL-safe check using IS DISTINCT FROM) | None needed; gross_sales is consistent with quantity and unit_price | Complete |