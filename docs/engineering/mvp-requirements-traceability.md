# MVP Requirements Traceability

Created: 2026-06-10

This traceability record maps the implementation plan to current evidence. It
does not approve client tenant access, tenant mutation, release publishing,
installer distribution, or code signing.

Status meanings:

- `Complete`: implemented and backed by current source, docs, or validation.
- `Source-safe complete`: complete for local/no-tenant or sanitized evidence.
- `Approval-gated`: requires Matthew approval before execution.
- `Post-MVP`: explicitly deferred by the MVP scope or roadmap.

## MVP Definition

| Requirement | Status | Evidence |
| --- | --- | --- |
| Preserve upstream feature surface | Source-safe complete | `scripts\validate-mvp-local.ps1` feature-surface preservation smoke checks expected report, automation, directory, and quick-fix forms, solution codes, factories, and menu routing |
| Build from AutomationsGuru fork with documented commands | Complete | `NuGet.Config`, `scripts\build.ps1`, README build section, full validator pass |
| Run locally under AutomationsGuru/NovaPoint-derived branding | Complete | WPF title `AutomationsGuru SPO Toolkit`; published executable `AutomationsGuruSPOToolkit.exe`; upstream attribution retained |
| MIT license attribution and upstream provenance | Complete | `LICENSE`, `NOTICE.md`, README, About page |
| Known correctness issue fixed | Complete | Validator rejects `using var clientContext = new ClientContext` return pattern |
| Client-safe logging defaults | Source-safe complete | Validator rejects old raw REST success and POST body logging patterns |
| Visible safety gates around tenant-mutating actions | Source-safe complete | WPF `APPROVE EXECUTE` gate plus mutation classification smoke |
| Predictable local evidence outputs | Complete | `docs\operations\evidence-output-contract.md`, run manifests, report output guide |
| Setup, permissions, operating modes, and support boundaries documented | Complete | Operator runbook, app-only auth runbook, permission matrix, risk register, report playbook |
| Client tenant execution not required | Approval-gated | New-tenant/Kate readiness runbook requires separate approval before any client scope |

## Phase Traceability

| Plan phase/task | Status | Evidence / note |
| --- | --- | --- |
| 0.1 Product working name | Complete | Decision uses `AutomationsGuru SPO Toolkit` in README, WPF title, About page, and run manifest application name |
| 0.2 Distribution format | Complete | Portable publish selected for MVP; MSI remains post-MVP in installer assessment |
| 0.3 Tenant smoke-test scope | Complete for approved scope | AutomationsGuru read-only scope documented; Kate/client tenant remains approval-gated |
| 1.1 Work packet in `spo-migrations` | Complete | `docs\work-packets\0041-novapoint-mvp-adaptation.md` |
| 1.2 MVP branch | Complete | Local NovaPoint branch `codex/novapoint-mvp-foundation` |
| 1.3 Reproducible NuGet config | Complete | `NuGet.Config`; validator restore/build pass without global source assumption |
| 1.4 Build script | Complete | `scripts\build.ps1`; full validator invokes it |
| 2.1 Disposed `ClientContext` fix | Complete | Source changed; validator source check covers regression |
| 2.2 Vulnerable dependency updates | Complete | Current `dotnet list ... --vulnerable --include-transitive` checks report no vulnerable packages |
| 2.3 Warning baseline | Complete | `docs\engineering\warning-baseline.md`; validation evidence records warning count |
| 3.1 REST logging redaction | Source-safe complete | Source changes plus validator checks for removed unsafe patterns |
| 3.2 Evidence output contract | Complete | `docs\operations\evidence-output-contract.md` |
| 3.3 Run manifest | Complete | `RunManifest.cs`, `LoggerSolution.cs`, `scripts\run-manifest-smoke.ps1` |
| 4.1 Mutation risk classification | Complete | `docs\operations\solution-risk-register.md`; validator confirms mutation/read-only solution sets |
| 4.2 Run mode vocabulary | MVP complete | `RunMode` vocabulary and manifests use `Report`/`Execute`; true per-solution `Plan` remains post-MVP |
| 4.3 Mutating action confirmation gate | Source-safe complete | `SolutionPreparationPage.xaml.cs`; no-tenant/source validator confirms gate and menu routing |
| 5.1 License and attribution | Complete | `NOTICE.md`, README, About page |
| 5.2 Branding without namespace rewrite | Complete for MVP | WPF assembly/executable is `AutomationsGuruSPOToolkit`; display name is `AutomationsGuru SPO Toolkit`; namespaces/library/output roots remain NovaPoint-derived by design |
| 5.3 Portable publish | Complete | `scripts\publish.ps1`; validator requires `AutomationsGuruSPOToolkit.exe` |
| 5.4 Installer assessment | Complete for MVP | `docs\packaging\installer-assessment.md`; MSI/signing remain post-MVP |
| 6.1 README update | Complete | README includes identity, build, safety, evidence, permissions, and support sections |
| 6.2 Operator runbook | Complete | `docs\operations\mvp-operator-runbook.md` |
| 6.3 Permission matrix | Complete | `docs\operations\permission-matrix.md`; least privilege remains marked as requiring verification |
| 7.1 Build validation | Complete | Full validator passes build |
| 7.2 Package validation | Complete | Full validator publishes and launches the portable app |
| 7.3 Security/dependency validation | Complete | Full validator runs package advisory scans |
| 7.4 No-tenant UI smoke | Complete | Full validator opens Reports, Automation, Settings, and About without tenant login |
| 8.1 Sandbox test manifest | Source-safe complete | Sandbox template and new-tenant readiness docs exist; any new tenant run requires approval |
| 8.2 Read-only report smoke | Complete for approved AutomationsGuru scope | Graph smoke, bounded report smoke, and full 12-report suite are documented in validation evidence |
| 8.3 Mutation gate smoke without execution | Source-safe complete | Source/UI gate verified locally; tenant-connected cancellation test remains approval-gated |
| 8.4 Optional controlled mutation test | Approval-gated | Not run; requires exact Matthew approval, validation, and rollback |
| 9.1 MVP evidence package | Complete for review | `docs\engineering\mvp-evidence-package-index.md` |
| 9.2 Final MVP review with Matthew | Approval-gated | `docs\engineering\mvp-review-checklist.md` awaits Matthew acceptance |
| 9.3 Post-MVP roadmap | Complete | `docs\engineering\post-mvp-roadmap.md` |

## Known Partial Evidence

The full AutomationsGuru report suite exercised every report key. `Item` and
`Permissions` produced partial full-tenant CSV evidence after timeout. Treat
those two full-tenant results as discovery evidence only until rerun with a
larger timeout or narrower approved scope.

## Remaining Approval Gates

- Matthew acceptance for internal MVP use.
- Release, installer distribution, and code signing.
- Kate/client tenant report execution.
- Tenant-connected mutation-gate cancellation smoke.
- Any controlled tenant mutation.
