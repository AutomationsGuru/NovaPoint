[CmdletBinding()]
param(
    [string]$LibraryPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($LibraryPath)) {
    $candidatePaths = @(
        (Join-Path $repoRoot "out/publish/win-x64/NovaPointLibrary.dll"),
        (Join-Path $repoRoot "src/NovaPointLibrary/bin/Release/net8.0/NovaPointLibrary.dll")
    )

    $LibraryPath = @($candidatePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })[0]
}

if ([string]::IsNullOrWhiteSpace($LibraryPath) -or -not (Test-Path -LiteralPath $LibraryPath -PathType Leaf)) {
    throw "NovaPointLibrary.dll was not found. Build or publish the app before running the manifest smoke."
}

$assembly = [System.Reflection.Assembly]::LoadFrom($LibraryPath)

$siteParamType = $assembly.GetType("NovaPointLibrary.Commands.SharePoint.Site.SPOTenantSiteUrlsParameters", $true)
$parameterType = $assembly.GetType("NovaPointLibrary.Solutions.Automation.SetSiteCollectionAdminAutoParameters", $true)
$loggerType = $assembly.GetType("NovaPointLibrary.Core.Logging.LoggerSolution", $true)
$logInfoType = $assembly.GetType("NovaPointLibrary.Solutions.LogInfo", $true)

$siteParam = [Activator]::CreateInstance($siteParamType)
$siteParam.ActiveSites = $false
$fakeUrl = "https://example.invalid/sites/manifest-smoke"
$fakeEmail = ("operator" + "@" + "example.invalid")
$siteParam.SiteUrl = $fakeUrl

$parameters = [Activator]::CreateInstance($parameterType, @($siteParam))
$parameters.TargetUserUPN = $fakeEmail
$parameters.IsSiteAdmin = $true

$actionType = [System.Action``1].MakeGenericType($logInfoType)
$callback = [System.Management.Automation.LanguagePrimitives]::ConvertTo({ param($logInfo) }, $actionType)
$ctorFlags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
$logger = [Activator]::CreateInstance($loggerType, $ctorFlags, $null, @($callback, "ManifestValidationSmoke", $parameters), $null)

$endMethod = $loggerType.GetMethod("End", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::Public)
$endMethod.Invoke($logger, @($null)) | Out-Null

$folderField = $loggerType.GetField("_solutionFolderPath", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public)
$folder = [string]$folderField.GetValue($logger)
$manifestPath = Get-ChildItem -LiteralPath $folder -Filter "*_RunManifest.json" -File |
    Select-Object -First 1 -ExpandProperty FullName
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$parameterValues = @($manifest.Parameters.PSObject.Properties | ForEach-Object { [string]$_.Value })

$checks = [ordered]@{
    ManifestExists = [bool](Test-Path -LiteralPath $manifestPath -PathType Leaf)
    StatusSucceeded = $manifest.Status -eq "Succeeded"
    RunModeExecute = $manifest.RunMode -eq "Execute"
    TenantMutationPossible = $manifest.TenantMutationIntent -eq "Possible"
    SourceMutationPossible = $manifest.SourceMutationIntent -eq "Possible"
    EndedUtcPresent = [bool]$manifest.EndedUtc
    HasRedactedParameter = $parameterValues -contains "<redacted>"
    FakeUrlRedacted = -not ($parameterValues -contains $fakeUrl)
    FakeEmailRedacted = -not ($parameterValues -contains $fakeEmail)
    OutputFilesRecorded = @($manifest.OutputFiles).Count -ge 3
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })

$documentsRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
$expectedRoot = Join-Path $documentsRoot "NovaPoint\ManifestValidationSmoke"
$resolvedFolder = [System.IO.Path]::GetFullPath($folder)
$resolvedRoot = [System.IO.Path]::GetFullPath($expectedRoot)
if ($resolvedFolder.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedFolder -Recurse -Force
    $checks.CleanupRemoved = -not (Test-Path -LiteralPath $resolvedFolder)
}
else {
    throw "Refusing cleanup outside expected manifest smoke root: $resolvedFolder"
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
if ($failedChecks.Count -gt 0) {
    throw "Run manifest smoke failed checks: $($failedChecks -join ', ')"
}

$checks.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
