[CmdletBinding()]
param(
    [string]$NovaPointOutputRoot = (Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) "NovaPoint"),
    [string]$OutputDirectory,
    [string[]]$Reports = @(),
    [switch]$IncludeRunning,
    [switch]$AllRuns,
    [string]$RunLabel = (Get-Date -Format "yyyyMMdd-HHmmss")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not [string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptRoot = Split-Path -Parent $scriptPath
    } else {
        $scriptRoot = (Get-Location).Path
    }
}

$repoRoot = Split-Path -Parent $scriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot "out/report-summaries"
}

function Get-HeaderFields {
    param([string]$CsvPath)

    if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
        return @()
    }

    $headerLine = Get-Content -LiteralPath $CsvPath -TotalCount 1
    if ([string]::IsNullOrWhiteSpace($headerLine)) {
        return @()
    }

    return @([regex]::Matches($headerLine, '"((?:[^"]|"")*)"') | ForEach-Object {
        $_.Groups[1].Value.Replace('""', '"')
    })
}

function ConvertTo-DecimalValue {
    param([object]$Value)

    if ($null -eq $Value) {
        return 0.0
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text) -or $text -eq "NA") {
        return 0.0
    }

    $number = 0.0
    if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return $number
    }

    if ([double]::TryParse($text, [ref]$number)) {
        return $number
    }

    return 0.0
}

function ConvertTo-SafeCategory {
    param(
        [string]$Field,
        [object]$Value
    )

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return "<blank>"
    }

    switch ($Field) {
        "AccountType" {
            if ($text -match "^Directory Group") { return "Directory group" }
            if ($text -match "^Security Group") { return "Security group" }
            if ($text -match "^SharePoint group") { return "SharePoint group" }
            if ($text -match "^User$") { return "User" }
            if ($text -match "^No users found$") { return "No users found" }
            if ($text -match "^No user access$") { return "No user access" }
            if ($text -match "^Inherits permissions$") { return "Inherits permissions" }
            return "Other account type"
        }
        "AccessType" {
            if ($text -match "^SharePoint Group") { return "SharePoint group" }
            if ($text -match "^Sharing link") { return "Sharing link" }
            if ($text -match "^Direct Permissions$") { return "Direct permissions" }
            if ($text -match "^Inherits permissions$") { return "Inherits permissions" }
            if ($text -match "^No user access$") { return "No user access" }
            return "Other access type"
        }
        default {
            return $text
        }
    }
}

function Get-ValueCounts {
    param(
        [object[]]$Rows,
        [string]$Field,
        [int]$Limit = 20
    )

    if ($Rows.Count -eq 0) {
        return @()
    }

    return @($Rows |
        Where-Object { $_.PSObject.Properties.Name -contains $Field } |
        ForEach-Object { ConvertTo-SafeCategory -Field $Field -Value $_.PSObject.Properties[$Field].Value } |
        Group-Object |
        Sort-Object -Property @{ Expression = "Count"; Descending = $true }, @{ Expression = "Name"; Descending = $false } |
        Select-Object -First $Limit |
        ForEach-Object {
            [pscustomobject]@{
                Value = if ([string]::IsNullOrWhiteSpace([string]$_.Name)) { "<blank>" } else { [string]$_.Name }
                Count = $_.Count
            }
        })
}

function Test-FieldTrue {
    param([object]$Value)
    return @("true", "yes", "1") -contains ([string]$Value).Trim().ToLowerInvariant()
}

function Get-RemarkCategory {
    param([string]$Remark)

    if ([string]::IsNullOrWhiteSpace($Remark)) {
        return "None"
    }

    $lower = $Remark.ToLowerInvariant()
    if ($lower -match "a2oextendedmetadata|extendedmetadata") {
        return "Missing or non-shortcut OneDrive metadata"
    }
    if ($lower -match "preservation hold|preservationholdlibrary") {
        return "Preservation Hold Library unavailable or inaccessible"
    }
    if ($lower -match "does not exist|not found|cannot find") {
        return "Expected object not found"
    }
    if ($lower -match "access denied|unauthoriz|forbidden|401|403") {
        return "Access denied"
    }
    if ($lower -match "group|privacy") {
        return "Group metadata unavailable"
    }

    return "Other remark"
}

function Get-RemarkCounts {
    param([object[]]$Rows)

    if ($Rows.Count -eq 0) {
        return @()
    }

    return @($Rows |
        Where-Object { $_.PSObject.Properties.Name -contains "Remarks" -and -not [string]::IsNullOrWhiteSpace([string]$_.Remarks) } |
        ForEach-Object { Get-RemarkCategory -Remark ([string]$_.Remarks) } |
        Group-Object |
        Sort-Object -Property @{ Expression = "Count"; Descending = $true }, @{ Expression = "Name"; Descending = $false } |
        ForEach-Object {
            [pscustomobject]@{
                Category = $_.Name
                Count = $_.Count
            }
        })
}

function Import-ReportCsv {
    param([string]$CsvPath)

    if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
        return @()
    }

    return @(Import-Csv -LiteralPath $CsvPath)
}

function New-FileSummary {
    param([System.IO.FileInfo]$CsvFile)

    $rows = @(Import-ReportCsv -CsvPath $CsvFile.FullName)
    $rowsWithRemarks = @($rows | Where-Object {
        $_.PSObject.Properties.Name -contains "Remarks" -and -not [string]::IsNullOrWhiteSpace([string]$_.Remarks)
    }).Count

    return [pscustomobject]@{
        FileName = $CsvFile.Name
        FileKind = ($CsvFile.Name -replace '^\w+_\d+_', '')
        RowCount = $rows.Count
        RowsWithRemarks = $rowsWithRemarks
        Headers = @(Get-HeaderFields -CsvPath $CsvFile.FullName)
        Rows = $rows
    }
}

function Get-ReportMetrics {
    param(
        [string]$Report,
        [object[]]$FileSummaries
    )

    $rows = @($FileSummaries | ForEach-Object { $_.Rows })

    switch ($Report) {
        "SiteReport" {
            return [pscustomobject]@{
                Sites = $rows.Count
                Templates = Get-ValueCounts -Rows $rows -Field "SiteTemplate"
                LockStates = Get-ValueCounts -Rows $rows -Field "LockState"
                Privacy = Get-ValueCounts -Rows $rows -Field "Privacy"
                ConnectedToTeams = @($rows | Where-Object { Test-FieldTrue $_.ConnectedToTeams }).Count
                HubSites = @($rows | Where-Object { Test-FieldTrue $_.IsHubSite }).Count
                StorageUsedGB = [math]::Round((@($rows | ForEach-Object { ConvertTo-DecimalValue $_.StorageUsedGB }) | Measure-Object -Sum).Sum, 3)
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "OrphanSiteReport" {
            return [pscustomobject]@{
                Rows = $rows.Count
                Status = Get-ValueCounts -Rows $rows -Field "Status"
                AccountTypes = Get-ValueCounts -Rows $rows -Field "AccountType"
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "PrivacySiteReport" {
            return [pscustomobject]@{
                Sites = $rows.Count
                Privacy = Get-ValueCounts -Rows $rows -Field "Privacy"
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "ListReport" {
            return [pscustomobject]@{
                Lists = $rows.Count
                ListTypes = Get-ValueCounts -Rows $rows -Field "ListType"
                Hidden = @($rows | Where-Object { Test-FieldTrue $_.Hidden }).Count
                SystemLists = @($rows | Where-Object { Test-FieldTrue $_.IsSystemList }).Count
                VersioningDisabled = @($rows | Where-Object { -not (Test-FieldTrue $_.EnableVersioning) }).Count
                RequireCheckout = @($rows | Where-Object { Test-FieldTrue $_.RequireCheckOut }).Count
                TotalFileCount = [int]((@($rows | ForEach-Object { ConvertTo-DecimalValue $_.TotalFileCount }) | Measure-Object -Sum).Sum)
                TotalSizeGB = [math]::Round((@($rows | ForEach-Object { ConvertTo-DecimalValue $_.TotalSizeGb }) | Measure-Object -Sum).Sum, 3)
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "ItemReport" {
            return [pscustomobject]@{
                Items = $rows.Count
                ItemTypes = Get-ValueCounts -Rows $rows -Field "ItemType"
                CheckedOutItems = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.FileCheckOut) -and [string]$_.FileCheckOut -ne "None" }).Count
                TotalSizeMB = [math]::Round((@($rows | ForEach-Object { ConvertTo-DecimalValue $_.ItemSizeMb }) | Measure-Object -Sum).Sum, 3)
                TotalVersionStorageMB = [math]::Round((@($rows | ForEach-Object { ConvertTo-DecimalValue $_.ItemSizeTotalMB }) | Measure-Object -Sum).Sum, 3)
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "ShortcutODReport" {
            return [pscustomobject]@{
                Rows = $rows.Count
                CandidateShortcuts = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.TargetSite) }).Count
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "PHLItemReport" {
            return [pscustomobject]@{
                Rows = $rows.Count
                ItemTypes = Get-ValueCounts -Rows $rows -Field "ItemType"
                FileTypes = Get-ValueCounts -Rows $rows -Field "FileType"
                TotalSizeMB = [math]::Round((@($rows | ForEach-Object { ConvertTo-DecimalValue $_.ItemSizeMb }) | Measure-Object -Sum).Sum, 3)
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "PageAssetsReport" {
            $pageAssetRows = @($FileSummaries | Where-Object { $_.FileKind -eq "PageAssetsReport.csv" } | ForEach-Object { $_.Rows })
            $unusedRows = @($FileSummaries | Where-Object { $_.FileKind -eq "UnusedAssetsReport.csv" } | ForEach-Object { $_.Rows })
            return [pscustomobject]@{
                UsedAssetReferences = $pageAssetRows.Count
                UnusedAssets = $unusedRows.Count
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "RecycleBinReport" {
            return [pscustomobject]@{
                Items = $rows.Count
                ItemTypes = Get-ValueCounts -Rows $rows -Field "ItemType"
                Stages = Get-ValueCounts -Rows $rows -Field "ItemState"
                TotalSizeMB = [math]::Round((@($rows | ForEach-Object { ConvertTo-DecimalValue $_.SizeMB }) | Measure-Object -Sum).Sum, 3)
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "MembershipReport" {
            return [pscustomobject]@{
                Rows = $rows.Count
                Membership = Get-ValueCounts -Rows $rows -Field "Membership"
                AccountTypes = Get-ValueCounts -Rows $rows -Field "AccountType"
                EmptyUserBuckets = @($rows | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Users) }).Count
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "PermissionsReport" {
            return [pscustomobject]@{
                Rows = $rows.Count
                LocationTypes = Get-ValueCounts -Rows $rows -Field "LocationType"
                AccessTypes = Get-ValueCounts -Rows $rows -Field "AccessType"
                AccountTypes = Get-ValueCounts -Rows $rows -Field "AccountType"
                PermissionLevels = Get-ValueCounts -Rows $rows -Field "PermissionLevels"
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        "SharingLinksReport" {
            return [pscustomobject]@{
                Rows = $rows.Count
                LinkTypes = Get-ValueCounts -Rows $rows -Field "SharingLink"
                RequiresPassword = @($rows | Where-Object { Test-FieldTrue $_.SharingLinkRequiresPassword }).Count
                ActiveLinks = @($rows | Where-Object { Test-FieldTrue $_.SharingLinkIsActive }).Count
                MissingExpiration = @($rows | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.SharingLinkExpiration) }).Count
                InvitationRows = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.InvitedTo) }).Count
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
        default {
            return [pscustomobject]@{
                Rows = $rows.Count
                RemarkCategories = Get-RemarkCounts -Rows $rows
            }
        }
    }
}

function Get-RunFolderSummary {
    param([System.IO.DirectoryInfo]$RunFolder)

    $manifestFile = Get-ChildItem -LiteralPath $RunFolder.FullName -Filter "*_RunManifest.json" -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    $manifest = $null
    if ($manifestFile) {
        $manifest = Get-Content -LiteralPath $manifestFile.FullName -Raw | ConvertFrom-Json
    }

    $csvFiles = @(Get-ChildItem -LiteralPath $RunFolder.FullName -Filter "*.csv" -File -ErrorAction SilentlyContinue)
    $fileSummaries = @($csvFiles | Sort-Object Name | ForEach-Object { New-FileSummary -CsvFile $_ })
    $rowCount = (@($fileSummaries | ForEach-Object { $_.RowCount }) | Measure-Object -Sum).Sum
    $remarks = (@($fileSummaries | ForEach-Object { $_.RowsWithRemarks }) | Measure-Object -Sum).Sum

    $publicFileSummaries = @($fileSummaries | ForEach-Object {
        [pscustomobject]@{
            FileName = $_.FileName
            FileKind = $_.FileKind
            RowCount = $_.RowCount
            RowsWithRemarks = $_.RowsWithRemarks
            Headers = $_.Headers
        }
    })

    return [pscustomobject]@{
        Report = $RunFolder.Parent.Name
        RunFolderName = $RunFolder.Name
        RunFolderPath = $RunFolder.FullName
        ManifestCreated = [bool]$manifestFile
        ManifestStatus = if ($manifest) { $manifest.Status } else { $null }
        ManifestRunMode = if ($manifest) { $manifest.RunMode } else { $null }
        TenantMutationIntent = if ($manifest) { $manifest.TenantMutationIntent } else { $null }
        SourceMutationIntent = if ($manifest) { $manifest.SourceMutationIntent } else { $null }
        StartedUtc = if ($manifest) { $manifest.StartedUtc } else { $null }
        EndedUtc = if ($manifest) { $manifest.EndedUtc } else { $null }
        CsvFileCount = $fileSummaries.Count
        RowCount = if ($null -eq $rowCount) { 0 } else { [int]$rowCount }
        RowsWithRemarks = if ($null -eq $remarks) { 0 } else { [int]$remarks }
        Files = $publicFileSummaries
        Metrics = Get-ReportMetrics -Report $RunFolder.Parent.Name -FileSummaries $fileSummaries
    }
}

function Add-MarkdownTable {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [object[]]$Rows
    )

    $Lines.Add("| Report | Run | Manifest | CSV files | Rows | Remarks | Output folder |") | Out-Null
    $Lines.Add("| --- | --- | --- | ---: | ---: | ---: | --- |") | Out-Null
    foreach ($row in $Rows) {
        $Lines.Add("| $($row.Report) | $($row.RunFolderName) | $($row.ManifestStatus) | $($row.CsvFileCount) | $($row.RowCount) | $($row.RowsWithRemarks) | ``$($row.RunFolderPath)`` |") | Out-Null
    }
}

if (-not (Test-Path -LiteralPath $NovaPointOutputRoot -PathType Container)) {
    throw "NovaPoint output root was not found: $NovaPointOutputRoot"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$knownReportDirectories = @(
    "SiteReport",
    "OrphanSiteReport",
    "PrivacySiteReport",
    "ListReport",
    "ItemReport",
    "ShortcutODReport",
    "PHLItemReport",
    "PageAssetsReport",
    "RecycleBinReport",
    "MembershipReport",
    "PermissionsReport",
    "SharingLinksReport"
)

$reportDirectories = @(Get-ChildItem -LiteralPath $NovaPointOutputRoot -Directory |
    Where-Object { $knownReportDirectories -contains $_.Name })
if ($Reports.Count -gt 0) {
    $wanted = @($Reports | ForEach-Object {
        if ($_ -like "*Report") { $_ } else { "$($_)Report" }
    })
    $reportDirectories = @($reportDirectories | Where-Object { $wanted -contains $_.Name })
}

$selectedRunFolders = @()
foreach ($reportDirectory in $reportDirectories | Sort-Object Name) {
    $runFolders = @(Get-ChildItem -LiteralPath $reportDirectory.FullName -Directory | Sort-Object Name -Descending)
    if (-not $IncludeRunning) {
        $runFolders = @($runFolders | Where-Object {
            $manifestFile = Get-ChildItem -LiteralPath $_.FullName -Filter "*_RunManifest.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $manifestFile) {
                return $false
            }
            $status = (Get-Content -LiteralPath $manifestFile.FullName -Raw | ConvertFrom-Json).Status
            return $status -ne "Running"
        })
    }

    if ($AllRuns) {
        $selectedRunFolders += $runFolders
    }
    elseif ($runFolders.Count -gt 0) {
        $selectedRunFolders += $runFolders[0]
    }
}

$summaries = @($selectedRunFolders | ForEach-Object { Get-RunFolderSummary -RunFolder $_ })
$jsonSafe = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")
    SourceRoot = $NovaPointOutputRoot
    IncludeRunning = [bool]$IncludeRunning
    AllRuns = [bool]$AllRuns
    RawRowsIncluded = $false
    Sanitized = $true
    ReportCount = $summaries.Count
    Reports = $summaries
}

$jsonPath = Join-Path $OutputDirectory "novapoint-report-summary-$RunLabel.json"
$markdownPath = Join-Path $OutputDirectory "novapoint-report-summary-$RunLabel.md"
$jsonSafe | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# NovaPoint Report Summary") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("Generated: $($jsonSafe.GeneratedAt)") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("Source root: ``$NovaPointOutputRoot``") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("This summary is sanitized. It includes counts, schemas, local output paths, and aggregate categories only. It does not include raw tenant URLs, user names, file names, item paths, sharing URLs, tokens, certificate paths, or raw CSV rows.") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Overview") | Out-Null
$lines.Add("") | Out-Null
Add-MarkdownTable -Lines $lines -Rows $summaries
$lines.Add("") | Out-Null

foreach ($summary in $summaries) {
    $lines.Add("## $($summary.Report)") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- Run folder: ``$($summary.RunFolderPath)``") | Out-Null
    $lines.Add("- Manifest: $($summary.ManifestStatus); run mode: $($summary.ManifestRunMode); tenant mutation intent: $($summary.TenantMutationIntent)") | Out-Null
    $lines.Add("- CSV files: $($summary.CsvFileCount); rows: $($summary.RowCount); rows with remarks: $($summary.RowsWithRemarks)") | Out-Null
    $lines.Add("") | Out-Null
    $summaryFiles = @($summary.Files)
    if ($summaryFiles.Count -gt 0) {
        $lines.Add("| File | Rows | Remarks | Headers |") | Out-Null
        $lines.Add("| --- | ---: | ---: | --- |") | Out-Null
        foreach ($file in $summaryFiles) {
            $headerText = ($file.Headers -join ", ")
            $lines.Add("| ``$($file.FileName)`` | $($file.RowCount) | $($file.RowsWithRemarks) | $headerText |") | Out-Null
        }
        $lines.Add("") | Out-Null
    }

    $metricJson = $summary.Metrics | ConvertTo-Json -Depth 12
    $lines.Add("Sanitized metrics:") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add('```json') | Out-Null
    $lines.Add($metricJson) | Out-Null
    $lines.Add('```') | Out-Null
    $lines.Add("") | Out-Null
}

$lines | Set-Content -LiteralPath $markdownPath -Encoding UTF8

[pscustomobject]@{
    SummaryJson = $jsonPath
    SummaryMarkdown = $markdownPath
    ReportCount = $summaries.Count
    RawRowsIncluded = $false
    Sanitized = $true
} | ConvertTo-Json -Compress
