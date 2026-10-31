# STAT 3660SEF Group Project

## Hong Kong University Summer Internship Supply, 2016–2026

This repository contains the research framework and SAS implementation for analysing the supply structure of summer internship opportunities available to university students in Hong Kong from 2016 to 2026.

The analysis is designed for public recruitment webpages, government announcements, recruitment-platform extracts, and manually curated CSV or Excel files. SAS is used for data import, cleaning, descriptive analysis, visualisation, modelling, and export of the clean analysis dataset.

## Research questions

1. How is summer internship supply distributed across Government, NGO, Private Enterprise, Large Chain, and Large Group sectors from 2016 to 2026?
2. How do sector shares, industry composition, paid opportunity rates, and reported stipends change over time?
3. Which factors, including sector, industry, location, and year, are associated with the probability that an internship is paid?

## Sector definitions

| Standard sector | Operational definition |
|---|---|
| Government | Government departments, Civil Service Bureau programmes, and other public-sector programmes |
| NGO | Social-welfare, environmental, youth, community, and charitable non-profit organisations |
| Private Enterprise | Ordinary private companies that are not classified as a large chain or large group |
| Large Chain | Large retail, restaurant, supermarket, and other chain-service employers |
| Large Group | Listed groups, banks, telecommunications companies, property groups, and other major corporations |

## Input data

Place the main source file at:

```text
data/intern_data.csv
```

The program also checks the optional files below and appends them when they exist:

```text
data/intern_data_source2.csv
data/intern_data_source3.csv
```

An input template is provided at `data/intern_data_template.csv`. Copy it to `data/intern_data.csv` and replace the synthetic rows with the collected observations. The expected columns are:

```text
Year,Sector,Industry,Company,Position,Paid,Stipend,Location,Collection_Date,Num_Positions
```

One row should represent one recruitment record. `Num_Positions` is optional. If it is missing, the program assigns a supply weight of 1 to that record.

The repository now includes a collected file at `data/intern_data.csv` with 537 deduplicated Hong Kong internship-related records. The collection combines two public structured sources:

- [HK Career Watch `jobs.json`](https://github.com/laier029/hk-career-watch/blob/main/jobs.json), which preserves employer or job-board source URLs, posting dates where available, and first-seen dates when a posting date is unavailable.
- [Workopia Hong Kong internship listings](https://github.com/workopia/Hong-Kong-Graduate-Internship-Jobs/blob/main/.github/scripts/listings.json) and its [active snapshot](https://github.com/workopia/Hong-Kong-Graduate-Internship-Jobs/blob/main/data/active.json), which provide active listings and employer-facing Workopia URLs.

The current year counts are:

| Listing year | Records |
|---:|---:|
| 2023 | 2 |
| 2024 | 2 |
| 2025 | 4 |
| 2026 | 529 |

The data intentionally does not fabricate 2016–2022 records. `Year_Basis` identifies whether the year comes from a published date or a first-seen-date proxy. `Source_URL`, `Data_Source`, `Source_Repository`, `Posting_Date`, `Listing_Status`, `Program_Year`, and `Season` provide provenance and support later auditing. Salary is left missing unless the source gives a usable amount; `Salary_Text` retains salary wording that cannot safely be converted to a comparable stipend.

To refresh the collection, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/collect_intern_data.ps1
```

The collection is a current public-listing snapshot rather than a complete historical census. The year distribution must therefore be shown in the report and should not be interpreted as comparable annual market totals.

## SAS implementation

For the ten assessment requirements in the course checklist, run the
standalone [checklist program](sas/checklist_requirements.sas). See the
[requirement mapping](docs/CHECKLIST.md) for the
item-by-item code mapping, setup, generated Excel/raw inputs, output files,
and interpretation. It includes Excel and raw-file reads, keyed merges,
labelled listings, four largest/smallest observations, two chart types, and
three types of statistical analysis. All preparation and analysis in this
program use SAS.

The original research framework and five-figure program is:

```text
sas/internship_analysis.sas
```

Run the program with the repository root as the SAS current working directory. The program now discovers the current project directory and builds portable `data` and `output` paths automatically:

```sas
filename project ".";
%let project_dir=%sysfunc(pathname(project));
filename project clear;

%let input_dir=&project_dir./data;
%let output_dir=&project_dir./output;
```

On another computer, download or clone the repository, set the SAS current working directory to the repository root, and run `sas/internship_analysis.sas`. No user-specific `C:\Users\...` path is required.

Run the program in SAS 9.4 or SAS Studio. It will:

1. Import multiple CSV files and provide an optional Excel import macro.
2. Standardise sector, industry, paid status, stipend, location, and date fields.
3. Handle missing values and create supply weights.
4. Restrict the analysis period to 2016–2026.
5. Produce descriptive statistics using `PROC FREQ`, `PROC MEANS`, and `PROC UNIVARIATE`.
6. Produce five core figures using `PROC SGPLOT`.
7. Fit a logistic regression for paid opportunity status.
8. Compare log stipends using `PROC GLM`.
9. Calculate company-level supply concentration using the Herfindahl–Hirschman Index.
10. Export `intern_analysis.csv` and several summary datasets.

## Core figures

The report should discuss these figures in detail:

1. Overall supply structure by sector.
2. Sector share trends from 2016 to 2026.
3. Industry composition of the Large Chain and Large Group sectors.
4. Paid opportunity rate by sector.
5. Reported stipend distribution by sector.

Additional cross-tabulations, position-keyword groups, logistic-regression output, and concentration measures can be placed in an appendix.

## Suggested report structure

1. Introduction
2. Research questions
3. Data sources and methodology
4. SAS implementation
5. Results for the five core figures
6. Additional analyses
7. Discussion and practical implications for students
8. Limitations
9. Conclusion

## Important limitations

- Public recruitment data may over-represent visible and large employers.
- Internal referrals, university-only postings, and unadvertised positions may be missing.
- The same opportunity may appear on multiple websites and require deduplication.
- Sector and industry labels depend on documented classification rules.
- Stipends may be reported monthly, as a total amount, or as a one-off allowance and may not be perfectly comparable.
- `Num_Positions` is often unavailable, so weighted supply may partly rely on one record equalling one position.
- 2026 may be an incomplete year and should be interpreted carefully.
- Logistic regression identifies associations rather than causal effects.
- Company-name standardisation can affect concentration estimates.

## Analysis plan

The cleaning workflow is implemented with SAS DATA steps and procedures. It imports the raw files, standardises labels, parses stipend and date fields, creates `Paid_Flag`, `Supply_Weight`, `Large_Private_Flag`, `Location_Group`, `Position_Group`, and `Log_Stipend`, filters the study period, and exports `outlib.intern_analysis`.

The five core figures are:

| Figure | SAS procedure and chart | Main question |
|---|---|---|
| 1 | `PROC SGPLOT` vertical bar chart | What is the overall supply share of each sector? |
| 2 | `PROC SGPLOT` multi-series line chart | How do sector shares change from 2016 to 2026? |
| 3 | `PROC SGPLOT` grouped bar chart | Which industries make up Large Chain and Large Group supply? |
| 4 | `PROC SGPLOT` weighted bar chart | Which sectors have the highest paid-opportunity rate? |
| 5 | `PROC SGPLOT` box plot | How do reported stipend distributions differ by sector? |

The additional procedures address sector-industry cross-tabulations, position-keyword groups, paid-opportunity prediction using `PROC LOGISTIC`, stipend differences using `PROC GLM`, and company-level concentration using the HHI. These outputs can be reported briefly or placed in an appendix.

The practical discussion should connect the results to student job-search decisions: where supply is concentrated, which sectors have higher paid rates, which industries are accessible through large employers, and where a high number of postings may still be accompanied by low or undisclosed compensation.

## Local Git workflow

After adding the actual input data locally, the standard workflow is:

```powershell
git add README.md sas data/intern_data_template.csv .gitignore
git commit -m "Add SAS internship supply analysis framework"
git branch -M main
git remote add origin https://github.com/<github-user>/<repository-name>.git
git push -u origin main
```

Raw data and generated output are ignored by default. This avoids accidentally committing large files or unverified source data.
