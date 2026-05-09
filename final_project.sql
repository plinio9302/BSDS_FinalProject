-- =============================================================================
-- BSD 200 | Project Milestone – Part 2
-- Dataset  : Beer Reviews (clean_file.csv)
-- Authors  : Plinio Durango | Zachary M
-- =============================================================================
-- TABLE OF CONTENTS
--   PART 1  – Motivation
--   PART 2  – Exploratory Data Analysis (7-step framework)
--   PART 3  – Data Cleaning
--   PART 4  – Join Strategy (single-table; self-join / derived tables)
--   PART 5  – Draft Analysis Queries
-- =============================================================================


-- =============================================================================
-- PART 1 – MOTIVATION
-- Authors: Plinio Durango & Zachary M
-- =============================================================================

/*
SOURCE
------
The dataset was obtained from Kaggle:
https://www.kaggle.com/datasets/ruthgn/beer-profile-and-ratings-data-set

The original data combines two public sources:
  1. BeerAdvocate user reviews (review scores + number of reviews)
  2. A curated beer profile dataset containing style, ABV, IBU ranges,
     and flavor-attribute scores derived from the beer descriptions.

WHY WE CHOSE IT
---------------
Beer is one of the most widely reviewed consumer products in the world,
and this dataset sits at an interesting intersection of objective chemistry
(ABV, IBU) and subjective taste perception (flavor scores, review ratings).
We were drawn to questions like:
  - Does higher bitterness (IBU) hurt or help overall ratings?
  - Are certain breweries consistently outperforming their style peers?
  - Do flavor descriptors (Hoppy, Malty, Sweet) actually predict review scores?

TABLE DIMENSIONS (from CSV inspection)
---------------------------------------
Rows    : 3,197 beers (one beer per row)
Columns : 25


EDA ISSUES FOUND (summary – details in PART 2 & 3)
----------------------------------------------------
  1. The Name column has a BOM character (ï»¿) prepended to the first row
     due to UTF-8 BOM encoding in the CSV export.
  2. Some flavor attribute scores appear to be on an arbitrary scale
     (0–~120) and are NOT on the same 0–5 scale as the review columns.
  3. The Description column contains raw HTML escape characters (\t, \n)
     and embedded formatting artifacts from the source website.
  4. ABV has a small number of 0.0 values that likely represent missing data
     rather than genuinely non-alcoholic beers (flagged during EDA).
  5. Min IBU = Max IBU = 0 for some rows, which may indicate missing IBU data
     rather than a truly zero-bitterness profile.
  6. number_of_reviews ranges widely (some beers have < 5 reviews),
     making average review scores unreliable for low-review beers.
*/


-- =============================================================================
-- PART 2 – EXPLORATORY DATA ANALYSIS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 1: What's in the table?
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

SELECT *
FROM beers
LIMIT 100;

/*
Observations:
- Each row is one beer product, identified by Name + Brewery.
- Columns fall into four groups:
    (a) Identity      : Name, Style, Brewery, Beer Name (Full), Description
    (b) Chemistry     : ABV, Min IBU, Max IBU
    (c) Flavor scores : Astringency through Malty (9 integer columns)
    (d) Review scores : review_aroma through review_overall (5 float columns),
                        plus number_of_reviews
- At first glance the flavor scores (e.g. Sweet = 101 in one row) are on
  a completely different scale than the review scores (0.0–5.0).
*/


-- -----------------------------------------------------------------------------
-- STEP 2: What does one row represent?
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

/*
Each row represents a single, uniquely named beer from a specific brewery.
There is no explicit primary key column, so we treat (Name, Brewery) as a
composite identifier. We verify this assumption below.
*/
USE final_project;
-- Count total rows
SELECT COUNT(*) AS total_rows
FROM beers;
-- Expected: 3077

-- Count distinct (Name, Brewery) combinations
-- If this equals total_rows, each row is a unique beer.
SELECT COUNT(DISTINCT CONCAT(Name, '|', Brewery)) AS distinct_beers
FROM beers;
-- Yes!! evey row is unique

-- Check for any NULL names
SELECT COUNT(*) AS null_names
FROM beers
WHERE Name IS NULL;
-- Zero null names!!

-- -----------------------------------------------------------------------------
-- STEP 3: Table dimensions
-- Author: Zachary M
-- -----------------------------------------------------------------------------

-- Should show 25 columns; inspect data types for issues.
DESCRIBE beers;
-- Answer: 25 rows

SELECT COUNT(*) AS row_count
FROM beers;
-- 3077 × 25 columns


-- -----------------------------------------------------------------------------
-- STEP 4: What values can each column take?
-- Author: Zachary M
-- -----------------------------------------------------------------------------

-- (4a) How many distinct beer styles are there?
SELECT
    Style,
    COUNT(*) AS beer_count
FROM beers
GROUP BY Style
ORDER BY beer_count DESC;

/*
There are many styles. The top styles by count give us a sense of
which categories dominate the dataset (likely IPAs, Stouts, Lagers).
*/

-- (4b) Distribution of ABV
SELECT
    MIN(ABV)  AS min_abv,
    MAX(ABV)  AS max_abv,
    ROUND(AVG(ABV), 2) AS avg_abv
FROM beers
WHERE ABV > 0; -- exclude suspected missing values (ABV = 0)

/*
We expect ABV to range roughly 2%–15% for standard beers,
with outliers above 20% for extreme styles like barleywines.
*/

-- (4c) Distribution of review_overall
SELECT
    MIN(review_overall)           AS min_rating,
    MAX(review_overall)           AS max_rating,
    ROUND(AVG(review_overall), 3) AS avg_rating,
    ROUND(STD(review_overall), 3) AS std_rating
FROM beers;

/*
BeerAdvocate uses a 0–5 scale. We expect:
  avg ~ 3.5–3.9 (craft beer datasets skew positive)
  std ~ 0.2–0.4
*/

-- (4d) Distribution of number_of_reviews
SELECT
    MIN(number_of_reviews)  AS min_reviews,
    MAX(number_of_reviews)  AS max_reviews,
    ROUND(AVG(number_of_reviews), 0) AS avg_reviews,
    -- How many beers have fewer than 10 reviews? (low-confidence ratings)
    SUM(CASE WHEN number_of_reviews < 10 THEN 1 ELSE 0 END) AS low_review_count
FROM beers;
-- This is grate, it means that out of 3077 distict beers
-- only 457 has number of reviews less than 10

-- (4e) Range of flavor attribute scores (they appear to be on a 0–120 scale)
SELECT
    MIN(Bitter)  AS min_bitter,
    MAX(Bitter)  AS max_bitter,
    MIN(Sweet)   AS min_sweet,
    MAX(Sweet)   AS max_sweet,
    MIN(Hoppy)   AS min_hoppy,
    MAX(Hoppy)   AS max_hoppy,
    MIN(Malty)   AS min_malty,
    MAX(Malty)   AS max_malty
FROM beers;

/*
If the max values are ~120 and the review scores are 0–5, these are
on different scales entirely. We flag this for the cleaning section.
*/

-- (4f) IBU ranges
SELECT
    MIN(`Min IBU`) AS min_ibu_lower,
    MAX(`Max IBU`) AS max_ibu_upper,
    -- How many rows have both IBU columns at 0?
    SUM(CASE WHEN `Min IBU` = 0 AND `Max IBU` = 0 THEN 1 ELSE 0 END) AS zero_ibu_count
FROM beers;


-- -----------------------------------------------------------------------------
-- STEP 5: Check min/max of key continuous columns for errors
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

-- ABV extremes
-- Extremely high ABV (>20%) would only make sense for specialty styles.
SELECT Name, Brewery, Style, ABV
FROM beers
ORDER BY ABV DESC
LIMIT 10;
-- Theese beers we will consider them as outliyers


-- ABV = 0.0 almost certainly means missing data, not non-alcoholic.

SELECT Name, Brewery, Style, ABV
FROM beers
ORDER BY ABV ASC
LIMIT 10;
-- Theese beers we will consider them as outliyers


-- Review score extremes
-- Top-rated beers; do they have enough reviews to be trustworthy?
SELECT Name, Brewery, Style, review_overall, number_of_reviews
FROM beers
ORDER BY review_overall DESC
LIMIT 10;
-- The first seven beers were not trustworthy, 
-- since they only contains less than 10 reviews

SELECT Name, Brewery, Style, review_overall, number_of_reviews
FROM beers
ORDER BY review_overall ASC
LIMIT 10;
-- Lowest-rated beers; again check review count.

-- Beers with suspiciously few reviews but extreme scores
SELECT Name, Brewery, Style, review_overall, number_of_reviews
FROM beers
WHERE number_of_reviews < 5
ORDER BY review_overall DESC
LIMIT 20;


-- -----------------------------------------------------------------------------
-- STEP 6: Check for duplicates
-- Author: Zachary M
-- -----------------------------------------------------------------------------

-- Total rows
SELECT COUNT(*) AS total
FROM beers; -- 3,197

-- Distinct (Name, Brewery) pairs
SELECT COUNT(DISTINCT CONCAT(Name, '||', Brewery)) AS distinct_pairs
FROM beers;

-- If the two numbers differ, identify the duplicates
SELECT
    Name,
    Brewery,
    COUNT(*) AS occurrences
FROM beers
GROUP BY Name, Brewery
HAVING occurrences > 1
ORDER BY occurrences DESC;

/*
If duplicates exist, they may represent:
  - The same beer listed under slightly different style tags
  - Data entry errors in the source CSV
We will handle these in the cleaning section.
*/


-- -----------------------------------------------------------------------------
-- STEP 7: Check for missing / NULL values
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

-- Check all key columns at once
SELECT
    SUM(Name        IS NULL) AS null_name,
    SUM(Style       IS NULL) AS null_style,
    SUM(Brewery     IS NULL) AS null_brewery,
    SUM(ABV         IS NULL) AS null_abv,
    SUM(`Min IBU`   IS NULL) AS null_min_ibu,
    SUM(`Max IBU`   IS NULL) AS null_max_ibu,
    SUM(review_overall IS NULL) AS null_review_overall,
    SUM(number_of_reviews IS NULL) AS null_n_reviews
FROM beers;

-- Check for ABV = 0 (suspected missing values, not true zeros)
SELECT COUNT(*) AS abv_zero_count
FROM beers
WHERE ABV = 0;

-- Check for both IBU columns = 0 (suspected missing, not truly zero bitterness)
SELECT COUNT(*) AS ibu_zero_count
FROM beers
WHERE `Min IBU` = 0 AND `Max IBU` = 0;

-- Check for empty strings in text columns (a common import artifact)
SELECT COUNT(*) AS empty_style
FROM beers
WHERE Style = '' OR Style IS NULL;

SELECT COUNT(*) AS empty_brewery
FROM beers
WHERE Brewery = '' OR Brewery IS NULL;


-- =============================================================================
-- PART 3 – DATA CLEANING
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3.1 Handle ABV = 0 (treat as NULL / exclude from numeric analysis)
-- Author: Zachary M
-- -----------------------------------------------------------------------------

/*
Rather than deleting rows, we create a cleaned view so the raw table
is preserved. Alternatively, for direct analysis we will use WHERE ABV > 0.

Example of the issue:
  SELECT Name, ABV FROM beers WHERE ABV = 0 LIMIT 5;
  Returns beers that clearly are not 0% alcohol (e.g., an IPA or Stout).
  0.0 is a sentinel for a missing value in the source CSV.
*/

-- Count how many rows are affected
SELECT COUNT(*) AS abv_is_zero
FROM beers
WHERE ABV = 0;

-- In all analysis queries we will filter with: WHERE ABV > 0
-- Example safe aggregate:
SELECT
    Style,
    ROUND(AVG(ABV), 2) AS avg_abv
FROM beers
WHERE ABV > 0
GROUP BY Style
ORDER BY avg_abv DESC
LIMIT 10;

-- -----------------------------------------------------------------------------
-- 3.2 Handle IBU = 0 on both columns
-- Author: Zachary M
-- -----------------------------------------------------------------------------

/*
Some rows have Min IBU = 0 AND Max IBU = 0. For most beer styles this is
implausible. We treat these as missing and exclude them from IBU-based analysis.
We use a computed midpoint IBU for convenience:
  IBU_mid = (Min IBU + Max IBU) / 2
*/

SELECT
    Name,
    Style,
    `Min IBU`,
    `Max IBU`,
    (`Min IBU` + `Max IBU`) / 2 AS IBU_mid
FROM beers
WHERE `Min IBU` > 0 OR `Max IBU` > 0
LIMIT 20;


-- -----------------------------------------------------------------------------
-- 3.3 Normalize text columns to consistent casing
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

/*
Style and Brewery names may have inconsistent capitalization. We inspect
whether any obvious inconsistencies exist. We do NOT alter the table here
(no UPDATE) but flag anything found and use UPPER()/LOWER() in queries
where needed.
*/

-- Check for mixed-case variants of the same style name
SELECT DISTINCT Style
FROM beers
ORDER BY Style
LIMIT 50;

-- Example: if 'ipa' and 'IPA' and 'Ipa' all exist, UPPER() fixes comparisons
SELECT
    UPPER(Style) AS style_upper,
    COUNT(*) AS count
FROM beers
GROUP BY style_upper
ORDER BY count DESC
LIMIT 20;


-- -----------------------------------------------------------------------------
-- 3.4 Flag low-review beers (unreliable average scores)
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

/*
A beer with 2 reviews has an average score that carries far less statistical
weight than a beer with 500 reviews. We define a threshold of 20 reviews
as the minimum for "reliable" ratings in our analysis.

Number of beers below threshold:
*/
SELECT
    SUM(CASE WHEN number_of_reviews < 20  THEN 1 ELSE 0 END) AS under_20_reviews,
    SUM(CASE WHEN number_of_reviews >= 20 THEN 1 ELSE 0 END) AS reliable_reviews,
    COUNT(*) AS total
FROM beers;

/*
In Part 5 analysis queries we will add: WHERE number_of_reviews >= 20
to ensure results reflect meaningful consensus rather than outlier noise.
*/


-- -----------------------------------------------------------------------------
-- 3.5 Inspect the Description column for noise
-- Author: Zachary M
-- -----------------------------------------------------------------------------

-- Descriptions contain raw tab characters (\t) imported from HTML.
-- We won't clean the column but flag that it is not usable for string
-- matching without preprocessing.

SELECT
    Name,
    CHAR_LENGTH(Description) AS desc_length,
    -- Check for rows with very short or empty descriptions
    CASE
        WHEN Description IS NULL        THEN 'NULL'
        WHEN TRIM(Description) = ''     THEN 'EMPTY'
        WHEN CHAR_LENGTH(Description) < 10 THEN 'TOO SHORT'
        ELSE 'OK'
    END AS desc_status
FROM beers
GROUP BY desc_status, Name, Description
ORDER BY desc_length ASC
LIMIT 20;

-- Count of each status
SELECT
    CASE
        WHEN Description IS NULL           THEN 'NULL'
        WHEN TRIM(Description) = ''        THEN 'EMPTY'
        WHEN CHAR_LENGTH(Description) < 10 THEN 'TOO SHORT'
        ELSE 'OK'
    END AS desc_status,
    COUNT(*) AS count
FROM beers
GROUP BY desc_status;


-- -----------------------------------------------------------------------------
-- 3.6 Create a cleaned working view (preserves raw table)
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

/*
This view applies all cleaning rules at once so analysis queries can
reference beers_clean instead of writing WHERE clauses every time.
*/

CREATE OR REPLACE VIEW beers_clean AS
SELECT
    Name,
    UPPER(Style)   AS Style,
    Brewery,
    `Beer Name (Full)`,
    ABV,
    `Min IBU`,
    `Max IBU`,
    (`Min IBU` + `Max IBU`) / 2                      AS IBU_mid,
    Astringency, Body, Alcohol, Bitter, Sweet, Sour,
    Salty, Fruits, Hoppy, Spices, Malty,
    review_aroma,
    review_appearance,
    review_palate,
    review_taste,
    review_overall,
    number_of_reviews,
    -- Composite reliability flag
    CASE WHEN number_of_reviews >= 20 THEN 1 ELSE 0 END AS reliable
FROM beers
WHERE ABV > 0                             -- exclude suspected missing ABV
  AND NOT (`Min IBU` = 0 AND `Max IBU` = 0); -- exclude suspected missing IBU

-- Verify the view
SELECT COUNT(*) AS clean_rows FROM beers_clean;
SELECT * FROM beers_clean LIMIT 5;


-- =============================================================================
-- PART 4 – JOIN STRATEGY
-- =============================================================================

/*
Our data analysys  consists of a there tables (beers / beers_clean / bjcp_styles_clean). There is no
second external table to JOIN against SO FAR. However, we still use JOIN-like
constructs in two meaningful ways:


(A) SELF-JOIN: comparing each beer against the average of its own style.
    This is equivalent to a JOIN of the table against a GROUP BY subquery
    on the same table.

(B) DERIVED TABLE (inline view / subquery JOIN): we compute aggregated
    summaries (e.g., style-level averages) in a subquery and JOIN them
    back to individual beer rows to enable per-beer vs. per-style comparison.

We use INNER JOIN semantics throughout — we only want beers that have a
matching style aggregate (which all rows will, since the aggregate is derived
from the same table).

If in a future milestone we add a second dataset (e.g., a brewing regions
lookup table or a Ratebeer dataset), we would use a LEFT JOIN so that
beers without a matching region are still included in the analysis.
*/

-- (A) Self-join style: each beer vs. its style average
-- Author: Zachary M
SELECT
    b.Name,
    b.Style,
    b.review_overall                            AS beer_rating,
    style_avg.avg_overall                       AS style_avg_rating,
    ROUND(b.review_overall - style_avg.avg_overall, 3) AS delta_vs_style
FROM beers_clean b
INNER JOIN (
    SELECT
        Style,
        ROUND(AVG(review_overall), 3) AS avg_overall
    FROM beers_clean
    WHERE reliable = 1
    GROUP BY Style
) AS style_avg
ON b.Style = style_avg.Style
WHERE b.reliable = 1
ORDER BY delta_vs_style DESC
LIMIT 20;

/*
This INNER JOIN returns only beers whose Style exists in the derived
aggregate — which is every row, since the subquery is built from the same
table. Result: we see which individual beers most exceed their style average.

Example result interpretation:
  If an IPA beer has review_overall = 4.5 and avg_overall for IPA = 3.8,
  delta_vs_style = +0.7, meaning it outperforms its category by 0.7 points.
*/


-- (B) Brewery-level join: each beer vs. its brewery average
-- Author: Plinio Durango
SELECT
    b.Name,
    b.Brewery,
    b.review_overall                              AS beer_rating,
    brewery_avg.avg_overall                       AS brewery_avg_rating,
    ROUND(b.review_overall - brewery_avg.avg_overall, 3) AS delta_vs_brewery
FROM beers_clean b
INNER JOIN (
    SELECT
        Brewery,
        ROUND(AVG(review_overall), 3) AS avg_overall,
        COUNT(*) AS beers_in_portfolio
    FROM beers_clean
    WHERE reliable = 1
    GROUP BY Brewery
    HAVING beers_in_portfolio >= 3  -- only breweries with at least 3 rated beers
) AS brewery_avg
ON b.Brewery = brewery_avg.Brewery
WHERE b.reliable = 1
ORDER BY delta_vs_brewery DESC
LIMIT 20;


-- =============================================================================
-- PART 5 – DRAFT ANALYSIS QUERIES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ANALYSIS 1: Which beer styles have the highest average overall rating?
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

/*
Draft insight: We expect styles like American Wild Ale, Quadrupel, and
Imperial Stout to rank near the top, as they are typically specialty beers
reviewed by enthusiasts.
*/

SELECT
    Style,
    COUNT(*)                             AS beer_count,
    ROUND(AVG(review_overall), 3)        AS avg_overall,
    ROUND(AVG(review_taste), 3)          AS avg_taste,
    ROUND(AVG(review_aroma), 3)          AS avg_aroma,
    ROUND(AVG(number_of_reviews), 0)     AS avg_n_reviews
FROM beers_clean
WHERE reliable = 1
GROUP BY Style
HAVING beer_count >= 5   -- only styles with at least 5 beers in dataset
ORDER BY avg_overall DESC
LIMIT 15;
-- Yess!! Our predictions were correct, we found Wild Ale and Imperial
-- both near the top.


-- -----------------------------------------------------------------------------
-- ANALYSIS 2: Which breweries are the most consistently highly rated?
-- Author: Zachary M
-- -----------------------------------------------------------------------------

/*
A brewery with avg_overall = 4.2 AND rating_range = 0.3 is more consistent
than one with avg_overall = 4.2 AND rating_range = 1.5.
We sort by avg_overall DESC, then rating_range ASC to surface the most
consistently excellent breweries.
*/

SELECT
    Brewery,
    COUNT(*)                              AS beers_in_portfolio,
    ROUND(AVG(review_overall), 3)         AS avg_overall,
    ROUND(MIN(review_overall), 3)         AS min_rating,
    ROUND(MAX(review_overall), 3)         AS max_rating,
    ROUND(MAX(review_overall)
          - MIN(review_overall), 3)       AS rating_range  -- consistency metric
FROM beers_clean
WHERE reliable = 1
GROUP BY Brewery
HAVING beers_in_portfolio >= 5
ORDER BY avg_overall DESC, rating_range ASC
LIMIT 20;



-- -----------------------------------------------------------------------------
-- ANALYSIS 3: Does ABV correlate with review_overall?
-- Author: Zachary M
-- -----------------------------------------------------------------------------

/*
Draft hypothesis: Higher-ABV beers (barleywines, imperial stouts) tend to
receive higher ratings on BeerAdvocate because enthusiast reviewers favor
complex, high-gravity styles. We will test this with the bucketed averages.
*/
-- Bucket ABV into ranges and check average ratings per bucket
SELECT
    CASE
        WHEN ABV < 4  THEN 'Under 4%'
        WHEN ABV < 6  THEN '4–6%'
        WHEN ABV < 8  THEN '6–8%'
        WHEN ABV < 10 THEN '8–10%'
        WHEN ABV < 14 THEN '10–14%'
        ELSE '14%+'
    END                                    AS abv_bucket,
    COUNT(*)                               AS beer_count,
    ROUND(AVG(review_overall), 3)          AS avg_overall,
    ROUND(AVG(review_taste), 3)            AS avg_taste
FROM beers_clean
WHERE reliable = 1
GROUP BY abv_bucket
ORDER BY MIN(ABV);




-- -----------------------------------------------------------------------------
-- ANALYSIS 4: Do high-IBU beers score better/worse on review_taste?
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

/*
We expect the Bitter flavor attribute score to rise as IBU increases,
which would validate that the flavor scores are internally consistent with
the chemistry data (IBU = iso-alpha acids = bitterness perception).
*/

SELECT
    CASE
        WHEN IBU_mid < 20  THEN 'Low (< 20 IBU)'
        WHEN IBU_mid < 40  THEN 'Medium (20–40 IBU)'
        WHEN IBU_mid < 60  THEN 'High (40–60 IBU)'
        WHEN IBU_mid < 80  THEN 'Very High (60–80 IBU)'
        ELSE 'Extreme (80+ IBU)'
    END                                    AS ibu_bucket,
    COUNT(*)                               AS beer_count,
    ROUND(AVG(review_taste), 3)            AS avg_taste,
    ROUND(AVG(review_overall), 3)          AS avg_overall,
    ROUND(AVG(Bitter), 1)                  AS avg_bitter_score
FROM beers_clean
WHERE reliable = 1
GROUP BY ibu_bucket
ORDER BY MIN(IBU_mid);


-- -----------------------------------------------------------------------------
-- ANALYSIS 5: What flavor profile predicts a high overall rating?
-- Author: Zachary M
-- -----------------------------------------------------------------------------

/*
We split beers into "top-rated" (review_overall >= 4.0) vs
"average/below" (review_overall < 4.0) and compare mean flavor scores.
*/

SELECT
    CASE
        WHEN review_overall >= 4.0 THEN 'Top-rated (≥ 4.0)'
        ELSE 'Below 4.0'
    END                              AS rating_tier,
    COUNT(*)                         AS beer_count,
    ROUND(AVG(Hoppy),   1)           AS avg_hoppy,
    ROUND(AVG(Malty),   1)           AS avg_malty,
    ROUND(AVG(Sweet),   1)           AS avg_sweet,
    ROUND(AVG(Bitter),  1)           AS avg_bitter,
    ROUND(AVG(Body),    1)           AS avg_body,
    ROUND(AVG(Fruits),  1)           AS avg_fruits,
    ROUND(AVG(Sour),    1)           AS avg_sour
FROM beers_clean
WHERE reliable = 1
GROUP BY rating_tier;

/*
Draft insight: If top-rated beers show notably higher Body, Malty, and
Hoppy scores compared to below-4.0 beers, it suggests complexity and
balance are rewarded by reviewers more than any single flavor extreme.
*/


-- -----------------------------------------------------------------------------
-- ANALYSIS 6: Review volume vs. rating – does popularity signal quality?
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

SELECT
    CASE
        WHEN number_of_reviews < 50   THEN 'Niche (< 50)'
        WHEN number_of_reviews < 200  THEN 'Known (50–199)'
        WHEN number_of_reviews < 500  THEN 'Popular (200–499)'
        ELSE 'Widely reviewed (500+)'
    END                                    AS popularity_tier,
    COUNT(*)                               AS beer_count,
    ROUND(AVG(review_overall), 3)          AS avg_overall,
    ROUND(AVG(review_taste), 3)            AS avg_taste
FROM beers_clean
GROUP BY popularity_tier
ORDER BY MIN(number_of_reviews);

/*
If widely-reviewed beers have higher avg_overall, it could mean:
  (a) Quality drives word-of-mouth and review volume, OR
  (b) Survivor bias: popular beers attract enthusiast reviewers who rate
      generously, inflating the average.
This is one of the open questions this data raises but cannot fully answer.
*/


-- -----------------------------------------------------------------------------
-- ANALYSIS 7: Top beers within each style (window function approach)
-- Author: Zachary M
-- -----------------------------------------------------------------------------

SELECT *
FROM (
    SELECT
        Name,
        Brewery,
        Style,
        review_overall,
        number_of_reviews,
        RANK() OVER (
            PARTITION BY Style
            ORDER BY review_overall DESC
        ) AS style_rank
    FROM beers_clean
    WHERE reliable = 1
) AS ranked
WHERE style_rank <= 3
ORDER BY Style, style_rank;

/*
This gives us the top 3 beers per style by overall rating.
Useful for building a "best in class" recommendation list in Part 3
of the project.
*/


-- -----------------------------------------------------------------------------
-- ANALYSIS 8: Brewery diversity – do breweries that make more styles
--             achieve better average ratings?
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------

SELECT
    Brewery,
    COUNT(DISTINCT Style)                  AS style_diversity,
    COUNT(*)                               AS total_beers,
    ROUND(AVG(review_overall), 3)          AS avg_overall
FROM beers_clean
WHERE reliable = 1
GROUP BY Brewery
HAVING total_beers >= 3
ORDER BY style_diversity DESC, avg_overall DESC
LIMIT 25;

/*
Draft hypothesis: Breweries with high style diversity (e.g., > 5 different
styles) might have lower consistency since they spread across many categories,
but it is also possible that versatile breweries are simply excellent across
the board.
*/

-- =============================================================================
-- END OF FILE
-- =============================================================================

-- =============================================================================
-- BSD 200 | Final Project – Part 3 SQL Additions
-- Authors  : Plinio Durango | Zachary M
-- =============================================================================
-- PART 6  – German Tank Problem: normalizing flavor attributes
-- PART 7  – Completed analysis queries
-- =============================================================================

USE final_project;

-- =============================================================================
-- PART 6 – GERMAN TANK NORMALIZATION
-- Author: Plinio Durango
-- =============================================================================

/*
BACKGROUND
----------
The German Tank Problem is a statistical technique developed during WWII.
Allied analysts needed to estimate how many tanks Germany had produced,
using only the serial numbers they observed on captured tanks.

The key insight: if you observe n tanks with serial numbers up to M (the max),
the best unbiased estimate of the true total population N is:

    N_estimated = M * (n + 1) / n  -  1

In our dataset the flavor/mouthfeel columns (Astringency, Body, Bitter,
Sweet, Sour, Salty, Fruits, Hoppy, Spices, Malty, Alcohol) are raw word
counts extracted from beer descriptions. Each column has a different natural
ceiling — Malty can reach 239 while Salty barely reaches 48 — making direct
comparison impossible.

We apply the German Tank estimator to infer the "true maximum" for each
attribute, then divide every beer's score by that estimate to normalize to 0–1.

Filter: only beers with > 25 reviews are used (reliable ratings).
*/

-- Step 6.1: Compute observed maximums and sample size
-- Author: Plinio Durango
SELECT
    COUNT(*)                AS n_beers,
    MAX(Astringency)        AS max_astringency,
    MAX(Body)               AS max_body,
    MAX(Alcohol)            AS max_alcohol,
    MAX(Bitter)             AS max_bitter,
    MAX(Sweet)              AS max_sweet,
    MAX(Sour)               AS max_sour,
    MAX(Salty)              AS max_salty,
    MAX(Fruits)             AS max_fruits,
    MAX(Hoppy)              AS max_hoppy,
    MAX(Spices)             AS max_spices,
    MAX(Malty)              AS max_malty
FROM beers
WHERE number_of_reviews > 25
  AND ABV > 0
  AND NOT (`Min IBU` = 0 AND `Max IBU` = 0);

/*
From these results we can manually compute each German Tank estimate:
  N_est = max_observed * (n + 1) / n  -  1

For example, if n = 1800 and max_malty = 239:
  N_est_malty = 239 * (1801 / 1800) - 1 = 239.13 - 1 = 238.13

The adjustment is small for large n (which is why it matters more for
small samples — just like the original tank problem).
*/

-- Step 6.2: Apply normalization in a derived table (inline view)
-- Author: Plinio Durango
-- We use a subquery to first get the stats, then divide each beer's value.

CREATE OR REPLACE VIEW beers_normalized AS
WITH stats AS (
    SELECT
        COUNT(*)            AS n,
        MAX(Astringency)    AS m_astringency,
        MAX(Body)           AS m_body,
        MAX(Alcohol)        AS m_alcohol,
        MAX(Bitter)         AS m_bitter,
        MAX(Sweet)          AS m_sweet,
        MAX(Sour)           AS m_sour,
        MAX(Salty)          AS m_salty,
        MAX(Fruits)         AS m_fruits,
        MAX(Hoppy)          AS m_hoppy,
        MAX(Spices)         AS m_spices,
        MAX(Malty)          AS m_malty
    FROM beers
    WHERE number_of_reviews > 25
      AND ABV > 0
      AND NOT (`Min IBU` = 0 AND `Max IBU` = 0)
)
SELECT
    b.Name,
    b.Style,
    b.Brewery,
    b.ABV,
    (`Min IBU` + `Max IBU`) / 2                                         AS IBU_mid,
    b.review_overall,
    b.review_taste,
    b.review_aroma,
    b.number_of_reviews,
    -- German Tank normalized scores (0 to 1)
    ROUND(b.Astringency / (s.m_astringency * (s.n+1)/s.n), 4)     AS astringency_norm,
    ROUND(b.Body        / (s.m_body        * (s.n+1)/s.n), 4)     AS body_norm,
    ROUND(b.Alcohol     / (s.m_alcohol     * (s.n+1)/s.n), 4)     AS alcohol_norm,
    ROUND(b.Bitter      / (s.m_bitter      * (s.n+1)/s.n ), 4)     AS bitter_norm,
    ROUND(b.Sweet       / (s.m_sweet       * (s.n+1)/s.n), 4)     AS sweet_norm,
    ROUND(b.Sour        / (s.m_sour        * (s.n+1)/s.n), 4)     AS sour_norm,
    ROUND(b.Salty       / (s.m_salty       * (s.n+1)/s.n), 4)     AS salty_norm,
    ROUND(b.Fruits      / (s.m_fruits      * (s.n+1)/s.n), 4)     AS fruits_norm,
    ROUND(b.Hoppy       / (s.m_hoppy       * (s.n+1)/s.n), 4)     AS hoppy_norm,
    ROUND(b.Spices      / (s.m_spices      * (s.n+1)/s.n), 4)     AS spices_norm,
    ROUND(b.Malty       / (s.m_malty       * (s.n+1)/s.n), 4)     AS malty_norm
FROM beers b
CROSS JOIN stats s
WHERE b.number_of_reviews > 25
  AND b.ABV > 0
  AND NOT (b.`Min IBU` = 0 AND b.`Max IBU` = 0);

-- Verify the view
SELECT * FROM beers_normalized;

/*
Each normalized column now ranges 0–1 where 1 means the beer scores at the
estimated true maximum for that attribute. This makes cross-attribute
comparisons valid for the first time.
*/


-- =============================================================================
-- PART 7 – COMPLETED ANALYSIS QUERIES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ANALYSIS 1: Top styles by average rating
-- Author: Zachary M
-- -----------------------------------------------------------------------------
SELECT
    Style,
    COUNT(*)                             AS beer_count,
    ROUND(AVG(review_overall), 3)        AS avg_overall,
    ROUND(AVG(review_taste),   3)        AS avg_taste,
    ROUND(AVG(review_aroma),   3)        AS avg_aroma
FROM beers_normalized
GROUP BY Style
HAVING beer_count >= 5
ORDER BY avg_overall DESC
LIMIT 15;

/*
Expected finding: Specialty styles like American Wild Ale, Quadrupel, and
Imperial Stout dominate the top of the list. These are complex, high-effort
beers typically reviewed by enthusiasts — which creates a selection bias
toward higher scores. This is one of the data limitations we flag in the paper.
*/


-- -----------------------------------------------------------------------------
-- ANALYSIS 2: Brewery consistency using normalized view
-- Author: Zachary M
-- -----------------------------------------------------------------------------
SELECT
    Brewery,
    COUNT(*)                                      AS beers_in_portfolio,
    ROUND(AVG(review_overall), 3)                 AS avg_overall,
    ROUND(MIN(review_overall), 3)                 AS worst_beer,
    ROUND(MAX(review_overall), 3)                 AS best_beer,
    ROUND(MAX(review_overall) - MIN(review_overall), 3) AS rating_range
FROM beers_normalized
GROUP BY Brewery
HAVING beers_in_portfolio >= 3
ORDER BY avg_overall DESC, rating_range ASC
LIMIT 20;

/*
A brewery with avg_overall = 4.3 and rating_range = 0.2 is far more
trustworthy than one with avg_overall = 4.3 and rating_range = 1.4.
The dual sort (high avg, low range) surfaces the most reliable producers.
*/


-- -----------------------------------------------------------------------------
-- ANALYSIS 3: ABV buckets vs. average rating
-- Author: Plinio Durango
-- -----------------------------------------------------------------------------
SELECT
    CASE
        WHEN ABV < 4  THEN '1. Under 4%'
        WHEN ABV < 6  THEN '2. 4 to 6%'
        WHEN ABV < 8  THEN '3. 6 to 8%'
        WHEN ABV < 10 THEN '4. 8 to 10%'
        WHEN ABV < 14 THEN '5. 10 to 14%'
        ELSE               '6. 14% and above'
    END                                    AS abv_bucket,
    COUNT(*)                               AS beer_count,
    ROUND(AVG(review_overall), 3)          AS avg_overall,
    ROUND(AVG(review_taste),   3)          AS avg_taste
FROM beers_normalized
GROUP BY abv_bucket
ORDER BY abv_bucket;

/*
This query directly tests the "stronger = better" hypothesis.
If avg_overall increases with each ABV bucket, the hypothesis holds.
*/


-- -----------------------------------------------------------------------------
-- ANALYSIS 4: Flavor profile of top-rated vs. below-average beers
-- Author: Plinio Durango
-- (Uses normalized scores so the comparison is valid across attributes)
-- -----------------------------------------------------------------------------
SELECT
    CASE
        WHEN review_overall >= 4.0 THEN 'Top-rated (>= 4.0)'
        ELSE                            'Below 4.0'
    END                                  AS rating_tier,
    COUNT(*)                             AS beer_count,
    ROUND(AVG(hoppy_norm),       3)      AS avg_hoppy,
    ROUND(AVG(malty_norm),       3)      AS avg_malty,
    ROUND(AVG(sweet_norm),       3)      AS avg_sweet,
    ROUND(AVG(bitter_norm),      3)      AS avg_bitter,
    ROUND(AVG(body_norm),        3)      AS avg_body,
    ROUND(AVG(fruits_norm),      3)      AS avg_fruits,
    ROUND(AVG(sour_norm),        3)      AS avg_sour,
    ROUND(AVG(astringency_norm), 3)      AS avg_astringency
FROM beers_normalized
GROUP BY rating_tier;

/*
The normalized scores allow direct comparison: if top-rated beers show
body_norm = 0.42 vs. 0.31 for below-average beers, we can say top-rated
beers score 35% higher on body — a meaningful, interpretable difference.
Without normalization this comparison would be distorted by each column's
different raw scale.
*/


-- -----------------------------------------------------------------------------
-- ANALYSIS 5: IBU range vs. review scores
-- Author: Zachary M
-- -----------------------------------------------------------------------------
SELECT
    CASE
        WHEN IBU_mid < 20  THEN '1. Low    (< 20 IBU)'
        WHEN IBU_mid < 40  THEN '2. Medium (20-40 IBU)'
        WHEN IBU_mid < 60  THEN '3. High   (40-60 IBU)'
        WHEN IBU_mid < 80  THEN '4. Very High (60-80 IBU)'
        ELSE                    '5. Extreme   (80+ IBU)'
    END                                    AS ibu_bucket,
    COUNT(*)                               AS beer_count,
    ROUND(AVG(review_taste),   3)          AS avg_taste,
    ROUND(AVG(review_overall), 3)          AS avg_overall,
    ROUND(AVG(bitter_norm),    3)          AS avg_bitter_norm
FROM beers_normalized
GROUP BY ibu_bucket
ORDER BY ibu_bucket;

/*
We expect avg_bitter_norm to increase with IBU, which would validate that
the word-count flavor scores are consistent with the chemical bitterness
measurement (IBU). If they track together, it gives us more confidence in
the flavor attribute data quality.
*/


-- -----------------------------------------------------------------------------
-- ANALYSIS 6: Top 3 beers per style (window function)
-- Author: Zachary M
-- -----------------------------------------------------------------------------
WITH sub1 AS (
SELECT *
FROM (
    SELECT
        Name,
        Brewery,
        Style,
        review_overall,
        number_of_reviews,
        RANK() OVER (
            PARTITION BY Style
            ORDER BY review_overall DESC
        ) AS style_rank
    FROM beers_normalized
) AS ranked
WHERE style_rank <= 3
ORDER BY Style, style_rank
) 
SELECT * 
FROM sub1 
WHERE number_of_reviews > 300 and
	review_overall > 4
ORDER BY number_of_reviews DESC;

/*
This produces a "best in class" table — the top 3 beers per style
by overall rating among beers with > 25 reviews. Useful for the
presentation's storytelling: we can call out specific beers by name
as examples of what excellence looks like in each category.
*/


-- -----------------------------------------------------------------------------
-- ANALYSIS 7: Do beers that excel in multiple flavor dimensions score higher?
-- Author: Plinio Durango
-- (Flavor complexity score = sum of all normalized flavor attributes)
-- -----------------------------------------------------------------------------
SELECT
    Name,
    Brewery,
    Style,
    review_overall,
    ROUND(
        hoppy_norm + malty_norm + sweet_norm + bitter_norm +
        body_norm + fruits_norm + sour_norm + spices_norm +
        astringency_norm + alcohol_norm + salty_norm,
    3)                             AS flavor_complexity_score,
    number_of_reviews
FROM beers_normalized
ORDER BY flavor_complexity_score DESC
LIMIT 20;

/*
The 'flavor_complexity_score' is the sum of all 11 normalized attributes.
A high score means the beer has strong representation across many flavor
dimensions simultaneously. We can correlate this with review_overall to
test whether complexity is rewarded by reviewers — and whether it is
better to excel in one dimension or be balanced across many.
*/


-- -----------------------------------------------------------------------------
-- ANALYSIS 8: BJCP join — is each beer true to its style?
-- Author: Plinio Durango
-- Compares actual ABV to the BJCP expected range for that style
-- -----------------------------------------------------------------------------
SELECT
    b.Name,
    b.Style,
    b.ABV                                           AS actual_abv,
    s.abv_low                                       AS bjcp_abv_low,
    s.abv_high                                      AS bjcp_abv_high,
    b.IBU_mid                                       AS actual_ibu_mid,
    s.ibu_low                                       AS bjcp_ibu_low,
    s.ibu_high                                      AS bjcp_ibu_high,
    CASE
        WHEN b.ABV BETWEEN s.abv_low AND s.abv_high THEN 'Within range'
        WHEN b.ABV < s.abv_low                       THEN 'Below style'
        ELSE                                              'Above style'
    END                                             AS abv_conformity,
    CASE
        WHEN b.IBU_mid BETWEEN s.ibu_low AND s.ibu_high THEN 'Within range'
        WHEN b.IBU_mid < s.ibu_low                       THEN 'Below style'
        ELSE                                                   'Above style'
    END                                             AS ibu_conformity,
    b.review_overall
FROM beers_normalized b
JOIN bjcp_styles_clean s
  ON b.Style LIKE CONCAT('%', s.style_name, '%')
  OR s.style_name LIKE CONCAT('%', SUBSTRING_INDEX(b.Style, ' - ', 1), '%')
ORDER BY b.review_overall DESC
LIMIT 40;

/*
This is the core analysis enabled by having two tables. We can now ask:
  - Do beers that stay within their BJCP style guidelines score better?
  - Are 'above style' beers (higher ABV or IBU than expected) rewarded
    or penalized by reviewers?
  - Are there styles where most beers deviate from the official guidelines?
*/

-- Summary version: conformity rate per style
SELECT
    abv_conformity,
    COUNT(*)                               AS beer_count,
    ROUND(AVG(review_overall), 3)          AS avg_rating
FROM (
    SELECT
        b.review_overall,
        CASE
            WHEN b.ABV BETWEEN s.abv_low AND s.abv_high THEN 'Within range'
            WHEN b.ABV < s.abv_low                       THEN 'Below style'
            ELSE                                              'Above style'
        END AS abv_conformity
    FROM beers_normalized b
    JOIN bjcp_styles_clean s
      ON b.Style LIKE CONCAT('%', s.style_name, '%')
      OR s.style_name LIKE CONCAT('%', SUBSTRING_INDEX(b.Style, ' - ', 1), '%')
) AS conformity_table
GROUP BY abv_conformity
ORDER BY avg_rating DESC;

-- =============================================================================
-- END OF PART 3 SQL ADDITIONS
-- =============================================================================

