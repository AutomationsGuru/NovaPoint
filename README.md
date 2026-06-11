# AutomationsGuru SPO Toolkit (NovaPoint-derived)

This AutomationsGuru fork is based on
[NovaPoint](https://github.com/Barbarur/NovaPoint), an MIT-licensed SharePoint
Online administration tool by Barbarur.

The first AutomationsGuru MVP preserves the existing NovaPoint feature bundle
while adding build reproducibility, source-safe documentation, dependency
hygiene, and client-safe logging defaults.

This fork is not an endorsement by the upstream NovaPoint author.

## Upstream Project

**NovaPoint** is a collection of ready and easy to use *Solutions* aiming to help SharePoint Admins and Site Collections Admins to manage the SharePoint Online Sites in their Tenants. These *solutions* help with different activities on Admins scope that are not available from the user interface.

Regular users can also find some benefits using **NovaPoint** specially the reports you can generate for better understanding of the overall structure and usage of their site. The final goal of this project is to streamline and improve the user experience when interacting with you data on SharePoint.
<div align="center">

Follow **NovaPoint** on

[Youtube](https://www.youtube.com/@NovaPoint22)
[Medium](https://novapoint.medium.com/)
[LinkedIn](https://www.linkedin.com/company/novapointopen)
[Twitter](https://x.com/NovaPoint22)


[![NovaPoint 0.7.0](https://img.youtube.com/vi/-0__y4mBYto/hqdefault.jpg)](https://youtu.be/-0__y4mBYto)

</div>

<br>

## Documentation

AutomationsGuru MVP operator documentation lives in this fork:

- Start here for internal review:
  `docs/engineering/mvp-evidence-package-index.md`
- Start here for day-to-day operation:
  `docs/operations/mvp-operator-runbook.md`
- Start here for a new tenant, client, or Kate environment:
  `docs/operations/new-tenant-report-readiness.md`
- Start here for report selection and follow-through:
  `docs/operations/report-scenario-playbook.md`

- `docs/operations/mvp-operator-runbook.md`
- `docs/operations/app-only-auth-runbook.md`
- `docs/operations/permission-matrix.md`
- `docs/operations/evidence-output-contract.md`
- `docs/operations/new-tenant-report-readiness.md`
- `docs/operations/report-output-guide.md`
- `docs/operations/report-scenario-playbook.md`
- `docs/operations/solution-risk-register.md`
- `docs/operations/sandbox-smoke-test-plan-template.md`
- `docs/engineering/mvp-evidence-package-index.md`
- `docs/engineering/mvp-requirements-traceability.md`
- `docs/engineering/mvp-review-checklist.md`
- `docs/engineering/mvp-source-control-handoff.md`
- `docs/engineering/mvp-plan-completion-audit.md`
- `docs/engineering/post-mvp-roadmap.md`

The upstream NovaPoint wiki remains useful for original setup context:
[NovaPoint Wiki](https://github.com/Barbarur/NovaPoint/wiki).

<br>

## Build

This fork targets .NET 8.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

To create the portable MVP publish folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

Output is written under `out\publish\`, which is ignored by git.

For the MVP, the published executable is
`AutomationsGuruSPOToolkit.exe`. Namespaces, solution class names, library
assembly names, and the existing NovaPoint output roots remain unchanged unless
a later rename pass is separately scoped and validated.

To run the source-safe MVP validation harness:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-mvp-local.ps1
```

The validation harness builds, scans package advisories, publishes the portable
app, checks for known unsafe source patterns, verifies mutation-gate
classification, and runs a no-tenant WPF navigation smoke.

## Safety Notes

- Do not connect to client tenants without Matthew approval.
- Do not run tenant-mutating automation without explicit scope, validation, and
  rollback approval.
- Mutation-capable tools show an AutomationsGuru approval gate before execute
  mode.
- Treat generated reports and logs as potentially sensitive.
- Keep tokens, credential material, raw reports, tenant URLs, user names, file
  names, and client content out of source control.

## Evidence Output

Runs write local evidence under the current user's Documents folder:

```text
Documents\NovaPoint\<SolutionName>\<yyMMddHHmmss>\
```

Each run writes logs and a JSON run manifest. Reports can contain tenant or
content metadata and should stay local unless Matthew approves a sanitized
artifact.

For review and handoff, start with
`docs/engineering/mvp-evidence-package-index.md`. For a new tenant or client
scope, start with `docs/operations/new-tenant-report-readiness.md`.

## Permission Model

The AutomationsGuru MVP smoke path uses app-only certificate authentication.
Start with `docs/operations/app-only-auth-runbook.md` before any tenant-connected
smoke test. The upstream delegated model remains documented as historical setup
context in `docs/operations/permission-matrix.md`. Per-solution least privilege
is marked as requiring verification until tested. Password-protected PFX
profiles are stored with local Windows DPAPI; certificate passwords are not
serialized into `user.config`.

## Package used by this App

- [Microsoft.Identity.Client](https://github.com/AzureAD/microsoft-authentication-library-for-dotnet)
- [Microsoft.Identity.Client.Extensions.Msal](https://github.com/AzureAD/microsoft-authentication-extensions-for-dotnet)
- [Newtonsoft.Json](https://www.newtonsoft.com/json)
- [PnP.Core](https://github.com/pnp/pnpcore)
- [PnP.Framework](https://github.com/pnp/pnpframework)
- [WPF](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/)
- [.NET 8](https://learn.microsoft.com/en-us/dotnet)

<br>
 
## Support

AutomationsGuru support for this fork is internal. Do not send AutomationsGuru
tenant details, logs, reports, or client evidence to the upstream NovaPoint
project.

For upstream NovaPoint behavior, use the upstream discussions and issue tracker
only with sanitized, non-client examples.

<br>

## Funding

This project is free for anyone and I hope you find it useful. If you want to fund this project and helping it to grow, I would really appreciate the support [buying me a coffee](https://buymeacoffee.com/novapoint).
