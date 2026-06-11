# Permission Matrix

This matrix starts from upstream NovaPoint setup guidance. Least-privilege
permissions are not verified yet.

## Upstream Broad Delegated Permissions

| API | Permission | Type | Status |
| --- | --- | --- | --- |
| Microsoft Graph | `Directory.ReadWrite.All` | Delegated | Upstream broad setup |
| Microsoft Graph | `User.Read` | Delegated | Upstream broad setup |
| SharePoint | `AllSites.FullControl` | Delegated | Upstream broad setup |

## MVP Rule

Do not claim a narrower permission set for a solution until it is verified
against that solution's Graph, SharePoint REST, CSOM, and tenant admin calls.

## Current AutomationsGuru App-Only Smoke Shape

Authentication setup and troubleshooting live in
`docs/operations/app-only-auth-runbook.md`.

The approved internal smoke registration uses certificate-based application
authentication. It does not use delegated scopes for the current app-only smoke.
Post-fix verification confirms zero delegated grants on the service principal.

Sanitized current application permissions:

| API | Permission | Type | Status |
| --- | --- | --- | --- |
| Microsoft Graph | `Group.Read.All` | Application | Verified for read-only Graph smoke |
| Microsoft Graph | `User.Read.All` | Application | Present; per-solution need still requires verification |
| Microsoft Graph | `Sites.FullControl.All` | Application | Present; per-solution need still requires verification |
| SharePoint Online | `Sites.FullControl.All` | Application | Verified for bounded CSOM report smoke |

The registration also has a certificate credential. Local private-key material
and password material stay outside source control.

## Per-Solution Least Privilege

| Solution Area | Current MVP Permission Position |
| --- | --- |
| Full NovaPoint report set | Verified as executable with app-only Graph and SharePoint Online application permissions; `Item` and `Permissions` can require longer or narrower runs; least privilege still requires follow-up |
| Bounded Site/List/RecycleBin/Membership reports | Verified with app-only Graph and SharePoint Online application permissions; least privilege still requires follow-up |
| Directory group lookup | Verified for read-only Graph smoke; least privilege still requires follow-up |
| Copy or duplicate files | Requires verification |
| Recycle bin actions | Requires verification |
| Sharing links actions | Requires verification |
| Site/user/admin actions | Requires verification |
| Versioning actions | Requires verification |
| Preservation Hold Library actions | Requires verification |
