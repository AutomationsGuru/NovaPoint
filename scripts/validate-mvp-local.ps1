[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$SkipPublish,
    [switch]$SkipVulnerabilityScan,
    [switch]$SkipSourceChecks,
    [switch]$SkipDocumentationChecks,
    [switch]$SkipManifestSmoke,
    [switch]$SkipReportConverterSmoke,
    [switch]$SkipUiSmoke,
    [string]$Runtime = "win-x64"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$publishPath = Join-Path $repoRoot "out/publish/$Runtime"
$publishedExe = Join-Path $publishPath "AutomationsGuruSPOToolkit.exe"
$libraryBuildPath = Join-Path $repoRoot "src/NovaPointLibrary/bin/Release/net8.0/NovaPointLibrary.dll"
$libraryPublishPath = Join-Path $publishPath "NovaPointLibrary.dll"

function Invoke-ValidationStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    Write-Host "==> $Name"
    & $Action
    Write-Host "PASS: $Name"
}

function Invoke-DotNetListVulnerable {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath
    )

    $output = & dotnet list $ProjectPath package --vulnerable --include-transitive 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $output | ForEach-Object { Write-Host $_ }
        throw "dotnet package advisory scan failed for $ProjectPath."
    }

    $joinedOutput = $output -join [Environment]::NewLine
    if ($joinedOutput -notmatch "has no vulnerable packages") {
        $output | ForEach-Object { Write-Host $_ }
        throw "Package advisory scan found vulnerable packages for $ProjectPath."
    }

    Write-Host "No vulnerable packages: $ProjectPath"
}

function Invoke-RgNoMatch {
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string[]]$Paths
    )

    $output = & rg -n $Pattern @Paths 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        $output | ForEach-Object { Write-Host $_ }
        throw "Unexpected source match found for pattern: $Pattern"
    }

    if ($exitCode -ne 1) {
        $output | ForEach-Object { Write-Host $_ }
        throw "rg failed while checking pattern: $Pattern"
    }
}

function Invoke-RgRequiredMatch {
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string[]]$Paths
    )

    $output = & rg -n $Pattern @Paths 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $output | ForEach-Object { Write-Host $_ }
        throw "Required source match was not found for pattern: $Pattern"
    }
}

function Assert-FileExists {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file is missing: $Path"
    }
}

function Assert-FileContains {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Text
    )

    Assert-FileExists -Path $Path
    $content = Get-Content -LiteralPath $Path -Raw
    if (-not $content.Contains($Text)) {
        throw "Required text was not found in ${Path}: $Text"
    }
}

function Get-WindowByProcessId {
    param(
        [Parameter(Mandatory)]
        [int]$ProcessIdValue
    )

    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessIdValue)

    for ($i = 0; $i -lt 30; $i++) {
        $window = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $window) {
            return $window
        }

        Start-Sleep -Milliseconds 500
    }

    throw "Main window was not found for process $ProcessIdValue."
}

function Find-UiElementByName {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Automation.AutomationElement]$Window,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        $Name)

    return $Window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
}

function Find-UiElementByNameAndControlType {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Automation.AutomationElement]$Window,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [System.Windows.Automation.ControlType]$ControlType
    )

    $nameCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        $Name)

    $controlTypeCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        $ControlType)

    $condition = New-Object System.Windows.Automation.AndCondition($nameCondition, $controlTypeCondition)

    return $Window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
}

function Test-UiTextExists {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Automation.AutomationElement]$Window,

        [Parameter(Mandatory)]
        [string]$Text
    )

    return $null -ne (Find-UiElementByName -Window $Window -Name $Text)
}

function Wait-UiTextExists {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Automation.AutomationElement]$Window,

        [Parameter(Mandatory)]
        [string]$Text,

        [int]$TimeoutMilliseconds = 2500
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        if (Test-UiTextExists -Window $Window -Text $Text) {
            return $true
        }

        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)

    return $false
}

function Invoke-UiKeyboardActivation {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Automation.AutomationElement]$Element
    )

    $pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) {
        ([System.Windows.Automation.SelectionItemPattern]$pattern).Select()
        Start-Sleep -Milliseconds 150
        return
    }

    $rect = $Element.Current.BoundingRectangle
    if (-not $rect.IsEmpty -and $rect.Width -gt 0 -and $rect.Height -gt 0) {
        $x = [int]($rect.Left + ($rect.Width / 2))
        $y = [int]($rect.Top + ($rect.Height / 2))

        try {
            $Element.SetFocus()
        } catch {
            # Mouse activation below is enough for visible controls.
        }
        Start-Sleep -Milliseconds 100
        [NovaPointValidationMouseInput]::SetCursorPos($x, $y) | Out-Null
        Start-Sleep -Milliseconds 50
        [NovaPointValidationMouseInput]::mouse_event(
            [NovaPointValidationMouseInput]::MouseEventLeftDown,
            0,
            0,
            0,
            [UIntPtr]::Zero)
        [NovaPointValidationMouseInput]::mouse_event(
            [NovaPointValidationMouseInput]::MouseEventLeftUp,
            0,
            0,
            0,
            [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 150
        return
    }

    $pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern, [ref]$pattern)) {
        ([System.Windows.Automation.TogglePattern]$pattern).Toggle()
        Start-Sleep -Milliseconds 150
        return
    }

    $pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        ([System.Windows.Automation.InvokePattern]$pattern).Invoke()
        Start-Sleep -Milliseconds 150
        return
    }

    $Element.SetFocus()
    Start-Sleep -Milliseconds 150
    [System.Windows.Forms.SendKeys]::SendWait(" ")
}

function Get-NovaPointLibraryPath {
    if (Test-Path -LiteralPath $libraryPublishPath -PathType Leaf) {
        return $libraryPublishPath
    }

    if (Test-Path -LiteralPath $libraryBuildPath -PathType Leaf) {
        return $libraryBuildPath
    }

    throw "NovaPointLibrary.dll was not found. Run without -SkipBuild or -SkipPublish first."
}

function Invoke-RunManifestSmoke {
    $libraryPath = Get-NovaPointLibraryPath

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        throw "PowerShell 7 (pwsh) is required for the .NET 8 run manifest smoke."
    }

    $smokeScript = Join-Path $PSScriptRoot "run-manifest-smoke.ps1"
    $output = & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $smokeScript -LibraryPath $libraryPath 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $output | ForEach-Object { Write-Host $_ }
        throw "Run manifest smoke failed."
    }

    $output | ForEach-Object { Write-Host $_ }
}

function Invoke-ReportConverterSmoke {
    $smokeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("novapoint-report-converter-smoke-" + [guid]::NewGuid().ToString("N"))
    $sourceRoot = Join-Path $smokeRoot "source"
    $summaryRoot = Join-Path $smokeRoot "summary"
    $runFolder = Join-Path $sourceRoot "SiteReport\20260610-ReportConverterSmoke"

    try {
        New-Item -ItemType Directory -Path $runFolder -Force | Out-Null

        [pscustomobject]@{
            Status = "Succeeded"
            RunMode = "Report"
            TenantMutationIntent = "None"
            SourceMutationIntent = "None"
            StartedUtc = "2026-06-10T00:00:00.0000000Z"
            EndedUtc = "2026-06-10T00:00:01.0000000Z"
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runFolder "20260610_RunManifest.json") -Encoding UTF8

        @'
"SiteTitle","SiteUrl","SiteId","GroupId","SiteTemplate","IsSubsite","ConnectedToTeams","TeamsChannel","StorageQuotaGB","StorageUsedGB","StorageWarningPercentageLevel","LastContentModifiedDate","LockState","IsHubSite","HubSiteId","ParentHubSiteId","Classification","SharingLinks","Privacy","Remarks"
"Smoke Site","https://example.invalid/sites/smoke","site-id","group-id","GROUP#0","False","False","","1","0.25","","2026-01-01","Unlock","False","","","","0","Private",""
'@ | Set-Content -LiteralPath (Join-Path $runFolder "20260610_Report.csv") -Encoding UTF8

        $converterScript = Join-Path $PSScriptRoot "convert-novapoint-report-output.ps1"
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $converterScript `
            -NovaPointOutputRoot $sourceRoot `
            -OutputDirectory $summaryRoot `
            -Reports Site `
            -RunLabel "smoke" 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $output | ForEach-Object { Write-Host $_ }
            throw "Report converter smoke failed."
        }

        $jsonPath = Join-Path $summaryRoot "novapoint-report-summary-smoke.json"
        $markdownPath = Join-Path $summaryRoot "novapoint-report-summary-smoke.md"
        if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) {
            throw "Report converter smoke did not create JSON summary."
        }
        if (-not (Test-Path -LiteralPath $markdownPath -PathType Leaf)) {
            throw "Report converter smoke did not create Markdown summary."
        }

        $summary = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
        if ($summary.ReportCount -ne 1 -or $summary.RawRowsIncluded -ne $false -or $summary.Sanitized -ne $true) {
            throw "Report converter smoke produced an unexpected summary contract."
        }

        $publicOutput = (Get-Content -LiteralPath $jsonPath -Raw) + (Get-Content -LiteralPath $markdownPath -Raw)
        if ($publicOutput -match "Smoke Site|example\.invalid/sites/smoke") {
            throw "Report converter smoke leaked raw CSV values into the sanitized summary."
        }

        Write-Host "SummaryJson=$jsonPath"
        Write-Host "SummaryMarkdown=$markdownPath"
        Write-Host "ReportCount=$($summary.ReportCount)"
        Write-Host "RawRowsIncluded=$($summary.RawRowsIncluded)"
        Write-Host "Sanitized=$($summary.Sanitized)"
    }
    finally {
        $resolvedSmokeRoot = [System.IO.Path]::GetFullPath($smokeRoot)
        $resolvedTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        $leafName = Split-Path -Leaf $resolvedSmokeRoot
        if ($resolvedSmokeRoot.StartsWith($resolvedTempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
            $leafName.StartsWith("novapoint-report-converter-smoke-", [System.StringComparison]::OrdinalIgnoreCase) -and
            (Test-Path -LiteralPath $resolvedSmokeRoot)) {
            Remove-Item -LiteralPath $resolvedSmokeRoot -Recurse -Force
        }
    }
}

Push-Location $repoRoot
try {
    if (-not $SkipBuild) {
        Invoke-ValidationStep -Name "Build" -Action {
            & (Join-Path $PSScriptRoot "build.ps1")
        }
    }

    if (-not $SkipVulnerabilityScan) {
        Invoke-ValidationStep -Name "Dependency advisory scan" -Action {
            Invoke-DotNetListVulnerable -ProjectPath ".\src\NovaPointLibrary\NovaPointLibrary.csproj"
            Invoke-DotNetListVulnerable -ProjectPath ".\src\NovaPointWPF\NovaPointWPF.csproj"
            Invoke-DotNetListVulnerable -ProjectPath ".\src\NovaPointConsoleTester\NovaPointConsoleTester.csproj"
        }
    }

    if (-not $SkipPublish) {
        Invoke-ValidationStep -Name "Publish portable app" -Action {
            & (Join-Path $PSScriptRoot "publish.ps1") -Runtime $Runtime
        }
    }

    if (-not $SkipSourceChecks) {
        Invoke-ValidationStep -Name "Source safety checks" -Action {
            if ($null -eq (Get-Command rg -ErrorAction SilentlyContinue)) {
                throw "ripgrep (rg) is required for source safety checks."
            }

            Invoke-RgNoMatch `
                -Pattern "using var clientContext = new ClientContext" `
                -Paths @("src\NovaPointLibrary")

            Invoke-RgNoMatch `
                -Pattern "Successful response \{|with content '\{|response content: \{responseContent\}|Redacted response summary|responseSummary" `
                -Paths @("src\NovaPointLibrary\Core\HttpService", "src\NovaPointLibrary\Commands\Utilities")

            Invoke-RgRequiredMatch `
                -Pattern "APPROVE EXECUTE" `
                -Paths @("src\NovaPointWPF\Pages\Solutions\SolutionPreparationPage.xaml.cs")

            Invoke-RgRequiredMatch `
                -Pattern "RunManifest|WriteRunManifest|ParameterRedactionPolicy" `
                -Paths @("src\NovaPointLibrary\Core\Logging")

            Invoke-RgNoMatch `
                -Pattern "new SolutionBasePage" `
                -Paths @("src\NovaPointWPF")

            Invoke-RgRequiredMatch `
                -Pattern "new SolutionPreparationPage" `
                -Paths @("src\NovaPointWPF\Pages\Menus")
        }

        Invoke-ValidationStep -Name "Mutation approval gate classification smoke" -Action {
            $gateSourcePath = "src\NovaPointWPF\Pages\Solutions\SolutionPreparationPage.xaml.cs"
            $gateSource = Get-Content -LiteralPath $gateSourcePath -Raw

            $requiredMutationCodes = @(
                "CheckInFileAuto",
                "ClearRecycleBinAuto",
                "CopyDuplicateFileAuto",
                "IdMismatchTrouble",
                "RemoveFileVersionAuto",
                "RemovePHLItemAuto",
                "RemoveSharingLinksAuto",
                "RemoveSiteAuto",
                "RemoveSiteUserAuto",
                "RestorePHLItemAuto",
                "RestoreRecycleBinAuto",
                "SetSiteCollectionAdminAuto",
                "SetVersioningLimitAuto"
            )

            $readOnlyCodes = @(
                "SiteReport",
                "ListReport",
                "ItemReport",
                "MembershipReport",
                "OrphanSiteReport",
                "PageAssetsReport",
                "PermissionsReport",
                "PHLItemReport",
                "PrivacySiteReport",
                "RecycleBinReport",
                "SharingLinksReport",
                "ShortcutODReport",
                "GetDirectoryGroup"
            )

            foreach ($solutionCode in $requiredMutationCodes) {
                if ($gateSource -notmatch [regex]::Escape("`"$solutionCode`"")) {
                    throw "Mutation-capable solution is missing from the approval gate list: $solutionCode"
                }
            }

            foreach ($solutionCode in $readOnlyCodes) {
                if ($gateSource -match [regex]::Escape("`"$solutionCode`"")) {
                    throw "Read-only or directory-read solution is unexpectedly blocked by the execute gate: $solutionCode"
                }
            }

            if ($gateSource -notmatch "return reportMode != true;") {
                throw "Approval gate no longer permits mutation-capable report-mode runs without execute approval."
            }

            if ($gateSource -notmatch "ShowExecutionApprovalDialog\(\)") {
                throw "Run path no longer calls the execution approval dialog."
            }
        }

        Invoke-ValidationStep -Name "Feature surface preservation source smoke" -Action {
            $expectedSolutions = @(
                @{ Solution = "SiteReport"; Form = "SiteReportForm" },
                @{ Solution = "OrphanSiteReport"; Form = "OrphanSiteReportForm" },
                @{ Solution = "PrivacySiteReport"; Form = "PrivacySiteReportForm" },
                @{ Solution = "ListReport"; Form = "ListReportForm" },
                @{ Solution = "ItemReport"; Form = "ItemReportForm" },
                @{ Solution = "ShortcutODReport"; Form = "ShortcutODReportForm" },
                @{ Solution = "PHLItemReport"; Form = "PHLItemReportForm" },
                @{ Solution = "PageAssetsReport"; Form = "PageAssetsReportForm" },
                @{ Solution = "RecycleBinReport"; Form = "RecycleBinReportForm" },
                @{ Solution = "MembershipReport"; Form = "MembershipReportForm" },
                @{ Solution = "PermissionsReport"; Form = "PermissionsReportForm" },
                @{ Solution = "SharingLinksReport"; Form = "SharingLinksReportForm" },
                @{ Solution = "CheckInFileAuto"; Form = "CheckInFileAutoForm" },
                @{ Solution = "ClearRecycleBinAuto"; Form = "ClearRecycleBinAutoForm" },
                @{ Solution = "CopyDuplicateFileAuto"; Form = "CopyDuplicateFileAutoForm" },
                @{ Solution = "RemoveFileVersionAuto"; Form = "RemoveFileVersionAutoForm" },
                @{ Solution = "RemovePHLItemAuto"; Form = "RemovePHLItemAutoForm" },
                @{ Solution = "RemoveSharingLinksAuto"; Form = "RemoveSharingLinksAutoForm" },
                @{ Solution = "RemoveSiteAuto"; Form = "RemoveSiteAutoForm" },
                @{ Solution = "RemoveSiteUserAuto"; Form = "RemoveSiteUserAutoForm" },
                @{ Solution = "RestorePHLItemAuto"; Form = "RestorePHLItemAutoForm" },
                @{ Solution = "RestoreRecycleBinAuto"; Form = "RestoreRecycleBinAutoForm" },
                @{ Solution = "SetSiteCollectionAdminAuto"; Form = "SetSiteCollectionAdminAutoForm" },
                @{ Solution = "SetVersioningLimitAuto"; Form = "SetVersioningLimitAutoForm" },
                @{ Solution = "GetDirectoryGroup"; Form = "GetDirectoryGroupForm" },
                @{ Solution = "IdMismatchTrouble"; Form = "IdMismatchTroubleForm" }
            )

            $menuSource = (Get-ChildItem -LiteralPath "src\NovaPointWPF\Pages\Menus" -Filter "*.xaml.cs" -File |
                ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join [Environment]::NewLine

            foreach ($entry in $expectedSolutions) {
                $solution = [string]$entry.Solution
                $form = [string]$entry.Form
                $formFile = Get-ChildItem -Path "src\NovaPointWPF\Pages\Solutions" -Recurse -Filter "$form.xaml.cs" -File |
                    Select-Object -First 1

                if (-not $formFile) {
                    throw "Expected solution form is missing: $form for $solution."
                }

                $formSource = Get-Content -LiteralPath $formFile.FullName -Raw
                $solutionRegex = [regex]::Escape($solution)
                $formRegex = [regex]::Escape($form)

                if ($formSource -notmatch "SolutionCode\s*=\s*nameof\($solutionRegex\)") {
                    throw "Solution form no longer binds the expected solution code: $form -> $solution."
                }

                if ($formSource -notmatch "SolutionCreate\s*=\s*$solutionRegex\.Create") {
                    throw "Solution form no longer binds the expected factory: $form -> $solution.Create."
                }

                if ($menuSource -notmatch "new\s+$formRegex\s*\(") {
                    throw "Solution form is not routed from a menu: $form."
                }
            }
        }
    }

    if (-not $SkipDocumentationChecks) {
        Invoke-ValidationStep -Name "MVP documentation contract smoke" -Action {
            $requiredDocs = @(
                "NOTICE.md",
                "README.md",
                "docs\engineering\mvp-evidence-package-index.md",
                "docs\engineering\mvp-plan-completion-audit.md",
                "docs\engineering\mvp-requirements-traceability.md",
                "docs\engineering\mvp-review-checklist.md",
                "docs\engineering\mvp-source-control-handoff.md",
                "docs\engineering\mvp-validation-evidence.md",
                "docs\engineering\post-mvp-roadmap.md",
                "docs\engineering\warning-baseline.md",
                "docs\operations\app-only-auth-runbook.md",
                "docs\operations\evidence-output-contract.md",
                "docs\operations\mvp-operator-runbook.md",
                "docs\operations\new-tenant-report-readiness.md",
                "docs\operations\permission-matrix.md",
                "docs\operations\report-output-guide.md",
                "docs\operations\report-scenario-playbook.md",
                "docs\operations\sandbox-smoke-test-plan-template.md",
                "docs\operations\solution-risk-register.md",
                "docs\packaging\installer-assessment.md"
            )

            foreach ($doc in $requiredDocs) {
                Assert-FileExists -Path $doc
            }

            Assert-FileContains -Path "README.md" -Text "AutomationsGuru SPO Toolkit (NovaPoint-derived)"
            Assert-FileContains -Path "README.md" -Text "AutomationsGuruSPOToolkit.exe"
            Assert-FileContains -Path "README.md" -Text "docs/operations/new-tenant-report-readiness.md"

            Assert-FileContains -Path "src\NovaPointWPF\NovaPointWPF.csproj" -Text "<AssemblyName>AutomationsGuruSPOToolkit</AssemblyName>"
            Assert-FileContains -Path "src\NovaPointWPF\NovaPointWPF.csproj" -Text "<Product>AutomationsGuru SPO Toolkit</Product>"
            Assert-FileContains -Path "scripts\publish.ps1" -Text "AutomationsGuruSPOToolkit.exe"

            $reportKeys = @(
                "Site",
                "OrphanSite",
                "PrivacySite",
                "List",
                "Item",
                "ShortcutOD",
                "PHLItem",
                "PageAssets",
                "RecycleBin",
                "Membership",
                "Permissions",
                "SharingLinks"
            )

            foreach ($reportKey in $reportKeys) {
                Assert-FileContains -Path "docs\operations\report-output-guide.md" -Text "``$reportKey``"
                Assert-FileContains -Path "scripts\run-tenant-readonly-report-smokes.ps1" -Text "`"$reportKey`""
            }

            Assert-FileContains -Path "docs\operations\report-output-guide.md" -Text "Documents\NovaPoint\<SolutionName>\<yyMMddHHmmss>\"
            Assert-FileContains -Path "docs\engineering\mvp-validation-evidence.md" -Text "RawRowsIncluded=False"
            Assert-FileContains -Path "docs\operations\report-scenario-playbook.md" -Text "Do not assume app registrations, certificates, or accounts."
            Assert-FileContains -Path "docs\operations\app-only-auth-runbook.md" -Text "Do not switch to a browser/delegated login prompt"
            Assert-FileContains -Path "docs\operations\new-tenant-report-readiness.md" -Text "Kate"
            Assert-FileContains -Path "docs\engineering\mvp-requirements-traceability.md" -Text "9.2 Final MVP review with Matthew"
            Assert-FileContains -Path "docs\engineering\mvp-evidence-package-index.md" -Text "Requirements traceability"
            Assert-FileContains -Path "docs\engineering\mvp-source-control-handoff.md" -Text "Do not stage"
        }
    }

    if (-not $SkipManifestSmoke) {
        Invoke-ValidationStep -Name "Run manifest smoke" -Action {
            Invoke-RunManifestSmoke
        }
    }

    if (-not $SkipReportConverterSmoke) {
        Invoke-ValidationStep -Name "Report converter smoke" -Action {
            Invoke-ReportConverterSmoke
        }
    }

    if (-not $SkipUiSmoke) {
        Invoke-ValidationStep -Name "No-tenant WPF navigation smoke" -Action {
            if (-not (Test-Path -LiteralPath $publishedExe)) {
                throw "Published executable missing: $publishedExe. Run without -SkipPublish first."
            }

            Add-Type -AssemblyName UIAutomationClient
            Add-Type -AssemblyName UIAutomationTypes
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class NovaPointValidationMouseInput
{
    public const uint MouseEventLeftDown = 0x0002;
    public const uint MouseEventLeftUp = 0x0004;

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
}
"@

            $process = Start-Process -FilePath $publishedExe -PassThru
            try {
                $window = Get-WindowByProcessId -ProcessIdValue $process.Id

                if ($window.Current.Name -ne "AutomationsGuru SPO Toolkit") {
                    throw "Unexpected window title: $($window.Current.Name)"
                }

                $targets = @(
                    @{ Nav = "Reports"; Expect = "All Site Collections and Subsites" },
                    @{ Nav = "Automation"; Expect = "Set or Remove a User as Site Collection Admin" },
                    @{ Nav = "Settings"; Expect = "New app-only certificate" },
                    @{ Nav = "About"; Expect = "AutomationsGuru SharePoint Online toolkit" }
                )

                foreach ($target in $targets) {
                    $element = Find-UiElementByNameAndControlType `
                        -Window $window `
                        -Name $target.Nav `
                        -ControlType ([System.Windows.Automation.ControlType]::RadioButton)
                    if ($null -eq $element) {
                        throw "Navigation element was not found: $($target.Nav)"
                    }

                    Invoke-UiKeyboardActivation -Element $element

                    if (-not (Wait-UiTextExists -Window $window -Text $target.Expect)) {
                        throw "Expected text '$($target.Expect)' was not found after opening '$($target.Nav)'."
                    }
                }
            }
            finally {
                if ($process -and -not $process.HasExited) {
                    Stop-Process -Id $process.Id -Force
                }
            }
        }
    }
}
finally {
    Pop-Location
}

Write-Host "MVP local validation completed successfully."
