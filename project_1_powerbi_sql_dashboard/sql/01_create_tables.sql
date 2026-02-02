-- 01_create_tables.sql
-- Retail Sales Star Schema (PostgreSQL)

DROP TABLE IF EXISTS fact_orders;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_geo;

CREATE TABLE dim_date (
  date_id       INT PRIMARY KEY,          -- YYYYMMDD
  date_value    DATE NOT NULL,
  year          INT NOT NULL,
  quarter       INT NOT NULL,
  month         INT NOT NULL,
  month_name    TEXT NOT NULL,
  day           INT NOT NULL,
  day_of_week   INT NOT NULL,
  day_name      TEXT NOT NULL
);

CREATE TABLE dim_customer (
  customer_id   TEXT PRIMARY KEY,
  customer_name TEXT,
  segment       TEXT
);

CREATE TABLE dim_product (
  product_id    TEXT PRIMARY KEY,
  category      TEXT,
  sub_category  TEXT,
  product_name  TEXT
);

CREATE TABLE dim_geo (
  geo_id        TEXT PRIMARY KEY,   -- city|state|region
  country       TEXT,
  region        TEXT,
  state         TEXT,
  city          TEXT
);

CREATE TABLE fact_orders (
  order_row_id  BIGSERIAL PRIMARY KEY,
  order_id      TEXT,
  order_date_id INT REFERENCES dim_date(date_id),
  ship_date     DATE,
  ship_mode     TEXT,

  customer_id   TEXT REFERENCES dim_customer(customer_id),
  product_id    TEXT REFERENCES dim_product(product_id),
  geo_id        TEXT REFERENCES dim_geo(geo_id),

  sales         NUMERIC(12,2),
  profit        NUMERIC(12,2),
  quantity      INT,
  discount      NUMERIC(5,2)
);

CREATE INDEX idx_fact_order_date ON fact_orders(order_date_id);
CREATE INDEX idx_fact_customer   ON fact_orders(customer_id);
CREATE INDEX idx_fact_product    ON fact_orders(product_id);
CREATE INDEX idx_fact_geo        ON fact_orders(geo_id);
