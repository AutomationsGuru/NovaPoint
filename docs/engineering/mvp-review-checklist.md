# MVP Review Checklist

This checklist is for Matthew's internal review of the AutomationsGuru SPO
Toolkit MVP foundation. It does not approve tenant access, tenant mutation,
release publishing, installer distribution, or code signing.

## Evidence Status Before Matthew Review

| Area | Status | Evidence |
| --- | --- | --- |
| Build, advisory scan, publish, source checks, manifests, report conversion, and no-tenant UI navigation | Proven by latest local validator | `scripts/validate-mvp-local.ps1`; `docs/engineering/mvp-validation-evidence.md` |
| Full NovaPoint report set inventory and usage guidance | Documented and tested against approved AutomationsGuru read-only scope | `docs/operations/report-output-guide.md`; `docs/operations/report-scenario-playbook.md` |
| Upstream feature surface preservation | Source-checked for expected reports, automation, directory, and quick-fix form routing | `scripts/validate-mvp-local.ps1` |
| Persistent app-only authentication path | Documented for saved profile, no-delegated-prompt operation, and 401 triage | `docs/operations/app-only-auth-runbook.md` |
| Sanitized raw-to-useful report conversion | Proven by converter smoke and local 12-report summary generation | `scripts/convert-novapoint-report-output.ps1`; ignored `out\report-summaries\` |
| Mutating action approval gate | Source-safe proven; tenant-connected cancellation test remains approval-gated | `SolutionPreparationPage.xaml.cs`; validator source/gate checks |
| Client/Kate tenant readiness | Not approved or executed | Requires Matthew-approved tenant scope, app registration review, and smoke manifest |
| Internal acceptance decision | Matthew-owned | Complete the acceptance fields at the end of this checklist |

## Source-Safe Foundation

- [ ] Fork builds from documented commands.
- [ ] Repo-local `NuGet.Config` restores without user-level package source
  assumptions.
- [ ] `scripts/validate-mvp-local.ps1` passes on Matthew's machine.
- [ ] Portable publish folder is generated under `out\publish\win-x64`.
- [ ] Published app launches locally.
- [ ] Reports navigation loads.
- [ ] Automation navigation loads.
- [ ] Settings navigation loads.
- [ ] About page shows AutomationsGuru and upstream attribution.
- [ ] Full NovaPoint report set is documented and runnable from the report
  runner.
- [ ] Expected upstream report, automation, directory, and quick-fix forms remain
  visible in the app and source-checked by the validator.
- [ ] App-only auth runbook is acceptable as the persistent profile and
  troubleshooting source of truth.
- [ ] Sanitized report conversion outputs are acceptable for internal evidence
  summaries.

## Attribution And Packaging

- [ ] Upstream `LICENSE` is preserved.
- [ ] `NOTICE.md` states upstream NovaPoint provenance and MIT license.
- [ ] README identifies this as an AutomationsGuru NovaPoint-derived fork.
- [ ] MVP display name is acceptable: `AutomationsGuru SPO Toolkit`.
- [ ] MVP executable name is acceptable for internal use:
  `AutomationsGuruSPOToolkit.exe`.
- [ ] Portable publish is acceptable as the first internal distribution format.
- [ ] MSI/signing remains deferred or is separately approved.

## Safety And Evidence

- [ ] Disposed `ClientContext` return bug is fixed.
- [ ] Dependency advisory scans report no vulnerable packages, or blockers are
  documented.
- [ ] REST POST bodies are not logged by default.
- [ ] Full REST/Graph success response bodies are not logged by default.
- [ ] Mutating solutions show the `APPROVE EXECUTE` gate before execution.
- [ ] Mutation gate classification validation covers every known
  mutation-capable solution code.
- [ ] Run manifests are written beside logs and reports.
- [ ] Evidence output location is documented.
- [ ] Raw logs/reports remain local and ignored unless sanitized and approved.

## Tenant-Connected Review Gates

Complete only after separate Matthew approval:

- [ ] Sandbox smoke-test plan is filled out.
- [ ] Read-only report smoke completes in approved sandbox scope.
- [ ] Logs are reviewed for redaction in approved sandbox scope.
- [ ] Manifest records read-only/report mode correctly in approved sandbox
  scope.
- [ ] Mutation-capable form gate is tested by cancelling before execution.
- [ ] Optional controlled mutation is approved, executed, validated, and rolled
  back if required.

## Acceptance Decision

- MVP accepted for internal use: `No`
- Required fixes before internal use:
- Approved users/operators:
- Approved tenant scopes:
- Approved distribution method:
- Next review date:
