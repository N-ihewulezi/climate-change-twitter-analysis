# Climate Change Twitter Sentiment Analysis
### End-to-End Data Analysis | PostgreSQL · Power BI

![Dashboard Preview](images/executive_overview.png)
<img width="2935" height="1615" alt="image" src="https://github.com/user-attachments/assets/7dc329fd-8196-4927-9188-8488011f9bb2" />

---

## Project Overview

A complete end-to-end data analysis pipeline built for a climate research 
organisation tracking global public opinion on climate change. The project 
analyses **15,789,411 tweets** spanning **14 years (2006–2019)** to answer 
two core leadership questions:

1. How have public sentiment and climate change stance shifted over 14 years?
2. Which topics and regions are driving the most divisive or aggressive discourse?
3. How do believers and deniers differ behaviorally?
4. Is there any relationship between temperature anomalies and online sentiment?
5. Which topics dominated climate discussions across different years?

---

## Tools & Technologies

| Tool | Purpose |
|------|---------|
| PostgreSQL 18 | Data ingestion, cleaning, transformation, analytics |
| pgAdmin 4 | Query execution and database management |
| Power BI Desktop | Dashboard development |
| Power BI Service | Dashboard publishing |

---

## Dataset

**The Climate Change Twitter Dataset**  
Source: Mendeley Data  
DOI: https://doi.org/10.17632/mw8yd7z9wc.2  
Rows: 15,789,411 tweets  
Period: 2006 – 2019  
Columns: timestamp, coordinates, topic, sentiment, stance, gender, 
temperature deviation, aggressiveness

---

## Project Structure

```
climate-change-twitter-analysis/
├── sql/
│   └── climate_analysis.sql      # Complete SQL script (all 6 phases)
├── report/
│   └── Analysis_Report.pdf       # Full written report with findings
├── dashboard/
│   └── climate_analysis.pbix     # Power BI dashboard file
└── images/
    ├── executive_overview.png
    ├── topic_analysis.png
    ├── regional_analysis.png
    └── demographics_aggressiveness.png
```

---

## Pipeline Architecture

```
Raw CSV (15.7M rows)
       ↓
PostgreSQL Staging Table (raw_tweets)
       ↓
Data Quality Audit (Phase 2)
       ↓
Clean Typed Table (clean_tweets)
       ↓
12 Analytical Views
       ↓
Power BI Dashboard (4 pages)
```

---

## Key Findings

### 1. Dramatic Stance Shift Over 14 Years
- Climate change **believers grew from 16.7% in 2006 to 79.4% in 2018**
- Deniers declined from 14.3% peak in 2010 to 6.2% in 2018
- The **Paris Agreement (2015)** was the single biggest turning point

### 2. Most Divisive Topics
| Topic | Divisiveness Score | Aggression Rate |
|-------|--------------------|-----------------|
| Donald Trump vs Science | 0.57 | 40.3% |
| Weather Extremes | 0.42 | 24.3% |
| Ideological Positions on Global Warming | 0.36 | 34.9% |
| Politics | 0.15 | 43.4% |

### 3. Regional Patterns
- **North America** dominates with 65% of geotagged tweets
- Most aggressive region at **31.8%**
- North America + Politics = most aggressive combination (45.8%)

### 4. Correlation Analysis
| Variables | Pearson r | Interpretation |
|-----------|-----------|----------------|
| Sentiment vs Aggressiveness | -0.16 | Moderate negative |
| Temperature vs Sentiment | +0.02 | Near zero |
| Temperature vs Aggressiveness | -0.01 | No relationship |

### 5. Demographics
- **Deniers are 56% more aggressive** than Believers (42.7% vs 27.3%)
- Aggressiveness declined from **35% in 2007 to 24% in 2019**
- Summer is the most aggressive season (31.1%)

---

## Dashboard

The interactive dashboard contains 4 pages:

### Page 1 — Executive Overview
![Executive Overview](images/executive_overview.png)
<img width="2935" height="1615" alt="image" src="https://github.com/user-attachments/assets/33a4cf21-807e-486c-b562-19c213a89de7" />


### Page 2 — Topic Analysis
![Topic Analysis](images/topic_analysis.png)
<img width="2820" height="1567" alt="image" src="https://github.com/user-attachments/assets/d75e2b91-f2a4-4bf7-a2f6-6bd8e825f984" />


### Page 3 — Regional Analysis
![Regional Analysis](images/regional_analysis.png)
<img width="1865" height="1617" alt="image" src="https://github.com/user-attachments/assets/4a5096d3-4723-42b8-bd1b-e9e86ead5b0f" />


### Page 4 — Demographics & Aggressiveness
![Demographics](images/demographics_aggressiveness.png)
<img width="2835" height="1622" alt="image" src="https://github.com/user-attachments/assets/26cae273-1eae-469f-b40d-39a1e40a56ea" />


---

## SQL Script Structure

```sql
-- PHASE 1: Raw data ingestion
-- PHASE 2: Data quality audit (15+ audit queries)
-- PHASE 3: Data cleaning and transformation
-- PHASE 4: 12 analytical views for Power BI
-- PHASE 5: Descriptive analytics queries
-- PHASE 6: Diagnostic analytics queries
```

---

## Data Quality Summary

| Column | Issue Found | Resolution |
|--------|-------------|------------|
| lat / lng | 66.4% blank | NULL-ified; continent derived |
| lng | 2 scientific notation values | Cast correctly via NUMERIC |
| temperature_avg | 37 scientific notation values | Cast correctly via NUMERIC |
| gender | 3.7% 'undefined' | Mapped to 'Unknown' |
| created_at | Text format | Cast to TIMESTAMPTZ |
| duplicates | 0 found | No action needed |

---

## How to Run This Project

### PostgreSQL Setup
1. Install PostgreSQL 18
2. Create database: `CREATE DATABASE climate_analysis;`
3. Download dataset from Mendeley DOI above
4. Update file path in `sql/climate_analysis.sql` Phase 1
5. Run the SQL script phase by phase

### Power BI Setup
1. Install Power BI Desktop
2. Install Npgsql driver
3. Connect to `localhost:5433` database `climate_analysis`
4. Load all 12 views
5. Open `dashboard/climate_analysis.pbix`

---

## Recommendations

1. Target counter-messaging campaigns at **North America**
2. Leverage high-profile policy events like the **Paris Agreement**
3. Focus moderation on **Denier communities** (56% more aggressive)
4. Monitor **Donald Trump vs Science** as a high-risk topic
5. Invest in **opinion-led communication** not weather-event reporting
6. Highlight the **positive long-term aggressiveness decline** in policy briefs

---

## References

Effrosynidis, D., Karas, A., Sylaios, G., & Arampatzis, A. (2022).
*The Climate Change Twitter Dataset* (Version 2). Mendeley Data.
https://doi.org/10.17632/mw8yd7z9wc.2

---

## Author

**Nkechi Ihewulezi**  
Data Analyst

[LinkedIn](https://www.linkedin.com/in/nkechi-ihewulezi/)
