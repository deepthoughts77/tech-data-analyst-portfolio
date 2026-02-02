-- 03_kpi_queries.sql

-- Executive KPIs
SELECT
  ROUND(SUM(sales), 2) AS total_sales,
  ROUND(SUM(profit), 2) AS total_profit,
  ROUND(100.0 * SUM(profit) / NULLIF(SUM(sales), 0), 2) AS profit_margin_pct,
  COUNT(DISTINCT order_id) AS total_orders,
  COUNT(DISTINCT customer_id) AS total_customers,
  ROUND(SUM(sales) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS avg_order_value
FROM fact_orders;

-- Monthly Sales Trend + MoM growth
WITH monthly AS (
  SELECT
    d.year,
    d.month,
    (d.year * 100 + d.month) AS year_month,
    SUM(f.sales) AS sales
  FROM fact_orders f
  JOIN dim_date d ON d.date_id = f.order_date_id
  GROUP BY d.year, d.month
)
SELECT
  year,
  month,
  year_month,
  ROUND(sales, 2) AS sales,
  ROUND(
    100.0 * (sales - LAG(sales) OVER (ORDER BY year_month)) /
    NULLIF(LAG(sales) OVER (ORDER BY year_month), 0), 2
  ) AS mom_growth_pct
FROM monthly
ORDER BY year_month;

-- Top 10 products
SELECT
  p.product_name,
  p.category,
  p.sub_category,
  ROUND(SUM(f.sales), 2) AS sales,
  ROUND(SUM(f.profit), 2) AS profit
FROM fact_orders f
JOIN dim_product p ON p.product_id = f.product_id
GROUP BY p.product_name, p.category, p.sub_category
ORDER BY sales DESC
LIMIT 10;

-- Sales by Region + Category
SELECT
  g.region,
  p.category,
  ROUND(SUM(f.sales), 2) AS sales,
  ROUND(SUM(f.profit), 2) AS profit
FROM fact_orders f
JOIN dim_geo g ON g.geo_id = f.geo_id
JOIN dim_product p ON p.product_id = f.product_id
GROUP BY g.region, p.category
ORDER BY g.region, sales DESC;
