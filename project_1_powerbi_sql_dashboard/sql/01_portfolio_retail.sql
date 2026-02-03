/* ============================================================
   Project 1: Portfolio Retail (Single Rerunnable Script)
   - Matches your CURRENT database design:
     * dim_geo.geo_id is TEXT (no postal_code)
     * dim_date.date_id is integer YYYYMMDD, date_value is DATE
     * staging already exists and is already loaded
   - Safe to rerun:
     * DROPs BI views first to avoid "cannot drop columns from view"
     * TRUNCATES fact table and reloads it from staging
     * UPSERTS dims safely
   ============================================================ */

-- If you ran a previous script that failed inside a transaction,
-- run this once before running the full script:
-- ROLLBACK;

BEGIN;

-- -------------------------
-- 0) Schemas
-- -------------------------
CREATE SCHEMA IF NOT EXISTS retail;
CREATE SCHEMA IF NOT EXISTS bi;

-- -------------------------
-- 1) Drop BI views first (dependency order)
-- -------------------------
DROP VIEW IF EXISTS bi.v_sales_by_segment_shipmode;
DROP VIEW IF EXISTS bi.v_sales_by_geo;
DROP VIEW IF EXISTS bi.v_sales_by_category;
DROP VIEW IF EXISTS bi.v_sales_by_month;
DROP VIEW IF EXISTS bi.v_kpi;
DROP VIEW IF EXISTS bi.v_orders;

-- -------------------------
-- 2) Core tables (create if missing)
-- -------------------------

-- Date dim
CREATE TABLE IF NOT EXISTS retail.dim_date (
  date_id     integer PRIMARY KEY,
  date_value  date NOT NULL,
  year        integer,
  quarter     integer,
  month       integer,
  month_name  text,
  day         integer,
  day_of_week integer,
  day_name    text
);

-- IMPORTANT: add UNIQUE so ON CONFLICT(date_value) works
CREATE UNIQUE INDEX IF NOT EXISTS ux_dim_date_date_value
ON retail.dim_date (date_value);

-- Customer dim
CREATE TABLE IF NOT EXISTS retail.dim_customer (
  customer_id    text PRIMARY KEY,
  customer_name  text,
  segment        text
);

-- Geo dim (NO postal_code, geo_id is TEXT)
CREATE TABLE IF NOT EXISTS retail.dim_geo (
  geo_id   text PRIMARY KEY,
  country  text,
  region   text,
  state    text,
  city     text
);

-- Product dim
CREATE TABLE IF NOT EXISTS retail.dim_product (
  product_id    text PRIMARY KEY,
  category      text,
  sub_category  text,
  product_name  text
);

-- Fact table
CREATE TABLE IF NOT EXISTS retail.fact_orders (
  order_row_id    bigint PRIMARY KEY,
  order_id        text,
  order_date_id   integer REFERENCES retail.dim_date(date_id),
  ship_date       date,
  ship_mode       text,
  customer_id     text REFERENCES retail.dim_customer(customer_id),
  product_id      text REFERENCES retail.dim_product(product_id),
  geo_id          text REFERENCES retail.dim_geo(geo_id),
  sales           numeric,
  profit          numeric,
  quantity        integer,
  discount        numeric
);

-- Indexes (optional)
CREATE INDEX IF NOT EXISTS idx_fact_orders_order_id     ON retail.fact_orders(order_id);
CREATE INDEX IF NOT EXISTS idx_fact_orders_date_id      ON retail.fact_orders(order_date_id);
CREATE INDEX IF NOT EXISTS idx_fact_orders_customer_id  ON retail.fact_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_fact_orders_product_id   ON retail.fact_orders(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_orders_geo_id       ON retail.fact_orders(geo_id);

-- -------------------------
-- 3) Rebuild dims + fact from staging
--    (Assumes retail.stg_superstore already exists + is loaded)
-- -------------------------

-- 3.0 Clear fact first
TRUNCATE TABLE retail.fact_orders;

-- 3.1 dim_date from DISTINCT order_date in staging (parse MM/DD/YYYY)
INSERT INTO retail.dim_date (date_id, date_value, year, quarter, month, month_name, day, day_of_week, day_name)
SELECT
  TO_CHAR(d, 'YYYYMMDD')::int        AS date_id,
  d                                  AS date_value,
  EXTRACT(YEAR FROM d)::int          AS year,
  EXTRACT(QUARTER FROM d)::int       AS quarter,
  EXTRACT(MONTH FROM d)::int         AS month,
  TO_CHAR(d, 'Mon')                  AS month_name,
  EXTRACT(DAY FROM d)::int           AS day,
  EXTRACT(DOW FROM d)::int           AS day_of_week,
  TO_CHAR(d, 'Dy')                   AS day_name
FROM (
  SELECT DISTINCT to_date(order_date, 'MM/DD/YYYY') AS d
  FROM retail.stg_superstore
  WHERE COALESCE(order_date,'') <> ''
) x
WHERE d IS NOT NULL
ON CONFLICT (date_value) DO NOTHING;

-- 3.2 dim_customer
INSERT INTO retail.dim_customer (customer_id, customer_name, segment)
SELECT DISTINCT
  customer_id,
  customer_name,
  segment
FROM retail.stg_superstore
WHERE NULLIF(customer_id,'') IS NOT NULL
ON CONFLICT (customer_id) DO NOTHING;

-- 3.3 dim_geo (geo_id derived from location fields)
INSERT INTO retail.dim_geo (geo_id, country, region, state, city)
SELECT DISTINCT
  MD5(
    COALESCE(country,'') || '|' ||
    COALESCE(region,'')  || '|' ||
    COALESCE(state,'')   || '|' ||
    COALESCE(city,'')
  ) AS geo_id,
  country,
  region,
  state,
  city
FROM retail.stg_superstore
ON CONFLICT (geo_id) DO NOTHING;

-- 3.4 dim_product
INSERT INTO retail.dim_product (product_id, category, sub_category, product_name)
SELECT DISTINCT
  product_id,
  category,
  sub_category,
  product_name
FROM retail.stg_superstore
WHERE NULLIF(product_id,'') IS NOT NULL
ON CONFLICT (product_id) DO NOTHING;

-- 3.5 fact_orders from staging
-- NOTE: ship_date in staging is text, so parse it to DATE safely
INSERT INTO retail.fact_orders (
  order_row_id,
  order_id,
  order_date_id,
  ship_date,
  ship_mode,
  customer_id,
  product_id,
  geo_id,
  sales,
  profit,
  quantity,
  discount
)
SELECT
  row_id::bigint AS order_row_id,
  order_id,
  TO_CHAR(to_date(order_date, 'MM/DD/YYYY'), 'YYYYMMDD')::int AS order_date_id,
  to_date(ship_date, 'MM/DD/YYYY') AS ship_date,
  ship_mode,
  customer_id,
  product_id,
  MD5(
    COALESCE(country,'') || '|' ||
    COALESCE(region,'')  || '|' ||
    COALESCE(state,'')   || '|' ||
    COALESCE(city,'')
  ) AS geo_id,
  sales::numeric,
  profit::numeric,
  quantity::int,
  discount::numeric
FROM retail.stg_superstore
WHERE NULLIF(row_id,'') IS NOT NULL;

-- -------------------------
-- 4) BI Views
-- -------------------------

-- 4.1 Base BI view (no postal_code)
CREATE OR REPLACE VIEW bi.v_orders AS
SELECT
  fo.order_row_id,
  fo.order_id,
  dd.date_value AS order_date,
  fo.ship_date,
  fo.ship_mode,

  dc.customer_id,
  dc.customer_name,
  dc.segment,

  dg.country,
  dg.region,
  dg.state,
  dg.city,

  dp.product_id,
  dp.category,
  dp.sub_category,
  dp.product_name,

  fo.sales,
  fo.profit,
  fo.quantity,
  fo.discount
FROM retail.fact_orders fo
JOIN retail.dim_date dd
  ON fo.order_date_id = dd.date_id
JOIN retail.dim_customer dc
  ON fo.customer_id = dc.customer_id
JOIN retail.dim_geo dg
  ON fo.geo_id = dg.geo_id
JOIN retail.dim_product dp
  ON fo.product_id = dp.product_id;

-- 4.2 KPI (one row)
CREATE OR REPLACE VIEW bi.v_kpi AS
SELECT
  COUNT(DISTINCT order_id) AS total_orders,
  COUNT(*) AS total_line_items,
  COUNT(DISTINCT customer_id) AS total_customers,
  SUM(sales) AS total_sales,
  SUM(profit) AS total_profit,
  SUM(quantity) AS total_quantity,
  AVG(discount) AS avg_discount,
  (SUM(profit) / NULLIF(SUM(sales), 0)) AS profit_margin,
  (SUM(sales) / NULLIF(COUNT(DISTINCT order_id), 0)) AS avg_order_value
FROM bi.v_orders;

-- 4.3 Sales by month
CREATE OR REPLACE VIEW bi.v_sales_by_month AS
SELECT
  DATE_TRUNC('month', order_date)::date AS month,
  SUM(sales) AS sales,
  SUM(profit) AS profit,
  COUNT(DISTINCT order_id) AS orders,
  (SUM(profit) / NULLIF(SUM(sales), 0)) AS profit_margin
FROM bi.v_orders
GROUP BY 1
ORDER BY 1;

-- 4.4 Sales by category/sub-category
CREATE OR REPLACE VIEW bi.v_sales_by_category AS
SELECT
  category,
  sub_category,
  SUM(sales) AS sales,
  SUM(profit) AS profit,
  COUNT(DISTINCT order_id) AS orders,
  (SUM(profit) / NULLIF(SUM(sales), 0)) AS profit_margin
FROM bi.v_orders
GROUP BY 1, 2
ORDER BY sales DESC;

-- 4.5 Sales by geography
CREATE OR REPLACE VIEW bi.v_sales_by_geo AS
SELECT
  country,
  region,
  state,
  city,
  SUM(sales) AS sales,
  SUM(profit) AS profit,
  COUNT(DISTINCT order_id) AS orders,
  (SUM(profit) / NULLIF(SUM(sales), 0)) AS profit_margin
FROM bi.v_orders
GROUP BY 1, 2, 3, 4
ORDER BY sales DESC;

-- 4.6 Sales by segment and ship mode
CREATE OR REPLACE VIEW bi.v_sales_by_segment_shipmode AS
SELECT
  segment,
  ship_mode,
  SUM(sales) AS sales,
  SUM(profit) AS profit,
  COUNT(DISTINCT order_id) AS orders,
  AVG(discount) AS avg_discount
FROM bi.v_orders
GROUP BY 1, 2
ORDER BY sales DESC;

COMMIT;
