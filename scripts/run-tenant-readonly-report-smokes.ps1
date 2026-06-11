[CmdletBinding()]
param(
    [switch]$ApproveTenantConnection,
    [string]$ApprovalReference,
    [string]$AppDisplayName = "PnP-ShareGate-NovaPoint",
    [string]$SiteUrl,
    [ValidateSet("Site", "OrphanSite", "PrivacySite", "List", "Item", "ShortcutOD", "PHLItem", "PageAssets", "RecycleBin", "Membership", "Permissions", "SharingLinks")]
    [string[]]$Reports = @("Site", "OrphanSite", "PrivacySite", "List", "Item", "ShortcutOD", "PHLItem", "PageAssets", "RecycleBin", "Membership", "Permissions", "SharingLinks"),
    [switch]$FullTenant,
    [switch]$IncludePersonalSites,
    [switch]$IncludeSubsites,
    [switch]$IncludeHiddenLists,
    [switch]$IncludeSystemLists,
    [switch]$IncludeListStorageMetrics,
    [switch]$BreakdownSharingInvitations,
    [int]$RecycleBinDaysBack = 365,
    [string]$Runtime = "win-x64",
    [int]$TimeoutSecondsPerReport = 900
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$publishPath = Join-Path $repoRoot "out/publish/$Runtime"
$libraryPath = Join-Path $publishPath "NovaPointLibrary.dll"

function Test-ApprovalReference {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return ($Value -notmatch "[<>]" -and $Value -notmatch "^(APPROVAL_|PLACEHOLDER|TODO|TBD)")
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

function Get-CsvSummary {
    param([string]$Folder)

    $csvFiles = @(Get-ChildItem -LiteralPath $Folder -Filter "*.csv" -File -ErrorAction SilentlyContinue)
    if ($csvFiles.Count -eq 0) {
        return [pscustomobject]@{
            CsvCreated = $false
            CsvFileCount = 0
            RowCount = 0
            RowsWithRemarks = 0
            Headers = @()
            Files = @()
        }
    }

    $rowCount = 0
    $rowsWithRemarks = 0
    $headers = @()
    $files = @()

    foreach ($csvFile in $csvFiles) {
        $headers = @(Get-HeaderFields -CsvPath $csvFile.FullName)
        $lines = @(Get-Content -LiteralPath $csvFile.FullName)
        $fileRowCount = [Math]::Max(0, $lines.Count - 1)
        $rowCount += $fileRowCount

        $rows = @(Import-Csv -LiteralPath $csvFile.FullName)
        $fileRowsWithRemarks = 0
        foreach ($row in $rows) {
            if ($row.PSObject.Properties.Name -contains "Remarks" -and -not [string]::IsNullOrWhiteSpace([string]$row.Remarks)) {
                $rowsWithRemarks++
                $fileRowsWithRemarks++
            }
        }

        $files += [pscustomobject]@{
            FileName = $csvFile.Name
            FileKind = ($csvFile.Name -replace '^\w+_\d+_', '')
            RowCount = $fileRowCount
            RowsWithRemarks = $fileRowsWithRemarks
            Headers = $headers
        }
    }

    return [pscustomobject]@{
        CsvCreated = $true
        CsvFileCount = $csvFiles.Count
        RowCount = $rowCount
        RowsWithRemarks = $rowsWithRemarks
        Headers = $headers
        Files = $files
    }
}

function New-Instance {
    param(
        [Parameter(Mandatory)]
        [System.Reflection.Assembly]$Assembly,

        [Parameter(Mandatory)]
        [string]$TypeName
    )

    return [Activator]::CreateInstance($Assembly.GetType($TypeName, $true))
}

function Invoke-Constructor {
    param(
        [Parameter(Mandatory)]
        [type]$Type,

        [Parameter(Mandatory)]
        [type[]]$Signature,

        [Parameter(Mandatory)]
        [object[]]$Arguments
    )

    $constructor = $Type.GetConstructor($Signature)
    if (-not $constructor) {
        throw "Constructor was not found for $($Type.FullName)."
    }

    return $constructor.Invoke($Arguments)
}

function New-ReadOnlyAdminAccess {
    param([System.Reflection.Assembly]$Assembly)

    $adminAccess = New-Instance -Assembly $Assembly -TypeName "NovaPointLibrary.Commands.SharePoint.Site.SPOAdminAccessParameters"
    $adminAccess.AddAdmin = $false
    $adminAccess.RemoveAdmin = $false
    return $adminAccess
}

function New-SiteScope {
    param(
        [System.Reflection.Assembly]$Assembly,
        [string]$TargetSiteUrl,
        [bool]$Subsites,
        [bool]$TenantWide,
        [bool]$PersonalSites
    )

    $siteParam = New-Instance -Assembly $Assembly -TypeName "NovaPointLibrary.Commands.SharePoint.Site.SPOTenantSiteUrlsParameters"
    if ($TenantWide) {
        $siteParam.ActiveSites = $true
        $siteParam.IncludePersonalSite = $PersonalSites
        $siteParam.IncludeCommunication = $true
        $siteParam.IncludeTeamSite = $true
        $siteParam.IncludeTeamSiteWithTeams = $true
        $siteParam.IncludeTeamSiteWithNoGroup = $true
        $siteParam.IncludeChannels = $true
        $siteParam.IncludeClassic = $true
    }
    else {
        $siteParam.ActiveSites = $false
        $siteParam.SiteUrl = $TargetSiteUrl
    }

    $siteParam.IncludeSubsites = $Subsites
    return $siteParam
}

function New-ListScope {
    param(
        [System.Reflection.Assembly]$Assembly,
        [bool]$HiddenLists,
        [bool]$SystemLists,
        [string]$ListTitle = ""
    )

    $listsParam = New-Instance -Assembly $Assembly -TypeName "NovaPointLibrary.Commands.SharePoint.List.SPOListsParameters"
    if ([string]::IsNullOrWhiteSpace($ListTitle)) {
        $listsParam.AllLists = $true
        $listsParam.IncludeLists = $true
        $listsParam.IncludeLibraries = $true
    }
    else {
        $listsParam.AllLists = $false
        $listsParam.ListTitle = $ListTitle
    }

    $listsParam.IncludeHiddenLists = $HiddenLists
    $listsParam.IncludeSystemLists = $SystemLists
    return $listsParam
}

function New-ItemScope {
    param([System.Reflection.Assembly]$Assembly)

    $itemsParam = New-Instance -Assembly $Assembly -TypeName "NovaPointLibrary.Commands.SharePoint.Item.SPOItemsParameters"
    $itemsParam.AllItems = $true
    return $itemsParam
}

function New-PermissionsUserScope {
    param([System.Reflection.Assembly]$Assembly)

    $userParam = New-Instance -Assembly $Assembly -TypeName "NovaPointLibrary.Commands.SharePoint.User.SPOSiteUserParameters"
    $userParam.AllUsers = $true
    $userParam.IncludeExternalUsers = $true
    $userParam.IncludeEveryone = $true
    $userParam.IncludeEveryoneExceptExternal = $true
    $userParam.Detailed = $true
    return $userParam
}

function New-SharingLinksFilter {
    param([System.Reflection.Assembly]$Assembly)

    $filter = New-Instance -Assembly $Assembly -TypeName "NovaPointLibrary.Commands.SharePoint.SharingLinks.SpoSharingLinksFilter"
    $filter.IncludeAnyone = $true
    $filter.IncludeOrganization = $true
    $filter.IncludeSpecific = $true
    $filter.IncludeCanEdit = $true
    $filter.IncludeCanReview = $true
    $filter.IncludeCanNotDownload = $true
    $filter.IncludeCanView = $true
    $filter.DaysOld = 0
    return $filter
}

function New-ReportParameters {
    param(
        [System.Reflection.Assembly]$Assembly,
        [string]$Report,
        [string]$TargetSiteUrl,
        [bool]$TenantWide,
        [bool]$PersonalSites,
        [bool]$Subsites,
        [bool]$HiddenLists,
        [bool]$SystemLists,
        [bool]$ListStorageMetrics,
        [int]$RecycleDays,
        [bool]$SharingInvitationBreakdown
    )

    $adminType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.Site.SPOAdminAccessParameters", $true)
    $siteParamType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.Site.SPOTenantSiteUrlsParameters", $true)

    $adminAccess = New-ReadOnlyAdminAccess -Assembly $Assembly
    $siteParam = New-SiteScope -Assembly $Assembly -TargetSiteUrl $TargetSiteUrl -Subsites $Subsites -TenantWide $TenantWide -PersonalSites $PersonalSites

    switch ($Report) {
        "Site" {
            $siteInfoType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.SiteInformationParameters", $true)
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.SiteReportParameters", $true)
            $siteInfo = [Activator]::CreateInstance($siteInfoType)
            $siteInfo.IncludeHubInfo = $true
            $siteInfo.IncludeClassification = $true
            $siteInfo.IncludeSharingLinks = $true
            $siteInfo.IncludePrivacy = $true
            return Invoke-Constructor -Type $paramType -Signature @($siteInfoType, $adminType, $siteParamType) -Arguments @($siteInfo, $adminAccess, $siteParam)
        }
        "OrphanSite" {
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.OrphanSiteReportParameters", $true)
            return Invoke-Constructor -Type $paramType -Signature @($siteParamType) -Arguments @($siteParam)
        }
        "PrivacySite" {
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.PrivacySiteReportParameters", $true)
            $privacyParam = [Activator]::CreateInstance($paramType)
            $privacySiteParam = $privacyParam.SiteParam
            $privacySiteParam.ActiveSites = $siteParam.ActiveSites
            $privacySiteParam.SiteUrl = $siteParam.SiteUrl
            $privacySiteParam.IncludePersonalSite = $siteParam.IncludePersonalSite
            $privacySiteParam.IncludeCommunication = $siteParam.IncludeCommunication
            $privacySiteParam.IncludeTeamSite = $siteParam.IncludeTeamSite
            $privacySiteParam.IncludeTeamSiteWithTeams = $siteParam.IncludeTeamSiteWithTeams
            $privacySiteParam.IncludeTeamSiteWithNoGroup = $siteParam.IncludeTeamSiteWithNoGroup
            $privacySiteParam.IncludeChannels = $siteParam.IncludeChannels
            $privacySiteParam.IncludeClassic = $siteParam.IncludeClassic
            $privacySiteParam.IncludeSubsites = $siteParam.IncludeSubsites
            return $privacyParam
        }
        "List" {
            $listsType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.List.SPOListsParameters", $true)
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.ListReportParameters", $true)
            $listsParam = New-ListScope -Assembly $Assembly -HiddenLists $HiddenLists -SystemLists $SystemLists
            return Invoke-Constructor -Type $paramType -Signature @([bool], $adminType, $siteParamType, $listsType) -Arguments @($ListStorageMetrics, $adminAccess, $siteParam, $listsParam)
        }
        "Item" {
            $listsType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.List.SPOListsParameters", $true)
            $itemsType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.Item.SPOItemsParameters", $true)
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.ItemReportParameters", $true)
            $listsParam = New-ListScope -Assembly $Assembly -HiddenLists $HiddenLists -SystemLists $SystemLists
            $itemsParam = New-ItemScope -Assembly $Assembly
            return Invoke-Constructor -Type $paramType -Signature @($adminType, $siteParamType, $listsType, $itemsType) -Arguments @($adminAccess, $siteParam, $listsParam, $itemsParam)
        }
        "ShortcutOD" {
            $itemsType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.Item.SPOItemsParameters", $true)
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.ShortcutODReportParameters", $true)
            $itemsParam = New-ItemScope -Assembly $Assembly
            return Invoke-Constructor -Type $paramType -Signature @($adminType, $siteParamType, $itemsType) -Arguments @($adminAccess, $siteParam, $itemsParam)
        }
        "PHLItem" {
            $phlType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.PreservationHoldLibrary.SPOPreservationHoldLibraryParameters", $true)
            $listsType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.List.SPOListsParameters", $true)
            $itemsType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.Item.SPOItemsParameters", $true)
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.PHLItemReportParameters", $true)
            $phlParam = [Activator]::CreateInstance($phlType)
            $listsParam = New-ListScope -Assembly $Assembly -HiddenLists $HiddenLists -SystemLists $SystemLists
            $itemsParam = New-ItemScope -Assembly $Assembly
            return Invoke-Constructor -Type $paramType -Signature @($phlType, $adminType, $siteParamType, $listsType, $itemsType) -Arguments @($phlParam, $adminAccess, $siteParam, $listsParam, $itemsParam)
        }
        "PageAssets" {
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.PageAssetsReportParameters", $true)
            return Invoke-Constructor -Type $paramType -Signature @($adminType, $siteParamType) -Arguments @($adminAccess, $siteParam)
        }
        "RecycleBin" {
            $recycleType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.RecycleBin.SPORecycleBinItemParameters", $true)
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.RecycleBinReportParameters", $true)
            $recycleParam = [Activator]::CreateInstance($recycleType)
            $recycleParam.FirstStage = $true
            $recycleParam.SecondStage = $true
            if ($RecycleDays -gt 0) {
                $recycleParam.DeletedAfter = [DateTime]::UtcNow.AddDays(-1 * $RecycleDays)
            }

            return Invoke-Constructor -Type $paramType -Signature @($recycleType, $adminType, $siteParamType) -Arguments @($recycleParam, $adminAccess, $siteParam)
        }
        "Membership" {
            $membershipType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.MembershipParameters", $true)
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.MembershipReportParameters", $true)
            $membership = [Activator]::CreateInstance($membershipType)
            $membership.SiteAdmins = $true
            $membership.SiteOwners = $true
            $membership.SiteMembers = $true
            $membership.SiteVisitors = $true
            $membership.Owners = $true
            $membership.Members = $true
            return Invoke-Constructor -Type $paramType -Signature @($membershipType, $adminType, $siteParamType) -Arguments @($membership, $adminAccess, $siteParam)
        }
        "Permissions" {
            $userType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.User.SPOSiteUserParameters", $true)
            $listsType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.List.SPOListsParameters", $true)
            $itemsType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.Item.SPOItemsParameters", $true)
            $permissionsType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.Permission.SPOSitePermissionsCSOMParameters", $true)
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.PermissionsReportParameters", $true)
            $userParam = New-PermissionsUserScope -Assembly $Assembly
            $listsParam = New-ListScope -Assembly $Assembly -HiddenLists $HiddenLists -SystemLists $SystemLists
            $itemsParam = New-ItemScope -Assembly $Assembly
            $permissionsParam = Invoke-Constructor -Type $permissionsType -Signature @($listsType, $itemsType) -Arguments @($listsParam, $itemsParam)
            $permissionsParam.IncludeAdmins = $true
            $permissionsParam.IncludeSiteAccess = $true
            $permissionsParam.IncludeUniquePermissions = $true
            return Invoke-Constructor -Type $paramType -Signature @($userType, $adminType, $siteParamType, $permissionsType) -Arguments @($userParam, $adminAccess, $siteParam, $permissionsParam)
        }
        "SharingLinks" {
            $filterType = $Assembly.GetType("NovaPointLibrary.Commands.SharePoint.SharingLinks.SpoSharingLinksFilter", $true)
            $paramType = $Assembly.GetType("NovaPointLibrary.Solutions.Report.SharingLinksReportParameters", $true)
            $filter = New-SharingLinksFilter -Assembly $Assembly
            return Invoke-Constructor -Type $paramType -Signature @([bool], $filterType, $siteParamType, $adminType) -Arguments @($SharingInvitationBreakdown, $filter, $siteParam, $adminAccess)
        }
        default {
            throw "Unsupported report: $Report"
        }
    }
}

function New-Logger {
    param(
        [System.Reflection.Assembly]$Assembly,
        [string]$SolutionName
    )

    $logInfoType = $Assembly.GetType("NovaPointLibrary.Solutions.LogInfo", $true)
    $loggerType = $Assembly.GetType("NovaPointLibrary.Core.Logging.LoggerSolution", $true)
    $parameterType = $Assembly.GetType("NovaPointLibrary.Commands.Directory.DirectoryGroupParameters", $true)
    $parameters = [Activator]::CreateInstance($parameterType)

    $actionType = [System.Action``1].MakeGenericType($logInfoType)
    $callback = [System.Management.Automation.LanguagePrimitives]::ConvertTo({ param($logInfo) }, $actionType)
    $ctorFlags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic

    return [Activator]::CreateInstance($loggerType, $ctorFlags, $null, @($callback, $SolutionName, $parameters), $null)
}

function Get-SavedProfile {
    param(
        [System.Reflection.Assembly]$Assembly,
        [string]$DisplayName
    )

    $configType = $Assembly.GetType("NovaPointLibrary.Core.Settings.AppConfig", $true)
    $propsType = $Assembly.GetType("NovaPointLibrary.Core.Authentication.AppClientConfidentialProperties", $true)
    $getSettings = $configType.GetMethod("GetSettings", [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
    $appConfig = $getSettings.Invoke($null, @())
    $profile = @($appConfig.ListAppClientConfidentialProperties | Where-Object { $_.ClientTitle -eq $DisplayName })[0]
    if (-not $profile) {
        throw "Saved app-only profile was not found."
    }

    $baseProfile = $profile.PSObject.BaseObject
    if ($null -ne $baseProfile -and $propsType.IsInstanceOfType($baseProfile)) {
        $profile = $baseProfile
    }

    if (-not $propsType.IsInstanceOfType($profile)) {
        throw "Saved app-only profile could not be loaded as the expected profile type."
    }

    return $profile
}

function New-AppClient {
    param(
        [System.Reflection.Assembly]$Assembly,
        [object]$Profile,
        [object]$Logger,
        [int]$TimeoutSeconds
    )

    $propsType = $Assembly.GetType("NovaPointLibrary.Core.Authentication.AppClientConfidentialProperties", $true)
    $loggerInterfaceType = $Assembly.GetType("NovaPointLibrary.Core.Logging.ILogger", $true)
    $appClientType = $Assembly.GetType("NovaPointLibrary.Core.Authentication.AppClientConfidential", $true)
    $ctorFlags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $constructor = $appClientType.GetConstructor($ctorFlags, $null, @($propsType, $loggerInterfaceType, [System.Threading.CancellationTokenSource]), $null)
    if (-not $constructor) {
        throw "App-only client constructor was not found."
    }

    $args = [object[]]::new(3)
    $args[0] = $Profile
    $args[1] = $Logger
    $args[2] = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))
    return $constructor.Invoke($args)
}

function Get-DefaultRootSiteUrl {
    param(
        [System.Reflection.Assembly]$Assembly,
        [object]$Profile
    )

    $logger = New-Logger -Assembly $Assembly -SolutionName "TenantReadonlyReportSmokeDiscovery"
    try {
        $appClient = New-AppClient -Assembly $Assembly -Profile $Profile -Logger $logger -TimeoutSeconds 60
        $appClientType = $Assembly.GetType("NovaPointLibrary.Core.Authentication.AppClientConfidential", $true)
        $rootSharedUrl = [string]$appClientType.GetProperty("RootSharedUrl").GetValue($appClient)
        $logger.End($null)
        return $rootSharedUrl
    } catch {
        $baseException = $_.Exception.GetBaseException()
        try { $logger.End($baseException) } catch {}
        throw
    }
}

function Invoke-Report {
    param(
        [System.Reflection.Assembly]$Assembly,
        [object]$Profile,
        [string]$Report,
        [object]$Parameters,
        [int]$TimeoutSeconds
    )

    $ctxType = $Assembly.GetType("NovaPointLibrary.Core.Context.ContextSolution", $true)
    $solutionParametersType = $Assembly.GetType("NovaPointLibrary.Solutions.ISolutionParameters", $true)
    $solutionType = $Assembly.GetType("NovaPointLibrary.Solutions.ISolution", $true)
    $appPropertiesType = $Assembly.GetType("NovaPointLibrary.Core.Authentication.IAppClientProperties", $true)
    $handlerType = $Assembly.GetType("NovaPointLibrary.Solutions.SolutionHandler", $true)

    $reportTypeName = "NovaPointLibrary.Solutions.Report.${Report}Report"
    if ($Report -eq "RecycleBin") {
        $reportTypeName = "NovaPointLibrary.Solutions.Report.RecycleBinReport"
    }
    $reportType = $Assembly.GetType($reportTypeName, $true)
    $createMethod = $reportType.GetMethod("Create", [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
    $funcType = [System.Func``3].MakeGenericType($ctxType, $solutionParametersType, $solutionType)
    $delegate = [System.Delegate]::CreateDelegate($funcType, $createMethod)

    $constructor = $handlerType.GetConstructor(@($funcType, $solutionParametersType, $appPropertiesType))
    if (-not $constructor) {
        throw "SolutionHandler constructor was not found."
    }

    $args = [object[]]::new(3)
    $args[0] = $delegate
    $args[1] = $Parameters
    $args[2] = $Profile
    $handler = $constructor.Invoke($args)

    $task = $handlerType.GetMethod("RunSolution").Invoke($handler, @())
    $completed = $task.Wait([TimeSpan]::FromSeconds($TimeoutSeconds))
    if (-not $completed) {
        $cancelTokenSource = $handlerType.GetProperty("CancelTokenSource").GetValue($handler)
        if ($cancelTokenSource) {
            $cancelTokenSource.Cancel()
        }

        try { $null = $task.Wait([TimeSpan]::FromSeconds(30)) } catch {}
    }

    $folder = [string]$handlerType.GetProperty("SolutionFolder").GetValue($handler)
    $manifestPath = Get-ChildItem -LiteralPath $folder -Filter "*_RunManifest.json" -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    $manifest = $null
    if ($manifestPath) {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    }

    $csv = Get-CsvSummary -Folder $folder

    return [pscustomobject]@{
        Report = $Report
        CompletedBeforeTimeout = $completed
        OutputFolder = $folder
        OutputFolderCreated = [bool](Test-Path -LiteralPath $folder -PathType Container)
        ManifestCreated = [bool]$manifestPath
        ManifestStatus = if ($manifest) { $manifest.Status } else { $null }
        ManifestRunMode = if ($manifest) { $manifest.RunMode } else { $null }
        ManifestTenantMutationIntent = if ($manifest) { $manifest.TenantMutationIntent } else { $null }
        ManifestSourceMutationIntent = if ($manifest) { $manifest.SourceMutationIntent } else { $null }
        CsvCreated = $csv.CsvCreated
        CsvFileCount = $csv.CsvFileCount
        RowCount = $csv.RowCount
        RowsWithRemarks = $csv.RowsWithRemarks
        Headers = $csv.Headers
        Files = $csv.Files
    }
}

if (-not $ApproveTenantConnection) {
    throw "ApproveTenantConnection is required before any tenant-connected report smoke."
}

if (-not (Test-ApprovalReference -Value $ApprovalReference)) {
    throw "A non-placeholder ApprovalReference is required before any tenant-connected report smoke."
}

if (-not (Test-Path -LiteralPath $libraryPath -PathType Leaf)) {
    throw "Published NovaPointLibrary.dll was not found. Run scripts/publish.ps1 first."
}

Push-Location $publishPath
try {
    $assembly = [System.Reflection.Assembly]::LoadFrom($libraryPath)
    $profile = Get-SavedProfile -Assembly $assembly -DisplayName $AppDisplayName

    $targetSiteProvided = -not [string]::IsNullOrWhiteSpace($SiteUrl)
    if (-not $FullTenant -and -not $targetSiteProvided) {
        $SiteUrl = Get-DefaultRootSiteUrl -Assembly $assembly -Profile $profile
    }

    $results = @()
    foreach ($report in $Reports) {
        $parameters = New-ReportParameters `
            -Assembly $assembly `
            -Report $report `
            -TargetSiteUrl $SiteUrl `
            -TenantWide ([bool]$FullTenant) `
            -PersonalSites ([bool]$IncludePersonalSites) `
            -Subsites ([bool]$IncludeSubsites) `
            -HiddenLists ([bool]$IncludeHiddenLists) `
            -SystemLists ([bool]$IncludeSystemLists) `
            -ListStorageMetrics ([bool]$IncludeListStorageMetrics) `
            -RecycleDays $RecycleBinDaysBack `
            -SharingInvitationBreakdown ([bool]$BreakdownSharingInvitations)

        $results += Invoke-Report `
            -Assembly $assembly `
            -Profile $profile `
            -Report $report `
            -Parameters $parameters `
            -TimeoutSeconds $TimeoutSecondsPerReport
    }

    [pscustomobject]@{
        TenantConnectionAttempted = $true
        TenantMutationAttempted = $false
        FullTenant = [bool]$FullTenant
        IncludePersonalSites = [bool]$IncludePersonalSites
        IncludeSubsites = [bool]$IncludeSubsites
        IncludeHiddenLists = [bool]$IncludeHiddenLists
        IncludeSystemLists = [bool]$IncludeSystemLists
        IncludeListStorageMetrics = [bool]$IncludeListStorageMetrics
        BreakdownSharingInvitations = [bool]$BreakdownSharingInvitations
        TargetSiteProvided = $targetSiteProvided
        SavedProfileUsed = $true
        SavedPasswordFlag = [bool]$profile.CertificatePasswordSaved
        PasswordProvidedInCommand = $false
        RawTenantValuesPrinted = $false
        ApprovalReferenceRecorded = $true
        ReportCount = @($results).Count
        Reports = $results
    } | ConvertTo-Json -Compress -Depth 8
} finally {
    Pop-Location
}
