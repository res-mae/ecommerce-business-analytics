# Recommendations

Brief question 6: what actions could improve profitability and customer retention?
These are actions to investigate or test, not proven fixes. Each rests on a descriptive association in `findings.md`.
No expected gains are quoted because the data cannot support them.
How to test items are suggested next steps, not completed analysis.

## 1. Test whether seasonal discounts earn their cost

- **Finding [all statuses, Q2, EDA]:** Discounts reach about 30% of gross sales in Nov and Dec (about 22% in July, about 14% in September). Profit-to-Net-Sales is 32.3% to 33.6% in Nov and Dec, against 47.1% to 47.9% in the other months. July orders are not higher than June or August.
- **Action:** Before repeating the July and September discount levels, run a controlled test (for example, a different discount depth in comparable weeks) and compare orders and profit.
- **Unknown:** Whether discounts lift order volume. Nov and Dec are peak months, but the data cannot separate discount effect from seasonal demand.
- **How to test:** Compare discount depth against orders within the same month across years, or run a holdout in a future period.

## 2. Review Electronics pricing and discounts

- **Finding [Completed, order_items basis, Q3, Q3a]:** Electronics is first in Net Sales (33,486,763.01) and lowest in Profit % of Net Sales (32.58%, against 41.56% overall). All 8 Electronics subcategories sit among the lowest margins (30.42% to 34.27%).
- **Action:** Review Electronics pricing, supplier cost and discount policy, since it is the largest category.
- **Unknown:** Why the margin is lower. The data does not show whether it comes from cost, discounts or mix. Profit and Net Sales both include tax and shipping.
- **How to test:** Break Electronics margin into cost and discount by subcategory, and compare with other categories.

## 3. Review the discount rule for Premium and VIP

- **Finding [all statuses, Q5, EDA]:** Premium and VIP are discounted about 4.5 points deeper (about 20% of gross sales vs 15.55% to 15.78%), with a profit ratio about 3 points lower. Net Sales per customer differs by only about 1.4% across segments. The gap remains in months without seasonal discounting.
- **Action:** Check whether the deeper discount for these segments has a business reason. If not, consider aligning it with the other segments.
- **Unknown:** Why they are discounted more, and whether the discount affects their order frequency.
- **How to test:** Compare order frequency and profit for Premium and VIP at different discount levels.

## 4. Investigate delivery delays

- **Finding [Completed, Q6b]:** Average rating is 3.22 for Delayed, 3.73 for On Time and 4.02 for Early. Order value is about the same across the three. Delayed orders are 16,886 of 113,559 Completed orders.
- **Action:** Find where delays occur and reduce them, then monitor ratings.
- **Unknown:** Whether delays cause the lower ratings. This is an association only. Returned, Cancelled and Pending orders have no ratings, so the effect on returns is not visible.
- **How to test:** Track ratings before and after a delivery improvement, with the delay share as the main metric.

## 5. Define retention metrics before targeting retention

- **Finding [all statuses, Q4, customer_type]:** 24,387 of 24,911 customers (97.90%) are repeat, and 524 are one-time. Per-customer Net Sales rises with order count, which follows largely from arithmetic.
- **Action:** Do not build a retention programme from this data yet. First define retention measures, such as time between orders and the share of customers with no order in a recent window.
- **Unknown:** Whether customers are leaving. With 2.10% one-time customers, the data shows no obvious one-time customer problem, and the order counts do not show churn over time.
- **How to test:** Build the repeat-purchase interval per customer from `analytics.sales` and check for lapse over the five years.

## Not recommended from this data

- **Targeting returns or cancellations by segment or channel.** Rates stay close to 6.85% and 6.08% everywhere (Q6a), so no group stands out. Return reasons were not analyzed and no cancellation reason exists.
- **Any growth target.** Net Sales show no sustained trend (Q2a), and no causal driver was identified.

## Limitations

See `findings.md`. The headline scope (Completed orders) is an assumed business rule, and no real stakeholder was involved.