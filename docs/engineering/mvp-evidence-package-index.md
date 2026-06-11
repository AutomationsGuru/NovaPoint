# MVP Evidence Package Index

Created: 2026-06-10

This index is the source-safe review package for the AutomationsGuru SPO Toolkit
MVP. It points to evidence, validation commands, generated artifact locations,
and approval gates without copying secrets, tenant URLs, user names, group
names, file names, IDs, tokens, certificate paths, or raw report rows into
source control.

## Review Position

Current position: `Merged for internal review`, not released, not installer
distributed, not code signed, and not approved for client tenant execution.

The MVP is ready for internal review because:

- The product fork builds from documented commands.
- The portable publish folder is generated locally.
- No-tenant WPF navigation smoke passes.
- Known package advisories are cleared by current scans.
- Upstream MIT attribution and AutomationsGuru fork identity are documented.
- Client-sensitive REST logging patterns are removed.
- Run manifests are implemented and documented.
- Mutation-capable solution codes are covered by an `APPROVE EXECUTE` gate.
- Expected report, automation, directory, and quick-fix forms remain routed
  from WPF menus and bound to their expected solution factories.
- The full NovaPoint report set is documented, runnable, and convertible into
  sanitized summaries.

## Source-Control Evidence

| Evidence | Path |
| --- | --- |
| Plan completion audit | `docs/engineering/mvp-plan-completion-audit.md` |
| Requirements traceability | `docs/engineering/mvp-requirements-traceability.md` |
| Validation results | `docs/engineering/mvp-validation-evidence.md` |
| Review checklist | `docs/engineering/mvp-review-checklist.md` |
| Source-control record | `docs/engineering/mvp-source-control-handoff.md` |
| Warning baseline | `docs/engineering/warning-baseline.md` |
| Post-MVP roadmap | `docs/engineering/post-mvp-roadmap.md` |
| Operator runbook | `docs/operations/mvp-operator-runbook.md` |
| App-only auth runbook | `docs/operations/app-only-auth-runbook.md` |
| Permission matrix | `docs/operations/permission-matrix.md` |
| Evidence output contract | `docs/operations/evidence-output-contract.md` |
| Report output guide | `docs/operations/report-output-guide.md` |
| Report scenario playbook | `docs/operations/report-scenario-playbook.md` |
| New-tenant readiness runbook | `docs/operations/new-tenant-report-readiness.md` |
| Solution risk register | `docs/operations/solution-risk-register.md` |
| Sandbox smoke-test template | `docs/operations/sandbox-smoke-test-plan-template.md` |
| Installer assessment | `docs/packaging/installer-assessment.md` |

Cross-repo migration practice handoff:

- `C:\Users\RDP\Projects\spo-migrations\docs\runbooks\novapoint-report-discovery-to-migration-workflow.md`

## Local Generated Evidence

These artifacts are generated locally and ignored by git:

| Artifact | Location | Handling |
| --- | --- | --- |
| Portable publish output | `out\publish\win-x64\` | Internal local artifact; regenerate before review or handoff; MVP executable is `AutomationsGuruSPOToolkit.exe` |
| Sanitized report summaries | `out\report-summaries\` | Safe to review internally after leakage scan |
| Raw NovaPoint logs/reports/manifests | `Documents\NovaPoint\<SolutionName>\<yyMMddHHmmss>\` | Sensitive local evidence; do not commit |
| Local app-only profile/certificate material | Operator profile outside repo | Secret/private-key material; do not print, copy, or commit |

## Regeneration Commands

Run from `C:\Users\RDP\Projects\NovaPoint`.

Full local MVP validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-mvp-local.ps1
```

Publish only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

Saved-profile Graph smoke after approval:

```powershell
.\scripts\run-tenant-readonly-graph-smoke.ps1 `
  -ApproveTenantConnection `
  -ApprovalReference "<approved-reference>" `
  -UseSavedProfile `
  -TimeoutSeconds 120
```

Report suite after approval:

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

Sanitized report conversion:

```powershell
.\scripts\convert-novapoint-report-output.ps1 `
  -RunLabel "<safe-label>"
```

## Latest Source-Safe Validation Summary

Latest full local validator result:

- Build: passed.
- Dependency advisory scan: passed.
- Portable publish: passed.
- Source safety checks: passed.
- Mutation approval gate classification smoke: passed.
- Feature surface preservation source smoke: passed.
- MVP documentation contract smoke: passed.
- Run manifest smoke: passed.
- Report converter smoke: passed.
- No-tenant WPF navigation smoke: passed.
- Known warning baseline remains documented; build produced warnings but no
  errors.

Latest approved AutomationsGuru tenant report-suite result:

- All 12 NovaPoint report keys were exercised read-only.
- Report-runner tenant mutation attempted: `False`.
- `Item` and `Permissions` produced partial full-tenant evidence after timeout;
  rerun them with a larger timeout or narrower scope before final client use.
- Sanitized JSON/Markdown conversion was generated under ignored
  `out\report-summaries\`.

## Safety Gates Not Crossed

The current package does not represent approval for:

- Client tenant access.
- Tenant mutation.
- Controlled mutation testing.
- Release publishing, code signing, or installer distribution.
- Copying raw reports/logs/manifests into source.
- Sharing raw tenant values outside the approved operator context.

## Review Checklist For Matthew

1. Run or inspect `scripts\validate-mvp-local.ps1` output.
2. Inspect the published app under `out\publish\win-x64\`.
3. Review `mvp-review-checklist.md`.
4. Confirm the app display name, `AutomationsGuruSPOToolkit.exe` executable
   name, and portable distribution format are acceptable for internal use.
5. Decide whether to approve any next tenant scope, such as Kate's environment,
   using `new-tenant-report-readiness.md`.
