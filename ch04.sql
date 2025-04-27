--  Aggregation and Analysis p.58

duckdb

ATTACH 'data/ch03.duckdb' AS ch03;
USE ch03;

LOAD HTTPFS;

-- check that the table contains 15 min timestamps only
SELECT minute( read_on) AS min
FROM ch03.readings 
WHERE min NOT IN (0, 15, 30, 45);

SUMMARIZE readings;

SELECT count(*),
min(power) AS min_W, max(power) AS max_W,
round(sum(power) / 4 / 1000, 2) AS kWh
FROM readings;

SELECT year(read_on) AS year,
system_id,
count(*),
round(sum(power) / 4 / 1000, 2) AS kWh
FROM readings
GROUP BY year, system_id
ORDER BY year, system_id;

-- GROUPING SETS

SELECT year(read_on) AS year,
system_id,
count(*),
round(sum(power) / 4 / 1000, 2) AS kWh
FROM readings
GROUP BY GROUPING SETS ((year, system_id), year, ())
ORDER BY year NULLS FIRST, system_id NULLS FIRST;


-- ALTERNATIVELY ROLLUP p.68

SELECT year(read_on) AS year,
system_id,
count(*),
round(sum(power) / 4 / 1000, 2) AS kWh
FROM readings
GROUP BY ROLLUP (year, system_id)
ORDER BY year NULLS FIRST, system_id NULLS FIRST;

-- CUBE p.69 combination of all grouping sets

SELECT year(read_on) AS year,
system_id,
count(*),
round(sum(power) / 4 / 1000, 2) AS kWh,
min(power) AS min_W,
max(power) AS max_W
FROM readings
GROUP BY CUBE (year, system_id)
ORDER BY year NULLS FIRST, system_id NULLS FIRST;


-- WINDOW FUNCTIONS p.70

-- CTE to rank the readings by power
WITH ranked_readings AS (
SELECT *,
dense_rank()
OVER (ORDER BY power DESC) AS rnk
FROM readings
)
-- then filter the top 3 readings i.e. the top 3 power values
SELECT *
FROM ranked_readings
WHERE rnk <= 3;

-- Now do the window function by system - using PARTITION

WITH ranked_readings AS (
SELECT *,
dense_rank()
OVER (
PARTITION BY system_id
ORDER BY power DESC
) AS rnk
FROM readings
)
SELECT * FROM ranked_readings WHERE rnk <= 2
ORDER BY system_id, rnk ASC;

-- USE THIS FOR THE EVIDENCE EMISSIONS FOR POPULATION and per cap emissions
-- avoid self - joins by using window functions

-- ROLLING STATISTICS WITH WINDOW FUNCTIONS p.74

SELECT system_id,
day,
kWh,
avg(kWh) OVER (
PARTITION BY system_id
ORDER BY day ASC
RANGE BETWEEN INTERVAL 3 Days PRECEDING
AND INTERVAL 3 Days FOLLOWING
) AS "kWh 7-day moving average"
FROM v_power_per_day
ORDER BY system_id, day;

-- using a named window with complex order and partition
-- quantile returns a list column

SELECT system_id,
    day,
    min(kWh) OVER seven_days AS "7-day min",
    quantile(kWh, [0.25, 0.5, 0.75])
OVER seven_days AS "kWh 7-day quartile",
    max(kWh) OVER seven_days AS "7-day max",
FROM v_power_per_day
-- below is where the window is defined
WINDOW
    seven_days AS (
    PARTITION BY system_id, month(day)
    ORDER BY day ASC
    RANGE BETWEEN INTERVAL 3 Days PRECEDING
    AND INTERVAL 3 Days FOLLOWING
)
ORDER BY system_id, day;

-- LAG AND LEAD WITH NAMED WINDOW FUNCTIONS p.78

SELECT
    valid_from,
    value,
    lag(value) OVER validity AS "Previous value",
    value - lag(value, 1, value) OVER validity AS Change
FROM prices
WHERE date_part('year', valid_from) = 2019
WINDOW validity AS (ORDER BY valid_from)
ORDER BY valid_from;