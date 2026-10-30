$ErrorActionPreference = 'Stop'

<#
    Download and combine two public Hong Kong internship feeds.

    The output is intentionally a snapshot. It does not manufacture
    observations for years that are absent from the public sources.
#>

$headers = @{ 'User-Agent' = 'STAT3660SEF-Internship-Project' }
$outputPath = Join-Path $PSScriptRoot '..\data\intern_data.csv'

function Normalize-Text([string]$value) {
    return (($value -replace '\s+', ' ').Trim())
}

function Get-Industry([string]$text) {
    $t = $text.ToLowerInvariant()

    if ($t -match 'bank|finance|financial|insurance|actuar|investment|asset management|accounting|equities|trading|capital|wealth|securities') { return 'Finance/Banking' }
    if ($t -match 'telecom|telecommunication|mobile network|broadband') { return 'Telecommunications' }
    if ($t -match 'property|real estate|landlord|facilit|building management') { return 'Property/Real Estate' }
    if ($t -match 'retail|sales advisor|fashion|beauty|luxury|store|merchandis|brand intern') { return 'Retail' }
    if ($t -match 'food|restaurant|catering|hospitality|hotel|f&b|culinary|beverage') { return 'Food & Beverage/Hospitality' }
    if ($t -match 'technology|software|data science|data analyst|artificial intelligence|\bai\b|cyber|information technology|\bit\b|engineer|cloud|digital product') { return 'Technology' }
    if ($t -match 'environment|sustainab|conservation|climate|ecology') { return 'Environment' }
    if ($t -match 'youth|education|school|university|teaching|academic') { return 'Youth/Education' }
    if ($t -match 'health|medical|pharma|clinical|nursing|biotech') { return 'Healthcare' }
    if ($t -match 'law|legal|consult|audit|professional services|public relations|communications|marketing') { return 'Professional/Business Services' }
    if ($t -match 'government|civil service|public administration|department') { return 'Public Administration' }

    return 'Other/Unclassified'
}

function Get-Sector([string]$company, [string]$position, [string]$industry) {
    $t = "$company $position $industry".ToLowerInvariant()

    if ($t -match 'government|\bgovt?\b|civil service|hksar|government department|hong kong productivity council|innovation and technology commission|\bhkpc\b') { return 'Government' }
    if ($t -match 'ngo|non.?profit|charit|welfare|welfare service society|red cross|oxfam|wwf|greenpeace|ywca|ymca|caritas|salvation army|social services society|community foundation|unicef|church of jesus christ') { return 'NGO' }
    if ($t -match 'd fi retail|dfi retail|7.?eleven|circle k|wellcome|parknshop|mannings|watsons|mcdonald|starbucks|kfc|subway|lidl|uniqlo|h&m|lululemon|zara|adidas|nike|decathlon|chow tai fook|estee lauder|coach|pvh|retail group|supermarket|retail chain|fashion house|beauty brand') { return 'Large Chain' }
    if ($t -match 'bank|insurance|insurer|telecom|telecommunications|property group|listed|holdings|group|citi|hsbc|standard chartered|dbs|aia|manulife|prudential|hkex|hong kong exchanges|china life|pccw|hkt|marriott international|google|amazon|microsoft|jpmorgan|jpmc|ubs|dhl|siemens|mtr corporation') { return 'Large Group' }

    return 'Private Enterprise'
}

function Get-PaidAndStipend([string]$position, [string]$description, [string]$salaryDisplay) {
    $text = "$position $description $salaryDisplay"
    $salaryText = ''
    $stipend = ''

    $salaryPattern = '(?i)(HK\$\s*[\d,]+(?:\.\d+)?(?:\s*(?:-|–|to)\s*(?:HK\$\s*)?[\d,]+(?:\.\d+)?)?\s*(?:per month|/month|/mo|monthly))'
    $salaryMatch = [regex]::Match($description, $salaryPattern)

    if ($salaryDisplay) { $salaryText = Normalize-Text $salaryDisplay }
    elseif ($salaryMatch.Success) { $salaryText = Normalize-Text $salaryMatch.Value }

    if ($salaryText) {
        $amounts = [regex]::Matches($salaryText, '[\d,]+(?:\.\d+)?')
        if ($amounts.Count -gt 0) {
            $parsed = @($amounts | ForEach-Object {
                [double]::Parse($_.Value.Replace(',', ''), [Globalization.CultureInfo]::InvariantCulture)
            })

            if ($parsed.Count -eq 1) { $stipend = [string]$parsed[0] }
            elseif ($parsed.Count -ge 2) { $stipend = [string](($parsed[0] + $parsed[1]) / 2) }
        }
    }

    if (-not $salaryText -and $description -match '(?i)HK\$\s*[\d,]+(?:\.\d+)?') {
        $salaryText = [regex]::Match($description, '(?i)HK\$\s*[\d,]+(?:\.\d+)?').Value + ' (period not stated)'
    }

    $paid = 'Unknown'
    if ($text -match '(?i)unpaid internship|internship is unpaid|intern position is unpaid|without pay') { $paid = 'Unpaid' }
    elseif ($text -match '(?i)paid internship|internship is paid|paid intern|HK\$\s*[\d,]+(?:\.\d+)?|\$\s*[\d,]+(?:\.\d+)?\s*(?:per month|/month|/mo|monthly)') { $paid = 'Paid' }

    return [pscustomobject]@{
        Paid = $paid
        Stipend = $stipend
        Salary_Text = $salaryText
    }
}

function New-Row($item, [string]$sourceRepository, [string]$sourceType) {
    $company = Normalize-Text ([Net.WebUtility]::HtmlDecode([string]$item.Company))
    $position = Normalize-Text ([Net.WebUtility]::HtmlDecode([string]$item.Position))
    $location = Normalize-Text ([Net.WebUtility]::HtmlDecode([string]$item.Location))

    $industry = Get-Industry "$company $position"
    $sector = Get-Sector $company $position $industry
    $pay = Get-PaidAndStipend $position ([string]$item.Description) ([string]$item.Salary_Text)

    [pscustomobject][ordered]@{
        Year = $item.Year
        Sector = $sector
        Industry = $industry
        Company = $company
        Position = $position
        Paid = $pay.Paid
        Stipend = $pay.Stipend
        Location = $location
        Collection_Date = '2026-10-31'
        Num_Positions = ''
        Record_ID = [string]$item.Record_ID
        Posting_Date = $item.Posting_Date
        Year_Basis = $item.Year_Basis
        Program_Year = [string]$item.Program_Year
        Listing_Status = [string]$item.Listing_Status
        Data_Source = [string]$item.Data_Source
        Salary_Text = $pay.Salary_Text
        Source_URL = [string]$item.Source_URL
        Source_Repository = $sourceRepository
        Season = if ($position -match '(?i)summer') { 'Summer' }
                 elseif ($position -match '(?i)winter') { 'Winter' }
                 elseif ($position -match '(?i)off[ -]?cycle') { 'Off-cycle' }
                 else { 'General/Unspecified' }
    }
}

$watchUrl = 'https://raw.githubusercontent.com/laier029/hk-career-watch/main/jobs.json'
$watch = Invoke-RestMethod -Headers $headers -Uri $watchUrl
$pattern = '(?i)\bintern\b|\binternship\b|\bco[ -]?op\b|\bplacement\b'

$watchRows = @($watch.jobs | Where-Object {
    $_.location -match '(?i)Hong Kong|\bHK\b' -and
    $_.title -match $pattern -and
    $_.state -notin @('excluded', 'rejected') -and
    $_.url
} | ForEach-Object {
    if ($_.posted) {
        $date = ([datetime]::Parse([string]$_.posted)).ToString('yyyy-MM-dd')
        $basis = 'Published_Date'
    }
    else {
        $date = ([datetime]$_.first_seen).ToString('yyyy-MM-dd')
        $basis = 'First_Seen_Date_Proxy'
    }

    New-Row ([pscustomobject]@{
        Company = $_.company
        Position = $_.title
        Location = $_.location
        Description = $_.description
        Salary_Text = ''
        Year = [int]$date.Substring(0, 4)
        Record_ID = $_.id
        Posting_Date = $date
        Year_Basis = $basis
        Program_Year = if ($_.project_years) { @($_.project_years) -join ';' } else { '' }
        Listing_Status = $_.state
        Data_Source = $_.source
        Source_URL = $_.url
    }) 'laier029/hk-career-watch/jobs.json' 'HK Career Watch'
})

$workopiaUrl = 'https://raw.githubusercontent.com/workopia/Hong-Kong-Graduate-Internship-Jobs/main/.github/scripts/listings.json'
$workopia = Invoke-RestMethod -Headers $headers -Uri $workopiaUrl

$workopiaRows = @($workopia.listings | Where-Object {
    $_.tier -eq 'Intern' -and $_.location -match 'Hong Kong'
} | ForEach-Object {
    $date = ([datetime]$_.date_posted).ToString('yyyy-MM-dd')

    New-Row ([pscustomobject]@{
        Company = $_.company_name
        Position = $_.title
        Location = $_.location
        Description = ''
        Salary_Text = $_.salary_display
        Year = [int]$date.Substring(0, 4)
        Record_ID = $_.id
        Posting_Date = $date
        Year_Basis = 'Published_Date'
        Program_Year = ''
        Listing_Status = 'Active'
        Data_Source = 'Workopia'
        Source_URL = $_.url
    }) 'workopia/Hong-Kong-Graduate-Internship-Jobs/listings.json' 'Workopia'
})

$workopiaActiveUrl = 'https://raw.githubusercontent.com/workopia/Hong-Kong-Graduate-Internship-Jobs/main/data/active.json'
$workopiaActive = Invoke-RestMethod -Headers $headers -Uri $workopiaActiveUrl
$activePattern = '(?i)\bintern\b|\binternship\b|\bco[ -]?op\b|\bplacement\b|\bsummer'
$workopiaActiveRows = @($workopiaActive.jobs.PSObject.Properties.Value | Where-Object {
    $_.location -match 'Hong Kong' -and $_.role -match $activePattern
} | ForEach-Object {
    New-Row ([pscustomobject]@{
        Company = $_.company
        Position = $_.role
        Location = $_.location
        Description = ''
        Salary_Text = ''
        Year = [int]([string]$workopiaActive.asOf).Substring(0, 4)
        Record_ID = $_.id
        Posting_Date = [string]$workopiaActive.asOf
        Year_Basis = 'Snapshot_Date_Proxy'
        Program_Year = ''
        Listing_Status = 'Active'
        Data_Source = 'Workopia_ActiveSnapshot'
        Source_URL = "https://workopia.io/jobs/$($_.id)"
    }) 'workopia/Hong-Kong-Graduate-Internship-Jobs/data/active.json' 'Workopia Active Snapshot'
})

$allRows = @($watchRows + $workopiaRows + $workopiaActiveRows)
$groups = $allRows | Group-Object {
    (($_.Company -replace '\s+', ' ').Trim().ToLowerInvariant()) + '|' +
    (($_.Position -replace '\s+', ' ').Trim().ToLowerInvariant()) + '|' +
    (($_.Location -replace '\s+', ' ').Trim().ToLowerInvariant()) + '|' +
    $_.Year
}

$uniqueRows = @($groups | ForEach-Object {
    $_.Group | Select-Object -First 1
})

$uniqueRows |
    Sort-Object Year, Company, Position |
    Export-Csv -LiteralPath $outputPath -NoTypeInformation -Encoding UTF8

Write-Output "HK Career Watch rows: $($watchRows.Count)"
Write-Output "Workopia rows: $($workopiaRows.Count)"
Write-Output "Workopia active snapshot rows: $($workopiaActiveRows.Count)"
Write-Output "Combined rows: $($allRows.Count)"
Write-Output "Unique rows written: $($uniqueRows.Count)"
$uniqueRows | Group-Object Year | Sort-Object Name | ForEach-Object {
    Write-Output "Year $($_.Name): $($_.Count)"
}
Write-Output "Output: $outputPath"
