/* Source provenance audit and TWO pie charts, all prepared in SAS.
   Unit: rows in data/intern_data.csv, not unique vacancies or positions.
   Original collection format: GitHub JSON feed.
   Conversion: GitHub JSON feed -> filtering/normalisation -> CSV -> SAS.

   Set project_dir to the repository folder on the SAS server if needed.
   Run the whole file; RESULTS displays both pies. */
%macro source_paths;
    %if not %symexist(project_dir) %then %do;
        %global project_dir;
        %let project_dir=.;
    %end;
    %global source_output;
    options validvarname=v7 dlcreatedir;
    %let source_output=&project_dir./source;
    libname srcout "&source_output";
%mend;
%source_paths;

filename sourcein "&project_dir./data/intern_data.csv" encoding="utf-8";
proc import datafile=sourcein out=work.source_csv dbms=csv replace;
    guessingrows=max;
    getnames=yes;
run;
filename sourcein clear;

data srcout.source_records;
    length Provider $40 Original_Format $40 Stored_Format $20
           Feed_URL $300 Linked_Host $256;
    set work.source_csv(keep=Source_Repository Source_URL Data_Source);
    select;
        when (index(upcase(Source_Repository),
                    'LAIER029/HK-CAREER-WATCH/')=1) do;
            Provider='HK Career Watch';
            Feed_URL='https://raw.githubusercontent.com/laier029/hk-career-watch/main/jobs.json';
        end;
        when (Source_Repository=
              'workopia/Hong-Kong-Graduate-Internship-Jobs/listings.json') do;
            Provider='Workopia';
            Feed_URL='https://raw.githubusercontent.com/workopia/Hong-Kong-Graduate-Internship-Jobs/main/.github/scripts/listings.json';
        end;
        when (Source_Repository=
              'workopia/Hong-Kong-Graduate-Internship-Jobs/data/active.json') do;
            Provider='Workopia';
            Feed_URL='https://raw.githubusercontent.com/workopia/Hong-Kong-Graduate-Internship-Jobs/main/data/active.json';
        end;
        otherwise Provider='Unmapped';
    end;
    if Provider ne 'Unmapped' then Original_Format='GitHub JSON feed';
    else Original_Format='Unverified';
    Stored_Format='CSV';
    /* M counts the empty token after https:, preserving URL token 3. */
    Linked_Host=lowcase(scan(strip(Source_URL),3,'/','m'));
    Linked_Host=prxchange('s/^www\.//i',1,Linked_Host);
    if missing(Linked_Host) then Linked_Host='Missing URL';
run;

proc sql noprint;
    select count(*) into :source_total trimmed from srcout.source_records;
    select count(*) into :unmapped_total trimmed
        from srcout.source_records where Provider='Unmapped';
quit;
%macro verify_sources;
    %if &source_total=0 or &unmapped_total>0 %then %do;
        %put ERROR: Source audit cannot classify all rows. Total=&source_total Unmapped=&unmapped_total;
        %abort cancel;
    %end;
%mend;
%verify_sources;

proc sql;
    create table srcout.website_counts as
    select Provider,count(*) as Records,
           count(*)/&source_total as Share format=percent8.2
    from srcout.source_records
    group by Provider order by Records desc,Provider;
    create table srcout.format_counts as
    select Original_Format,count(*) as Records,
           count(*)/&source_total as Share format=percent8.2
    from srcout.source_records group by Original_Format;
    create table srcout.linked_hosts as
    select Linked_Host,count(*) as Records,
           count(*)/&source_total as Share format=percent8.2
    from srcout.source_records
    group by Linked_Host order by Records desc,Linked_Host;
    create table srcout.feed_counts as
    select Feed_URL,Provider,count(*) as Records
    from srcout.source_records group by Feed_URL,Provider;
quit;

/* Generate a tidy TXT next to the source tables on the SAS server.
   The Git version is source/DATA_SOURCES.txt and includes the feed catalogue,
   conversion notes, attribution rules, and complete linked-host inventory. */
filename auditxt "&source_output./DATA_SOURCES.txt" encoding="utf-8";
data _null_;
    file auditxt lrecl=32767;
    put 'STAT 3660SEF - DATA SOURCES AND FILE FORMATS';
    put '===========================================';
    put "Counting base: &source_total rows in data/intern_data.csv.";
    put 'One retained row is assigned to its recorded Source_Repository.';
    put 'This is a provenance audit, not an estimate of unique vacancies.';
    put;
    put 'DATA FORMAT AND CONVERSION';
    put 'Original format: GitHub JSON feed (JSON), for all retained rows.';
    put 'Saved format: CSV, data/intern_data.csv, UTF-8, 20 columns.';
    put 'Flow: GitHub JSON feed -> filter/normalise -> deduplicate -> CSV -> SAS.';
    put 'CSV is the converted analysis input, not a second original source.';
    put 'No Excel workbook or raw fixed-width file was used for collection.';
    put;
    put 'DIRECT COLLECTION WEBSITES / REPOSITORIES';
    put 'HK Career Watch: https://github.com/laier029/hk-career-watch';
    put 'Workopia: https://github.com/workopia/Hong-Kong-Graduate-Internship-Jobs';
    put 'Both feed repositories are hosted on GitHub.';
    put;
    put 'RETAINED RECORD COUNTS BY PROVIDER';
run;
data _null_;
    set srcout.website_counts;
    file auditxt mod lrecl=32767;
    put Provider ': ' Records comma8. ' rows; ' Share percent8.2;
run;
data _null_;
    file auditxt mod lrecl=32767;
    put;
    put 'FEED ENDPOINTS WITH RETAINED RECORDS';
run;
data _null_;
    set srcout.feed_counts;
    file auditxt mod lrecl=32767;
    put Provider ' | ' Records comma8. ' rows | ' Feed_URL;
run;
data _null_;
    file auditxt mod lrecl=32767;
    put;
    put 'SOURCE_URL DOMAINS (REFERENCED LISTING PAGES)';
    put 'These are links inside the feeds, not evidence of direct scraping.';
    put 'Counts use all CSV rows; remove www. only; keep ATS subdomains.';
run;
data _null_;
    set srcout.linked_hosts;
    file auditxt mod lrecl=32767;
    put Linked_Host ' | ' Records comma8. ' rows | ' Share percent8.2;
run;
filename auditxt clear;

/* Save EVERY source-audit table in portable CSV format for GitHub.
   Share is a numeric fraction in CSV; plots retain the percent format.
   The original imported CSV is also exported as a source snapshot. */
%macro export_source_table(table);
    data work.source_export;
        set srcout.&table;
        format _numeric_ best32.;
    run;
    proc export data=work.source_export
        outfile="&source_output./&table..csv" dbms=csv replace;
        putnames=yes;
    run;
%mend;
%export_source_table(source_records);
%export_source_table(website_counts);
%export_source_table(format_counts);
%export_source_table(linked_hosts);
%export_source_table(feed_counts);
proc export data=work.source_csv outfile="&source_output./intern_data.csv"
    dbms=csv replace;
run;

/* Both charts use row-level attribution in the full input CSV.
   The single-slice format chart is intentionally 100% JSON feed. */
ods listing gpath="&source_output" image_dpi=160;
ods html5(id=sourceaudit) file="&source_output./source_pies.html"
    options(bitmap_mode='inline') style=HTMLBlue;
ods graphics on / reset=all width=8in height=4.5in imagefmt=png;

title1 "Records by GitHub source repository";
title2 "N=&source_total CSV rows; one source attribution per retained row";
footnote1 "GitHub JSON feed -> filtering and normalisation -> CSV -> SAS";
ods graphics / reset=index imagename="pie_01_source_repository";
proc sgpie data=srcout.website_counts;
    styleattrs datacolors=(CX2563EB CXF59E0B);
    pie Provider / response=Records
        datalabeldisplay=(category response percent)
        datalabelloc=outside;
run;

title1 "Records by original collection format";
title2 "Saved as CSV after collection; CSV is the SAS input";
footnote1 "Original: GitHub JSON feed (JSON). Converted file: data/intern_data.csv.";
ods graphics / reset=index imagename="pie_02_original_format";
proc sgpie data=srcout.format_counts;
    styleattrs datacolors=(CX0D9488);
    pie Original_Format / response=Records
        datalabeldisplay=(category response percent)
        datalabelloc=outside;
run;

/* Optional copyable CSV text in the results page. The default keeps only
   the two requested charts visible. To inspect a table, for example run
   %show_export(website_counts, display=1) in the same SAS session. */
/* Close the fixed-width LISTING destination before displaying long CSV
   lines. The HTML tables retain every character of these audit records. */
ods listing close;
%macro show_export(table, display=0);
    %if &display=0 %then %return;
    filename showcsv "&source_output./&table..csv" encoding="utf-8";
    data work.display_&table;
        length CSV_Line $4096;
        infile showcsv truncover lrecl=4096;
        input CSV_Line $char4096.;
    run;
    filename showcsv clear;
    title1 "CSV export: &table";
    title2;
    footnote;
    proc print data=work.display_&table noobs;
        var CSV_Line;
    run;
%mend;
%show_export(source_records);
%show_export(website_counts);
%show_export(format_counts);
%show_export(linked_hosts);
%show_export(feed_counts);

title;
footnote;
ods html5(id=sourceaudit) close;
ods listing close;
ods graphics off;
%put NOTE: SOURCE_PIES_COMPLETE Total=&source_total Unmapped=&unmapped_total;
