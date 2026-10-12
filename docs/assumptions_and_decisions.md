# Assumptions and Decisions

| Date | Question or Issue | Evidence | Decision | Reason |
|---|---|---|---|---|
|2026-10-12|How to type `order_date`, `order_time`, and `is_repeat_customer` in the raw sales table|Sample row shows clean values, but only one row was inspected|Load as TEXT. Convert and validate during cleaning.|Raw layer should not fail on unseen bad values, conversion is a documented cleaning step|Raw layer should not fail on unseen bad values; conversion is a documented cleaning step|
|---|---|---|---|---|