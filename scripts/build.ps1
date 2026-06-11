[CmdletBinding()]
param(
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$solutionPath = Join-Path $repoRoot "src/NovaPoint.sln"

Write-Host "Restoring NovaPoint solution..."
dotnet restore $solutionPath

Write-Host "Building NovaPoint solution in Release..."
dotnet build $solutionPath -c Release --no-restore --no-incremental

if ($Publish) {
    $publishScript = Join-Path $PSScriptRoot "publish.ps1"
    & $publishScript
}
