# MVP Plan Completion Audit

Created: 2026-06-10

This audit maps the MVP adaptation plan to current source-safe evidence plus
one Matthew-approved AutomationsGuru tenant read-only app-only Graph smoke. It
does not approve tenant mutation, release publishing, installer distribution,
commits, pushes, pull requests, or code signing.

For task-by-task traceability, use
`docs/engineering/mvp-requirements-traceability.md`.

## Phase Status

| Phase | Status | Evidence |
| --- | --- | --- |
| 0. Product decisions and boundaries | Source-safe complete | `spo-migrations/docs/decisions/002-novapoint-derived-tool-identity.md` |
| 1. Repo and build foundation | Source-safe complete | `NuGet.Config`, `scripts/build.ps1`, `README.md`, branch `codex/novapoint-mvp-foundation` |
| 2. Correctness and dependency hygiene | Source-safe complete | `ClientContext` fix, package updates, advisory scans, warning baseline |
| 3. Client-safe logging and evidence foundation | Source-safe complete | REST logging redaction, evidence contract, run manifest implementation, automated no-tenant manifest smoke |
| 4. Safety gates for mutating actions | MVP source-safe complete | Risk register and WPF `APPROVE EXECUTE` gate |
| 5. Packaging and branding | Source-safe complete | `NOTICE.md`, README, About page, portable publish scripts |
| 6. Documentation and operator runbook | Source-safe complete | Operations docs, app-only auth runbook, permission matrix, sandbox template |
| 7. Local validation | Source-safe complete | `scripts/validate-mvp-local.ps1`, validation evidence; latest full run passed with mutation-gate classification, feature-surface preservation, run-manifest, report-converter, and UI navigation smokes |
| 8. Approved sandbox smoke test | Read-only report path complete for AutomationsGuru scope | App-only Graph smokes passed with explicit cert input and saved WPF profile; full NovaPoint report set exercised read-only against the approved AutomationsGuru tenant; controlled mutation remains approval-gated |
| 9. MVP review and handoff | Review-ready | Validation evidence, review checklist, post-MVP roadmap |

## Definition Of Done Audit

| Requirement | Current status | Evidence |
| --- | --- | --- |
| AutomationsGuru fork builds from documented commands | Complete | `scripts/build.ps1`; `scripts/validate-mvp-local.ps1` passed |
| Portable artifact or installer generated | Complete for portable artifact | `scripts/publish.ps1`; `out\publish\win-x64\AutomationsGuruSPOToolkit.exe` generated locally |
| App launches locally and navigation loads | Complete | UI Automation smoke in `scripts/validate-mvp-local.ps1` |
| Upstream MIT attribution is present | Complete | `LICENSE`, `NOTICE.md`, README, About page |
| Disposed `ClientContext` bug is fixed | Complete | Source check confirms no `using var clientContext = new ClientContext` return pattern |
| Known high-severity package advisories resolved or documented | Complete | `dotnet list ... --vulnerable --include-transitive` reports no vulnerable packages |
| REST logging no longer writes POST bodies or full success bodies | Complete | Source check confirms old raw logging strings absent |
| Mutating modules show an explicit approval gate | MVP complete | WPF run gate requires `APPROVE EXECUTE` for mutation-capable execute paths; validator confirms the mutation-capable solution list, read-only exclusions, and that menus route through the gated preparation page |
| Evidence/run manifest behavior documented and minimally implemented | Complete | `RunManifest.cs`, `LoggerSolution.cs`, evidence output contract, `scripts/run-manifest-smoke.ps1` |
| Raw report conversion is repeatably validated | Complete | `scripts/convert-novapoint-report-output.ps1`; validator report-converter smoke confirms sanitized JSON/Markdown output without raw row leakage |
| Operator runbook exists | Complete | `docs/operations/mvp-operator-runbook.md`; `docs/operations/app-only-auth-runbook.md` |
| No client tenant data, credentials, tokens, or raw reports committed | Source-safe complete | Tenant smoke summary is sanitized; generated `out/` and local cert/evidence remain outside source |
| Git status and validation evidence reported | Complete for local handoff | Work packet/current-state docs and validation evidence |
| Full report set is mapped and operable | Complete for approved AutomationsGuru scope | `report-output-guide.md`, `report-scenario-playbook.md`, `run-tenant-readonly-report-smokes.ps1`, `convert-novapoint-report-output.ps1` |
| Upstream feature surface is preserved for MVP | Source-safe complete | Validator confirms expected report, automation, directory, and quick-fix forms exist, bind expected solution codes/factories, and are routed from WPF menus |
| MVP package identity is explicit | Complete | Display name and WPF executable are AutomationsGuru branded; namespaces, library names, output roots, and setup internals remain NovaPoint-derived until a later rename pass |

## Remaining Approval-Gated Work

- Complete the sandbox smoke-test plan for any additional SharePoint site or
  client tenant report scope.
- Rerun high-volume full-tenant `Item` and `Permissions` reports with a larger
  timeout or narrower scope before treating them as final client evidence.
- Review raw generated logs/manifests from approved sandbox runs only within the
  approved operator context.
- Test mutation-capable forms by cancelling the approval gate in an approved
  tenant-connected context if Matthew wants tenant-connected gate evidence.
- Verify saved app-only certificate profiles per solution before documenting a
  solution as app-only operator-ready.
- Optionally run one controlled mutation only after Matthew approves exact
  action, evidence, validation, and rollback.
- Matthew accepts or rejects the MVP for internal use.
- Any commit, push, pull request, release, installer distribution, or signing
  path requires separate approval.
