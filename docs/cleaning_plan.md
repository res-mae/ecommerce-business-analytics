# Cleaning Plan

Maps each column that needs action to a cleaning step, with the evidence behind it.
Findings are in `data_quality_log.md` and choices in `assumptions_and_decisions.md`.
The raw layer is never changed. All actions are applied in the analytics layer.

**Status values:** To do, Done, No action (reviewed, nothing to change), Modeling rule (applies in the model, not in cleaning)

## ecommerce_sales_customer_analytics_150k

| Column | Issue found | Cleaning action | Evidence / decision | Status |
|---|---|---|---|---|
| `order_date` | TEXT in raw | Convert to DATE | All 138,116 values parse. Decision 2026-10-17 | Done |
| `order_time` | TEXT in raw | Convert to TIME | All 138,116 values parse. Decision 2026-10-17 | Done |
| `is_repeat_customer` | TEXT, only 'True' and 'False' | Convert to BOOLEAN | Decision 2026-10-17 | Done |
| `gross_sales` | More than 2 decimals in 29,195 rows (floating-point noise) | Round to 2 decimals | Decision 2026-10-18 | Done |
| `discount_amount` | More than 2 decimals in 25,885 rows | Round to 2 decimals | Decision 2026-10-18 | Done |
| `tax_amount` | More than 2 decimals in 29,335 rows | Round to 2 decimals | Decision 2026-10-18 | Done |
| `shipping_cost` | More than 2 decimals in 34,081 rows | Round to 2 decimals | Decision 2026-10-18 | Done |
| `net_sales` | More than 2 decimals in 29,433 rows. Includes tax and shipping | Round to 2 decimals. Decide in the model whether Total Sales means `net_sales` | Decision 2026-10-18. Formula check in log | Done |
| `product_cost` | More than 2 decimals in 29,457 rows | Round to 2 decimals | Decision 2026-10-18 | Done |
| `profit` | More than 2 decimals in 29,735 rows. Includes tax | Round to 2 decimals. Keep as given. Optional "profit excl. tax" measure later | Decisions 2026-10-17 and 2026-10-18. Rounded sum matches reference profit | Done |
| `customer_lifetime_value` | More than 2 decimals in 29,963 rows | Round to 2 decimals | Decision 2026-10-18 | Done |
| `profit_margin_percentage` | Already 2 decimals. 1 row differs from the recomputed value by a rounding tie | None | Log: margin formula check | No action |
| `campaign_name` | NULL on 60.3% of rows | Keep NULL. Add `has_campaign` flag. Keep `Default_Campaign` as its own value | Decision 2026-10-18 | Done |
| `coupon_code` | NULL on 80.0% of rows | Keep NULL. Add `has_coupon` flag | Decision 2026-10-18 | Done |
| `delivery_days` | NULL on 24,557 non-Completed orders | No imputation. Analyze Completed orders only | Decision 2026-10-13 | Modeling rule |
| `estimated_delivery_days` | Same as above | Same as above | Decision 2026-10-13 | Modeling rule |
| `customer_rating` | Same as above | Same as above | Decision 2026-10-13 | Modeling rule |
| `review_sentiment` | Same as above | Same as above | Decision 2026-10-13 | Modeling rule |
| `customer_review` | Same as above | Same as above | Decision 2026-10-13 | Modeling rule |
| `delivery_status` | 'Cancelled' on all Returned, Pending and Cancelled orders | Use delivery fields for Completed orders only | Log: status fields | Modeling rule |
| `return_status` | NULL on 93.1% (not returned) | No imputation | Log: return columns | No action |
| `return_reason` | NULL on 93.1% (not returned) | No imputation | Log: return columns | No action |
| `loyalty_points_earned` | 0 on all 24,557 non-Completed orders and 5 Completed orders | None. Valid values | Log: numeric ranges | No action |
| `quantity` | Differs from the SUM of `order_items` quantity on 11,226 orders | Use sales table for order-level measures | Decision 2026-10-18 | Modeling rule |
| `has_campaign` (new) | Derived from `campaign_name` | TRUE when a campaign name is recorded. Expected TRUE count 54,883 | Decision 2026-10-18 | Done |
| `has_coupon` (new) | Derived from `coupon_code` | TRUE when a coupon code is recorded. Expected TRUE count 27,614 | Decision 2026-10-18 | Done |

New columns to create: `has_campaign`, `has_coupon`.
All other columns: no cleaning needed.


## order_items

| Column | Issue found | Cleaning action | Evidence / decision | Status |
|---|---|---|---|---|
| `order_id`, `product_id` | 87 repeated pairs, none are exact copies | Keep all rows. Grain is one row per order line | Decision 2026-10-13 | No action |
| `shipping_cost` | More than 2 decimals in 51,654 rows (13.0%) | Round to 2 decimals | Decision 2026-10-18 | Done |
| `unit_price`, `discount_amount`, `gross_sales`, `tax_amount`, `net_sales`, `product_cost`, `profit` | 0 rows with more than 2 decimals | None | Log: order_items decimal check | No action |
| `discount_percentage` | Continuous fraction (0 to 0.6) with up to 16 decimals. Not float noise | Keep full precision. Format as a percentage in Power BI | Rounding to 2 decimals breaks the discount formula on 341,223 rows (85.8%). Decision 2026-10-18 | No action |
| (whole table) | Totals about 8.6% above the sales table | Product-level analysis only. Never sum with the sales table | Decision 2026-10-18 | Modeling rule |

All other columns: no cleaning needed.

## customer_master

| Column | Issue found | Cleaning action | Evidence / decision | Status |
|---|---|---|---|---|
| `customer_postal_code` | TEXT by design (preserves leading zeros) | Keep as TEXT | Raw table design | No action |
| `customer_id` | 89 customers have no orders | Count active customers from the sales table | Decision 2026-10-18 | Modeling rule |

All other columns: no cleaning needed (0 NULLs, no blanks, no casing variants, no impossible values).

## product_catalog

| Column | Issue found | Cleaning action | Evidence / decision | Status |
|---|---|---|---|---|
| `product_subcategory` | Storage, Watches and Furniture appear under 2 categories each | Always group by `product_category` and `product_subcategory` together | Decision 2026-10-14 | Modeling rule |

All other columns: no cleaning needed.

## dataset_statistics

Reference only, used for validation.

| Column | Issue found | Cleaning action | Evidence / decision | Status |
|---|---|---|---|---|
| `total_revenue`, `total_profit`, `average_order_value` | TEXT with `$` and commas | Strip symbols and convert to NUMERIC when used | Decision 2026-10-12 | No action |
| `return_rate`, `cancellation_rate` | TEXT with `%` | Strip `%` and convert when used | Decision 2026-10-12 | No action |
| `date_range` | TEXT range string | Split into start and end dates if needed | Decision 2026-10-12 | No action |
| `total_products_used` | Equals Total Transactions, not distinct products | Ignore. Use 1,175 from the data | Log: Total Products Used | No action |

## Cross-table rules

| Rule | Evidence / decision |
|---|---|
| Use the sales table for order-level revenue, profit, AOV, returns and delivery | Matches `dataset_statistics`. Decision 2026-10-18 |
| Use `order_items` only for product-level analysis | 11,226 orders where `order_items` has extra units |
| Never join the two tables and sum order-level columns | Double-counting risk |
| Join keys: `order_id`, `customer_id`, `product_id` | 0 orphan keys in all joins |