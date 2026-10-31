# STAT 3660SEF assessment checklist

The independent entry point for all ten requirements is
[sas/checklist_requirements.sas](../sas/checklist_requirements.sas).
Every section is marked [01] to [10C] in
the code. The script creates all companion input formats from the committed
CSV using SAS, then reads them back. There is no need to manually create an
Excel workbook or raw text file.

## Requirement-to-code mapping

| Item | Requirement | Code and output evidence |
|---|---|---|
| 1 | Read Excel, a delimited file, and raw data | [01]: PROC IMPORT DBMS=CSV; PROC EXPORT and PROC IMPORT DBMS=XLSX for source_lookup.xlsx; column input with numeric/date informats for record_metadata.txt. |
| 2 | Read problematic files: overlength and missing data | [02]: explicit character lengths, LRECL, DSD, TRUNCOVER, original field strings, validation flags, and input_issues. problematic_records.txt includes a real long location and a short record with omitted numeric/date fields. |
| 3 | Read character, numeric, and date data | [03]: character source fields; numeric Year, Stipend, Num_Positions; numeric SAS dates with YYMMDD10. informats and formats. PROC CONTENTS VARNUM shows resulting types. |
| 4 | Merge datasets | [04]: PROC SORT and DATA MERGE BY with IN= flags. One-to-one merge by Listing_Row_ID attaches raw metadata; many-to-one merge by Source_Key attaches Excel source metadata. |
| 5 | Export CSV | [05]: PROC EXPORT DBMS=CSV writes output/checklist/checklist_analysis.csv. |
| 6 | Identify four largest and four smallest extreme observations | [06]: count collected postings per recorded employer name using PROC SQL, sort ascending and descending with PROC SORT, then OBS=4 and a rank. Results are four_largest and four_smallest. Ties use employer name. |
| 7 | List data with headings and column labels | [07]: TITLE1, TITLE2, LABEL, and PROC PRINT LABEL NOOBS. |
| 8 | Use conditional statements or loops properly | [08]: SELECT/WHEN and IF/ELSE distinguish paid, unpaid, and unknown. A DO Year=2016 TO 2026 loop builds the year grid. |
| 9 | At least two types of visualisation | [09]: PROC SGPLOT VBAR and HISTOGRAM; a SERIES chart additionally shows collection coverage. |
| 10 | At least two types of analytics | [10A]: PROC MEANS, PROC UNIVARIATE, and PROC FREQ. [10B]: exact binomial inference using PROC FREQ. [10C]: Firth logistic regression using PROC LOGISTIC. |

These implementations follow the supplied checklist. This mapping describes
code coverage, not an assessment mark awarded by the course.

## Run instructions

1. Clone or download the repository, including data/intern_data.csv.
2. Start a UTF-8 SAS session with Base SAS, SAS/STAT, ODS Graphics, and an
   installation that supports DBMS=XLSX.
3. Set the SAS current directory to the repository root, or set project_dir
   to the repository path on the SAS server.
4. Submit sas/checklist_requirements.sas. It does not require the original
   research program to have run first.

From the repository root:

~~~sas
%let project_dir=.;
%include "&project_dir./sas/checklist_requirements.sas" / source2;
~~~

For SAS Studio, set project_dir to the folder on the SAS server:

~~~sas
%let project_dir=/home/your_account/stat3660-summer-internship-analysis;
%include "&project_dir./sas/checklist_requirements.sas" / source2;
~~~

The input schema is the 20 columns in the committed CSV, in their current
order. A source with renamed or reordered columns must be mapped before using
the explicit reader. PROC IMPORT is retained as a required format example;
the explicit reader owns the field types and text lengths used for analysis.

## Outputs

All generated files are placed in output/checklist/:

| File or SAS dataset | Purpose |
|---|---|
| source_lookup.xlsx | SAS-generated Excel source-label lookup, subsequently read by PROC IMPORT. |
| record_metadata.txt | Fixed-width raw metadata, subsequently read with column informats. |
| problematic_records.txt | Separate IO test for long text and a short record. |
| checklist_analysis.sas7bdat and .csv | Cleaned input with both metadata joins. |
| input_issues.sas7bdat | Invalid/missing-format input audit. |
| problematic_read.sas7bdat | Parsed long/short test records, excluded from analysis data. |
| company_postings.sas7bdat | Collected-posting counts by recorded employer name. |
| four_largest.sas7bdat, four_smallest.sas7bdat | Four employer names at each end of the posting-count distribution. |
| year_coverage.sas7bdat | Collected-record counts for every study year. |
| disclosure_predictions.sas7bdat | Disclosure model predictions, when the outcome-count guard permits fitting. |
| run_checks.sas7bdat | Runtime integrity checks after successful reads and merges. |
| checklist_report.html and PNG images | Labelled tables, charts, and statistical output. |

Excel and raw inputs contain additional columns about the same records. They
are not independent sources of new internship observations.
Keep the HTML report and its PNG images together when sharing the output.

## Statistical interpretation

The current input contains 537 collected records, only 16 of which have an
explicit paid/unpaid label. Two have a numeric stipend. For that reason:

- The four extremes use observed posting counts by employer name, because
  fewer than four comparable numeric stipends are available.
- The binomial analysis estimates the paid fraction conditional on known pay
  status, not among all internships.
- The regression outcome is whether pay status is known, not whether an
  internship is paid. Firth penalisation handles sparse outcomes; it does
  not repair non-random sampling or poor labels.
- Source dates can be publication or first-seen dates rather than programme
  years. See Year_Basis and Program_Year.
- The input includes general, winter, off-cycle, and summer internships.
  Select Season before making summer-specific claims.
- Source URLs can repeat across employer aliases or truncated titles. The
  script preserves the collected records and uses a surrogate row key for
  joins. Resolve remaining duplicate vacancies before estimating supply.
- Sector and industry labels remain provisional and require employer review.
- Years with no records represent missing collection coverage, not zero
  internship supply.

## Verification

The code includes checks for CSV row counts, potential long-text truncation,
long/short-record input, key uniqueness, merge row counts, field round-trips,
and the number of extreme observations.

No SAS executable is installed in the development environment. SAS execution
and XLSX-engine availability must therefore be verified in the course SAS
environment. Review the SAS log for ERROR: and CHECKLIST CHECK PASSED.
