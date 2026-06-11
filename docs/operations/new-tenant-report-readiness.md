# New-Tenant Report Readiness Runbook

Created: 2026-06-10

Use this runbook before pointing the NovaPoint-derived AutomationsGuru SPO
Toolkit at a new AutomationsGuru, client, or Kate environment. It is designed to
keep app-only auth, report scope, raw output handling, and follow-through
persistent across sessions.

This runbook is not approval to connect to a client tenant. Matthew must approve
the exact tenant, account/app registration, site or tenant scope, report set,
evidence handling, and any mutation separately.

## Required Approval Record

Before any tenant connection, record these fields in the work packet or local
approved test manifest:

| Field | Required value |
| --- | --- |
| Tenant/environment name | Human-safe label only |
| Approval reference | Matthew-approved reference string |
| App registration/profile | Display name only; do not record IDs or secrets |
| Auth mode | App-only certificate preferred |
| Scope | Root site, named site, site batch, or full tenant |
| Reports | Exact report keys |
| Personal sites | Include or exclude |
| Subsites | Include or exclude |
| Timeout | Per-report timeout |
| Evidence handling | Raw local only or sanitized summary allowed |
| Mutation allowed | `No` unless separately approved |

## Auth Standard

Use `app-only-auth-runbook.md` as the source of truth for profile setup,
preflight smoke, wrong-app/401 triage, and the no-delegated-prompt rule.

Preferred path:

- Saved WPF app-only profile.
- Certificate-based confidential client.
- DPAPI-protected PFX password for the current Windows user.
- Application permissions documented in `permission-matrix.md`.

Avoid:

- Browser/delegated login prompts for automation/report smoke paths.
- Client secrets for this MVP path.
- Copying tenant IDs, app IDs, object IDs, certificate paths, PFX passwords, or
  tokens into source-controlled docs.

## Preflight

Run from `C:\Users\RDP\Projects\NovaPoint`.

1. Confirm repo and branch:

```powershell
git status --short --branch
```

2. Confirm the portable app exists or rebuild it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

3. Run the local validator if the package changed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-mvp-local.ps1
```

4. Run saved-profile Graph smoke after tenant approval:

```powershell
.\scripts\run-tenant-readonly-graph-smoke.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -UseSavedProfile `
  -TimeoutSeconds 120
```

Expected:

- `TenantConnectionAttempted=True`.
- `TenantMutationAttempted=False`.
- `SavedProfileUsed=True`.
- `PasswordProvidedInCommand=False`.
- `RawTenantValuesPrinted=False`.
- Graph smoke status `Pass`.
- Manifest status `Succeeded`.

Stop if this fails. Do not fall back to delegated prompts unless Matthew
explicitly changes the auth route.

## First-Pass Report Set

Use this for a new tenant when the goal is quick inventory and risk posture:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -Reports Site,List,Membership,SharingLinks `
  -IncludeListStorageMetrics `
  -TimeoutSecondsPerReport 900
```

Convert immediately:

```powershell
.\scripts\convert-novapoint-report-output.ps1 `
  -RunLabel "<tenant-safe-label>-first-pass"
```

Use the sanitized summary to decide the second pass.

## Full Report Suite

Use this only when the scope and runtime are acceptable:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -IncludePersonalSites `
  -IncludeSubsites `
  -Reports Site,OrphanSite,PrivacySite,List,Item,ShortcutOD,PHLItem,PageAssets,RecycleBin,Membership,Permissions,SharingLinks `
  -IncludeListStorageMetrics `
  -TimeoutSecondsPerReport 1800
```

Notes:

- `Item` can be long-running and should often be run by site, workload, or
  batch after the first-pass sizing review.
- `Permissions` can be long-running and should often be run against selected
  high-risk sites first.
- `ShortcutOD` can produce many non-shortcut remark rows. Use the converter's
  candidate shortcut count, not the raw row count, for triage.
- `PHLItem`, `SharingLinks`, `PageAssets`, and `OrphanSite` remark rows often
  need operator interpretation before client-facing conclusions.

## Site-Scoped Follow-Up

Use site-scoped runs when full-tenant output is too large or the question is
site-specific:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -SiteUrl "<approved-site-url>" `
  -Reports Site,List,Item,Membership,Permissions,SharingLinks `
  -IncludeListStorageMetrics `
  -TimeoutSecondsPerReport 1800
```

Do not put the site URL in source-controlled docs. Keep it in the local approved
manifest or operator notes only.

## Output Review

1. Open the latest manifest first.
2. Confirm `RunMode=Report`.
3. Confirm `TenantMutationIntent=None` and `SourceMutationIntent=None`.
4. Confirm `Status=Succeeded`, or record partial/cancelled status explicitly.
5. Convert the output.
6. Review the sanitized Markdown/JSON summary.
7. Open raw CSVs only inside the approved operator context.

Raw output root:

```text
Documents\NovaPoint\<SolutionName>\<yyMMddHHmmss>\
```

Sanitized conversion output:

```text
out\report-summaries\novapoint-report-summary-<label>.json
out\report-summaries\novapoint-report-summary-<label>.md
```

## Troubleshooting

| Symptom | Likely cause | Action |
| --- | --- | --- |
| Browser login prompt appears | Wrong profile or delegated auth path | Stop and verify saved app-only profile; do not continue with delegated prompts unless approved |
| Graph smoke fails | App-only profile, certificate, or Graph app permission issue | Fix auth/profile first; do not run reports |
| SharePoint report rows show `401` or access denied | SharePoint Online application app-role grant or site access issue | Verify SharePoint Online application grant and app-only token role claims in an operator-local diagnostic |
| Report succeeds but no CSV exists | No matching rows or dynamic CSV report wrote no records | Check manifest and logs; this can be valid for empty results |
| Report status is `Cancelled` | Timeout or manual cancellation | Treat CSV as partial evidence and rerun with narrower scope or larger timeout |
| Sanitized summary has unexpected raw values | Converter gap | Stop, delete generated summary, fix converter, rerun leakage scan |

## Follow-Through

Use `report-scenario-playbook.md` after the first-pass summary. The next action
should be scenario-driven:

- Migration sizing.
- Permission/access review.
- External sharing cleanup.
- Recycle-bin recovery or cleanup.
- Retention/Preservation Hold Library review.
- Page asset cleanup.
- OneDrive shortcut review.
- Public/private group governance.
- Orphaned ownership remediation.

Mutation is a separate approval path. Reports can identify actions, but they do
not approve removing links, deleting content, changing admins, changing version
limits, restoring/deleting recycle-bin items, or modifying sites.
