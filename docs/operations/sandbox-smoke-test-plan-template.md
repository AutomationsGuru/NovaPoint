# Sandbox Smoke Test Plan Template

This template must be completed and approved before any AutomationsGuru or
client tenant connection. It is not approval by itself.

Save completed, tenant-specific copies outside source control unless Matthew
explicitly approves a sanitized summary.

## Approval

- Approval date:
- Approved by:
- Operator:
- Tenant type: `AutomationsGuru sandbox` / `client test site`
- Tenant connection approved: `No`
- Tenant mutation approved: `No`
- Client data present: `No`
- Evidence may leave operator machine: `No`

## Scope

- Tenant or sandbox label:
- Site collection URL: `<redacted in source-controlled summaries>`
- Target list/library:
- Test account or app registration label:
- Authentication mode: `App-only certificate`
- Token caching enabled: `No`
- Local evidence root:

## App-Only Graph Smoke

Run this before any site-specific report smoke:

```powershell
.\scripts\run-tenant-readonly-graph-smoke.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>"
```

Acceptance:

- Graph smoke status is `Pass`.
- Tenant connection attempted is `True`.
- Tenant mutation attempted is `False`.
- Manifest records `RunMode=Report`.
- Manifest records `TenantMutationIntent=None`.
- No tenant ID, app ID, certificate path, token, group name, or raw Graph
  response is printed or copied into source.

## Read-Only Report Tests

| Solution | Scope | Expected output | Approved to run |
| --- | --- | --- | --- |
| Site report | One sandbox site | Log, CSV/report, manifest | No |
| List report | One sandbox site | Log, CSV/report, manifest | No |
| Permissions report | One sandbox site | Log, CSV/report, manifest | No |

Acceptance:

- Report completes.
- Manifest records `RunMode=Report`.
- Manifest records `TenantMutationIntent=None`.
- Logs do not contain access tokens, POST bodies, or full REST/Graph response
  bodies.
- Raw report files remain local.

## Mutation-Gate Tests Without Execution

| Solution | Form reached | Gate displayed | Gate cancelled | Mutation attempted |
| --- | --- | --- | --- | --- |
| Remove sharing links | No | No | No | No |
| Remove site user | No | No | No | No |
| Set versioning limits | No | No | No | No |

Acceptance:

- Operator can reach the form.
- Attempting to run in execute mode displays the `APPROVE EXECUTE` gate.
- Cancelling the gate prevents the solution from starting.
- No tenant mutation occurs.

## Optional Controlled Mutation

Do not fill this section unless Matthew separately approves one exact mutation.

- Approved action:
- Pre-state evidence:
- Exact input values:
- Expected post-state:
- Rollback command/process:
- Rollback owner:
- Stop conditions:

Acceptance:

- Pre-state captured.
- Mutation intent approved and typed by operator.
- Post-state validated.
- Rollback completed if required.
- Evidence remains local unless sanitized sharing is approved.

## Results

- Start time:
- End time:
- Result: `Not run` / `Passed` / `Failed` / `Stopped`
- Evidence folder:
- Manifest files:
- Report files:
- Stop reasons:
- Follow-ups:

## Sanitized Summary For Source Control

Only include a source-controlled summary if it contains no tenant URL, user,
file name, list/library name, report row, token, credential, or client content.
