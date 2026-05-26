CREATE DATABASE tn_election_analysis;

CREATE TABLE tn_2021_results (
    constituency TEXT,
    ac_number INT,
    candidate TEXT,
    party TEXT,
    votes INT,
    turnout NUMERIC,
    reserved TEXT,
    region TEXT
);
SELECT * FROM tn_2021_results;

COPY tn_2021_results (constituency, ac_number, candidate, party, votes, turnout, reserved, region )
FROM '/Applications/PostgreSQL 18/input_files_for_participants_rpc/data/tn_2021_results.csv'
DELIMITER ','
CSV HEADER;

CREATE TABLE tn_2026_results (constituency TEXT,
    ac_number INT,
    candidate TEXT,
    party TEXT,
    votes INT,
    turnout NUMERIC,
    reserved TEXT,
    region TEXT
);
COPY tn_2026_results (constituency,	ac_number,	candidate,	party,	votes,	turnout,	reserved,	region)
FROM '/Applications/PostgreSQL 18/input_files_for_participants_rpc/data/tn_2026_results.csv'
DELIMITER ','
CSV HEADER;
SELECT * FROM tn_2026_results;

SELECT * FROM tn_2026_results;
CREATE TABLE constituency_master( ac_number INT PRIMARY KEY,
constituency TEXT,
district VARCHAR (50),
region TEXT	,
reserved TEXT
);

COPY constituency_master (ac_number, constituency,	district,	region,	reserved)
FROM '/Applications/PostgreSQL 18/input_files_for_participants_rpc/data/constituency_master.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM constituency_master;

----------------------------------------------
SELECT COUNT(DISTINCT constituency)
FROM tn_2021_results;

SELECT COUNT(DISTINCT constituency)
FROM tn_2026_results;

SELECT COUNT(*)
FROM constituency_master;

SELECT cm.ac_number,
       cm.constituency,
       cm.region

FROM constituency_master cm

LEFT JOIN

(
SELECT DISTINCT constituency
FROM tn_2021_results
)t

ON cm.constituency = t.constituency

WHERE t.constituency IS NULL;

SELECT COUNT(DISTINCT constituency)
FROM constituency_master;

SELECT constituency, 
COUNT(*)
FROM constituency_master
GROUP BY 	constituency 
HAVING COUNT(*) > 1;

SELECT *
FROM constituency_master
WHERE constituency = 'Tiruppattur';

SELECT DISTINCT
ac_number,
constituency

FROM tn_2021_results

WHERE constituency='Tiruppattur';

SELECT DISTINCT
ac_number,
constituency

FROM tn_2026_results

WHERE constituency='Tiruppattur';
-----------------------------------
DROP VIEW winners_2021 CASCADE;
DROP VIEW winners_2026 CASCADE;

CREATE VIEW winners_2021 AS
SELECT * FROM ( SELECT *, 
ROW_NUMBER() OVER ( PARTITION BY ac_number ORDER BY votes DESC) AS rn
FROM tn_2021_results)t
WHERE rn = 1;

SELECT COUNT(*) FROM winners_2021;

CREATE VIEW winners_2026 AS
SELECT * FROM ( SELECT *, 
ROW_NUMBER() OVER ( PARTITION BY ac_number ORDER BY votes DESC) AS rn
FROM tn_2026_results)t
WHERE rn = 1;

SELECT COUNT(*) FROM winners_2026;

SELECT * FROM winners_2021
LIMIT 5;
SELECT * FROM winners_2026
LIMIT 5;

SELECT region, party,
COUNT(*) AS seats_won
FROM winners_2021
GROUP BY region, party
ORDER BY region, seats_won DESC;

SELECT region, party,
COUNT(*) AS seats_won
FROM winners_2026
GROUP BY region, party
ORDER BY region, seats_won DESC;

CREATE OR REPLACE VIEW seat_change_constituency AS
SELECT
    COALESCE(w21.ac_number, w26.ac_number) AS ac_number,
    cm.constituency,
    cm.region,
    w21.party AS party_2021,
    w26.party AS party_2026
FROM winners_2021 w21
FULL JOIN winners_2026 w26
    ON w21.ac_number = w26.ac_number
LEFT JOIN constituency_master cm
    ON cm.ac_number = COALESCE(w21.ac_number, w26.ac_number);


SELECT * FROM seat_change_constituency;

SELECT COUNT(*) FROM seat_change_constituency;

-- Flipped constituencies
SELECT *
FROM seat_change_constituency
WHERE party_2021 IS DISTINCT FROM party_2026;

--party seats in 2021
SELECT party_2021 AS party, COUNT(*) AS seats_2021
FROM seat_change_constituency
GROUP BY party_2021;

--Party seats in 2026
SELECT party_2026 AS party, COUNT(*) AS seats_2026
FROM seat_change_constituency
GROUP BY party_2026;

--How many constituencies changed winning party?

SELECT COUNT(*) AS flipped_constituencies
FROM seat_change_constituency
WHERE party_2021 IS DISTINCT FROM party_2026;

--Which constituencies changed winning party?
SELECT
    ac_number,
    constituency,
    region,
    party_2021,
    party_2026
FROM seat_change_constituency
WHERE party_2021 IS DISTINCT FROM party_2026;

--Which party gained/lost seats?

-- 2021 seats
SELECT
party_2021 AS party,
COUNT(*) AS seats
FROM seat_change_constituency
WHERE party_2021 IS NOT NULL
GROUP BY party_2021;

--2026 seats 
SELECT
party_2026 AS party,
COUNT(*) AS seats
FROM seat_change_constituency
WHERE party_2026 IS NOT NULL
GROUP BY party_2026;

--Net seat change per party
WITH s2021 AS (
SELECT
party_2021 AS party,
COUNT(*) AS seats_2021
FROM seat_change_constituency
WHERE party_2021 IS NOT NULL
GROUP BY party_2021
),

s2026 AS (
SELECT
party_2026 AS party,
COUNT(*) AS seats_2026
FROM seat_change_constituency
WHERE party_2026 IS NOT NULL
GROUP BY party_2026
)

SELECT
COALESCE(s2021.party,s2026.party) AS party,
COALESCE(seats_2021,0) AS seats_2021,
COALESCE(seats_2026,0) AS seats_2026,
COALESCE(seats_2026,0)-COALESCE(seats_2021,0)
AS net_change

FROM s2021
FULL JOIN s2026
ON s2021.party=s2026.party;

--Did competitiveness increase?
WITH ranked AS (
    SELECT
        ac_number,
        votes,
        ROW_NUMBER() OVER (PARTITION BY ac_number ORDER BY votes DESC) AS rn
    FROM tn_2021_results
),
margin AS (
    SELECT
        ac_number,
        MAX(CASE WHEN rn = 1 THEN votes END) -
        MAX(CASE WHEN rn = 2 THEN votes END) AS margin
    FROM ranked
    GROUP BY ac_number
)
SELECT AVG(margin) AS avg_margin_2021
FROM margin;

--2026 average margin
WITH ranked AS (
    SELECT
        ac_number,
        votes,
        ROW_NUMBER() OVER (PARTITION BY ac_number ORDER BY votes DESC) AS rn
    FROM tn_2026_results
),
margin AS (
    SELECT
        ac_number,
        MAX(CASE WHEN rn = 1 THEN votes END) -
        MAX(CASE WHEN rn = 2 THEN votes END) AS margin
    FROM ranked
    GROUP BY ac_number
)
SELECT AVG(margin) AS avg_margin_2026
FROM margin;

--Distribution of winning margins
WITH ranked AS (
    SELECT
        ac_number,
        votes,
        ROW_NUMBER() OVER (PARTITION BY ac_number ORDER BY votes DESC) AS rn
    FROM tn_2026_results
),
margin AS (
    SELECT
        ac_number,
        MAX(CASE WHEN rn = 1 THEN votes END) -
        MAX(CASE WHEN rn = 2 THEN votes END) AS margin
    FROM ranked
    GROUP BY ac_number
)
SELECT
    CASE
        WHEN margin < 5000 THEN 'Very Close'
        WHEN margin < 15000 THEN 'Close'
        ELSE 'Safe'
    END AS competitiveness_bucket,
    COUNT(*) AS constituencies
FROM margin
GROUP BY 1;

--Which regions are most volatile?
SELECT
    region,
    COUNT(*) AS flipped_seats
FROM seat_change_constituency
WHERE party_2021 IS DISTINCT FROM party_2026
GROUP BY region
ORDER BY flipped_seats DESC;

--Strongholds vs Swing seats

--Strongholds (no change)
SELECT *
FROM seat_change_constituency
WHERE party_2021 = party_2026;

--Swing seats
SELECT *
FROM seat_change_constituency
WHERE party_2021 IS DISTINCT FROM party_2026;

--Party-to-party transitions
SELECT
    party_2021,
    party_2026,
    COUNT(*) AS transitions
FROM seat_change_constituency
WHERE party_2021 IS DISTINCT FROM party_2026
GROUP BY party_2021, party_2026
ORDER BY transitions DESC;

-- percentage of flipped constituencies
SELECT
ROUND(
100.0 * COUNT(*) /
(SELECT COUNT(*) FROM seat_change_constituency),
2
) AS flip_percentage
FROM seat_change_constituency
WHERE party_2021 IS DISTINCT FROM party_2026;

-- Top 10 closest battles in Tamil Nadu

WITH ranked AS (
SELECT
ac_number,
constituency,
votes,
ROW_NUMBER() OVER (
PARTITION BY ac_number
ORDER BY votes DESC
) rn
FROM tn_2026_results
),

margin_calc AS (
SELECT
ac_number,
constituency,
MAX(CASE WHEN rn=1 THEN votes END)
-
MAX(CASE WHEN rn=2 THEN votes END)
AS margin
FROM ranked
GROUP BY ac_number, constituency
)

SELECT *
FROM margin_calc
ORDER BY margin ASC
LIMIT 10;

---------------------------------------

--Did competitiveness increase?
WITH ranked AS (
    SELECT
        ac_number,
        votes,
        ROW_NUMBER() OVER (
            PARTITION BY ac_number
            ORDER BY votes DESC
        ) AS rn
    FROM tn_2021_results
),

margin AS (
    SELECT
        ac_number,
        MAX(CASE WHEN rn=1 THEN votes END)
        -
        MAX(CASE WHEN rn=2 THEN votes END)
        AS margin
    FROM ranked
    GROUP BY ac_number
)

SELECT AVG(margin) AS avg_margin_2021
FROM margin;

--2026 average margin

WITH ranked AS (
SELECT
ac_number,
votes,
ROW_NUMBER() OVER(
PARTITION BY ac_number
ORDER BY votes DESC
) rn
FROM tn_2026_results
),

margin AS (
SELECT
ac_number,
MAX(CASE WHEN rn=1 THEN votes END)
-
MAX(CASE WHEN rn=2 THEN votes END)
AS margin
FROM ranked
GROUP BY ac_number
)

SELECT AVG(margin) AS avg_margin_2026
FROM margin;
