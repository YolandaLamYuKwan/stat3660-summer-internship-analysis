/*==============================================================*
 | STAT 3660SEF Group Project                                   |
 | Hong Kong University Summer Internship Supply, 2016-2026    |
 |                                                              |
 | The program assumes one row per recruitment record.         |
 | If Num_Positions is missing, one record receives weight 1.   |
 *==============================================================*/

options validvarname=v7;
options dlcreatedir;
options mprint mlogic symbolgen;
ods graphics on;

/*--------------------------------------------------------------*
 | 1. Portable project paths                                    |
 |                                                              |
 | Run this program with the repository root as the SAS current |
 | working directory. The paths below then work on Windows,    |
 | macOS, Linux, SAS Studio, and other computers.               |
 *--------------------------------------------------------------*/

filename project ".";
%let project_dir=%sysfunc(pathname(project));
filename project clear;

%let input_dir=&project_dir./data;
%let output_dir=&project_dir./output;

libname outlib "&output_dir";

proc format;
    value paidfmt
        0 = 'Unpaid'
        1 = 'Paid';
run;

/*--------------------------------------------------------------*
 | 2. Standardise one imported dataset                          |
 |                                                              |
 | VVALUEX reads a variable as text regardless of whether the  |
 | original source imported it as character or numeric.        |
 *--------------------------------------------------------------*/

%let norm_list=;
%let analysis_ready=0;

%macro normalize_one(in=, out=);

    data &out;

        set &in;

        length
            year_std            8
            sector_std          $30
            industry_std        $50
            company_std         $120
            position_std        $200
            paid_status         $10
            paid_flag            8
            stipend_num          8
            location_std        $120
            location_group       $30
            collection_date_std  8
            num_positions_std    8
            supply_weight        8
            posting_count        8
            large_private_flag   8
            position_group       $40
            log_stipend          8
            record_id            $80
            source_url           $500
            source_repository    $150
            data_source          $150
            listing_status       $30
            posting_date_std     8
            year_basis            $40
            program_year         $30
            salary_text_std      $200
            season_std           $30
            year_text            $100
            sector_raw           $200
            industry_raw         $200
            paid_raw             $200
            stipend_text         $200
            stipend_clean        $200
            num_positions_text   $100
            num_positions_clean  $100
            collection_text      $100
            location_raw         $200
            position_raw         $300;

        year_text       = strip(vvaluex('Year'));
        sector_raw      = lowcase(strip(vvaluex('Sector')));
        industry_raw    = lowcase(strip(vvaluex('Industry')));
        company_std     = strip(vvaluex('Company'));
        position_raw    = lowcase(strip(vvaluex('Position')));
        paid_raw        = lowcase(strip(vvaluex('Paid')));
        stipend_text    = strip(vvaluex('Stipend'));
        location_raw    = lowcase(strip(vvaluex('Location')));
        collection_text = strip(vvaluex('Collection_Date'));
        record_id       = strip(vvaluex('Record_ID'));
        source_url      = strip(vvaluex('Source_URL'));
        source_repository = strip(vvaluex('Source_Repository'));
        data_source     = strip(vvaluex('Data_Source'));
        listing_status  = strip(vvaluex('Listing_Status'));
        posting_date_std = input(strip(vvaluex('Posting_Date')), anydtdte.);
        year_basis      = strip(vvaluex('Year_Basis'));
        program_year    = strip(vvaluex('Program_Year'));
        salary_text_std = strip(vvaluex('Salary_Text'));
        season_std      = strip(vvaluex('Season'));

        /*------------------------ Year -------------------------*/
        year_std = input(compress(year_text,,'kd'), 4.);

        /*----------------------- Sector ------------------------*/
        if index(sector_raw,'large chain') > 0
           or index(sector_raw,'chain') > 0
           or index(sector_raw,'連鎖') > 0
           or index(sector_raw,'大型連鎖') > 0 then
            sector_std = 'Large Chain';

        else if index(sector_raw,'large group') > 0
           or index(sector_raw,'listed') > 0
           or index(sector_raw,'bank') > 0
           or index(sector_raw,'telecom') > 0
           or index(sector_raw,'property') > 0
           or index(sector_raw,'大型集團') > 0
           or index(sector_raw,'上市') > 0
           or index(sector_raw,'銀行') > 0
           or index(sector_raw,'電訊') > 0
           or index(sector_raw,'物業') > 0 then
            sector_std = 'Large Group';

        else if index(sector_raw,'government') > 0
           or index(sector_raw,'government department') > 0
           or index(sector_raw,'gov') > 0
           or index(sector_raw,'public sector') > 0
           or index(sector_raw,'政府') > 0
           or index(sector_raw,'公務員') > 0
           or index(sector_raw,'公營') > 0 then
            sector_std = 'Government';

        else if index(sector_raw,'ngo') > 0
           or index(sector_raw,'non-profit') > 0
           or index(sector_raw,'nonprofit') > 0
           or index(sector_raw,'charity') > 0
           or index(sector_raw,'social welfare') > 0
           or index(sector_raw,'慈善') > 0
           or index(sector_raw,'社福') > 0
           or index(sector_raw,'非牟利') > 0
           or index(sector_raw,'環保') > 0 then
            sector_std = 'NGO';

        else if index(sector_raw,'private') > 0
           or index(sector_raw,'company') > 0
           or index(sector_raw,'corporate') > 0
           or index(sector_raw,'一般企業') > 0
           or index(sector_raw,'私企') > 0
           or index(sector_raw,'私人') > 0 then
            sector_std = 'Private Enterprise';

        else
            sector_std = 'Other/Unclassified';

        /*---------------------- Industry ----------------------*/
        if index(industry_raw,'bank') > 0
           or index(industry_raw,'finance') > 0
           or index(industry_raw,'insurance') > 0
           or index(industry_raw,'金融') > 0
           or index(industry_raw,'銀行') > 0
           or index(industry_raw,'保險') > 0 then
            industry_std = 'Finance/Banking';

        else if index(industry_raw,'telecom') > 0
           or index(industry_raw,'telecommunication') > 0
           or index(industry_raw,'電訊') > 0 then
            industry_std = 'Telecommunications';

        else if index(industry_raw,'property') > 0
           or index(industry_raw,'real estate') > 0
           or index(industry_raw,'property management') > 0
           or index(industry_raw,'地產') > 0
           or index(industry_raw,'物業') > 0 then
            industry_std = 'Property/Real Estate';

        else if index(industry_raw,'retail') > 0
           or index(industry_raw,'零售') > 0
           or index(industry_raw,'shop') > 0
           or index(industry_raw,'store') > 0 then
            industry_std = 'Retail';

        else if index(industry_raw,'food') > 0
           or index(industry_raw,'restaurant') > 0
           or index(industry_raw,'catering') > 0
           or index(industry_raw,'餐飲') > 0
           or index(industry_raw,'飲食') > 0 then
            industry_std = 'Food & Beverage';

        else if index(industry_raw,'supermarket') > 0
           or index(industry_raw,'超市') > 0 then
            industry_std = 'Supermarket';

        else if index(industry_raw,'technology') > 0
           or index(industry_raw,'tech') > 0
           or index(industry_raw,'software') > 0
           or index(industry_raw,'information technology') > 0
           or index(industry_raw,'科技') > 0
           or index(industry_raw,'資訊') > 0 then
            industry_std = 'Technology';

        else if index(industry_raw,'environment') > 0
           or index(industry_raw,'environmental') > 0
           or index(industry_raw,'環保') > 0
           or index(industry_raw,'環境') > 0 then
            industry_std = 'Environment';

        else if index(industry_raw,'youth') > 0
           or index(industry_raw,'education') > 0
           or index(industry_raw,'school') > 0
           or index(industry_raw,'青年') > 0
           or index(industry_raw,'教育') > 0 then
            industry_std = 'Youth/Education';

        else if index(industry_raw,'social') > 0
           or index(industry_raw,'charity') > 0
           or index(industry_raw,'community') > 0
           or index(industry_raw,'社福') > 0
           or index(industry_raw,'慈善') > 0
           or index(industry_raw,'社區') > 0 then
            industry_std = 'Social Services/Charity';

        else if index(industry_raw,'health') > 0
           or index(industry_raw,'medical') > 0
           or index(industry_raw,'healthcare') > 0
           or index(industry_raw,'醫療') > 0
           or index(industry_raw,'健康') > 0 then
            industry_std = 'Healthcare';

        else if index(industry_raw,'media') > 0
           or index(industry_raw,'creative') > 0
           or index(industry_raw,'marketing') > 0
           or index(industry_raw,'媒體') > 0
           or index(industry_raw,'創意') > 0
           or index(industry_raw,'市場推廣') > 0 then
            industry_std = 'Media/Creative';

        else if index(industry_raw,'logistics') > 0
           or index(industry_raw,'transport') > 0
           or index(industry_raw,'shipping') > 0
           or index(industry_raw,'物流') > 0
           or index(industry_raw,'運輸') > 0 then
            industry_std = 'Transport/Logistics';

        else if index(industry_raw,'professional') > 0
           or index(industry_raw,'consulting') > 0
           or index(industry_raw,'business service') > 0
           or index(industry_raw,'專業服務') > 0
           or index(industry_raw,'顧問') > 0 then
            industry_std = 'Professional/Business Services';

        else
            industry_std = 'Other/Unclassified';

        /*---------------- Company and position ----------------*/
        if missing(company_std) then company_std = 'Unknown';

        position_std = strip(vvaluex('Position'));
        if missing(position_std) then position_std = 'Unknown';

        /*-------------------- Paid status ---------------------*/
        paid_flag = .;

        /* Test unpaid first because the word "unpaid" contains "paid". */
        if index(paid_raw,'unpaid') > 0
           or index(paid_raw,'no pay') > 0
           or index(paid_raw,'volunteer') > 0
           or index(paid_raw,'無薪') > 0
           or index(paid_raw,'義工') > 0
           or paid_raw in ('0','no','n','false') then
            paid_flag = 0;

        else if index(paid_raw,'paid') > 0
           or index(paid_raw,'salary') > 0
           or index(paid_raw,'allowance') > 0
           or index(paid_raw,'有薪') > 0
           or index(paid_raw,'津貼') > 0
           or index(paid_raw,'薪酬') > 0
           or paid_raw in ('1','yes','y','true') then
            paid_flag = 1;

        /* A positive stipend is evidence of a paid opportunity. */
        if missing(paid_flag) and not missing(stipend_text) then paid_flag = 1;

        if paid_flag = 1 then paid_status = 'Paid';
        else if paid_flag = 0 then paid_status = 'Unpaid';
        else paid_status = 'Unknown';

        /*----------------------- Stipend ----------------------*/
        stipend_clean = prxchange('s/[^0-9\.\-]//', -1, stipend_text);
        stipend_num = input(stipend_clean, best32.);
        if stipend_num <= 0 then stipend_num = .;
        if stipend_num > 0 then log_stipend = log(stipend_num);
        else log_stipend = .;

        /*------------------- Number of positions ---------------*/
        num_positions_text = strip(vvaluex('Num_Positions'));
        num_positions_clean = prxchange('s/[^0-9\.\-]//', -1, num_positions_text);
        num_positions_std = input(num_positions_clean, best32.);
        if num_positions_std <= 0 then num_positions_std = .;

        supply_weight = coalesce(num_positions_std, 1);
        posting_count = 1;

        /*-------------------- Collection date -----------------*/
        if prxmatch('/^[0-9]{4,5}$/', strip(collection_text)) > 0 then
            collection_date_std = input(strip(collection_text), best32.);
        else
            collection_date_std = input(strip(collection_text), anydtdte.);

        /*------------------------ Location ---------------------*/
        location_std = strip(vvaluex('Location'));
        if missing(location_std) then location_std = 'Unknown';

        if index(location_raw,'hong kong island') > 0
           or index(location_raw,'香港島') > 0 then
            location_group = 'Hong Kong Island';

        else if index(location_raw,'kowloon') > 0
           or index(location_raw,'九龍') > 0 then
            location_group = 'Kowloon';

        else if index(location_raw,'new territories') > 0
           or index(location_raw,'新界') > 0 then
            location_group = 'New Territories';

        else if index(location_raw,'multiple') > 0
           or index(location_raw,'全港') > 0
           or index(location_raw,'remote') > 0
           or index(location_raw,'hybrid') > 0 then
            location_group = 'Multiple/Hybrid';

        else
            location_group = 'Multiple/Unknown';

        /*---------------- Large private sector ----------------*/
        if sector_std in ('Large Chain','Large Group') then
            large_private_flag = 1;
        else
            large_private_flag = 0;

        /*-------------------- Position group -------------------*/
        if index(position_raw,'data') > 0
           or index(position_raw,'research') > 0
           or index(position_raw,'分析') > 0
           or index(position_raw,'研究') > 0 then
            position_group = 'Research/Data';

        else if index(position_raw,'marketing') > 0
           or index(position_raw,'communication') > 0
           or index(position_raw,'media') > 0
           or index(position_raw,'市場') > 0
           or index(position_raw,'傳訊') > 0 then
            position_group = 'Marketing/Communications';

        else if index(position_raw,'finance') > 0
           or index(position_raw,'account') > 0
           or index(position_raw,'財務') > 0
           or index(position_raw,'會計') > 0 then
            position_group = 'Finance/Accounting';

        else if index(position_raw,'human resource') > 0
           or index(position_raw,'hr') > 0
           or index(position_raw,'人力資源') > 0 then
            position_group = 'Human Resources';

        else if index(position_raw,'technology') > 0
           or index(position_raw,'software') > 0
           or index(position_raw,'program') > 0
           or index(position_raw,'it') > 0
           or index(position_raw,'資訊科技') > 0 then
            position_group = 'IT/Technology';

        else if index(position_raw,'admin') > 0
           or index(position_raw,'operation') > 0
           or index(position_raw,'行政') > 0
           or index(position_raw,'營運') > 0 then
            position_group = 'Administration/Operations';

        else if index(position_raw,'social worker') > 0
           or index(position_raw,'community') > 0
           or index(position_raw,'社工') > 0
           or index(position_raw,'社區') > 0 then
            position_group = 'Social/Community';

        else if index(position_raw,'retail') > 0
           or index(position_raw,'customer') > 0
           or index(position_raw,'sales') > 0
           or index(position_raw,'零售') > 0
           or index(position_raw,'銷售') > 0
           or index(position_raw,'客戶服務') > 0 then
            position_group = 'Retail/Customer Service';

        else
            position_group = 'Other';

        keep
            year_std sector_std industry_std company_std position_std
            paid_status paid_flag stipend_num location_std location_group
            collection_date_std num_positions_std supply_weight posting_count
            large_private_flag position_group log_stipend
            record_id source_url source_repository data_source listing_status
            posting_date_std year_basis program_year salary_text_std season_std;

    run;

    %global norm_list;
    %let norm_list=&norm_list &out;
    %global analysis_ready;
    %let analysis_ready=1;

%mend normalize_one;

/*--------------------------------------------------------------*
 | 3. Import a CSV only when it exists                          |
 *--------------------------------------------------------------*/

%macro import_csv_if_exists(file=, out=);

    %local fullpath;
    %let fullpath=&input_dir./&file;

    %if %sysfunc(fileexist("&fullpath")) %then %do;

        proc import datafile="&fullpath"
            out=work.&out
            dbms=csv
            replace;
            guessingrows=max;
            getnames=yes;
            datarow=2;
        run;

        %normalize_one(in=work.&out, out=work.norm_&out);

    %end;
    %else %do;
        %put NOTE: File not found and skipped: &fullpath;
    %end;

%mend import_csv_if_exists;

/* Main source plus optional additional sources. */
%import_csv_if_exists(file=intern_data.csv,         out=raw_main);
%import_csv_if_exists(file=intern_data_source2.csv, out=raw_source2);
%import_csv_if_exists(file=intern_data_source3.csv, out=raw_source3);

/*--------------------------------------------------------------*
 | 4. Optional Excel import                                    |
 | Uncomment and edit the macro call if required.               |
 *--------------------------------------------------------------*/

%macro import_xlsx_if_exists(file=, sheet=, out=);

    %local fullpath;
    %let fullpath=&input_dir./&file;

    %if %sysfunc(fileexist("&fullpath")) %then %do;

        proc import datafile="&fullpath"
            out=work.&out
            dbms=xlsx
            replace;
            sheet="&sheet";
            getnames=yes;
        run;

        %normalize_one(in=work.&out, out=work.norm_&out);

    %end;
    %else %do;
        %put NOTE: Excel file not found and skipped: &fullpath;
    %end;

%mend import_xlsx_if_exists;

/* Example:
%import_xlsx_if_exists(file=government_source.xlsx, sheet=Sheet1,
                       out=raw_government);
*/

/*--------------------------------------------------------------*
 | 5. Append standardized source datasets                       |
 *--------------------------------------------------------------*/

%macro build_analysis_dataset;

    %if %length(%superq(norm_list)) = 0 %then %do;
        %put ERROR: No input files were found in &input_dir.;
        %put ERROR: Add data/intern_data.csv or update the input path.;
        %return;
    %end;

    data work.intern_clean0;
        set &norm_list;
    run;

    data outlib.intern_clean;

        set work.intern_clean0;

        Year               = year_std;
        Sector             = sector_std;
        Industry           = industry_std;
        Company            = company_std;
        Position           = position_std;
        Record_ID          = record_id;
        Source_URL         = source_url;
        Source_Repository  = source_repository;
        Data_Source        = data_source;
        Listing_Status     = listing_status;
        Posting_Date       = posting_date_std;
        Year_Basis         = year_basis;
        Program_Year       = program_year;
        Salary_Text        = salary_text_std;
        Season             = season_std;
        Paid_Status        = paid_status;
        Paid_Flag          = paid_flag;
        Stipend            = stipend_num;
        Location           = location_std;
        Location_Group     = location_group;
        Collection_Date    = collection_date_std;
        Num_Positions      = num_positions_std;
        Supply_Weight      = supply_weight;
        Posting_Count      = posting_count;
        Large_Private_Flag = large_private_flag;
        Position_Group     = position_group;
        Log_Stipend        = log_stipend;

        format
            Year 4.
            Collection_Date yymmdd10.
            Paid_Flag paidfmt.
            Stipend comma12.2
            Supply_Weight comma12.2;

        label
            Year               = 'Year'
            Sector             = 'Standardized Sector'
            Industry           = 'Standardized Industry'
            Company            = 'Company'
            Position           = 'Position'
            Paid_Status        = 'Paid Status'
            Paid_Flag          = 'Paid Indicator'
            Stipend            = 'Reported Stipend'
            Location           = 'Location'
            Location_Group     = 'Location Group'
            Collection_Date    = 'Collection Date'
            Num_Positions      = 'Number of Positions'
            Supply_Weight      = 'Supply Weight'
            Posting_Count      = 'Posting Count'
            Large_Private_Flag = 'Large Private Sector Indicator'
            Position_Group     = 'Position Group'
            Log_Stipend        = 'Log Stipend'
            Record_ID          = 'Source Record ID'
            Source_URL         = 'Source URL'
            Source_Repository  = 'Source Repository'
            Data_Source        = 'Data Source'
            Listing_Status     = 'Listing Status'
            Posting_Date       = 'Posting Date'
            Year_Basis         = 'Year Basis'
            Program_Year       = 'Program Year'
            Salary_Text        = 'Salary Text'
            Season             = 'Internship Season';

        keep
            Year Sector Industry Company Position Paid_Status Paid_Flag
            Stipend Location Location_Group Collection_Date Num_Positions
            Supply_Weight Posting_Count Large_Private_Flag Position_Group
            Log_Stipend Record_ID Source_URL Source_Repository Data_Source
            Listing_Status Posting_Date Year_Basis Program_Year Salary_Text
            Season;

    run;

    data outlib.intern_analysis;
        set outlib.intern_clean;
        if missing(Year) then delete;
        if Year >= 2016 and Year <= 2026;
    run;

    proc export data=outlib.intern_analysis
        outfile="&output_dir./intern_analysis.csv"
        dbms=csv
        replace;
        putnames=yes;
    run;

%mend build_analysis_dataset;

%build_analysis_dataset;

/* Keep all analysis procedures inside a macro so the program can exit
   cleanly when the required input file has not yet been supplied. */
%macro run_all_analysis;

    %if &analysis_ready = 0 %then %do;
        %put WARNING: No input file was found. Copy the template to;
        %put WARNING: &input_dir./intern_data.csv and rerun the program.;
        %return;
    %end;

/*--------------------------------------------------------------*
 | 6. Data quality checks                                       |
 *--------------------------------------------------------------*/

proc contents data=outlib.intern_analysis;
run;

proc print data=outlib.intern_analysis(obs=20);
run;

proc freq data=outlib.intern_analysis;
    tables Year Sector Industry Paid_Status Location_Group Position_Group
           / missing;
    tables Sector*Paid_Status / norow nocol missing;
run;

/* Review this table before removing duplicates. The key is a project decision. */
proc sort data=outlib.intern_analysis out=work.intern_sorted;
    by Year Sector Company Position Location;
run;

proc freq data=work.intern_sorted;
    tables Year*Sector*Company*Position / list missing;
run;

/*--------------------------------------------------------------*
 | 7. Descriptive statistics                                   |
 *--------------------------------------------------------------*/

proc means data=outlib.intern_analysis n mean median min max sum std;
    class Sector;
    var Supply_Weight Posting_Count Num_Positions Stipend;
run;

proc means data=outlib.intern_analysis n mean median p25 p75 min max;
    var Stipend Supply_Weight Num_Positions;
run;

proc univariate data=outlib.intern_analysis;
    where Stipend > 0;
    var Stipend;
    histogram Stipend;
    inset n mean median p25 p75 min max;
run;

/*--------------------------------------------------------------*
 | 8. Figure 1: overall supply structure                       |
 *--------------------------------------------------------------*/

proc sql noprint;
    create table work.sector_supply as
    select Sector, sum(Supply_Weight) as Supply
    from outlib.intern_analysis
    group by Sector;

    select sum(Supply) into :total_supply trimmed
    from work.sector_supply;
quit;

data work.sector_supply;
    set work.sector_supply;
    Share = Supply / &total_supply;
    format Supply comma12. Share percent8.1;
run;

title 'Figure 1: Overall Summer Internship Supply Structure';
proc sgplot data=work.sector_supply;
    vbar Sector / response=Share stat=sum datalabel;
    yaxis values=(0 to 1 by 0.1) grid label='Share of Supply';
    xaxis discreteorder=data label='Sector';
run;
title;

/*--------------------------------------------------------------*
 | 9. Figure 2: sector trend by year                            |
 *--------------------------------------------------------------*/

proc sql;
    create table work.year_sector_supply as
    select Year, Sector, sum(Supply_Weight) as Supply
    from outlib.intern_analysis
    group by Year, Sector;

    create table work.year_total_supply as
    select Year, sum(Supply) as Year_Supply
    from work.year_sector_supply
    group by Year;
quit;

proc sort data=work.year_sector_supply; by Year; run;
proc sort data=work.year_total_supply; by Year; run;

data work.year_sector_supply;
    merge work.year_sector_supply work.year_total_supply;
    by Year;
    Share = Supply / Year_Supply;
    format Share percent8.1;
run;

title 'Figure 2: Sector Share of Supply by Year';
proc sgplot data=work.year_sector_supply;
    series x=Year y=Share / group=Sector markers lineattrs=(thickness=2);
    yaxis values=(0 to 1 by 0.1) grid label='Sector Share';
    xaxis values=(2016 to 2026 by 1) label='Year';
run;
title;

/*--------------------------------------------------------------*
 | 10. Figure 3: large private sector industry composition      |
 *--------------------------------------------------------------*/

proc sql;
    create table work.large_private_industry as
    select Sector, Industry, sum(Supply_Weight) as Supply
    from outlib.intern_analysis
    where Large_Private_Flag = 1
    group by Sector, Industry;

    create table work.large_private_total as
    select Sector, sum(Supply) as Sector_Supply
    from work.large_private_industry
    group by Sector;
quit;

proc sort data=work.large_private_industry; by Sector; run;
proc sort data=work.large_private_total; by Sector; run;

data work.large_private_industry;
    merge work.large_private_industry work.large_private_total;
    by Sector;
    Share = Supply / Sector_Supply;
    format Share percent8.1;
run;

title 'Figure 3: Industry Composition of Large Private Sector';
proc sgplot data=work.large_private_industry;
    vbar Industry / response=Share stat=sum group=Sector
        groupdisplay=cluster datalabel;
    yaxis values=(0 to 1 by 0.1) grid label='Share Within Sector';
    xaxis fitpolicy=rotate label='Industry';
run;
title;

/*--------------------------------------------------------------*
 | 11. Figure 4: weighted paid opportunity rate by sector       |
 *--------------------------------------------------------------*/

proc sql;
    create table work.paid_rate as
    select Sector,
           sum(Paid_Flag * Supply_Weight) / sum(Supply_Weight) as Paid_Rate,
           sum(Supply_Weight) as Known_Supply
    from outlib.intern_analysis
    where Paid_Flag in (0,1)
    group by Sector;
quit;

title 'Figure 4: Paid Opportunity Rate by Sector';
proc sgplot data=work.paid_rate;
    vbar Sector / response=Paid_Rate stat=sum datalabel;
    yaxis values=(0 to 1 by 0.1) grid label='Weighted Paid Rate';
    xaxis discreteorder=data label='Sector';
    format Paid_Rate percent8.1 Known_Supply comma12.;
run;
title;

/*--------------------------------------------------------------*
 | 12. Figure 5: stipend distribution by sector                  |
 *--------------------------------------------------------------*/

title 'Figure 5: Reported Stipend Distribution by Sector';
proc sgplot data=outlib.intern_analysis;
    where Paid_Flag = 1 and Stipend > 0;
    vbox Stipend / category=Sector;
    yaxis type=log grid label='Reported Stipend in HKD, Log Scale';
    xaxis label='Sector';
run;
title;

/*--------------------------------------------------------------*
 | 13. Cross-tabulations and additional analysis                 |
 *--------------------------------------------------------------*/

proc freq data=outlib.intern_analysis;
    tables Sector*Industry Industry*Paid_Status Sector*Location_Group
           / norow nocol chisq missing;
run;

proc freq data=outlib.intern_analysis order=freq;
    tables Position_Group Sector*Position_Group / norow nocol missing;
run;

/*--------------------------------------------------------------*
 | 14. Logistic regression for paid opportunity                  |
 *--------------------------------------------------------------*/

ods output ParameterEstimates=work.logistic_parameters;

proc logistic data=outlib.intern_analysis;
    where Paid_Flag in (0,1);

    class
        Sector(ref='Private Enterprise')
        Industry(ref='Other/Unclassified')
        Location_Group(ref='Multiple/Unknown')
        / param=ref;

    model Paid_Flag(event='1') = Year Sector Industry Location_Group;

    oddsratio Sector;
    oddsratio Industry;
    oddsratio Location_Group;

    output out=work.logistic_scored
        p=Predicted_Paid_Probability;
run;

ods output close;

data outlib.logistic_scored;
    set work.logistic_scored;
run;

/*--------------------------------------------------------------*
 | 15. GLM comparison of reported stipend                        |
 *--------------------------------------------------------------*/

proc glm data=outlib.intern_analysis;
    where Paid_Flag = 1 and Stipend > 0;
    class Sector;
    model Log_Stipend = Sector;
    means Sector / tukey;
    lsmeans Sector / pdiff=all adjust=tukey cl;
run;
quit;

/*--------------------------------------------------------------*
 | 16. Company-level supply concentration                        |
 *--------------------------------------------------------------*/

proc sql noprint;
    create table work.company_supply as
    select Company, sum(Supply_Weight) as Supply
    from outlib.intern_analysis
    where Company ne 'Unknown'
    group by Company;

    select sum(Supply) into :company_total trimmed
    from work.company_supply;
quit;

data work.company_hhi;
    set work.company_supply;
    Company_Share = Supply / &company_total;
    HHI_Component = Company_Share ** 2;
    format Company_Share percent8.2 HHI_Component 8.6;
run;

proc sql;
    select sum(HHI_Component) as HHI format=8.4
    from work.company_hhi;
quit;

/*--------------------------------------------------------------*
 | 17. Save analysis tables                                      |
 *--------------------------------------------------------------*/

data outlib.sector_supply_summary;
    set work.sector_supply;
run;

data outlib.year_sector_summary;
    set work.year_sector_supply;
run;

data outlib.large_private_industry_summary;
    set work.large_private_industry;
run;

data outlib.paid_rate_summary;
    set work.paid_rate;
run;

%mend run_all_analysis;

%run_all_analysis;

title;
ods graphics off;
