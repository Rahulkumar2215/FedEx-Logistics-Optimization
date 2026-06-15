create database FedEx;
use fedex;
show tables;
select * from fedex_delivery_agents;
select * from fedex_orders;
select * from fedex_routes;
select * from fedex_shipments;
select * from fedex_warehouses;
-- Identify duplicate records in fedex_orders based on Order_ID
select * from(select *,row_number() over(partition by order_id order by customer_id) as row_num from fedex_orders)
 as Dup_records where row_num >1;
-- Identify duplicate records in fedex_shipments based on Shipment_ID
select * from(select *,row_number() over(partition by shipment_id order by order_id)
 as row_num1 from fedex_shipments) as d where row_num1>1;
-- Delete duplicate shipments keeping first occurrence
delete from fedex_shipments where Shipment_ID
in (select Shipment_ID from (select Shipment_ID, row_number() over(partition by Shipment_ID order by Order_ID)
as row_num1 
from fedex_shipments) as temp where row_num1 > 1);
-- Delete duplicate orders keeping first occurrence
delete from fedex_orders where order_ID 
in (select order_ID from (select order_ID, ROW_NUMBER() OVER(PARTITION BY order_ID ORDER BY customer_ID)
 AS row_num 
 FROM fedex_orders) AS t WHERE row_num > 1);
-- Replacing null Delay_Hours with average delay for that Route_ID
update fedex_shipments f1
join (
select Route_ID, avg(Delay_Hours) as avg_delay
from fedex_shipments
where Delay_Hours is not null
group by Route_ID
) as avg_table on f1.Route_ID = avg_table.Route_ID
set f1.Delay_Hours = avg_table.avg_delay
where f1.Delay_Hours is null;
-- change the Date Formats
select date_format(order_date,'%Y-%m-%d %H:%i:%s') as formatted_order_date from fedex_orders;
select date_format(pickup_date,'%Y-%m-%d %H:%i:%s') as formatted_pickup_date,
date_format(delivery_date,'%Y-%m-%d %H:%i:%s') as formatted_delivery_date
from fedex_shipments;
-- Flag out the Pickup_Date that occurs before delivery_Date
select * from fedex_shipments where pickup_date > delivery_date;
--  check Every shipment has a valid corresponding order
SELECT s.* FROM fedex_shipments s
LEFT JOIN fedex_orders o ON s.Order_ID = o.Order_ID
WHERE o.Order_ID IS NULL;
-- check every shipment has a valid route_id
select s.* from fedex_shipments s 
left join fedex_routes r on s.route_id=r.route_id
where r.route_id is null;
-- check every shipment has a valid warehouse_id
select s.* from fedex_shipments s left join fedex_warehouses w
on s.warehouse_id=w.warehouse_id
where w.warehouse_id is null;
-- Check every shipment has a valid agent_id
SELECT s.* FROM fedex_shipments s 
LEFT JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
WHERE a.Agent_ID IS NULL;
-- calculated delivery_delay_hours using pickup_date and delivery_date
select shipment_id,timestampdiff(hour,pickup_date,delivery_date) as delivery_delay_hours
from fedex_shipments;
-- top 10 delayed routes based on avg delay_hours
select route_id,round(avg(delay_hours),2) as avg_delay from fedex_shipments
 group by route_id order by avg_delay desc limit 10;
-- Used SQL window functions to rank shipments by delay within each Warehouse_ID.
select *,dense_rank() over(partition by warehouse_id order by delay_hours desc) 
as rk from fedex_shipments;
-- the average delay per Delivery_Type (Express / Standard) to compare service-level efficiency
select o.delivery_type,round(avg(s.delay_hours),2) as avg_delay 
from fedex_orders o inner join fedex_shipments s on o.order_id=s.order_id group by o.delivery_type;
-- Average transit time (in hours) across all shipments for each route
SELECT s.route_id, 
ROUND(AVG(TIMESTAMPDIFF(HOUR, s.pickup_date, s.delivery_date)), 2) AS avg_actual_transit_time
FROM fedex_shipments s
GROUP BY s.route_id
ORDER BY s.route_id;
-- Average delay (in hours) per route
select route_id,round(avg(delay_hours),2) as avg_delay_by_route from fedex_shipments group by route_id;
-- Distance-to-time efficiency ratio = Distance_KM / Avg_Transit_Time_Hours
select route_id,round((distance_km/avg_transit_time_hours),2) as distance_time_efficiency from fedex_routes;
-- Identify 3 routes with the worst efficiency ratio (most inefficient routes)
select route_id,round((distance_km/avg_transit_time_hours),2) as distance_time_efficiency 
from fedex_routes
order by distance_time_efficiency asc limit 3;
-- Find routes with >20% of shipments delayed beyond expected transit time
SELECT s.route_id, COUNT(*) AS total_shipments,
SUM(CASE WHEN TIMESTAMPDIFF(HOUR, s.pickup_date, s.delivery_date) > r.avg_transit_time_hours THEN 1 ELSE 0 END) 
AS delayed_beyond_expected,
ROUND(SUM(CASE WHEN TIMESTAMPDIFF(minute, s.pickup_date, s.delivery_date)
/60.0 > r.avg_transit_time_hours THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS delayed_pct
FROM fedex_shipments s
LEFT JOIN fedex_routes r ON s.route_id = r.route_id
GROUP BY s.route_id
HAVING delayed_pct > 20
order by delayed_pct desc;
-- Recommend potential routes or hub pairs for optimization
select *,round((distance_km/avg_transit_time_hours),2) as distance_time_efficiency 
from fedex_routes order by distance_time_efficiency asc;
-- the top 3 warehouses with the highest average delay in shipments dispatched
select warehouse_id,round(avg(delay_hours),2) as avg_delay 
from fedex_shipments group by warehouse_id order by avg_delay desc limit 3;
-- Calculate total shipments vs delayed shipments for each warehouse
select s.warehouse_id,count(*) as total_shipments,
sum(case when timestampdiff(hour,s.pickup_date,s.delivery_date) >r.avg_transit_time_hours then 1 else 0 end) 
as delayed_shipments from fedex_shipments s join fedex_routes r on s.route_id=r.route_id group by s.warehouse_id;
-- Use CTEs to identify warehouses where average delay exceeds the global average delay
with warehouse_delay as
(
select warehouse_id,round(avg(delay_hours),2) as avg_delay from fedex_shipments group by warehouse_id
),
global_delay as 
(
select round(avg(delay_hours),2) as global_avg_delay from fedex_shipments
)
select wd.warehouse_id,wd.avg_delay,gd.global_avg_delay from global_delay gd,warehouse_delay wd
where wd.avg_delay>gd.global_avg_delay;
-- Rank all warehouses based on on-time delivery percentage
with warehouse_ontime as(
select s.warehouse_id,sum(case when timestampdiff(minute,s.pickup_date,s.delivery_date)/60.0<=r.avg_transit_time_hours then 1 else 0 end)/ count(*)*100
 as on_time_delivery
from fedex_shipments s join fedex_routes r on s.route_id=r.route_id group by warehouse_id)
select warehouse_id,on_time_delivery,rank() over(order by on_time_delivery desc) as warehouse_rank
 from warehouse_ontime;
-- Rank delivery agents (per route) by on-time delivery percentage
WITH agent_ontime AS (SELECT s.agent_id, s.route_id,COUNT(*) AS total_shipments,
ROUND(SUM(CASE WHEN TIMESTAMPDIFF(minute, s.pickup_date, s.delivery_date)
/60.0 <= r.avg_transit_time_hours THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS on_time_pct
  FROM fedex_shipments s
  JOIN fedex_routes r ON s.route_id = r.route_id GROUP BY s.agent_id, s.route_id
)
SELECT agent_id, route_id, total_shipments, on_time_pct,
dense_RANK() OVER (PARTITION BY route_id ORDER BY on_time_pct DESC) AS agent_rank_on_route
FROM agent_ontime ORDER BY route_id, agent_rank_on_route;
-- Finded agents whose on-time % is below 85%.
WITH agent_ontime AS (
  SELECT s.agent_id,
    ROUND(SUM(CASE WHEN TIMESTAMPDIFF(HOUR, s.pickup_date, s.delivery_date) <= r.avg_transit_time_hours THEN 1 ELSE 0 END)
    / COUNT(*) * 100, 2) AS on_time_pct
  FROM fedex_shipments s
  JOIN fedex_routes r ON s.route_id = r.route_id
  GROUP BY s.agent_id
)
SELECT agent_id,on_time_pct
FROM agent_ontime
where on_time_pct<85;
-- Compare the average rating and experience (in years) of the top 5 vs bottom 5 agents using subqueries
SELECT 'Top 5' AS category,
ROUND(AVG(a.avg_rating), 2) AS avg_rating,
ROUND(AVG(a.experience_years), 2) AS avg_experience
FROM fedex_delivery_agents a
WHERE a.agent_id IN (
SELECT agent_id FROM (
SELECT s.agent_id,
ROUND(SUM(CASE WHEN TIMESTAMPDIFF(MINUTE, s.pickup_date, s.delivery_date)
 / 60.0 <= r.avg_transit_time_hours THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS on_time_pct
FROM fedex_shipments s
JOIN fedex_routes r ON s.route_id = r.route_id
GROUP BY s.agent_id
ORDER BY on_time_pct DESC,agent_id desc
LIMIT 5
) AS top_agents
)
UNION ALL
-- Bottom 5 group averages
SELECT 'Bottom 5' AS category,
ROUND(AVG(a.avg_rating), 2) AS avg_rating,
ROUND(AVG(a.experience_years), 2) AS avg_experience
FROM fedex_delivery_agents a
WHERE a.agent_id IN (
SELECT agent_id FROM (
SELECT s.agent_id,
ROUND(SUM(CASE WHEN TIMESTAMPDIFF(MINUTE, s.pickup_date, s.delivery_date)
 / 60.0 <= r.avg_transit_time_hours THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS on_time_pct
FROM fedex_shipments s
JOIN fedex_routes r ON s.route_id = r.route_id
GROUP BY s.agent_id
ORDER BY on_time_pct ASC,agent_id asc
LIMIT 5
) AS bottom_agents
);
-- For each shipment, display the latest status (Delivered, In Transit, or Returned) along with the latest Delivery_Date.
SELECT delivery_status,count(*) as total_shipments
FROM fedex_shipments
group by delivery_status;
-- Identify routes where the majority of shipments are still “In Transit” or “Returned
select route_id,count(*) as total,
sum(case when delivery_status in ('In Transit','Returned') then 1 else 0 end) as stuck,
round(sum(case when delivery_status in('In Transit','Returned') then 1 else 0 end)/count(*)*100,2) as stuck_perct
from fedex_shipments 
group by route_id
having stuck_perct>50;
-- Find the most frequent delay reasons (if available in delay-related columns or flags).
select delay_reason,count(*) as no_of_shipments
from fedex_shipments
group by delay_reason
order by no_of_shipments desc;
-- Identify orders with exceptionally high delay (>120 hours) to investigate potential bottlenecks.
select order_id,delay_hours,delay_reason
from fedex_shipments
where delay_hours>120
order by delay_hours desc;
-- Average Delivery Delay per Source_Country
select r.source_country,round(avg(s.delay_hours),2) as avg_delivery_delay
from fedex_routes r join fedex_shipments s
on r.route_id=s.route_id
group by r.source_country
order by avg_delivery_delay desc;
-- On-Time Delivery % = (Total On-Time Deliveries / Total Deliveries) * 100
select 
round(sum(case when timestampdiff(minute,s.pickup_date,s.delivery_date)
/60.0<=r.avg_transit_time_hours then 1 else 0 end)/count(*)*100,2) as on_time_delivery_pct
from fedex_shipments s
join fedex_routes r
on s.route_id=r.route_id;
--  Average Delay (in hours) per Route_ID.
select route_id,round(avg(delay_hours),2) as avg_delay_hours
from fedex_shipments 
group by route_id
order by avg_delay_hours desc;
-- Warehouse Utilization % = (Shipments_Handled / Capacity_per_day) * 100
with cte as (select count(shipment_id) as shipment_handled,warehouse_id
from fedex_shipments 
group by warehouse_id)
select c.warehouse_id,c.shipment_handled,w.capacity_per_day,
round((shipment_handled/capacity_per_day*100),2) as warehouse_utilization_pct
from cte c join fedex_warehouses w
on c.warehouse_id=w.warehouse_id
order by warehouse_utilization_pct desc;

