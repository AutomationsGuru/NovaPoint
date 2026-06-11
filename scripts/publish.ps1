[CmdletBinding()]
param(
    [string]$Runtime = "win-x64",
    [switch]$SelfContained
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot "src/NovaPointWPF/NovaPointWPF.csproj"
$outputPath = Join-Path $repoRoot "out/publish/$Runtime"
$expectedExePath = Join-Path $outputPath "AutomationsGuruSPOToolkit.exe"

if (Test-Path -LiteralPath $outputPath) {
    Remove-Item -LiteralPath $outputPath -Recurse -Force
}

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

$selfContainedValue = if ($SelfContained) { "true" } else { "false" }

Write-Host "Publishing AutomationsGuru SPO Toolkit portable app to $outputPath..."
dotnet publish $projectPath `
    -c Release `
    -r $Runtime `
    --self-contained $selfContainedValue `
    -o $outputPath

if (-not (Test-Path -LiteralPath $expectedExePath -PathType Leaf)) {
    throw "Published executable was not found: $expectedExePath"
}

Write-Host "Published executable: $expectedExePath"
