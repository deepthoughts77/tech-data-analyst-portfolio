-- staging
SELECT COUNT(*) AS stg_rows FROM retail.stg_superstore;

-- fact + base view
SELECT COUNT(*) AS fact_rows FROM retail.fact_orders;
SELECT COUNT(*) AS v_orders_rows FROM bi.v_orders;

-- KPI (should return 1 row)
SELECT * FROM bi.v_kpi;

-- quick checks: do views return data?
SELECT * FROM bi.v_sales_by_month LIMIT 5;
SELECT * FROM bi.v_sales_by_category LIMIT 5;
SELECT * FROM bi.v_sales_by_geo LIMIT 5;
SELECT * FROM bi.v_sales_by_segment_shipmode LIMIT 5;
