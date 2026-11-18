# E-commerce Business Performance & Customer Analytics

## Business Scenario

An online retailer wants to better understand its sales performance, product profitability, customer behavior, and order fulfillment outcomes.

## Objective

Analyze e-commerce transaction and customer data to identify revenue and profit drivers, evaluate customer purchasing behavior, investigate operational issues, and recommend potential business improvements.

## Key Business Questions

1. How do sales, profit, and order volume change over time?
2. Which products and categories contribute most to revenue and profit?
3. How do repeat customers compare with one-time customers?
4. Which customer segments contribute the most business value?
5. Are returns, cancellations, discounts, or delivery delays associated with weaker performance?
6. What actions could improve profitability and customer retention?

## Dataset

Kaggle "E-Commerce Sales Analytics Dataset" (datascikhan), CC0 public domain. Five CSVs: orders (138,116 rows), order lines (397,569), customers (25,000), products (1,175) and a one-row reference statistics file. Orders span 2021-01-01 to 2025-12-31. The source has no data dictionary, so column meanings are inferred from arithmetic.

## Tools

* PostgreSQL, pgAdmin 4 and SQL: CSV import into the `raw` schema, cleaning, data profiling and business analysis
* Python (pandas, SQLAlchemy, matplotlib): EDA notebook
* Power BI and DAX: semantic model, measures and three dashboard pages
* Git and GitHub: version control (Power BI project saved as PBIP text files)

## Approach

1. Load the raw data into a `raw` schema without changes.
2. Profile the data in SQL and log data quality findings and decisions.
3. Clean in SQL into an `analytics` schema.
4. Answer the business questions in SQL, with scope and evidence stated for each.
5. Explore distributions in a Python notebook, cross-checking the SQL results and testing whether averages hold on medians.
6. Build the analytical model: two fact tables, three dimensions, and a date table, with measure rules that prevent order-level amounts from being counted once per order line.
7. Build the Power BI dashboard and test every measure against SQL results or reference values.
8. Present evidence-based findings, recommendations and limitations.

## Audience and Assumptions

The dashboard is written for an assumed business-executive audience. No real stakeholder was involved. Dashboard headline figures use Completed orders only, as an assumed business rule (decision 2026-11-16). All-status measures are kept to reconcile with the dataset's reference statistics.

## Scope and Limitations

Metric definitions, exclusions and limits are documented in `docs/assumptions_and_decisions.md`, `docs/findings.md` and `docs/model_design.md`. Findings are descriptive associations. No causal claims are made.