# Report Output Guide

Created: 2026-06-10

This guide documents the source-safe shape of NovaPoint report output from the
AutomationsGuru app-only MVP path. It does not contain live tenant URLs, site
names, user names, file names, IDs, tokens, certificate paths, or raw report
rows.

## Report Runner

The repeatable report command is:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -Reports Site,OrphanSite,PrivacySite,List,Item,ShortcutOD,PHLItem,PageAssets,RecycleBin,Membership,Permissions,SharingLinks `
  -IncludeListStorageMetrics
```

If `-SiteUrl` is omitted and `-FullTenant` is not used, the script discovers the
tenant root SharePoint site from the saved app-only profile and uses that as the
bounded target. To run across the tenant, use:

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

`Item` and `Permissions` are high-volume reports. For production client work,
prefer site- or workload-scoped runs first, then broaden only when the use case
needs tenant-wide evidence.

Useful switches:

- `-SiteUrl "<approved-site-url>"` limits the report set to one approved site.
- `-FullTenant` uses NovaPoint tenant site discovery instead of a single site.
- `-IncludePersonalSites` includes OneDrive personal sites for reports that use
  the tenant-site scope.
- `-IncludeSubsites` includes subsites where the report supports it.
- `-IncludeHiddenLists` and `-IncludeSystemLists` broaden list/item/permission
  reporting.
- `-IncludeListStorageMetrics` adds list/library storage metrics.
- `-BreakdownSharingInvitations` enables sharing-link invitation breakdown.
- `-RecycleBinDaysBack <days>` bounds recycle-bin rows by delete date.
- `-TimeoutSecondsPerReport <seconds>` bounds each report run.

The script uses the saved WPF app-only profile named in the operator runbook. It
does not accept or print a password, certificate path, tenant ID, client ID,
token, raw report row, or raw Graph/SharePoint response.

## Output Location

Each report writes a timestamped folder under the current user's Documents
folder:

```text
Documents\NovaPoint\<SolutionName>\<yyMMddHHmmss>\
```

Typical files:

```text
<SolutionName>_<yyMMddHHmmss>_Logs.txt
<SolutionName>_<yyMMddHHmmss>_RunManifest.json
<SolutionName>_<yyMMddHHmmss>_Report.csv
```

Some reports use a different CSV suffix or write multiple CSVs. Some reports
only create a CSV after at least one row is written. A successful empty report
can therefore have logs and a manifest but no CSV.

## Manifest Review

Open the run manifest first. For report runs, the important fields should be:

```json
{
  "RunMode": "Report",
  "TenantMutationIntent": "None",
  "SourceMutationIntent": "None",
  "Status": "Succeeded"
}
```

If `Status` is `Cancelled` or `Running`, treat the CSV as partial evidence. This
can happen when a high-volume report reaches the per-report timeout.

## Sanitized Conversion

Use the converter before turning raw CSVs into tickets, briefs, or client-facing
materials:

```powershell
.\scripts\convert-novapoint-report-output.ps1 `
  -RunLabel "<client-or-workstream-safe-label>"
```

The converter reads the latest completed run folder for each NovaPoint report
and writes:

```text
out\report-summaries\novapoint-report-summary-<label>.json
out\report-summaries\novapoint-report-summary-<label>.md
```

The converted summaries include counts, headers, local output paths, and
aggregate categories only. They intentionally do not include raw site URLs, user
names, group names, file names, item paths, sharing URLs, tokens, certificate
paths, or raw CSV rows.

## Report Inventory

| Runner key | NovaPoint folder | CSV files | Primary use |
| --- | --- | --- | --- |
| `Site` | `SiteReport` | `*_Report.csv` | Tenant/site inventory, storage, template, hub, privacy, classification, lock state, Teams connection |
| `OrphanSite` | `OrphanSiteReport` | `*_Report.csv` | Governance review for sites whose admins cannot be resolved cleanly |
| `PrivacySite` | `PrivacySiteReport` | `*_Report.csv` | Public/private Microsoft 365 group privacy posture |
| `List` | `ListReport` | `*_Report.csv` | Library/list inventory, versioning, item counts, storage, IRM/check-out settings |
| `Item` | `ItemReport` | `*_Report.csv` | File/item inventory, size, versions, checkout, folder/file mix |
| `ShortcutOD` | `ShortcutODReport` | `*_Report.csv` | OneDrive shortcut discovery and migration risk review |
| `PHLItem` | `PHLItemReport` | `*_Report.csv` | Preservation Hold Library evidence and retention-risk review |
| `PageAssets` | `PageAssetsReport` | `*_PageAssetsReport.csv`, `*_UnusedAssetsReport.csv` | Modern page asset usage and unused asset cleanup |
| `RecycleBin` | `RecycleBinReport` | `*_Report.csv` when rows exist | Recovery/cleanup review for first- and second-stage recycle bins |
| `Membership` | `MembershipReport` | `*_Report.csv` | Site admins, SharePoint groups, Microsoft 365 group owners/members |
| `Permissions` | `PermissionsReport` | `*_Report.csv` | Site/list/item access, unique permissions, sharing-link permission surface |
| `SharingLinks` | `SharingLinksReport` | `*_Report.csv` | Sharing link inventory, link type, active state, expiration, invitation expansion |

## CSV Schemas

Raw CSV values are double-quoted. Treat every CSV as sensitive local evidence.

| Report | Headers |
| --- | --- |
| Site | `SiteTitle`, `SiteUrl`, `SiteId`, `GroupId`, `SiteTemplate`, `IsSubsite`, `ConnectedToTeams`, `TeamsChannel`, `StorageQuotaGB`, `StorageUsedGB`, `StorageWarningPercentageLevel`, `LastContentModifiedDate`, `LockState`, `IsHubSite`, `HubSiteId`, `ParentHubSiteId`, `Classification`, `SharingLinks`, `Privacy`, `Remarks` |
| OrphanSite | `SiteTitle`, `SiteUrl`, `SiteTemplate`, `AdminName`, `AdminUpnOrId`, `AdminLoginName`, `AdminEmail`, `AdminInfo`, `AccountType`, `Status`, `Remarks` |
| PrivacySite | `SiteTitle`, `SiteUrl`, `GroupId`, `Privacy`, `Remarks` |
| List | `SiteURL`, `ListTitle`, `ListType`, `ListServerRelativeUrl`, `ListID`, `Created`, `LastModified`, `TotalFileCount`, `TotalSizeGb`, `ContentApproval`, `EnableVersioning`, `AutomaticExpiration`, `MajorVersionLimit`, `ExpireAfter`, `MinorVersioning`, `MinorVersionLimit`, `RequireCheckOut`, `IRM_Emabled`, `Hidden`, `IsSystemList`, `Remarks` |
| Item | `SiteUrl`, `ListTitle`, `ListType`, `ListServerRelativeUrl`, `ItemID`, `ItemUniqueID`, `ItemTitle`, `ItemPath`, `ItemType`, `ItemCreated`, `ItemCreatedBy`, `ItemModified`, `ItemModifiedBy`, `ItemVersion`, `ItemVersionsCount`, `ItemSizeMb`, `ItemSizeTotalMB`, `FileCheckOut`, `Remarks` |
| ShortcutOD | `SiteUrl`, `ListTitle`, `ListType`, `ItemID`, `ShortcutName`, `ShortcutPath`, `TargetSite`, `Remarks` |
| PHLItem | `SiteUrl`, `ListTitle`, `ListType`, `ListServerRelativeUrl`, `ItemID`, `ItemName`, `ItemOriginalName`, `ItemType`, `FileType`, `ItemPath`, `ItemOriginalPath`, `ItemCreated`, `ItemCreatedBy`, `ItemModified`, `ItemModifiedBy`, `ItemPreserved`, `ItemVersion`, `ItemVersionsCount`, `ItemSizeMb`, `ItemSizeTotalMB`, `Remarks` |
| PageAssets | `SiteUrl`, `PageTitle`, `PageUrl`, `PageCreated`, `PageCreatedBy`, `PageModified`, `PageModifiedBy`, `SiteAssetTitle`, `SiteAssetId`, `SiteAssetUrl`, `Remarks` |
| UnusedAssets | `SiteUrl`, `SiteAssetTitle`, `SiteAssetId`, `SiteAssetUrl`, `Remarks` |
| RecycleBin | `SiteUrl`, `ItemId`, `ItemTitle`, `ItemType`, `ItemState`, `DateDeleted`, `DeletedByName`, `DeletedByEmail`, `CreatedByName`, `CreatedByEmail`, `OriginalLocation`, `SizeMB`, `Remarks` |
| Membership | `SiteTitle`, `SiteUrl`, `SiteTemplate`, `IsSubsite`, `Membership`, `AccountType`, `Users`, `Remarks` |
| Permissions | `LocationType`, `LocationName`, `LocationUrl`, `AccessType`, `GroupId`, `AccountType`, `Users`, `PermissionLevels`, `Remarks` |
| SharingLinks | `SiteTitle`, `SiteUrl`, `ListTitle`, `ListId`, `ItemId`, `ItemUniqueId`, `ItemPath`, `SharingLink`, `SharingLinkRequiresPassword`, `SharingLinkExpiration`, `SharingLinkIsActive`, `SharingLinkCreated`, `SharingLinkCreatedBy`, `SharingLinkModified`, `SharingLinkModifiedBy`, `SharingLinkUrl`, `SharingLinkShareId`, `InvitedBy`, `InvitedOn`, `InvitedTo`, `GroupId`, `GroupTitle`, `Users`, `Remarks` |

## Current AutomationsGuru Validation

Sanitized full report-set run on 2026-06-10:

| Report | Manifest | CSV files | Rows | Rows with `Remarks` | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| Site | `Succeeded` | 1 | 13 | 0 | Full tenant with personal sites and subsites |
| OrphanSite | `Succeeded` | 1 | 2 | 2 | Admin/group resolution needs review |
| PrivacySite | `Succeeded` | 1 | 13 | 0 | Full tenant privacy inventory |
| List | `Succeeded` | 1 | 35 | 0 | Storage metrics included |
| Item | `Cancelled` | 1 | 41,751 | 4 | Partial full-tenant output after 900-second timeout |
| ShortcutOD | `Succeeded` | 1 | 78,688 | 78,688 | Very noisy; converter classifies non-shortcut metadata rows |
| PHLItem | `Succeeded` | 1 | 13 | 13 | Sites without accessible PHL produce remark rows |
| PageAssets | `Succeeded` | 2 | 84 | 5 | Writes used-asset and unused-asset CSVs |
| RecycleBin | `Succeeded` | 1 | 3,921 | 0 | First- and second-stage rows |
| Membership | `Succeeded` | 1 | 55 | 0 | Includes site buckets plus owners/members |
| Permissions | `Cancelled` | 1 | 87 | 0 | Partial full-tenant output after 900-second timeout |
| SharingLinks | `Succeeded` | 1 | 59 | 39 | Link rows plus remark rows for unresolved objects |

No report-runner tenant mutation was attempted. The cancelled reports still
produced useful partial CSVs, but should be rerun with either a larger timeout
or a narrower site/list scope before using them as final client evidence.

Sanitized site-scoped report-set run on 2026-06-10:

| Report | Manifest | CSV files | Rows | Rows with `Remarks` | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| Site | `Succeeded` | 1 | 1 | 0 | Single approved test-site scope |
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

All 12 site-scoped reports completed before timeout. Use this pattern as the
first-pass validation shape for small approved test sites: app-only Graph
preflight first, then site-scoped report set, then sanitized conversion.

## Review Workflow

1. Confirm Matthew-approved tenant and scope.
2. Run the Graph/app-only smoke in the operator runbook if the machine or
   profile changed.
3. Run a bounded root-site report set first.
4. Run the selected tenant-wide or site-scoped reports.
5. Open each manifest before opening raw CSV files.
6. Confirm `RunMode=Report`, mutation intents are `None`, and status is
   `Succeeded` unless partial evidence is explicitly acceptable.
7. Run `convert-novapoint-report-output.ps1`.
8. Review sanitized summary counts, file schemas, and remark categories.
9. Open raw CSVs only for the approved investigation and keep them local.
10. Use the scenario playbook to decide the next action, not ad hoc guessing.

## Raw-To-Useful Mapping

| Report | Useful converted output |
| --- | --- |
| Site | Site count, template mix, lock states, privacy mix, Teams-connected count, hub count, storage used |
| OrphanSite | unresolved admin rows, account-type category, remark category |
| PrivacySite | public/private/NA counts |
| List | list/library mix, hidden/system counts, versioning disabled count, checkout count, total file count, total size |
| Item | item/folder/file counts, checked-out items, current size, version-storage size, remark categories |
| ShortcutOD | candidate shortcut count, non-shortcut/no-metadata remark categories |
| PHLItem | preservation-hold row count, item/file type counts, size, remark categories |
| PageAssets | used page asset references, unused asset count, missing-object remarks |
| RecycleBin | first/second-stage counts, item type counts, total recycle-bin size |
| Membership | membership bucket counts, safe account-type categories, empty user buckets |
| Permissions | location type counts, access type categories, account type categories, permission levels |
| SharingLinks | link type counts, active link count, password requirement count, missing expiration count, invitation rows |

## Handling Raw Evidence

Do not copy raw CSV rows into source, tickets, chat, or client-facing materials
without sanitization and approval. Raw report files can contain tenant URLs,
site names, user identifiers, emails, group names, file names, paths, sharing
URLs, and exception text.
