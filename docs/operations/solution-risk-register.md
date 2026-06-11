# Solution Risk Register

This register classifies solution risk for the AutomationsGuru MVP. It does not
grant tenant execution approval.

| Solution | Risk Class | MVP Handling |
| --- | --- | --- |
| Site report | ReadOnlyReport | Allowed after operator scope review |
| List report | ReadOnlyReport | Allowed after operator scope review |
| Item/files report | ReadOnlyReport | Allowed after operator scope review |
| Membership report | ReadOnlyReport | Allowed after operator scope review |
| Orphan site report | ReadOnlyReport | Allowed after operator scope review |
| Page assets report | ReadOnlyReport | Allowed after operator scope review |
| Permissions report | ReadOnlyReport | May expose sensitive permission data |
| PHL item report | ReadOnlyReport | May expose compliance-sensitive data |
| Privacy site report | ReadOnlyReport | May expose privacy posture metadata |
| Recycle bin report | ReadOnlyReport | May expose deleted item metadata |
| Sharing links report | ReadOnlyReport | May expose external sharing metadata |
| Shortcut OneDrive report | ReadOnlyReport | May expose OneDrive shortcut metadata |
| Get directory group | DirectoryRead | May expose directory membership |
| ID mismatch troubleshooting | TenantAdminMutation | Can alter site collection admin state |
| Check in files | ContentMutation | Requires explicit approval |
| Clear recycle bin | ContentMutation | Requires explicit approval |
| Copy or duplicate files | ContentCopy | Requires explicit approval when not report mode |
| Remove file versions | ContentMutation | Requires explicit approval |
| Remove PHL items | ContentMutation | Requires explicit approval |
| Remove sharing links | PermissionMutation | Requires explicit approval |
| Remove sites | SiteMutation | Requires explicit approval |
| Remove site users | PermissionMutation | Requires explicit approval |
| Restore PHL items | ContentMutation | Requires explicit approval |
| Restore recycle bin items | ContentMutation | Requires explicit approval |
| Set site collection admin | TenantAdminMutation | Requires explicit approval |
| Set versioning limits | TenantAdminMutation | Requires explicit approval |

## MVP Gate Behavior

The WPF start page allows read-only reports and report-mode runs to continue
after normal form validation. Mutation-capable modules require the operator to
type `APPROVE EXECUTE` before the run starts when no `ReportMode` flag exists or
when `ReportMode` is set to false.

The MVP gate is a pre-run operator safety control. It is not a substitute for a
separately approved tenant test scope, rollback plan, or evidence review.
