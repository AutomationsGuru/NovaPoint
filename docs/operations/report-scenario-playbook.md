# Report Scenario Playbook

Created: 2026-06-10

This playbook maps common SharePoint Online migration, governance, and cleanup
questions to the NovaPoint reports, commands, raw outputs, and sanitized
follow-through process. It assumes the AutomationsGuru app-only profile and
permission model documented in `mvp-operator-runbook.md` and
`permission-matrix.md`.

## Standard Process

1. Confirm the tenant, scope, and approval reference.
2. Run the app-only Graph smoke if the machine, profile, certificate, or app
   registration changed.
3. Run a bounded report set against the root site or a named approved site.
4. Run the scenario report set against the selected scope.
5. Review manifests before CSVs.
6. Convert the latest report output into sanitized summaries.
7. Use sanitized summaries for triage, tickets, briefs, and client discussions.
8. Open raw CSVs only for the approved operator investigation.
9. Record findings, assumptions, and follow-up actions in the project work
   packet or client evidence package.

Graph smoke:

```powershell
.\scripts\run-tenant-readonly-graph-smoke.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -UseSavedProfile `
  -TimeoutSeconds 120
```

Root-site report smoke:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -Reports Site,List,RecycleBin,Membership `
  -IncludeListStorageMetrics
```

Sanitized conversion:

```powershell
.\scripts\convert-novapoint-report-output.ps1 `
  -RunLabel "<safe-label>"
```

## Scenarios

| Scenario | Run these reports | Why |
| --- | --- | --- |
| Tenant inventory and migration sizing | `Site`, `List`, `Item` | Site count, template mix, storage, list/library count, file/item volume, version storage |
| Permission and access review | `Membership`, `Permissions`, `SharingLinks`, `OrphanSite` | Site admins/groups, unique permissions, sharing links, unresolved admin ownership |
| External sharing and anonymous link cleanup | `SharingLinks`, `Permissions`, `Site` | Link types, active links, missing expiration, sharing-derived access |
| Recycle-bin recovery or cleanup | `RecycleBin`, `Site`, `List` | First/second-stage items, deleted size, target site context |
| Preservation Hold Library and retention risk | `PHLItem`, `Item`, `RecycleBin` | Preserved items, version footprint, deletion posture |
| Modern page and asset cleanup | `PageAssets`, `Site`, `List` | Used page assets, unused assets, missing-object remarks |
| OneDrive shortcut migration risk | `ShortcutOD`, `Item`, `List` | Shortcut candidates, personal-site document library volume, non-shortcut noise |
| Public/private group governance | `PrivacySite`, `Site`, `Membership` | Public/private/NA counts, Teams-connected sites, owners/members |
| Orphaned ownership remediation | `OrphanSite`, `Membership`, `Permissions` | unresolved admins, admin/member buckets, site access context |
| First pass in a new client tenant | `Site`, `List`, `Membership`, `SharingLinks` | Low-friction inventory, access posture, sharing posture before heavier scans |

## Tenant Inventory And Migration Sizing

Command:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -IncludeSubsites `
  -Reports Site,List,Item `
  -IncludeListStorageMetrics `
  -TimeoutSecondsPerReport 1800
```

Use the converted output to answer:

- How many sites and subsites exist in scope?
- What site templates are in play?
- How much storage is in use?
- How many libraries/lists and files/items are in scope?
- How much version storage may affect migration duration?
- Are any reports partial because the timeout was hit?

Follow-through:

- If `Item` is partial, rerun by `-SiteUrl` for the largest or highest-risk
  sites first.
- Use `List` totals for early sizing and `Item` totals for detailed file-level
  planning.
- Keep raw item CSVs local; they contain file names and paths.

## Permission And Access Review

Command:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -IncludeSubsites `
  -Reports Membership,Permissions,SharingLinks,OrphanSite `
  -TimeoutSecondsPerReport 1800
```

Use the converted output to answer:

- Which membership buckets are populated?
- Are access rows mostly direct, inherited, SharePoint group, or sharing-link
  driven?
- Which permission levels are present?
- Are there orphan/admin resolution remarks?
- Are there active sharing links or missing expirations?

Follow-through:

- Use raw CSVs only to identify the exact approved site/list/item/user.
- Convert findings into remediation actions: owner fix, group cleanup, unique
  permission review, sharing link expiration, or client decision.
- For large tenants, run `Permissions` by site or by high-risk workload first.

## External Sharing And Anonymous Link Cleanup

Command:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -Reports SharingLinks,Permissions,Site `
  -BreakdownSharingInvitations `
  -TimeoutSecondsPerReport 1800
```

Use the converted output to answer:

- How many active links exist?
- How many links have no expiration?
- Are `Anyone` links present?
- Does permission reporting show sharing-link access rows?
- Are link rows failing because objects are missing or inaccessible?

Follow-through:

- Export a sanitized count summary for stakeholders.
- Use raw CSVs locally to identify candidate sites and items.
- Do not remove links without a separate mutation approval and rollback plan.

## Recycle Bin Recovery Or Cleanup

Command:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -Reports RecycleBin,Site,List `
  -RecycleBinDaysBack 365 `
  -IncludeListStorageMetrics
```

Use the converted output to answer:

- How many deleted items exist in first and second stage?
- What item types are present?
- How much recycle-bin storage is represented?
- Which site/list context needs raw review?

Follow-through:

- For recovery, use raw CSVs to confirm object identity and original location.
- For cleanup, get separate deletion approval; this report path is read-only.

## Preservation Hold Library And Retention Risk

Command:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -Reports PHLItem,Item,RecycleBin `
  -TimeoutSecondsPerReport 1800
```

Use the converted output to answer:

- Are Preservation Hold Library rows present?
- Are remarks mostly expected missing/inaccessible PHL cases?
- How much version/item storage is in play?
- Is recycle-bin volume relevant to retention or cleanup discussions?

Follow-through:

- Treat PHL evidence as compliance-sensitive.
- Do not change retention, deletion, or hold configuration without separate
  approval.

## Modern Page And Asset Cleanup

Command:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -Reports PageAssets,Site,List `
  -TimeoutSecondsPerReport 1800
```

Use the converted output to answer:

- How many page asset references exist?
- How many unused assets are detected?
- Are missing-object remarks present?
- Which sites should be reviewed manually before cleanup?

Follow-through:

- Use `UnusedAssetsReport.csv` locally for candidate cleanup.
- Confirm with site owners before deleting assets.

## OneDrive Shortcut Migration Risk

Command:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -IncludePersonalSites `
  -Reports ShortcutOD,Item,List `
  -TimeoutSecondsPerReport 1800
```

Use the converted output to answer:

- Are actual shortcut target sites detected?
- How much non-shortcut noise is present?
- Which personal-site document libraries need raw review?

Observed behavior:

- `ShortcutOD` scans the `Documents` library and can write large numbers of
  remark rows for files that are not OneDrive shortcuts.
- Use the converter's candidate shortcut count and remark categories before
  opening raw CSVs.

Follow-through:

- For a client migration, run by personal-site batch when the tenant is large.
- Do not treat raw `ShortcutOD` row count as shortcut count.

## Public/Private Group Governance

Command:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -Reports PrivacySite,Site,Membership
```

Use the converted output to answer:

- Which group-connected sites are public or private?
- Which sites are `NA` because they are not group-connected?
- Do owner/member buckets look populated?

Follow-through:

- Public/private changes are tenant-impacting governance actions. Capture a
  decision record and approval before changing privacy.

## First Pass In A New Client Tenant

Start with a low-friction pass:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -FullTenant `
  -Reports Site,List,Membership,SharingLinks `
  -IncludeListStorageMetrics `
  -TimeoutSecondsPerReport 900
```

Then convert:

```powershell
.\scripts\convert-novapoint-report-output.ps1 `
  -RunLabel "<client-safe-label>-first-pass"
```

Deliverables:

- Sanitized summary JSON/Markdown.
- Notes on partial/cancelled reports.
- Raw output folder paths for operator follow-up.
- Recommended second-pass report set and scope.

Do not assume app registrations, certificates, or accounts. Use the named
AutomationsGuru app-only profile and verify it with the Graph smoke before
running reports in a new tenant.
