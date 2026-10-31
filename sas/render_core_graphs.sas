/* Five core figures from the collected CSV only. All calculations and
   visualisation use SAS. Run in a UTF-8 SAS session.
   Set project_dir to the repository folder on the SAS server if needed. */
%macro figure_paths;
    %if not %symexist(project_dir) %then %do;
        %global project_dir;
        %let project_dir=.;
    %end;
    %global graph_dir;
    options dlcreatedir validvarname=v7;
    libname figs "&project_dir./output";
    %let graph_dir=&project_dir./output/figures;
    libname figs "&graph_dir";
%mend;
%figure_paths;

/* Read the committed 20-column CSV in its documented order. */
filename incsv "&project_dir./data/intern_data.csv" encoding="utf-8";
data work.figure_input;
    length Year_Raw $20 Sector $40 Industry $100 Company $512
           Position Location Source_URL $8192 Paid $40 Stipend_Raw $100
           Collection_Date_Raw Posting_Date_Raw $40 Num_Positions_Raw $40
           Record_ID $128 Year_Basis $40 Program_Year $100
           Listing_Status $40 Data_Source $160 Salary_Text $1024
           Source_Repository $512 Season $40;
    infile incsv dsd dlm=',' firstobs=2 truncover lrecl=1048576;
    input Year_Raw :$20. Sector :$40. Industry :$100. Company :$512.
          Position :$8192. Paid :$40. Stipend_Raw :$100. Location :$8192.
          Collection_Date_Raw :$40. Num_Positions_Raw :$40.
          Record_ID :$128. Posting_Date_Raw :$40. Year_Basis :$40.
          Program_Year :$100. Listing_Status :$40. Data_Source :$160.
          Salary_Text :$1024. Source_URL :$8192.
          Source_Repository :$512. Season :$40.;
    Year=input(Year_Raw, ?? best32.);
    if missing(Year) or Year<2016 or Year>2026 then delete;
    Stipend=input(compress(Stipend_Raw,','), ?? best32.);
    length Paid_Status $10;
    if upcase(strip(Paid))='PAID' then Paid_Status='Paid';
    else if upcase(strip(Paid))='UNPAID' then Paid_Status='Unpaid';
    else Paid_Status='Unknown';
    Row_ID=_n_;
run;
filename incsv clear;

/* Reduce duplicate URLs first, then exact employer/title/year records.
   Employer aliases and cross-board duplicates still need manual review.
   Prefer a publication date over a proxy when the same URL is repeated. */
data work.figure_keys;
    set work.figure_input;
    Date_Priority=(Year_Basis ne 'Published_Date');
    Title_Length=klength(Position);
run;
proc sort data=work.figure_keys;
    by Source_URL Date_Priority descending Title_Length Row_ID;
run;
data work.figure_by_url;
    set work.figure_keys;
    by Source_URL;
    if first.Source_URL or missing(Source_URL);
run;
proc sort data=work.figure_by_url;
    by Company Position Year Date_Priority;
run;
data figs.graph_records;
    set work.figure_by_url;
    by Company Position Year;
    if first.Year;
run;

data work.sector_colors;
    length ID $12 Value $40 FillColor LineColor $9;
    ID='sector';
    Value='Government'; FillColor='CX2563EB'; LineColor=FillColor; output;
    Value='NGO'; FillColor='CX0D9488'; LineColor=FillColor; output;
    Value='Private Enterprise'; FillColor='CX64748B'; LineColor=FillColor; output;
    Value='Large Chain'; FillColor='CXD97706'; LineColor=FillColor; output;
    Value='Large Group'; FillColor='CX7C3AED'; LineColor=FillColor; output;
run;

proc sql noprint;
    select count(*) into :input_count trimmed from work.figure_input;
    select count(*) into :graph_count trimmed from figs.graph_records;
    select count(*) into :stipend_count trimmed from figs.graph_records
        where Stipend>0;
    create table figs.sector_share as
    select Sector, count(*) as Postings,
           count(*)/&graph_count as Share format=percent8.1
    from figs.graph_records group by Sector;
    create table figs.year_sector as
    select Year,Sector,count(*) as Postings
    from figs.graph_records group by Year,Sector;
    create table figs.year_totals as
    select Year,count(*) as Total
    from figs.graph_records group by Year;
    create table figs.year_shares as
    select a.Year,a.Sector,a.Postings,b.Total,
           a.Postings/b.Total as Share format=percent8.1
    from figs.year_sector as a
    left join figs.year_totals as b on a.Year=b.Year;
    create table figs.large_industries as
    select Sector,Industry,count(*) as Postings
    from figs.graph_records
    where Sector in ('Large Chain','Large Group')
    group by Sector,Industry;
    create table work.large_totals as
    select Sector,sum(Postings) as Total
    from figs.large_industries group by Sector;
    create table figs.industry_shares as
    select a.*,a.Postings/b.Total as Share format=percent8.1
    from figs.large_industries as a left join work.large_totals as b
    on a.Sector=b.Sector;
    create table work.pay_counts as
    select Sector,Paid_Status,count(*) as Postings
    from figs.graph_records group by Sector,Paid_Status;
    create table figs.pay_status as
    select a.*,a.Postings/b.Postings as Share format=percent8.1
    from work.pay_counts as a left join figs.sector_share as b
    on a.Sector=b.Sector;
    create table figs.paid_rates as
    select Sector,count(*) as All_Postings,
           sum(Paid_Status='Paid') as Paid_N,
           sum(Paid_Status='Unpaid') as Unpaid_N,
           sum(Paid_Status='Unknown') as Unknown_N
    from figs.graph_records group by Sector;
quit;
data figs.paid_rates;
    set figs.paid_rates;
    Known_N=Paid_N+Unpaid_N;
    if Known_N>0 then Paid_Rate_Among_Known=Paid_N/Known_N;
    else Paid_Rate_Among_Known=.;
    format Paid_Rate_Among_Known percent8.1;
run;
proc sort data=figs.year_shares;
    by Sector Year;
run;
data work.pay_colors;
    length ID $12 Value $10 FillColor $9;
    ID='pay';
    Value='Paid'; FillColor='CX0D9488'; output;
    Value='Unpaid'; FillColor='CXE11D48'; output;
    Value='Unknown'; FillColor='CXCBD5E1'; output;
run;

/* Create reproducible PNG images, a standalone HTML report, and a PDF.
   Keep all destinations on the same English figure definitions. */
ods listing gpath="&graph_dir" image_dpi=200;
ods html5(id=core) file="&graph_dir./core_graphs.html"
    options(bitmap_mode='inline') style=HTMLBlue;
options orientation=landscape papersize=A4;
ods pdf file="&graph_dir./core_graphs.pdf" style=HTMLBlue notoc;
ods graphics on / reset=all width=10in height=5.5in imagefmt=png;
title2;
footnote2 "Collected listings; provisional employer classes; general and seasonal internships combined.";

ods graphics / reset=index imagename="figure_01_sector_structure";
title1 "1. Structure of collected internship listings";
footnote1 "N=&graph_count after URL and exact-title deduplication; input N=&input_count.";
proc sgplot data=figs.sector_share dattrmap=work.sector_colors noautolegend;
    hbarparm category=Sector response=Share / group=Sector attrid=sector
        datalabel datalabelattrs=(size=11);
    xaxis grid label="Share of collected postings" values=(0 to 1 by 0.1);
    yaxis display=(nolabel);
run;

ods graphics / reset=index imagename="figure_02_year_sector";
title1 "2. Sector composition in observed listing years";
footnote1 "Very small 2023-2025 samples; 2016-2022 unobserved. This is collection coverage, not market growth.";
proc sgplot data=figs.year_shares dattrmap=work.sector_colors;
    series x=Year y=Share / group=Sector attrid=sector markers
        lineattrs=(thickness=2);
    xaxis integer values=(2023 to 2026 by 1) label="Listing year";
    yaxis grid values=(0 to 1 by 0.1) label="Sector share within collected year";
    keylegend / title="" position=bottom;
run;

ods graphics / reset=index imagename="figure_03_large_private_industries";
title1 "3. Industry mix within large private employers";
footnote1 "Shares are calculated separately within Large Chain and Large Group; classifications are provisional.";
proc sgplot data=figs.industry_shares dattrmap=work.sector_colors;
    hbarparm category=Industry response=Share / group=Sector attrid=sector
        groupdisplay=cluster;
    xaxis grid values=(0 to 1 by 0.1) label="Share within employer sector";
    yaxis display=(nolabel) labelattrs=(size=10);
    keylegend / title="" position=bottom;
run;

ods graphics / reset=index imagename="figure_04_pay_disclosure";
title1 "4. Pay status by sector, including undisclosed pay";
footnote1 "Unknown is shown explicitly; paid-rate denominators are documented in paid_rates.csv.";
proc sgplot data=figs.pay_status dattrmap=work.pay_colors;
    hbarparm category=Sector response=Share / group=Paid_Status
        attrid=pay groupdisplay=stack seglabel;
    xaxis grid label="Percent within sector" values=(0 to 1 by 0.1);
    yaxis display=(nolabel);
    keylegend / title="" position=bottom;
run;

ods graphics / reset=index imagename="figure_05_reported_stipends";
title1 "5. Reported stipend amounts: only &stipend_count records";
footnote1 "Source wording: $8,000/mo. Currency is not explicit; these are not verified comparable HKD monthly wages.";
proc sgplot data=figs.graph_records dattrmap=work.sector_colors noautolegend;
    where Stipend>0;
    scatter x=Stipend y=Position / group=Sector attrid=sector
        markerattrs=(symbol=circlefilled size=12) datalabel=Company;
    xaxis grid min=0 max=12000 label="Reported amount per month (source currency unspecified)";
    yaxis display=(nolabel);
run;
title;
footnote;
ods pdf close;
ods html5(id=core) close;
ods listing close;
ods graphics off;

/* Companion tables explain denominators and coverage. */
%macro graph_export(table);
    proc export data=figs.&table
        outfile="&graph_dir./&table..csv" dbms=csv replace;
    run;
%mend;
%graph_export(sector_share);
%graph_export(year_totals);
%graph_export(industry_shares);
%graph_export(paid_rates);
%put NOTE: GRAPH_RUN_COMPLETE Input=&input_count Analysis=&graph_count Stipends=&stipend_count;
