# STAT 3660SEF Group Project

## Public Internship Listings Relevant to Hong Kong University Students

This project uses SAS to describe the employer sectors, industries, pay information and text characteristics of collected public internship postings. The original research period is 2016–2026, but the current CSV contains records from 2023–2026 and is dominated by 2026. General and seasonal internships are combined; the figures do not describe a verified summer-only market census.

All data preparation, statistical analysis and visualisation in the SAS programs use SAS. PowerShell scripts collect public JSON feeds and convert them to the CSV input.

## Quick start in SAS OnDemand

1. Download or clone this repository. Extract a downloaded ZIP before uploading files.
2. In SAS Studio, create a project folder containing `data/` and `sas/`, and upload the matching repository files into them.
3. Set `project_dir` to the actual project folder on the SAS server. A server path normally starts with `/home/`; it cannot read a local Windows `C:` drive directly.
4. Run the appropriate program using a UTF-8 SAS session. Each program below is a separate entry point.

```sas
/* Replace your_id with the account folder shown in SAS Studio. */
%let project_dir=/home/your_id/stat3660-summer-internship-analysis;

/* Figures 01–05. */
%include "&project_dir./sas/render_core_graphs.sas" / source2;

/* Figures 06–09 and their supporting summary tables. */
%include "&project_dir./sas/render_other_graph.sas" / source2;

/* Two source-provenance pie charts. */
%include "&project_dir./sas/source_pies.sas" / source2;
```

If a `.sas` file is uploaded directly into the project root, omit `/sas` from its `%INCLUDE` path. The two graph programs default to `project_dir=.` only when that macro variable does not exist; opening a file does not necessarily change SAS's working directory. The older `internship_analysis.sas` contains its own `%let project_dir=...;` assignment, which must be edited inside that file before running it.

Read **LOG** before using **RESULTS**. Check errors, warnings, observation counts and the completion note; a completion note alone does not prove an error-free run. Refresh **Server Files and Folders** to locate saved outputs.

## Programs and folders

| File or folder | Purpose |
|---|---|
| [data/intern_data.csv](data/intern_data.csv) | Collected 537-row input snapshot |
| [sas/render_core_graphs.sas](sas/render_core_graphs.sas) | Standalone CSV preparation and Figures 01–05 |
| [sas/render_other_graph.sas](sas/render_other_graph.sas) | Standalone preparation, Figures 06–09 and five supporting summary tables |
| [sas/source_pies.sas](sas/source_pies.sas) | Source inventory, exported tables and two pie charts |
| [sas/checklist_requirements.sas](sas/checklist_requirements.sas) | Separate demonstration of the ten assessment requirements; see [CHECKLIST.md](CHECKLIST.md) |
| [sas/internship_analysis.sas](sas/internship_analysis.sas) | Original general framework, including optional inputs and exploratory models |
| [graphs/](graphs/) | Saved figure PNGs for the report |
| [source/](source/) | Source inventory, audit CSV tables and a duplicate input snapshot |
| [scripts/](scripts/) | PowerShell collection and source-inventory scripts |

The programs use different samples and purposes. The core and additional graph programs use the same duplicate rules and retain 472 postings. The source audit and checklist start from all 537 input rows. Running one program does not validate every other program or model in the repository.

## Research questions

1. How are the collected postings distributed across employer sectors and industries?
2. What do the observed listing years, pay disclosures and reported stipends allow us to describe?
3. What do employer posting counts and title characteristics reveal about concentration and data quality?

## Sector definitions

| Standard sector | Operational definition |
|---|---|
| Government | Government departments, Civil Service Bureau programmes and other public-sector programmes |
| NGO | Social-welfare, environmental, youth, community and charitable non-profit organisations |
| Private Enterprise | Ordinary private companies outside the Large Chain and Large Group categories |
| Large Chain | Large retail, restaurant, supermarket and other chain-service employers |
| Large Group | Listed groups, banks, telecommunications companies, property groups and other major corporations |

These are intended mutually exclusive employer categories. Current labels come from keyword rules and need independent employer-level verification; they are not a validated classification of employer size.

## Input data and preparation

The graph programs read the committed UTF-8 CSV using these 20 columns in this order:

```text
Year,Sector,Industry,Company,Position,Paid,Stipend,Location,Collection_Date,Num_Positions,Record_ID,Posting_Date,Year_Basis,Program_Year,Listing_Status,Data_Source,Salary_Text,Source_URL,Source_Repository,Season
```

Preserve the column order unless the explicit SAS `INPUT` statements are updated. [intern_data_template.csv](data/intern_data_template.csv) is an example template; the collected file is already available and should be retained for reproducing the current results. Optional extra CSV inputs in the original framework are not automatically appended by the two standalone graph programs.

One row is a recruitment posting, not a known number of vacancies. `Num_Positions` is missing throughout the current input, so the graph programs count postings equally. Pay is classified as Paid, Unpaid or Unknown; unknown pay is not treated as unpaid.

| Preparation stage | Records |
|---|---:|
| Collected CSV and source-audit input | 537 |
| After URL deduplication | 506 |
| After exact Company + Position + Year deduplication | 472 |
| Exact employer names in the graph sample | 265 |
| Nonmissing titles in the graph sample | 472 |
| Recent published-date HK Career Watch subset for LOESS | 321 |

URL deduplication prefers a published-date basis, a longer title and then original row order. Exact employer/title/year duplicates are removed next. Employer aliases, differences in capitalisation and cross-platform duplicate vacancies may remain.

The input-year counts are:

| Listing year | Input records |
|---|---:|
| 2016–2022 | No collected records |
| 2023 | 2 |
| 2024 | 2 |
| 2025 | 4 |
| 2026 | 529 |

The saved collection date is October 31, 2026. `Year_Basis` distinguishes publication dates from first-seen-date proxies. Listing year may differ from `Program_Year`; a 2026 posting can advertise a 2027 programme. Missing historical coverage does not mean zero internships in those years.

## Source inventory and pie charts

The collection pipeline is **GitHub JSON feed → filtering and normalisation → CSV → SAS**. JSON is the original collection format; CSV is the converted input to SAS.

| Import provider | Retained input rows | Share | Original format |
|---|---:|---:|---|
| [HK Career Watch jobs.json](https://github.com/laier029/hk-career-watch/blob/main/jobs.json) | 472 | 87.90% | GitHub JSON feed |
| [Workopia listings.json](https://github.com/workopia/Hong-Kong-Graduate-Internship-Jobs/blob/main/.github/scripts/listings.json) | 65 | 12.10% | GitHub JSON feed |
| Total | 537 | 100% | Converted to CSV |

The collector also checks [Workopia active.json](https://github.com/workopia/Hong-Kong-Graduate-Internship-Jobs/blob/main/data/active.json). [DATA_SOURCES.txt](source/DATA_SOURCES.txt) records the feed URLs, attribution and format conversion. `Source_Repository` identifies the imported feed, while `Source_URL` points to a referenced listing. A linked recruitment website does not establish that this project directly scraped that website.

The [provider pie](graphs/pie_01_source_repository.png) uses all 537 rows, assigned once by `Source_Repository`. The [original-format pie](graphs/pie_02_original_format.png) is one slice: GitHub JSON feed, 100%. CSV is the subsequent conversion, not another original-format category. The 472 HK Career Watch input rows are a different set from the 472 additionally deduplicated graph records.

The source program writes `DATA_SOURCES.txt`, `source_records.csv`, `website_counts.csv`, `format_counts.csv`, `linked_hosts.csv`, `feed_counts.csv`, the input snapshot and chart reports to `source/`. Do not append `source/intern_data.csv` to the main input: it duplicates the same observations.

## Core figures 01–05

Use [render_core_graphs.sas](sas/render_core_graphs.sas) for these five figures. They remain the main report figures; the current run describes 472 retained postings across all collected season labels.

| Figure | SAS method | Interpretation |
|---|---|---|
| [01 Sector structure](graphs/figure_01_sector_structure.png) | `PROC SGPLOT` horizontal bar chart | Sector shares within the 472-posting sample |
| [02 Observed listing years](graphs/figure_02_year_sector.png) | `PROC SGPLOT` grouped series | Within-year sector composition; very small historical samples prevent market-trend conclusions |
| [03 Large private industries](graphs/figure_03_large_private_industries.png) | `PROC SGPLOT` grouped horizontal bars | Industry shares calculated separately within Large Chain and Large Group |
| [04 Pay disclosure](graphs/figure_04_pay_disclosure.png) | `PROC SGPLOT` stacked horizontal bars | Paid, Unpaid and Unknown shares within each sector |
| [05 Individual stipends](graphs/figure_05_reported_stipends.png) | `PROC SGPLOT` labelled points | Only two reported amounts; no reliable cross-sector stipend distribution |

In the graph sample, 14 records are labelled Paid, one Unpaid and 457 Unknown. The paid rate among known outcomes is 14/15, or 93.3%; this is not the paid proportion of all postings. The two numeric stipends quote `$8,000/mo` from one employer, with currency unspecified in that wording.

## Additional figures 06–09

[render_other_graph.sas](sas/render_other_graph.sas) selects two methods from each Chapter 5 PDF. It reads the CSV independently and applies the same duplicate rules as the core program. These four statistical graph types add distribution and data-quality diagnostics without repeating the existing bar, pie, histogram, box or ordinary scatter types.

| Figure and report section | Course method and PDF pages | SAS implementation | Analysis unit |
|---|---|---|---|
| [06 Empirical CDF](graphs/figure_06_Empirical_CDF.png), Section 4.10 | Part A, pp. 33 and 36 | `PROC UNIVARIATE` with `CDFPLOT` | 265 exact employer names, weighted equally |
| [07 Quantile diagnostic](graphs/figure_07_quantile_diagnostic.png), Section 4.11 | Part A, pp. 33 and 35 | `PROC UNIVARIATE` with `QQPLOT` and a fitted normal reference | Natural log of postings per employer name |
| [08 Standalone KDE](graphs/figure_08_Standalone_KDE.png), Section 4.12 | Part B, pp. 8–9 | `PROC SGPLOT` with `DENSITY TYPE=KERNEL` | 472 nonmissing title lengths measured with `KLENGTH` |
| [09 LOESS fitted curve](graphs/figure_09_LOESS_fitted_curve.png), Section 4.13 | Part B, pp. 24–26 | `PROC SGPLOT` with `LOESS`, `NOMARKERS`, span 0.65 and local linear fits | 321 recent HK Career Watch postings with a published-date basis |

Figure 06 shows that 177 employer names have one posting (66.8%) and 226 have at most two (85.3%). Figure 07 shows substantial ties and departures from the normal reference after logging. Figure 08 shows right-skewed title lengths: mean 43.4 characters, median 40, with the middle half between 29 and 55. These are summaries of retained postings and labels, not estimates of employer market shares or internship quality.

Figure 09 uses the latest saved collection date, excludes first-seen proxies and restricts publication-to-snapshot age to 0–90 days. The observed ages are 2–90 days. Age does not measure time to fill a vacancy, and the smoother does not establish causation or market growth. Set `%let other_loess_window=90;` before running the program to specify the window explicitly.

The additional program was executed in SAS OnDemand on November 10, 2026, producing all four graphs. For the current snapshot, its completion note is:

```text
OTHER_GRAPH_RUN_COMPLETE Input=537 Analysis=472 Employers=265 Titles=472 LOESS=321 Graphs=4
```

The committed script still uses the internal method labels A1, A2, B1 and B2 and the generated PNG basenames below. The saved images in `graphs/` use the report numbering 06–09.

| Report figure | PNG generated in `output/other_graphs/` |
|---|---|
| 06 | `other_A1_employer_cdf.png` |
| 07 | `other_A2_log_volume_qq.png` |
| 08 | `other_B1_title_length_kde.png` |
| 09 | `other_B2_title_age_loess.png` |

## Generated outputs

| Program | Output location and contents |
|---|---|
| `render_core_graphs.sas` | `output/figures/`: five PNGs, `core_graphs.html`, `core_graphs.pdf`, SAS datasets and summary CSVs |
| `render_other_graph.sas` | `output/other_graphs/`: four PNGs, `other_graphs.html`, `other_graphs.pdf`, SAS datasets and seven CSV exports |
| `source_pies.sas` | `source/`: two pie charts, HTML report, source inventory, five audit CSVs and an input snapshot |

The seven additional CSV exports are `other_graph_records.csv`, `employer_counts.csv`, `employer_summary.csv`, `employer_cdf.csv`, `loess_records.csv`, `run_counts.csv` and `method_mapping.csv`. Its HTML/PDF also contains five summary tables: employer CDF, employer summary, title length, LOESS subset and source attribution after deduplication. Rendering checks can skip a graph when there is insufficient data; input updates can change all counts.

## Assessment demonstrations and exploratory methods

[checklist_requirements.sas](sas/checklist_requirements.sas) covers three input formats, problematic records, data types, keyed merges, CSV export, four largest/smallest employer counts, labelled listings, conditions/loops, multiple chart types and statistical analysis. The XLSX and fixed-width companion files are generated demonstrations from the same observations, not independently collected market sources. Review the checklist's own log and run checks before claiming successful execution.

The original [internship_analysis.sas](sas/internship_analysis.sas) contains broader cleaning, descriptive statistics, logistic regression, GLM, employer HHI and keyword examples. Its proposed box plot and model outputs are separate from the current executed graph workflow. With only one known unpaid outcome and two numeric stipends, adjusted paid-status models and sector-wage comparisons are poorly supported. A pay-disclosure model answers a different question from a paid-status model; neither establishes causation.

## Report structure and limitations

Use Introduction → Methodology → Implementation → Results → Conclusion. Discuss Figures 01–05 in depth, then use Sections 4.10–4.13 for the four additional diagnostics. Place detailed code, source pies, cross-tabulations and exploratory extras in appendices as appropriate.

- Public feeds can over-represent visible private employers and omit government, NGO, university-only and unadvertised opportunities.
- There are no collected 2016–2022 records and very few 2023–2025 records. The data cannot establish a complete 2016–2026 trend.
- Current figures mix general and seasonal internships. A summer-only analysis requires a verified filter and recalculated denominators.
- Sector and industry rules, employer aliases and remaining duplicates affect composition and concentration.
- Unknown pay remains distinct from unpaid work. Missing vacancy counts prevent estimates of actual places; stipend comparisons need verified currencies, periods and hours.
- KDE and LOESS are descriptive smoothers. Shape, bandwidth and sparse support do not establish population effects or causal relationships.

## Refreshing and preserving the analysis

Preserve the submitted CSV before refreshing live feeds. The collector overwrites `data/intern_data.csv`, and its collection-date assignment and classification rules should be reviewed for a new collection.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/collect_intern_data.ps1
powershell -ExecutionPolicy Bypass -File scripts/build_source_inventory.ps1
```

After a deliberate data update, rerun the SAS programs and regenerate the source inventory, figures and report numbers together. Keep source-audit counts separate from graph-sample counts.

For an existing clone, review intended changes with `git status` and `git diff`, stage the specific files, commit and push. `.gitignore` excludes `output/` and many generated formats; already tracked images in `graphs/` remain versioned. Do not assume that saving a file in SAS OnDemand synchronises it with GitHub.
