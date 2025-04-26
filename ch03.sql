nu
-- get the apikey for use in the api call
cat ../config.yml | from yaml | get data_gov | get apikey | save data/apikey.txt

duckdb

ATTACH 'data/ch03.duckdb' AS ch03;
USE ch03;

LOAD HTTPFS;

-- tinkering with import syntax - will complete later
SET VARIABLE APIKEY = (SELECT content FROM read_text('data/apikey.txt') AS apikey);

SELECT getvariable('APIKEY') as apikey;

SET VARIABLE testpath = 
(SELECT concat('https://developer.nrel.gov/api/pvdaq/v3/data_file?api_key=', 'xd4iojRiqG6bf9hnQG0DYNF9i5IlMFBVl50Gv1Pb', '&system_id=34&year=2019'));

FROM read_csv(getvariable('testpath')) AS t;

-- DDL creating tables and views

CREATE TABLE IF NOT EXISTS systems(
    id INTEGER PRIMARY KEY,
    name VARCHAR(128) NOT NULL 
);

DROP TABLE IF EXISTS readings;

CREATE TABLE IF NOT EXISTS readings(
    system_id INTEGER NOT NULL,
    read_on TIMESTAMP NOT NULL,
    power DECIMAL(10, 3) NOT NULL DEFAULT 0 CHECK(power >= 0),
    PRIMARY KEY(system_id, read_on),
    FOREIGN KEY(system_id) REFERENCES systems(id)
);

CREATE SEQUENCE IF NOT EXISTS prices_id
    INCREMENT BY 1 MINVALUE 10;

CREATE TABLE IF NOT EXISTS prices(
    id INTEGER PRIMARY KEY DEFAULT(nextval('prices_id')),
    value DECIMAL(5, 2) NOT NULL,
    valid_from DATE NOT NULL,
    CONSTRAINT prices_uk UNIQUE (valid_from)
);

ALTER TABLE prices
ADD COLUMN IF NOT EXISTS valid_until DATE;

CREATE OR REPLACE VIEW v_power_per_day AS
SELECT system_id,
date_trunc('day', read_on) AS day,
round(sum(power) / 4 / 1000, 2) AS kWh,
FROM readings
GROUP BY system_id, day;

-- Insering data

-- inspect the data
DESCRIBE SELECT * FROM
'https://oedi-data-lake.s3.amazonaws.com/pvdaq/csv/systems.csv';

-- Load - and remove duplicates
INSERT INTO systems(id, name)
SELECT DISTINCT system_id, system_public_name
FROM 'https://oedi-data-lake.s3.amazonaws.com/pvdaq/csv/systems.csv'
ORDER BY system_id ASC;

FROM systems LIMIT 5;
summarize systems;


-- in this section we create a table of urls to be used in the read_csv function
-- we will use the system_id and year to create the urls
-- combined with the API key, which is read from config.yml with nushell and saved as a text file
-- duckdb reads the text file and saves the api key as a variable APIKEY

-- A cross join is used to capture all the permutations of the system_id and year to build the single
-- column table of urls
-- This is then turned into a list of urls to be used in the read_csv function
-- the urls are then used to read the csv files into the readings table
CREATE TABLE sys_id(
    id INTEGER PRIMARY KEY
);

INSERT INTO sys_id(id)
VALUES (10), (34), (1200);

FROM sys_id;

CREATE TABLE years_tbl(
    year INTEGER PRIMARY KEY
);
INSERT INTO years_tbl(year)
VALUES (2019), (2020);

CREATE TABLE urls_tbl AS
(SELECT 'https://developer.nrel.gov/api/pvdaq/v3/data_file?' ||
'api_key=' || getvariable('APIKEY') || '&system_id=' || sys_id.id || '&year=' || YEAR AS url
FROM sys_id
CROSS JOIN years_tbl);

-- make the list of urls
SET VARIABLE urls = (SELECT list(url) urls FROM urls_tbl);

-- now the readings
-- setting power to 0 if negative or null
-- ref p.36

INSERT INTO readings(system_id, read_on, power)
SELECT SiteId, "Date-Time",
CASE
    WHEN ac_power < 0 OR ac_power IS NULL THEN 0
    ELSE ac_power END
FROM read_csv_auto(getvariable('urls'), filename := True);


-- delete the readings that are not on the quarter hour
DELETE FROM readings
WHERE date_part('minute', read_on) NOT IN (0,15,30,45);

SUMMARIZE readings;

-- now prices

INSERT INTO prices(value, valid_from, valid_until)
SELECT * FROM read_csv_auto('https://raw.githubusercontent.com/duckdb-in-action/examples/refs/heads/main/ch03/prices.csv');


SHOW ALL TABLES;

SELECT date_part('year', valid_from) AS year,
min(value) AS minimum_price,
max(value) AS maximum_price
FROM prices
WHERE year BETWEEN 2019 AND 2020
GROUP BY year
ORDER BY year;