# Project 2 — Python ETL + Data Quality Checks

## Goal
Build a small ETL pipeline that loads raw data into PostgreSQL and generates a data quality report.

## Tools
Python (pandas) | PostgreSQL | SQL

## What I built
- Python ETL script to ingest raw CSV and load clean tables into PostgreSQL
- Automated checks: nulls, duplicates, out-of-range values
- Generated a `data_quality_report` table with timestamps

## Folder structure
- `etl/` — Python scripts
- `sql/` — table creation + quality queries
- `screenshots/` — outputs and results
