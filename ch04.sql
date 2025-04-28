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


-- QUALIFY - Filter on the results of a Window function
-- QUALIFY is like a WHERE clause but for window functions

SELECT dense_rank() OVER (ORDER BY power DESC) AS rnk, *
FROM readings
QUALIFY rnk <= 3;

-- another one
-- note QUALIFY comes after FROM as it is analagous to WHERE
-- Can use alias to refer to the result of the window function

-- find the & day moving AVG that exceeds 875 kWh
SELECT
    system_id,
    day,
    avg(kWh) OVER (PARTITION BY system_id ORDER BY day ASC  RANGE BETWEEN 
    INTERVAL 3 Days PRECEDING
    AND INTERVAL 3 Days FOLLOWING
) AS "kWh 7-day moving average"
FROM v_power_per_day
QUALIFY "kWh 7-day moving average" > 875
ORDER BY system_id, day;

-- FILTER aggregates

-- FILTER (WHERE ac_power IS NOT NULL AND ac_power >= 0):
-- This is the crucial FILTER clause, which modifies the behavior of the preceding aggregate function (avg).
-- Purpose: It specifies that the avg function should only consider rows that meet the 
-- conditions within the WHERE clause before performing the averaging calculation for each group 
-- defined by GROUP BY read_on.
-- Conditions:
-- ac_power IS NOT NULL: Excludes any rows where the ac_power reading is missing (NULL). 
-- This prevents NULLs from skewing or causing errors in the average calculation.
-- ac_power >= 0: Excludes any rows where the ac_power reading is negative. Negative AC power generation is generally physically impossible or indicates an error in the sensor or data logging. 
-- Filtering these out improves the quality and reliability of the calculated average power.
-- Benefit: Using FILTER is the standard SQL way to apply conditional aggregation. 
-- It's often more readable and potentially more efficient than older methods like 
-- avg(CASE WHEN ac_power IS NOT NULL AND ac_power >= 0 THEN ac_power ELSE NULL END).
-- coalesce(..., 0):
-- This is the COALESCE function.
-- Purpose: COALESCE takes a list of arguments and returns the first argument in the list that is not NULL.
-- Arguments:
-- The result of avg(ac_power) FILTER (...).
-- The literal value 0.
-- Behavior:
-- If the filtered average calculation (avg(ac_power) FILTER (...)) results in a valid average value (meaning there was at least one non-NULL, non-negative ac_power reading in that 15-minute time bucket), coalesce will return that average value.
-- However, if all the ac_power readings within a specific 15-minute bucket are either NULL or negative (and therefore filtered out by the FILTER clause), the avg function will return NULL (as there are no valid rows to average).
-- In this scenario where avg returns NULL, coalesce moves to its next argument, which is 0. Since 0 is not NULL, coalesce returns 0.
-- Benefit: This ensures that every 15-minute interval in the output has a defined power value. Instead of potentially having NULL for power (which might complicate later analysis), intervals with no valid data are assigned an average power of 0. This often makes sense in energy contexts, representing zero generation during that period.
-- https://g.co/gemini/share/b1dd4569df71
INSERT INTO readings(system_id, read_on, power)
SELECT any_value(SiteId),
time_bucket(
INTERVAL '15 Minutes',
CAST("Date-Time" AS timestamp)
) AS read_on,
coalesce(avg(ac_power)
FILTER (
ac_power IS NOT NULL AND
ac_power >= 0
),0 )
FROM
read_csv_auto(
'https://developer.nrel.gov/api/pvdaq/v3/' ||
'data_file?api_key=DEMO_KEY&system_id=10&year=2019'
)
GROUP BY read_on
ORDER BY read_on
ON CONFLICT DO NOTHING;