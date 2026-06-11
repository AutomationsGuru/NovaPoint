# App-Only Authentication Runbook

Created: 2026-06-10

This runbook is the durable AutomationsGuru authentication path for the MVP
report workflow. It exists so future work starts from the saved application
profile and certificate path instead of ad hoc delegated browser prompts.

Do not write tenant IDs, app IDs, object IDs, certificate paths, PFX passwords,
private keys, tokens, raw Graph responses, or tenant URLs into source-controlled
docs.

## Standard Profile

The internal AutomationsGuru profile is identified by display name:

```text
PnP-ShareGate-NovaPoint
```

The MVP read-only report workflow expects this registration to use:

- Certificate-based application authentication.
- Microsoft Graph application permissions required by the report path.
- SharePoint Online application permissions required by CSOM/REST report reads.
- No delegated OAuth grants for the app-only smoke path.
- Local private-key material outside the repository.

The display name is safe to document. Numeric app, tenant, object, key, and
certificate identifiers are operator-local facts and should not be copied into
the repo.

## Local WPF Profile

In the app, open `Settings` and create or edit the app-only certificate profile
with `New app-only certificate`.

Store the PFX password through the app-only profile form. The MVP stores the PFX
password with Windows DPAPI for the current Windows user and does not serialize
the password into `user.config`.

The delegated profile button is labeled as a legacy path. Do not use delegated
browser login for the MVP report smoke unless Matthew explicitly approves that
exception.

## Preflight Smoke

Before any report run in AutomationsGuru, a new client tenant, or Kate's
environment, run the saved-profile smoke:

```powershell
.\scripts\run-tenant-readonly-graph-smoke.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -UseSavedProfile
```

Expected source-safe result:

- `Status=Pass`.
- `SavedProfileUsed=True`.
- `PasswordProvidedInCommand=False`.
- `TenantMutationAttempted=False`.
- Manifest status is `Succeeded`.

Stop if the smoke fails. Do not switch to a browser/delegated login prompt as a
workaround.

## Report Runner Dependency

The tenant report runner depends on the saved app-only profile:

```powershell
.\scripts\run-tenant-readonly-report-smokes.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -Reports Site,List,Membership,SharingLinks `
  -IncludeListStorageMetrics
```

For full tenant discovery, follow `report-output-guide.md` and
`report-scenario-playbook.md`. High-volume `Item` and `Permissions` reports may
need site-scoped reruns or a larger timeout.

## Wrong-App Or 401 Triage

If prompts appear, a `401 Unauthorized` occurs, or report rows show access
errors:

1. Stop the report workflow.
2. Confirm the saved WPF profile display name matches the standard profile.
3. Confirm the app-only Graph smoke passes with `-UseSavedProfile`.
4. Confirm the registration has certificate credentials and application
   permissions for both Microsoft Graph and SharePoint Online.
5. Confirm delegated grants are not being used for the app-only smoke path.
6. Confirm the SharePoint Online application role grant exists; Graph-only
   permissions are not enough for CSOM report reads.
7. Rerun the read-only report smoke only after the app-only smoke passes.

Record only sanitized status, command names, and result categories in source
docs. Keep raw diagnostic output local unless Matthew approves a sanitized
extract.

## New Tenant Or Client Scope

For any new tenant, including Kate's environment, use
`new-tenant-report-readiness.md` before running smoke tests. That runbook
captures approval scope, expected auth mode, first-pass reports, full report
sets, conversion, and troubleshooting.

Client tenant access is not approved by this runbook. It only defines the
repeatable authentication process once Matthew approves a specific tenant and
scope.
