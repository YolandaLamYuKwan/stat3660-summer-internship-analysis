%macro render_other_graphs;
    %local og_raw_n og_input_n og_url_n og_analysis_n og_employers
           og_employer_values og_title_n og_title_values og_curve_n
           og_curve_ages og_curve_titles og_snapshot og_snapshot_label
           og_missing_company og_graphs;

    %if not %symexist(project_dir) %then %do;
        %global project_dir;
        %let project_dir=.;
    %end;
    %if not %symexist(other_loess_window) %then %do;
        %global other_loess_window;
        %let other_loess_window=90;
    %end;
    %global other_graph_dir;
    %let other_graph_dir=&project_dir./output/other_graphs;
    %let og_graphs=0;

    /* Validate the file before creating any analysis outputs. */
    filename ogcsv "&project_dir./data/intern_data.csv" encoding="utf-8";
    %if not %sysfunc(fexist(ogcsv)) %then %do;
        %put ERROR: Input CSV not found: &project_dir./data/intern_data.csv;
        %put ERROR: Upload the CSV and set project_dir to its SAS server parent folder.;
        filename ogcsv clear;
        %return;
    %end;

    options validvarname=v7 dlcreatedir;
    /* Create output first, then its child; do not assume recursive mkdir. */
    libname ogout "&project_dir./output";
    %if %sysfunc(libref(ogout)) ne 0 %then %do;
        %put ERROR: Cannot create or access the project output folder.;
        filename ogcsv clear;
        %return;
    %end;
    libname ogout "&other_graph_dir";
    %if %sysfunc(libref(ogout)) ne 0 %then %do;
        %put ERROR: Cannot create or access &other_graph_dir.;
        filename ogcsv clear;
        %return;
    %end;

    /* 1. Explicit schema: handles quoted commas, long text and blanks.
       Match the column order of the committed CSV; do not reorder it.
       Original date strings and source attribution remain available. */
    data work.og_raw;
        length Year_Raw $20 Sector $40 Industry $100 Company $512
               Position Location Source_URL $8192 Paid $40 Stipend_Raw $100
               Collection_Date_Raw Posting_Date_Raw $40 Num_Positions_Raw $40
               Record_ID $128 Year_Basis $40 Program_Year $100
               Listing_Status $40 Data_Source $160 Salary_Text $1024
               Source_Repository $512 Season $40;
        infile ogcsv dsd dlm=',' firstobs=2 truncover lrecl=1048576;
        input Year_Raw :$20. Sector :$40. Industry :$100. Company :$512.
              Position :$8192. Paid :$40. Stipend_Raw :$100. Location :$8192.
              Collection_Date_Raw :$40. Num_Positions_Raw :$40.
              Record_ID :$128. Posting_Date_Raw :$40. Year_Basis :$40.
              Program_Year :$100. Listing_Status :$40. Data_Source :$160.
              Salary_Text :$1024. Source_URL :$8192.
              Source_Repository :$512. Season :$40.;
        Row_ID=_n_;
        Year=input(Year_Raw, ?? best32.);
        Collection_Date_SAS=input(Collection_Date_Raw, ?? yymmdd10.);
        Posting_Date_SAS=input(Posting_Date_Raw, ?? yymmdd10.);
        format Collection_Date_SAS Posting_Date_SAS yymmdd10.;
    run;
    filename ogcsv clear;

    /* 2. Use the same period and duplicate keys as render_core_graphs.sas.
       Preserve exact employer/title text so the sample is comparable.
       Row_ID supplies the URL-sort tie-breaker. Missing URLs do not
       collapse unrelated records into a single observation. */
    data work.og_input;
        set work.og_raw;
        if missing(Year) or Year<2016 or Year>2026 then delete;
        Date_Priority=(Year_Basis ne 'Published_Date');
        Title_Length=klength(Position);
    run;
    proc sort data=work.og_input out=work.og_keys;
        by Source_URL Date_Priority descending Title_Length Row_ID;
    run;
    data work.og_by_url;
        set work.og_keys;
        by Source_URL;
        if first.Source_URL or missing(Source_URL);
    run;
    /* EQUALS preserves the previous URL order for otherwise tied keys,
       matching the stable second sort used by the core-figure program. */
    proc sort data=work.og_by_url equals;
        by Company Position Year Date_Priority;
    run;
    data ogout.other_graph_records;
        set work.og_by_url;
        by Company Position Year;
        if first.Year;
        length Source_Provider $40;
        if index(upcase(Source_Repository),'LAIER029/HK-CAREER-WATCH')>0
            then Source_Provider='HK Career Watch';
        else if index(upcase(Source_Repository),
                      'WORKOPIA/HONG-KONG-GRADUATE-INTERNSHIP-JOBS')>0
            then Source_Provider='Workopia';
        else Source_Provider='Other/Unmapped';
        if not missing(Position) then Position_Chars=klength(strip(Position));
        else Position_Chars=.;
        label Position_Chars='Job title length in characters';
    run;

    proc sql noprint;
        select count(*) into :og_raw_n trimmed from work.og_raw;
        select count(*) into :og_input_n trimmed from work.og_input;
        select count(*) into :og_url_n trimmed from work.og_by_url;
        select count(*) into :og_analysis_n trimmed
            from ogout.other_graph_records;
        select count(*) into :og_missing_company trimmed
            from ogout.other_graph_records where missing(Company);
    quit;
    %if &og_analysis_n=0 %then %do;
        %put ERROR: No records remain in the 2016-2026 analysis period.;
        %return;
    %end;

    /* 3. Employer-level observations for A1 and A2.
       One row is one exact nonblank collected Company label.
       These are NOT verified parent-company groups or vacancy counts. */
    proc sql;
        create table ogout.employer_counts as
        select Company, count(*) as Postings
        from ogout.other_graph_records
        where not missing(Company)
        group by Company;
    quit;
    data ogout.employer_counts;
        set ogout.employer_counts;
        Log_Postings=log(Postings);
        label Postings='Analysed postings per employer label'
              Log_Postings='Natural log of postings per employer label';
    run;
    proc means data=ogout.employer_counts noprint;
        var Postings;
        output out=ogout.employer_summary(drop=_TYPE_ _FREQ_)
            n=Employer_Labels sum=Postings mean=Mean_Postings
            median=Median_Postings min=Min_Postings max=Max_Postings;
    run;

    /* A companion empirical CDF table makes the denominator explicit.
       For example, Cumulative_Share at Postings=2 is the proportion of
       employer LABELS with at most two analysed postings, not a vacancy
       share and not a cumulative market share. */
    proc freq data=ogout.employer_counts noprint;
        tables Postings / out=work.og_count_frequency;
    run;
    proc sort data=work.og_count_frequency;
        by Postings;
    run;
    proc sql noprint;
        select count(*),count(distinct Postings)
            into :og_employers trimmed,:og_employer_values trimmed
            from ogout.employer_counts;
    quit;
    data ogout.employer_cdf;
        set work.og_count_frequency(rename=(Count=Employer_Labels));
        Cumulative_Employers+Employer_Labels;
        if &og_employers>0 then
            Cumulative_Share=Cumulative_Employers/&og_employers;
        format Cumulative_Share percent8.2;
        drop Percent;
    run;

    /* 4. Title diagnostics for B1 and B2.
       Use the saved collection date, not TODAY(), so the historical
       snapshot gives the same result when this code is rerun later.
       B2 restricts to feed-labelled publication dates, the latest snapshot,
       one provider and a recent window to reduce obvious mixing.
       The date proxy is explicitly excluded; no dates are imputed. */
    proc sql noprint;
        select max(Collection_Date_SAS) into :og_snapshot trimmed
            from ogout.other_graph_records;
        select count(Position_Chars),count(distinct Position_Chars)
            into :og_title_n trimmed,:og_title_values trimmed
            from ogout.other_graph_records;
    quit;
    %let og_snapshot_label=%sysfunc(putn(&og_snapshot,yymmdd10.));
    data ogout.loess_records;
        set ogout.other_graph_records;
        if Source_Provider ne 'HK Career Watch' then delete;
        if Year_Basis ne 'Published_Date' then delete;
        if missing(Collection_Date_SAS) or missing(Posting_Date_SAS)
           or missing(Position_Chars) then delete;
        if Collection_Date_SAS ne &og_snapshot then delete;
        Listing_Age_Days=Collection_Date_SAS-Posting_Date_SAS;
        if Listing_Age_Days<0 or Listing_Age_Days>&other_loess_window
            then delete;
        label Listing_Age_Days='Days from publication to saved snapshot';
    run;
    proc sql noprint;
        select count(*),count(distinct Listing_Age_Days),
               count(distinct Position_Chars)
            into :og_curve_n trimmed,:og_curve_ages trimmed,
                 :og_curve_titles trimmed
            from ogout.loess_records;
    quit;

    /* 5. Four requests only. UNIVARIATE NOPRINT suppresses its summary
       tables while retaining explicitly requested statistical graphs.
       Checks below prevent fitting constant or very sparse variables.
       Their thresholds are rendering safeguards, not proof of validity.
       The report is descriptive: no normality p-values or population
       confidence bands are claimed for this convenience web sample. */
    ods listing gpath="&other_graph_dir" image_dpi=200;
    ods html5(id=othergraphs) file="&other_graph_dir./other_graphs.html"
        options(bitmap_mode='inline') style=HTMLBlue;
    options orientation=landscape papersize=A4;
    ods pdf file="&other_graph_dir./other_graphs.pdf" style=HTMLBlue notoc;
    ods graphics on / reset=all width=10in height=5.5in imagefmt=png;

    /* A1 - Empirical CDF: not an ordinary time-series line graph. */
    %if &og_employers>=2 %then %do;
        ods graphics / reset=index imagename="other_A1_employer_cdf";
        title1 "A1. Cumulative distribution of employer posting volume";
        title2 "Part A: CDFPLOT | &og_employers exact employer labels";
        footnote1 "Each employer label has equal weight; &og_missing_company records with missing Company excluded.";
        footnote2 "CDF at k = share of observed labels with at most k postings; all seasons combined.";
        proc univariate data=ogout.employer_counts noprint;
            var Postings;
            cdfplot Postings;
        run;
        %let og_graphs=%eval(&og_graphs+1);
    %end;
    %else %put WARNING: A1 skipped - fewer than two observed employer labels.;

    /* A2 - Quantile diagnostic, distinct from a two-variable scatter.
       Count ties remain after logging. Normality is not assumed and a
       reference line does not establish it or validate later inference. */
    %if &og_employers>=5 and &og_employer_values>=3 %then %do;
        ods graphics / reset=index imagename="other_A2_log_volume_qq";
        title1 "A2. Normal Q-Q diagnostic of log employer posting volume";
        title2 "Part A: QQPLOT | &og_employers exact employer labels";
        footnote1 "Reference line estimates the mean and standard deviation of log posting counts.";
        footnote2 "Tied discrete counts and a convenience sample: shape diagnostic only, not a normality claim.";
        proc univariate data=ogout.employer_counts noprint;
            var Log_Postings;
            qqplot Log_Postings / normal(mu=est sigma=est);
        run;
        %let og_graphs=%eval(&og_graphs+1);
    %end;
    %else %put WARNING: A2 skipped - insufficient employer count variation.;

    /* B1 - Standalone KDE: deliberately no HISTOGRAM overlay.
       Use density units, NOT a percentage or histogram-bin proportion.
       Integer title lengths are smoothed as a descriptive approximation. */
    %if &og_title_n>=20 and &og_title_values>=5 %then %do;
        ods graphics / reset=index imagename="other_B1_title_length_kde";
        title1 "B1. Kernel density of collected job title lengths";
        title2 "Part B: DENSITY TYPE=KERNEL | &og_title_n nonmissing titles";
        footnote1 "Characters are measured with KLENGTH, not byte length. All analysed seasons and providers are included.";
        footnote2 "Height is density, not percent. Integer lengths are smoothed; peaks may reflect feed truncation.";
        proc sgplot data=ogout.other_graph_records noautolegend;
            where not missing(Position_Chars);
            density Position_Chars / type=kernel scale=density
                lineattrs=(color=CX0D9488 thickness=3);
            xaxis min=0 grid label="Job title length (characters)";
            yaxis min=0 grid label="Estimated density per character";
        run;
        %let og_graphs=%eval(&og_graphs+1);
    %end;
    %else %put WARNING: B1 skipped - insufficient nonmissing title length variation.;

    /* B2 - LOESS fitted curve only: no SCATTER or SERIES statement.
       Each retained posting has equal weight. SMOOTH=0.65 controls the
       local neighbourhood; DEGREE=1 fits local straight-line models.
       No CLM band: web selection and source artefacts remain unmodelled.
       Age means publication-to-snapshot lag, not time to fill a vacancy,
       application duration or the internship programme's start date. */
    %if &og_curve_n>=30 and &og_curve_ages>=8 and &og_curve_titles>=3 %then %do;
        ods graphics / reset=index imagename="other_B2_title_age_loess";
        title1 "B2. Smoothed title length by publication-to-snapshot age";
        title2 "Part B: LOESS | HK Career Watch | N=&og_curve_n | Snapshot &og_snapshot_label";
        footnote1 "Feed-labelled publication dates only; ages 0-&other_loess_window days; LOESS span 0.65; no raw-point overlay.";
        footnote2 "Descriptive source-quality diagnostic; no causal effect, pay prediction or market-growth claim.";
        proc sgplot data=ogout.loess_records noautolegend;
            loess x=Listing_Age_Days y=Position_Chars /
                nomarkers smooth=0.65 degree=1
                lineattrs=(color=CX7C3AED thickness=3);
            xaxis min=0 max=&other_loess_window grid
                label="Days from publication to saved collection snapshot";
            yaxis min=0 grid label="Smoothed job title length (characters)";
        run;
        %let og_graphs=%eval(&og_graphs+1);
    %end;
    %else %put WARNING: B2 skipped - needs 30 records, 8 distinct ages and 3 title lengths in its subset.;

    title;
    footnote;
    ods pdf close;
    ods html5(id=othergraphs) close;
    ods listing close;
    ods graphics off;

    /* 6. Save denominators and source-to-method mapping for the report.
       ODS outputs are closed, so these create no additional charts. */
    data ogout.run_counts;
        length Stage $60;
        Stage='CSV input rows'; Records=&og_raw_n; output;
        Stage='Rows in the 2016-2026 listing-year period'; Records=&og_input_n; output;
        Stage='After URL deduplication'; Records=&og_url_n; output;
        Stage='After exact Company + Position + Year deduplication'; Records=&og_analysis_n; output;
        Stage='Employer labels used in A1 and A2'; Records=&og_employers; output;
        Stage='Nonmissing titles eligible for B1'; Records=&og_title_n; output;
        Stage='Recent published-date records eligible for B2'; Records=&og_curve_n; output;
        Stage='Distinct publication ages eligible for B2'; Records=&og_curve_ages; output;
        Stage='Graph requests submitted'; Records=&og_graphs; output;
    run;
    data ogout.method_mapping;
        length Method_ID $2 PDF_Part $1 PDF_Pages $12 Method $40
               SAS_Procedure $64 Unit $100 Interpretation $300;
        Method_ID='A1'; PDF_Part='A'; PDF_Pages='33, 36';
        Method='Empirical CDF'; SAS_Procedure='PROC UNIVARIATE / CDFPLOT';
        Unit='One exact nonblank Company label';
        Interpretation='Share of observed employer labels with at most k analysed postings.'; output;
        Method_ID='A2'; PDF_Part='A'; PDF_Pages='33, 35';
        Method='Normal Q-Q diagnostic'; SAS_Procedure='PROC UNIVARIATE / QQPLOT';
        Unit='One exact nonblank Company label';
        Interpretation='Compare log posting-count quantiles with fitted normal quantiles; ties and skew remain possible.'; output;
        Method_ID='B1'; PDF_Part='B'; PDF_Pages='8-9';
        Method='Standalone kernel density'; SAS_Procedure='PROC SGPLOT / DENSITY TYPE=KERNEL';
        Unit='One analysed posting with nonmissing Position';
        Interpretation='Smoothed distribution of title length; density height is not percentage.'; output;
        Method_ID='B2'; PDF_Part='B'; PDF_Pages='24-26';
        Method='LOESS fitted curve'; SAS_Procedure='PROC SGPLOT / LOESS NOMARKERS';
        Unit='One recent published-date HK Career Watch posting at the latest saved snapshot';
        Interpretation='Exploratory association of title length and publication age; source quality, not market growth.'; output;
    run;

    %og_export(other_graph_records);
    %og_export(employer_counts);
    %og_export(employer_summary);
    %og_export(employer_cdf);
    %og_export(loess_records);
    %og_export(run_counts);
    %og_export(method_mapping);

    /* A completion note records requests, not proof of error-free output.
       Inspect the entire LOG and all four charts before reporting them.
       The committed input snapshot should give Input=537 and Analysis=472;
       later input changes can legitimately change these counts. */
    %put NOTE: OTHER_GRAPH_RUN_COMPLETE Input=&og_raw_n Analysis=&og_analysis_n Employers=&og_employers Titles=&og_title_n LOESS=&og_curve_n Graphs=&og_graphs;
    %put NOTE: Additional graph outputs: &other_graph_dir;
%mend render_other_graphs;

%macro og_export(table);
    proc export data=ogout.&table
        outfile="&other_graph_dir./&table..csv" dbms=csv replace;
    run;
%mend og_export;

%render_other_graphs;
