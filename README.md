# BSDS Final Project — Beer Reviews Analysis

**Course:** BSDS 200 | **Authors:** Plinio Durango & Zachary M

---

## Overview

Beer is one of the most widely reviewed consumer products in the world, and this dataset sits at an interesting intersection of objective chemistry (ABV, IBU) and subjective taste perception (flavor scores, review ratings).

This project combines SQL-based exploratory analysis with Python visualizations to answer three core questions:

- Does higher bitterness (IBU) hurt or help overall ratings?
- Are certain breweries consistently outperforming their style peers?
- Do flavor descriptors (Hoppy, Malty, Sweet) actually predict review scores?

---

## Dataset

**Source:** [Beer Profile and Ratings Data Set — Kaggle](https://www.kaggle.com/datasets/ruthgn/beer-profile-and-ratings-data-set)

The dataset merges two public sources:
1. **BeerAdvocate** user reviews (scores + number of reviews)
2. A curated **beer profile** dataset with style, ABV, IBU ranges, and flavor-attribute scores derived from beer descriptions.

| Property | Value |
|---|---|
| Rows | 3,197 beers (one beer per row) |
| Columns | 25 |
| Unique identifier | (Name, Brewery) composite key |

### Key Columns

| Group | Columns |
|---|---|
| Identity | Name, Style, Brewery, Beer Name (Full), Description |
| Chemistry | ABV, Min IBU, Max IBU |
| Flavor scores | Astringency, Body, Alcohol, Bitter, Sweet, Sour, Salty, Fruits, Hoppy, Spices, Malty |
| Review scores | review_aroma, review_appearance, review_palate, review_taste, review_overall, number_of_reviews |

---

## Project Structure

```
BSDS_FinalProject/
├── final_project.sql              # SQL: EDA, data cleaning, joins & analysis queries
├── fp_part3.ipynb                 # Python notebook: visualizations & extended analysis
├── beer_presentation.pptx         # Final project presentation slides
├── Project 1 proposal.pdf         # Original project proposal
├── BSDS200_ProjectGuidelines.pdf  # Course project guidelines
└── README.md
```

---

## Methodology

### Data Cleaning (SQL)

A `beers_clean` view was created applying the following rules:

- Excluded rows where ABV = 0 (suspected missing values, not truly non-alcoholic)
- Excluded rows where both Min IBU = 0 and Max IBU = 0 (suspected missing IBU data)
- Computed IBU_mid = (Min IBU + Max IBU) / 2 as a single bitterness reference value
- Added a `reliable` flag: beers with number_of_reviews >= 20 are statistically reliable

### EDA Issues Found

1. BOM character prepended to Name in the first CSV row due to UTF-8 BOM encoding
2. Flavor attribute scores use an arbitrary scale (0-120), not the same 0-5 scale as review columns
3. Description column contains raw HTML escape characters from the source website
4. ABV = 0.0 for some rows likely represents missing data, not truly non-alcoholic beers
5. Min IBU = Max IBU = 0 for some rows may indicate missing IBU data
6. number_of_reviews ranges widely — low-review beers have unreliable average scores

---

## Analysis

### Analysis 1 — Best Beer Styles by Rating

Identified which styles achieve the highest average review_overall scores (styles with at least 5 beers and 20+ reviews per beer). Findings confirmed that specialty styles like **American Wild Ale** and **Imperial Stout** rank near the top.

### Analysis 2 — Most Consistently Rated Breweries

Ranked breweries by average overall rating combined with a **consistency metric** (max_rating - min_rating). A brewery with a tight rating range and a high average is considered more reliably excellent than one with a high average but high variance.

### Analysis 3 — ABV vs. Overall Rating

ABV was bucketed into ranges (<4%, 4-6%, 6-8%, 8-10%, 10-14%, 14%+) and average review scores were compared across buckets. Hypothesis confirmed: higher-ABV beers (barleywines, imperial stouts) tend to score higher because enthusiast reviewers favor complex, high-gravity styles.

### Analysis 4 — IBU (Bitterness) vs. Taste Score

IBU midpoint was bucketed (Low <20, Medium 20-40, High 40-60, Very High 60-80, Extreme 80+) and correlated with review_taste, review_overall, and the Bitter flavor attribute score to validate internal consistency between chemistry and perception data.

### Analysis 5 — Flavor Profile vs. High Ratings

Beers were split into **top-rated** (review_overall >= 4.0) vs. **below average** (< 4.0) and mean flavor scores (Hoppy, Malty, Sweet, Bitter, Body, Fruits, Sour) were compared across both groups to identify which flavor descriptors distinguish highly-rated beers.

### Join Strategy

- **Self-join:** each beer compared against the average rating of its own style (beer vs. style peer group)
- **Derived table join:** each beer compared against its brewery's average rating (beer vs. brewery portfolio), limited to breweries with at least 3 rated beers

---

## Tools & Technologies

| Tool | Purpose |
|---|---|
| MySQL | Data storage, EDA, cleaning, and analysis queries |
| Python (Jupyter Notebook) | Visualizations and extended analysis (Part 3) |
| pandas / matplotlib / seaborn | Data manipulation and plotting |
| PowerPoint | Final presentation |

---

## Authors

| Name | Contributions |
|---|---|
| **Plinio Durango** | EDA (steps 1-2), Analysis 1 (style ratings), Analysis 4 (IBU vs. taste), Brewery self-join |
| **Zachary M** | EDA (steps 3+), Analysis 2 (brewery consistency), Analysis 3 (ABV correlation), Analysis 5 (flavor profiles), Style self-join |
