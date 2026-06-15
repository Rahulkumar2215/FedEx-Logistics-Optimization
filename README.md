# FedEx Logistics Optimization

End-to-end logistics analytics project combining **SQL (MySQL)** for data cleaning and analysis with **Power BI** for interactive reporting. The project models a five-table logistics network and surfaces shipment delays, route efficiency, agent performance, and warehouse utilization.

## Overview

This project analyzes shipment, route, warehouse, agent, and order data to answer operational questions such as: which routes are slowest, where delays concentrate, which warehouses and agents underperform, and which lanes are the least efficient. SQL handles the data cleaning and analytical heavy lifting; Power BI delivers the visual layer.

## Dataset

The analysis is built on five related tables:

- `fedex_orders` — order records and delivery type (Express / Standard)
- `fedex_shipments` — shipment-level data including pickup/delivery dates, delay hours, delivery status, and delay reasons
- `fedex_routes` — route distance, expected transit time, and source country
- `fedex_warehouses` — warehouse capacity per day
- `fedex_delivery_agents` — agent rating and years of experience

## Dashboard Screenshots

### Actual vs Expected Transit Time
![Actual Transit Time](images/Actual_transit_time.png)

Actual transit time exceeds the planned baseline on all 20 routes, identified as the root cause of the high overall delay rate.

### Agent Performance
![Agent Performance](images/Agent_performance.png)

### Shipment Delay Analysis
![Shipment Delay](images/Shipment_delay.png)

### Traffic Delay
![Traffic Delay](images/Traffic_delay.png)

### Source Country Analysis
![Source Country](images/source_country.png)

## Tech Stack

- **MySQL Workbench** — data cleaning, joins, CTEs, window functions, conditional aggregation, and date arithmetic
- **Power BI Desktop** — data model, DAX measures, and interactive dashboard

## Data Cleaning (SQL)

- Identified duplicate orders and shipments using `ROW_NUMBER()` partitioned by ID, then removed duplicates keeping the first occurrence
- Backfilled missing `Delay_Hours` with the average delay per route using a correlated `UPDATE ... JOIN`
- Standardized order, pickup, and delivery date formats with `DATE_FORMAT`
- Flagged invalid records where pickup date occurs after delivery date
- Validated referential integrity — confirmed every shipment maps to a valid order, route, warehouse, and agent using `LEFT JOIN ... IS NULL` checks

## Key Analyses (SQL)

**Route performance**
- Average actual transit time per route using `TIMESTAMPDIFF`
- Top 10 most-delayed routes by average delay hours
- Distance-to-time efficiency ratio (`distance_km / avg_transit_time_hours`) to rank the least efficient routes
- Routes where more than 20% of shipments exceed expected transit time, using `CASE` with conditional aggregation
- Routes where the majority of shipments are still "In Transit" or "Returned"

**Warehouse performance**
- Top warehouses by average shipment delay
- Total vs. delayed shipments per warehouse
- Warehouses whose average delay exceeds the global average, using CTEs
- On-time delivery ranking across warehouses with `RANK()`
- Warehouse utilization % (`shipments_handled / capacity_per_day`)

**Agent performance**
- Agent on-time delivery ranking per route using `DENSE_RANK()`
- Agents performing below 85% on-time delivery
- Top 5 vs. bottom 5 agents compared on average rating and experience using subqueries and `UNION ALL`

**Delay diagnostics**
- Average delay per delivery type (Express vs. Standard)
- Average delivery delay per source country
- Most frequent delay reasons
- High-delay orders (over 120 hours) flagged as bottlenecks
- Overall on-time delivery percentage

## SQL Techniques Demonstrated

- Multi-table `JOIN`s across all five tables
- `CTE`s for staged, readable transformations
- Window functions — `ROW_NUMBER`, `RANK`, `DENSE_RANK`
- `CASE` expressions for SLA flagging and conditional aggregation
- Date arithmetic with `TIMESTAMPDIFF`, `DATE_FORMAT`
- Subqueries and `UNION ALL` for comparative analysis

## Repository Structure

```
images/                          -- dashboard screenshots
Fedex_logistics_optimization.sql -- schema use, data cleaning, and analysis queries
logistics_optimization.pbix      -- Power BI report
Presentation1.pptx               -- project presentation
README.md
```

## How to Run

1. Create the `FedEx` schema and load the five tables into MySQL.
2. Run the queries in `Fedex_logistics_optimization.sql` — the file moves from data validation and cleaning through to the full analysis.
3. Open `logistics_optimization.pbix` in Power BI Desktop and point the data source to your MySQL instance.
4. Refresh to populate the visuals.

## Author

**Rahul Kumar** — Data Analytics | SQL · Power BI · Python
