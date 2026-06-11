# MVP Operator Runbook

This runbook covers the internal AutomationsGuru MVP build derived from
NovaPoint. It is not client execution approval.

## Install Or Run

Preferred MVP packaging is a portable publish folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

Run the published executable from:

```text
out\publish\win-x64\
```

For the MVP, the executable in that folder is
`AutomationsGuruSPOToolkit.exe`. The app display name is
`AutomationsGuru SPO Toolkit`; namespaces, library names, and NovaPoint output
roots remain unchanged until a later rename pass is separately scoped and
validated.

## Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

## App Registration And Auth

The internal MVP smoke path uses app-only certificate authentication. The
current AutomationsGuru validation registration is documented by display name in
`docs/operations/permission-matrix.md`; do not copy app IDs, tenant IDs,
certificate paths, passwords, or tokens into source-controlled docs.

Use `docs/operations/app-only-auth-runbook.md` as the persistent auth source of
truth. It defines the saved WPF profile, preflight smoke, wrong-app/401 triage,
and no-delegated-prompt rule for the MVP report workflow.

The WPF app-only profile form supports password-protected PFX files. PFX
passwords are stored locally with Windows DPAPI for the current Windows user and
are not serialized into `user.config`.

Run the saved-profile app-only Graph smoke before site-specific report testing:

```powershell
.\scripts\run-tenant-readonly-graph-smoke.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -UseSavedProfile
```

If the saved WPF profile has not been created yet, run the explicit local
certificate smoke instead:

```powershell
.\scripts\run-tenant-readonly-graph-smoke.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>"
```

The script uses local certificate material outside the repo and must report
`TenantMutationAttempted=False`.

For a new tenant, client, or Kate environment, use
`docs/operations/new-tenant-report-readiness.md` before running any smoke test.
That runbook records the approval fields, app-only auth expectation, first-pass
report set, full report set, conversion step, and troubleshooting path.

The upstream delegated setup used:

- Microsoft Graph delegated `Directory.ReadWrite.All`.
- Microsoft Graph delegated `User.Read`.
- SharePoint delegated `AllSites.FullControl`.

Those permissions are broad and are not the preferred internal MVP smoke path.
Per-solution least privilege is not verified for this MVP unless documented in
`docs/operations/permission-matrix.md`.

## Token Cache

If access-token caching is enabled, MSAL cache material stays local on the
operator machine. Do not copy token cache files into source control, support
tickets, or shared evidence packages.

## Reports

Reports are the preferred first smoke-test surface because they are intended to
be read-only. Confirm the selected scope before running any report.

Before any tenant-connected smoke test, complete
`docs/operations/sandbox-smoke-test-plan-template.md` and get Matthew approval
for the exact scope.

The bounded app-only report smoke command is:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -Reports Site,List,RecycleBin,Membership `
  -IncludeListStorageMetrics
```

If `-SiteUrl` is omitted, the script discovers the tenant root SharePoint site
from the saved app-only profile and uses that as the bounded target. See
`docs/operations/report-output-guide.md` for raw output shape, CSV schemas,
manifest review, and source-safe handling rules.

The full report set is:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -IncludePersonalSites `
  -IncludeSubsites `
  -Reports Site,OrphanSite,PrivacySite,List,Item,ShortcutOD,PHLItem,PageAssets,RecycleBin,Membership,Permissions,SharingLinks `
  -IncludeListStorageMetrics `
  -TimeoutSecondsPerReport 900
```

`Item`, `ShortcutOD`, and `Permissions` can be high-volume reports. Use
site-scoped or workload-scoped runs when the question does not need a tenant-wide
scan.

After report runs, create a sanitized summary:

```powershell
.\scripts\convert-novapoint-report-output.ps1 `
  -RunLabel "<safe-label>"
```

Use `docs/operations/report-scenario-playbook.md` to map scenarios to report
sets, commands, review steps, and follow-through actions.

## Mutation-Capable Actions

Automation actions can alter SharePoint Online or Microsoft 365 state. Do not
run them in a client tenant without a separate Matthew approval that names the
tenant, site, action, inputs, validation, evidence root, and rollback notes.

For MVP validation, first test mutation-capable forms by cancelling the
`APPROVE EXECUTE` gate. Controlled mutation testing is a separate approval path.

## Evidence

Treat output files as potentially sensitive. Keep raw evidence local and share
only sanitized summaries unless Matthew approves otherwise.

Each run writes a JSON run manifest beside the logs and reports. The manifest is
intended as the first review artifact because it records app version, solution,
run mode, timestamps, output paths, mutation intent, result status, and redacted
parameter metadata without requiring an operator to open raw logs first.

For MVP review, use `docs/engineering/mvp-evidence-package-index.md` as the
source-safe package index. It identifies which artifacts are source-controlled,
which are generated under ignored `out\` folders, and which raw evidence stays
local under the user's Documents folder.
