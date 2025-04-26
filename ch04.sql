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