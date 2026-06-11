[CmdletBinding()]
param(
    [switch]$ApproveTenantConnection,
    [string]$ApprovalReference,
    [string]$TenantId,
    [string]$ClientId,
    [string]$AppDisplayName = "PnP-ShareGate-NovaPoint",
    [switch]$UseSavedProfile,
    [string]$CertificatePath,
    [string]$CertificatePasswordPath,
    [string]$Runtime = "win-x64",
    [int]$TimeoutSeconds = 120
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

function Get-AzCliValue {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [string]$FailureMessage
    )

    $output = & az @Arguments 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($output)) {
        throw $FailureMessage
    }

    return ([string]$output).Trim()
}

if (-not $ApproveTenantConnection) {
    throw "ApproveTenantConnection is required before any tenant-connected Graph smoke."
}

if (-not (Test-ApprovalReference -Value $ApprovalReference)) {
    throw "A non-placeholder ApprovalReference is required before any tenant-connected Graph smoke."
}

if (-not (Test-Path -LiteralPath $libraryPath -PathType Leaf)) {
    throw "Published NovaPointLibrary.dll was not found. Run scripts/publish.ps1 first."
}

if (-not $UseSavedProfile) {
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        $TenantId = Get-AzCliValue -Arguments @("account", "show", "--query", "tenantId", "--output", "tsv") -FailureMessage "Azure CLI tenant context was not available."
    }

    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        $appsJson = Get-AzCliValue -Arguments @("ad", "app", "list", "--display-name", $AppDisplayName, "--query", "[].{appId:appId}", "--output", "json") -FailureMessage "Azure CLI app registration lookup was not available."
        $apps = @($appsJson | ConvertFrom-Json)
        if ($apps.Count -ne 1) {
            throw "Expected exactly one matching app registration for automatic selection. Pass ClientId explicitly for a local smoke."
        }

        $ClientId = [string]$apps[0].appId
    }

    if ([string]::IsNullOrWhiteSpace($CertificatePath) -or [string]::IsNullOrWhiteSpace($CertificatePasswordPath)) {
        $certRoot = Join-Path $env:LOCALAPPDATA "AutomationsGuru\NovaPoint\certs"
        if (-not (Test-Path -LiteralPath $certRoot -PathType Container)) {
            throw "Local certificate root was not found. Create or provide CertificatePath and CertificatePasswordPath."
        }

        if ([string]::IsNullOrWhiteSpace($CertificatePath)) {
            $latestPfx = Get-ChildItem -LiteralPath $certRoot -Filter "novapoint-appauth-*.pfx" -File |
                Sort-Object LastWriteTimeUtc -Descending |
                Select-Object -First 1

            if (-not $latestPfx) {
                throw "No local NovaPoint app-auth PFX was found. Provide CertificatePath."
            }

            $CertificatePath = $latestPfx.FullName
        }

        if ([string]::IsNullOrWhiteSpace($CertificatePasswordPath)) {
            $latestPassword = Get-ChildItem -LiteralPath $certRoot -Filter "novapoint-appauth-*.pfx-password.clixml" -File |
                Sort-Object LastWriteTimeUtc -Descending |
                Select-Object -First 1

            if (-not $latestPassword) {
                throw "No local NovaPoint app-auth PFX password file was found. Provide CertificatePasswordPath."
            }

            $CertificatePasswordPath = $latestPassword.FullName
        }
    }

    if (-not (Test-Path -LiteralPath $CertificatePath -PathType Leaf)) {
        throw "CertificatePath file was not found."
    }

    if (-not (Test-Path -LiteralPath $CertificatePasswordPath -PathType Leaf)) {
        throw "CertificatePasswordPath file was not found."
    }

    $certificatePassword = Import-Clixml -LiteralPath $CertificatePasswordPath
    if ($certificatePassword -isnot [System.Security.SecureString]) {
        throw "CertificatePasswordPath did not contain a DPAPI-protected SecureString."
    }
}

$result = [ordered]@{
    TenantConnectionAttempted = $false
    TenantMutationAttempted = $false
    SavedProfileUsed = [bool]$UseSavedProfile
    SavedPasswordFlag = $null
    PasswordProvidedInCommand = (-not $UseSavedProfile)
    RawTenantValuesPrinted = $false
    GraphSmokeStatus = "NotStarted"
    GraphObjectCount = $null
    ManifestCreated = $false
    ManifestStatus = $null
    ManifestRunMode = $null
    ManifestTenantMutationIntent = $null
    ManifestSourceMutationIntent = $null
    OutputFolderCreated = $false
    ErrorStage = $null
    ErrorType = $null
    ErrorTarget = $null
}

Push-Location $publishPath
$stage = "Initialize"
try {
    $stage = "LoadAssembly"
    $assembly = [System.Reflection.Assembly]::LoadFrom($libraryPath)

    $logInfoType = $assembly.GetType("NovaPointLibrary.Solutions.LogInfo", $true)
    $loggerType = $assembly.GetType("NovaPointLibrary.Core.Logging.LoggerSolution", $true)
    $iLoggerType = $assembly.GetType("NovaPointLibrary.Core.Logging.ILogger", $true)
    $paramType = $assembly.GetType("NovaPointLibrary.Commands.Directory.DirectoryGroupParameters", $true)
    $propsType = $assembly.GetType("NovaPointLibrary.Core.Authentication.AppClientConfidentialProperties", $true)
    $configType = $assembly.GetType("NovaPointLibrary.Core.Settings.AppConfig", $true)
    $appClientType = $assembly.GetType("NovaPointLibrary.Core.Authentication.AppClientConfidential", $true)
    $graphHandlerType = $assembly.GetType("NovaPointLibrary.Commands.Utilities.GraphAPIHandler", $true)

    $actionType = [System.Action``1].MakeGenericType($logInfoType)
    $callback = [System.Management.Automation.LanguagePrimitives]::ConvertTo({ param($logInfo) }, $actionType)

    $stage = "CreateLogger"
    $parameters = [Activator]::CreateInstance($paramType)
    $ctorFlags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $logger = [Activator]::CreateInstance($loggerType, $ctorFlags, $null, @($callback, "TenantReadonlyGraphSmokeReport", $parameters), $null)

    try {
        if ($UseSavedProfile) {
            $stage = "LoadSavedProfile"
            $getSettings = $configType.GetMethod("GetSettings", [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
            $appConfig = $getSettings.Invoke($null, @())
            $properties = @($appConfig.ListAppClientConfidentialProperties | Where-Object { $_.ClientTitle -eq $AppDisplayName })[0]
            if (-not $properties) {
                throw "Saved app-only profile was not found."
            }

            $baseProperties = $properties.PSObject.BaseObject
            if ($null -ne $baseProperties -and $propsType.IsInstanceOfType($baseProperties)) {
                $properties = $baseProperties
            }

            if (-not $propsType.IsInstanceOfType($properties)) {
                throw "Saved app-only profile could not be loaded as the expected profile type."
            }

            $result.SavedPasswordFlag = [bool]$properties.CertificatePasswordSaved
        }
        else {
            $stage = "BuildExplicitProfile"
            $properties = [Activator]::CreateInstance($propsType)
            $properties.TenantId = [Guid]$TenantId
            $properties.ClientId = [Guid]$ClientId
            $properties.CertificatePath = $CertificatePath
            $properties.Password = $certificatePassword
        }

        $stage = "CreateCancellationToken"
        $cancel = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))
        $stage = "CreateAppClient"
        $appClientConstructor = $appClientType.GetConstructor($ctorFlags, $null, @($propsType, $iLoggerType, [System.Threading.CancellationTokenSource]), $null)
        if (-not $appClientConstructor) {
            throw "App-only client constructor was not found."
        }

        $appClientArgs = [object[]]::new(3)
        $appClientArgs[0] = $properties
        $appClientArgs[1] = $logger
        $appClientArgs[2] = $cancel
        $appClient = $appClientConstructor.Invoke($appClientArgs)
        $stage = "CreateGraphHandler"
        $graphHandler = [Activator]::CreateInstance($graphHandlerType, $ctorFlags, $null, @($logger, $appClient), $null)
        $getMethod = @($graphHandlerType.GetMethods($ctorFlags) | Where-Object {
            $_.Name -eq "GetAsync" -and $_.GetParameters().Count -eq 3
        })[0]

        $stage = "InvokeGraphGet"
        $result.TenantConnectionAttempted = $true
        $task = $getMethod.Invoke($graphHandler, @("/groups?`$top=1&`$select=id", "application/json", $null))
        $json = $task.GetAwaiter().GetResult()
        $stage = "ParseGraphResponse"
        $parsed = $json | ConvertFrom-Json

        $result.GraphObjectCount = @($parsed.value).Count
        $result.GraphSmokeStatus = "Pass"
        $stage = "EndLoggerSuccess"
        $logger.End($null)
    } catch {
        $result.GraphSmokeStatus = "Fail"
        $result.ErrorStage = $stage
        $baseException = $_.Exception.GetBaseException()
        $result.ErrorType = $baseException.GetType().FullName
        if ($null -ne $baseException.TargetSite) {
            $result.ErrorTarget = $baseException.TargetSite.Name
        }
        try {
            $logger.End($baseException)
        } catch {
            # Keep console output source-safe even if failure logging fails.
        }
    }

    $folderField = $loggerType.GetField("_solutionFolderPath", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public)
    $folder = [string]$folderField.GetValue($logger)
    $result.OutputFolderCreated = [bool](Test-Path -LiteralPath $folder)

    $stage = "ReadManifest"
    $manifestPath = Get-ChildItem -LiteralPath $folder -Filter "*_RunManifest.json" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName

    if ($manifestPath) {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $result.ManifestCreated = $true
        $result.ManifestStatus = $manifest.Status
        $result.ManifestRunMode = $manifest.RunMode
        $result.ManifestTenantMutationIntent = $manifest.TenantMutationIntent
        $result.ManifestSourceMutationIntent = $manifest.SourceMutationIntent
    }
} finally {
    Pop-Location
}

[pscustomobject]$result | ConvertTo-Json -Compress
