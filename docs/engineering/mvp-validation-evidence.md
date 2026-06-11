# MVP Validation Evidence

Created: 2026-06-10

This evidence covers source-safe local validation plus one Matthew-approved
AutomationsGuru tenant read-only app-only Graph smoke. It does not approve
tenant mutation, client data access, release publishing, installer
distribution, or code signing.

## Build

Repeatable all-in-one command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-mvp-local.ps1
```

Latest full result on 2026-06-10 after the report-suite, gate-classification,
feature-surface, report-converter, MVP packaging identity, and
source-control handoff updates:

- Build: passed.
- Dependency advisory scan: passed.
- Publish portable app: passed.
- Source safety checks: passed.
- Mutation approval gate classification smoke: passed.
- Feature surface preservation source smoke: passed.
- MVP documentation contract smoke: passed.
- Run manifest smoke: passed.
- Report converter smoke: passed.
- No-tenant WPF navigation smoke: passed.
- Final script message: `MVP local validation completed successfully.`
- Publish script message confirms the portable app is branded as
  `AutomationsGuru SPO Toolkit` and publishes
  `AutomationsGuruSPOToolkit.exe`.
- Build warning backlog remains the documented existing warning baseline:
  `361 Warning(s)`, `0 Error(s)`.

Follow-up light validation after documentation, saved-profile auth, and
navigation-smoke updates:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-mvp-local.ps1 -SkipBuild -SkipPublish -SkipVulnerabilityScan
```

Result:

- Source safety checks: passed.
- No-tenant WPF navigation smoke: passed with page-specific Reports,
  Automation, Settings, and About markers. The Settings marker is
  `New app-only certificate`, which keeps the preferred MVP auth path visible
  in the UI smoke.

Follow-up source-safety validation after strengthening the mutation-gate
classification check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-mvp-local.ps1 -SkipBuild -SkipPublish -SkipVulnerabilityScan -SkipUiSmoke
```

Result:

- Source safety checks: passed.
- Mutation approval gate classification smoke: passed.
- Run manifest smoke: passed.
- The smoke verifies every known mutation-capable solution code is registered
  for the execute gate, read-only report/directory-read codes are not registered
  for that gate, report-mode runs remain unblocked, and the run path still calls
  the approval dialog.
- Source safety also verifies solution menu navigation uses the gated
  `SolutionPreparationPage` and does not instantiate the older ungated
  `SolutionBasePage`.
- Feature surface preservation verifies the expected report, automation,
  directory, and quick-fix forms still exist, keep the expected `SolutionCode`
  and `SolutionCreate` bindings, and remain reachable from the WPF menus.
- The manifest smoke verifies a no-tenant execute-mode parameter path writes a
  manifest, records mutation intent as `Possible`, redacts URL and UPN values,
  records output files, marks the run `Succeeded`, and removes only the
  generated local smoke folder.
- The report converter smoke verifies a synthetic one-row CSV report can be
  converted to sanitized JSON and Markdown without leaking raw row values, and
  confirms the summary contract keeps `RawRowsIncluded=False`.

Follow-up build after saved-profile auth and navigation updates:

```powershell
dotnet build .\src\NovaPoint.sln -c Release --no-restore
```

Result:

- Release build succeeded.
- Final MSBuild summary: `22 Warning(s)`, `0 Error(s)`.
- Remaining warnings are existing nullable/async warning debt in the WPF
  project.

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

Result:

- Restore succeeded using the repo-local `NuGet.Config`.
- Release build succeeded.
- Final MSBuild summary: `361 Warning(s)`, `0 Error(s)`.
- Warning backlog is tracked in `docs/engineering/warning-baseline.md`.

## Package

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

Result:

- Portable publish succeeded.
- Output path: `out\publish\win-x64\`.
- Published executable: `out\publish\win-x64\AutomationsGuruSPOToolkit.exe`.

## Dependency Advisory Scan

Commands:

```powershell
dotnet list .\src\NovaPointLibrary\NovaPointLibrary.csproj package --vulnerable --include-transitive
dotnet list .\src\NovaPointWPF\NovaPointWPF.csproj package --vulnerable --include-transitive
dotnet list .\src\NovaPointConsoleTester\NovaPointConsoleTester.csproj package --vulnerable --include-transitive
```

Result:

- `NovaPointLibrary`: no vulnerable packages given the current sources.
- `NovaPointWPF`: no vulnerable packages given the current sources.
- `NovaPointConsoleTester`: no vulnerable packages given the current sources.

## No-Tenant UI Smoke

Method:

- Launched `out\publish\win-x64\AutomationsGuruSPOToolkit.exe`.
- Used Windows UI Automation against the local WPF window.
- Activated navigation with keyboard focus and space.
- Closed the process after checks.

Result:

- Window title: `AutomationsGuru SPO Toolkit`.
- Reports navigation loaded: `True`.
- Automation navigation loaded: `True`.
- Settings navigation loaded: `True`; app-only certificate profile action
  visible.
- About navigation loaded: `True`.
- No tenant login was initiated by these navigation checks.

## Manifest Smoke

Method:

- Instantiated `LoggerSolution` with local no-tenant parameters by reflection
  through `scripts\run-manifest-smoke.ps1`.
- Read the generated manifest.
- Removed only the generated smoke-test folder under the expected local
  Documents output root.

Result:

- Manifest existed: `True`.
- Run mode: `Execute`.
- Tenant mutation intent: `Possible`.
- Source mutation intent: `Possible`.
- Parameters were present: `True`.
- Sensitive URL and UPN values were redacted: `True`.
- Output files were present: `True`.
- Cleanup removed the generated smoke folder: `True`.

This smoke uses an existing compiled parameter type and does not compile a
temporary dynamic class.

## Tenant App-Only Graph Smoke

Approval:

- Matthew approved use of the configured AutomationsGuru tenant, credentials,
  and app registration on 2026-06-10 for this validation path.
- No tenant mutation was approved or attempted.

Setup:

- Target app registration display name: `PnP-ShareGate-NovaPoint`.
- The registration was corrected from delegated-only permissions to
  certificate-based application permissions.
- A local PFX was created under the operator profile outside the repo.
- The PFX password is stored in a DPAPI-protected local file outside the repo.
- The WPF app-only settings path can persist the PFX password with Windows
  DPAPI for the current Windows user. The password is not serialized into
  `user.config`.
- No app ID, tenant ID, certificate path, password, token, group name, or raw
  Graph response is recorded here.

Command:

```powershell
.\scripts\run-tenant-readonly-graph-smoke.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "Matthew-2026-06-10-apponly-graph-smoke-post-cleanup" `
  -TimeoutSeconds 120
```

Result:

- Tenant connection attempted: `True`.
- Tenant mutation attempted: `False`.
- Raw tenant values printed: `False`.
- Graph smoke status: `Pass`.
- Graph object count: `1`.
- Manifest created: `True`.
- Manifest status: `Succeeded`.
- Manifest run mode: `Report`.
- Manifest tenant mutation intent: `None`.
- Manifest source mutation intent: `None`.

Saved WPF profile command:

```powershell
.\scripts\run-tenant-readonly-graph-smoke.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "Matthew-2026-06-10-saved-profile-graph-smoke" `
  -UseSavedProfile `
  -TimeoutSeconds 120
```

Saved WPF profile result:

- Tenant connection attempted: `True`.
- Tenant mutation attempted: `False`.
- Saved profile used: `True`.
- Saved password flag: `True`.
- Password provided in command: `False`.
- Raw tenant values printed: `False`.
- Graph smoke status: `Pass`.
- Graph object count: `1`.
- Manifest created: `True`.
- Manifest status: `Succeeded`.
- Manifest run mode: `Report`.
- Manifest tenant mutation intent: `None`.
- Manifest source mutation intent: `None`.

## Tenant Read-Only Report Smokes

Approval:

- Matthew approved read-only report testing against the AutomationsGuru tenant
  on 2026-06-10.
- No report-runner tenant mutation was attempted.

Auth correction:

- SharePoint report smokes initially returned per-report `401 Unauthorized`
  rows.
- Root cause was incomplete service-principal consent: the app registration
  required SharePoint Online `Sites.FullControl.All`, but the service principal
  did not yet have the matching SharePoint Online application app-role grant.
- The missing SharePoint Online application grant was added.
- A stale Microsoft Graph delegated OAuth grant was removed.
- Post-fix verification: all required application permissions are granted,
  delegated grant count is `0`, one certificate credential is present, and no
  client secret is present.
- A SharePoint Online app-only token then contained the
  `Sites.FullControl.All` role and a minimal CSOM web read succeeded.

Command:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "Matthew-2026-06-10-automationsguru-readonly-report-smokes-post-consent" `
  -Reports Site,List,RecycleBin,Membership `
  -IncludeListStorageMetrics `
  -TimeoutSecondsPerReport 240
```

Sanitized result:

- Tenant connection attempted: `True`.
- Tenant mutation attempted by report runner: `False`.
- Saved profile used: `True`.
- Password provided in command: `False`.
- Raw tenant values printed: `False`.
- Report count: `4`.
- `Site`: manifest `Succeeded`, run mode `Report`, mutation intents `None`,
  CSV rows `1`, rows with `Remarks` `0`.
- `List`: manifest `Succeeded`, run mode `Report`, mutation intents `None`,
  CSV rows `2`, rows with `Remarks` `0`.
- `RecycleBin`: manifest `Succeeded`, run mode `Report`, mutation intents
  `None`, CSV rows `0`; no CSV was created because no matching rows were
  returned.
- `Membership`: manifest `Succeeded`, run mode `Report`, mutation intents
  `None`, CSV rows `5`, rows with `Remarks` `0`.

Raw output shape and review workflow are documented in
`docs/operations/report-output-guide.md`.

Full report-set command:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "Matthew-2026-06-10-automationsguru-full-all-report-suite" `
  -FullTenant `
  -IncludePersonalSites `
  -IncludeSubsites `
  -Reports Site,OrphanSite,PrivacySite,List,Item,ShortcutOD,PHLItem,PageAssets,RecycleBin,Membership,Permissions,SharingLinks `
  -IncludeListStorageMetrics `
  -TimeoutSecondsPerReport 900
```

Sanitized full report-set result:

| Report | Manifest | CSV files | Rows | Rows with `Remarks` | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| Site | `Succeeded` | 1 | 13 | 0 | Full tenant with personal sites and subsites |
| OrphanSite | `Succeeded` | 1 | 2 | 2 | Admin/group resolution remarks |
| PrivacySite | `Succeeded` | 1 | 13 | 0 | Full tenant privacy inventory |
| List | `Succeeded` | 1 | 35 | 0 | Storage metrics included |
| Item | `Cancelled` | 1 | 41,751 | 4 | Partial full-tenant output after timeout |
| ShortcutOD | `Succeeded` | 1 | 78,688 | 78,688 | High-noise shortcut scan; conversion required |
| PHLItem | `Succeeded` | 1 | 13 | 13 | PHL unavailable/inaccessible remarks |
| PageAssets | `Succeeded` | 2 | 84 | 5 | Used and unused asset CSVs |
| RecycleBin | `Succeeded` | 1 | 3,921 | 0 | First- and second-stage rows |
| Membership | `Succeeded` | 1 | 55 | 0 | Site buckets plus owners/members |
| Permissions | `Cancelled` | 1 | 87 | 0 | Partial full-tenant output after timeout |
| SharingLinks | `Succeeded` | 1 | 59 | 39 | Link rows plus unresolved-object remarks |

No report-runner tenant mutation was attempted. `Item` and `Permissions` are
usable as partial evidence only for this full-tenant run; rerun with a larger
timeout or narrower scope before treating them as final client evidence.

A follow-up `Item`-only full-tenant rerun with a larger timeout was started but
did not produce additional CSV or summary output after its log and CPU activity
stopped. The background process was stopped, and no additional evidence from
that rerun is used in this validation record.

Conversion command:

```powershell
.\scripts\convert-novapoint-report-output.ps1 `
  -RunLabel "validation-current-report-set"
```

Conversion result:

- Sanitized JSON summary created under `out\report-summaries\`.
- Sanitized Markdown summary created under `out\report-summaries\`.
- Report count: `12`.
- Raw rows included: `False`.
- Sensitive account/access values are collapsed into generic categories such as
  `Directory group`, `SharePoint group`, `Sharing link`, and `User`.

## Approved Test-Site Read-Only Report Suite

Approval:

- Matthew approved tenant-connected testing against the known AutomationsGuru
  test site on 2026-06-10.
- This validation used the saved app-only certificate profile
  `PnP-ShareGate-NovaPoint`.
- No report-runner tenant mutation was attempted.
- The actual site URL remains out of source-controlled documentation.

Preflight command:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-tenant-readonly-graph-smoke.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "Matthew-2026-06-10-script-testing-readonly-preflight" `
  -UseSavedProfile
```

Preflight result:

- Tenant connection attempted: `True`.
- Tenant mutation attempted: `False`.
- Saved profile used: `True`.
- Password provided in command: `False`.
- Raw tenant values printed: `False`.
- Graph smoke status: `Pass`.
- Manifest status: `Succeeded`.
- Manifest run mode: `Report`.
- Manifest mutation intents: `None`.

Site-scoped report command:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "Matthew-2026-06-10-script-testing-readonly-all-reports" `
  -SiteUrl "<approved-automationsguru-test-site-url>" `
  -IncludeListStorageMetrics `
  -IncludeSubsites `
  -BreakdownSharingInvitations `
  -TimeoutSecondsPerReport 900
```

Sanitized site-scoped result:

| Report | Manifest | CSV files | Rows | Rows with `Remarks` | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| Site | `Succeeded` | 1 | 1 | 0 | Single site scope |
| OrphanSite | `Succeeded` | 0 | 0 | 0 | No matching rows |
| PrivacySite | `Succeeded` | 1 | 1 | 1 | Group/privacy remark requires raw local review |
| List | `Succeeded` | 1 | 2 | 0 | Storage metrics included |
| Item | `Succeeded` | 1 | 17 | 0 | Site-scoped item inventory |
| ShortcutOD | `Succeeded` | 1 | 1 | 1 | Non-shortcut/missing OneDrive metadata remark |
| PHLItem | `Succeeded` | 1 | 1 | 1 | PHL unavailable/inaccessible remark |
| PageAssets | `Succeeded` | 0 | 0 | 0 | No matching rows |
| RecycleBin | `Succeeded` | 0 | 0 | 0 | No matching rows |
| Membership | `Succeeded` | 1 | 6 | 0 | Site membership buckets |
| Permissions | `Succeeded` | 1 | 6 | 0 | Site and document-library permissions |
| SharingLinks | `Succeeded` | 0 | 0 | 0 | No matching rows |

All 12 reports completed before timeout. Every run manifest recorded
`RunMode=Report`, `TenantMutationIntent=None`, and
`SourceMutationIntent=None`.

Conversion command:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\convert-novapoint-report-output.ps1 `
  -RunLabel "script-testing-20260610-readonly-all-reports"
```

Conversion result:

- Sanitized Markdown summary:
  `out\report-summaries\novapoint-report-summary-script-testing-20260610-readonly-all-reports.md`.
- Sanitized JSON summary:
  `out\report-summaries\novapoint-report-summary-script-testing-20260610-readonly-all-reports.json`.
- Report count: `12`.
- Raw rows included: `False`.
- Summary Markdown code fences were corrected in
  `scripts\convert-novapoint-report-output.ps1` after this run and the summary
  was regenerated.

## Source Checks

Focused searches confirmed:

- No remaining `using var clientContext = new ClientContext` return pattern.
- No old raw REST success response logging string.
- No old raw REST POST body logging string.
- Approval phrase `APPROVE EXECUTE` is present in the WPF run gate.
- Run manifest fields and writer are present in `LoggerSolution`.

## Remaining Approval Gates

- Additional tenant/site read-only report smoke tests require Matthew approval
  naming exact solution and scope.
- Mutation-gate smoke against a real tenant form requires separate Matthew
  approval for that tenant-connected form path.
- Controlled mutation testing requires separate Matthew approval naming scope,
  rollback, and evidence requirements.
