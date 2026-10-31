<# Build a provenance TXT from the existing CSV. Does not recollect data.
   Charts and analysis are implemented separately in sas/source_pies.sas. #>
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$inputPath = Join-Path $taskRoot 'data/intern_data.csv'
$sourceDirectory = Join-Path $taskRoot 'source'
[IO.Directory]::CreateDirectory($sourceDirectory) | Out-Null
$outputPath = Join-Path $sourceDirectory 'DATA_SOURCES.txt'
$rows = @(Import-Csv -LiteralPath $inputPath -Encoding UTF8)
if ($rows.Count -eq 0) { throw 'The collected CSV has no rows.' }

$knownSources = @(
    'laier029/hk-career-watch/jobs.json',
    'workopia/Hong-Kong-Graduate-Internship-Jobs/listings.json',
    'workopia/Hong-Kong-Graduate-Internship-Jobs/data/active.json'
)
$unmapped = @($rows | Where-Object { $_.Source_Repository -notin $knownSources })
if ($unmapped.Count) { throw 'Unmapped source repositories found. Update the source catalogue first.' }

$total = $rows.Count
$watchCount = @($rows | Where-Object {
    $_.Source_Repository -eq 'laier029/hk-career-watch/jobs.json'
}).Count
$workopiaCount = $total - $watchCount
$hostCounts = @($rows | Group-Object {
    if (-not $_.Source_URL) { 'Missing URL' }
    else { ([uri]$_.Source_URL).DnsSafeHost.ToLowerInvariant() -replace '^www\.','' }
} | Sort-Object @{Expression='Count';Descending=$true},Name)
$sha = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
$text = [System.Collections.Generic.List[string]]::new()
$text.Add('STAT 3660SEF - DATA SOURCES AND FILE FORMATS')
$text.Add('===========================================')
$text.Add('Collection date recorded in the CSV: 2026-10-31')
$text.Add("Input: data/intern_data.csv | Retained rows: $total | Columns: 20")
$text.Add("CSV SHA-256: $sha")
$text.Add('')
$text.Add('1. DATA FLOW AND FORMAT')
$text.Add('Original collection format: GitHub JSON feed (JSON).')
$text.Add('Conversion: GitHub JSON feed -> filtering/normalisation -> deduplication -> CSV -> SAS.')
$text.Add('The data become a UTF-8 CSV file at data/intern_data.csv.')
$text.Add('SAS reads this converted CSV for analysis and the two source pie charts.')
$text.Add('CSV is the stored analysis format, not a second original format.')
$text.Add('No Excel workbook or fixed-width raw text file contributed collected records.')
$text.Add('The course checklist generates separate demonstration files; these do not count as collection sources.')
$text.Add('')
$text.Add('2. DIRECT COLLECTION SOURCES')
$text.Add('Both repositories are hosted on GitHub. They provide the JSON feeds actually downloaded.')
$text.Add('')
$catalogue = @(
    @{
        Name='HK Career Watch'
        Repo='https://github.com/laier029/hk-career-watch'
        Label='laier029/hk-career-watch/jobs.json'
        Feed='https://raw.githubusercontent.com/laier029/hk-career-watch/main/jobs.json'
        Description='Public internship/job-monitoring feed. Contains source URLs and dates where available.'
    },
    @{
        Name='Workopia - structured listings'
        Repo='https://github.com/workopia/Hong-Kong-Graduate-Internship-Jobs'
        Label='workopia/Hong-Kong-Graduate-Internship-Jobs/listings.json'
        Feed='https://raw.githubusercontent.com/workopia/Hong-Kong-Graduate-Internship-Jobs/main/.github/scripts/listings.json'
        Description='Public structured Hong Kong graduate/internship listing feed.'
    },
    @{
        Name='Workopia - active snapshot'
        Repo='https://github.com/workopia/Hong-Kong-Graduate-Internship-Jobs'
        Label='workopia/Hong-Kong-Graduate-Internship-Jobs/data/active.json'
        Feed='https://raw.githubusercontent.com/workopia/Hong-Kong-Graduate-Internship-Jobs/main/data/active.json'
        Description='Active-listing snapshot checked by the collector. No additional retained rows in this CSV.'
    }
)
foreach ($source in $catalogue) {
    $count = @($rows | Where-Object { $_.Source_Repository -eq $source.Label }).Count
    $percent = (100.0*$count/$total).ToString('F2',[Globalization.CultureInfo]::InvariantCulture)
    $text.Add($source.Name)
    $text.Add('  Website: ' + $source.Repo)
    $text.Add('  Downloaded feed: ' + $source.Feed)
    $text.Add('  Original format: GitHub JSON feed (JSON)')
    $text.Add('  Converted format: CSV')
    $text.Add("  Retained CSV rows: $count ($percent%)")
    $text.Add('  Notes: ' + $source.Description)
    $text.Add('')
}
$text.Add('3. PIE CHART DEFINITIONS')
$text.Add("Denominator: $total rows of the committed CSV. No additional vacancy deduplication in this audit.")
foreach ($pair in @(@('HK Career Watch',$watchCount),@('Workopia',$workopiaCount))) {
    $percent = (100.0*[int]$pair[1]/$total).ToString('F2',[Globalization.CultureInfo]::InvariantCulture)
    $text.Add("Website/provider pie: $($pair[0]) = $($pair[1]) rows ($percent%).")
}
$text.Add("Original-format pie: GitHub JSON feed = $total rows (100.00%).")
$text.Add("Stored/SAS-input format: CSV = $total rows (100.00%); not another slice in the original-format pie.")
$text.Add('Website slices distinguish repository providers; a hosting-domain-only count would be GitHub 100%.')
$text.Add('')
$text.Add('4. ATTRIBUTION AND LIMITATIONS')
$text.Add('Each retained row is assigned once using Source_Repository, not the Source_URL domain.')
$text.Add('Counts are after the collector keeps the first company/title/location/year record.')
$text.Add('HK Career Watch can itself reference Workopia. Those rows count under HK Career Watch when that repository is the recorded import source.')
$text.Add('Do not add the Data_Source Workopia count to the repository-level Workopia count.')
$text.Add('Source_URL points to a referenced listing. It does not prove this project directly downloaded or scraped that page.')
$text.Add('The feeds may have used HTML, APIs or other methods upstream; this project cannot infer those original formats from a URL.')
$text.Add('Do not classify a referenced job page as an imported HTML, Excel, PDF or raw-file record.')
$text.Add('This audit counts CSV rows. It does not claim every row is a unique vacancy or every source claim was independently verified.')
$text.Add('The 472 rows attributed to HK Career Watch are not the same denominator as the 472 records retained by the separate core-chart deduplication.')
$text.Add('')
$text.Add('5. REFERENCED LISTING WEBSITES')
$text.Add('The following hosts come from Source_URL. They are indirect references, not direct collection endpoints.')
$text.Add('Normalisation: remove a leading www. only; preserve ATS subdomains.')
$text.Add("Host count: $($hostCounts.Count) | Row count: $total")
$text.Add('Host | Rows | Share of CSV rows')
foreach ($group in $hostCounts) {
    $percent = (100.0*$group.Count/$total).ToString('F2',[Globalization.CultureInfo]::InvariantCulture)
    $text.Add("$($group.Name) | $($group.Count) | $percent%")
}
$text.Add('')
$text.Add('6. REPRODUCIBILITY')
$text.Add('Collection code: scripts/collect_intern_data.ps1')
$text.Add('TXT inventory code: scripts/build_source_inventory.ps1')
$text.Add('SAS pie charts and SAS-generated companion TXT: sas/source_pies.sas')
$text.Add('GitHub destination: source/ for all source tables, TXT and CSV; sas/ for SAS code.')
$text.Add('SAS table exports: source_records.csv, website_counts.csv, format_counts.csv, linked_hosts.csv, feed_counts.csv.')
$text.Add('source/intern_data.csv is a snapshot of data/intern_data.csv, not new observations to append.')
$text.Add('The collection CSV remains unchanged by this provenance audit.')

[IO.File]::WriteAllLines($outputPath,$text,[Text.UTF8Encoding]::new($false))
Write-Output "Written: $outputPath"
Write-Output "Total=$total; HK Career Watch=$watchCount; Workopia=$workopiaCount; Original format=GitHub JSON feed; Converted to CSV."
