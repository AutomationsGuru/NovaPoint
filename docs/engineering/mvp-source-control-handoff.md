# MVP Source-Control Record

Created: 2026-06-10

This record documents the source-control handling for the NovaPoint-derived MVP.
It is not approval to publish, release, sign, installer-distribute, connect to a
client tenant, or run tenant mutations.

## Merged State

```text
Base branch: main
Merged PR: https://github.com/AutomationsGuru/NovaPoint/pull/1
Merge commit: 1b5b66e2409e4f8114337258f84686356e26670b
```

Expected remotes:

```text
origin   https://github.com/AutomationsGuru/NovaPoint.git
upstream https://github.com/Barbarur/NovaPoint.git
```

The upstream push URL should remain disabled locally.

## Review Position

The MVP source tree is ready for Matthew review when the following command
passes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-mvp-local.ps1
```

The latest successful validation published and launched:

```text
out\publish\win-x64\AutomationsGuruSPOToolkit.exe
```

The publish folder is generated evidence and must remain ignored.

## Commit Shape

Merged commit title:

```text
feat: add AutomationsGuru SPO Toolkit MVP foundation
```

Commit body summary:

```text
- add reproducible restore/build/publish/validation scripts
- brand WPF shell and portable executable for AutomationsGuru
- preserve upstream NovaPoint feature surface with source checks
- add app-only certificate profile support with DPAPI-backed PFX password state
- add run manifests, safer REST logging defaults, and report conversion tooling
- document report scenarios, output handling, permissions, risk, and MVP review evidence
```

## Staged Intentionally

The merged MVP source-control set intentionally included:

- `NuGet.Config`
- `NOTICE.md`
- `README.md`
- `.gitignore`
- `scripts\*.ps1`
- `docs\**\*.md`
- `src\NovaPointLibrary\**\*.cs`
- `src\NovaPointLibrary\NovaPointLibrary.csproj`
- `src\NovaPointWPF\**\*.xaml`
- `src\NovaPointWPF\**\*.cs`
- `src\NovaPointWPF\NovaPointWPF.csproj`

The staging review used:

```powershell
git diff --cached --name-status
git diff --cached --check
```

## Do Not Stage In Future Work

Do not stage:

- `out\`
- `bin\`
- `obj\`
- `Documents\NovaPoint\...`
- `out\report-summaries\...`
- certificate files, password files, token caches, `.pfx`, `.clixml`, or
  `msal.cache`
- raw NovaPoint logs, reports, manifests, or tenant CSV output
- screenshots or report excerpts containing tenant URLs, emails, user names,
  group names, IDs, item paths, file names, sharing URLs, tokens, certificate
  paths, or client content

## Pre-Commit Checks For Follow-Up Changes

Run these before future staging/PR work:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-mvp-local.ps1
git diff --check
git status --short --branch
```

Run a focused leakage scan over source-controlled docs and scripts:

```powershell
rg -n --pcre2 "https://[^\s`\"<>]*sharepoint\.com|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|(?i)client_secret\s*[=:]|(?i)BEGIN [A-Z ]*PRIVATE KEY|(?i)access_token\s*[=:]|(?i)refresh_token\s*[=:]|(?i)thumbprint\s*[=:]" README.md docs scripts
```

Expected result: no matches.

## Pull Request Notes

The merged MVP PR included:

- Link to `docs\engineering\mvp-evidence-package-index.md`.
- Link to `docs\engineering\mvp-requirements-traceability.md`.
- Latest `validate-mvp-local.ps1` result.
- Statement that client tenant access, tenant mutation, publishing, release,
  installer distribution, and signing were not included.
- Known partial full-tenant report evidence: `Item` and `Permissions` timed out
  on the approved AutomationsGuru full-suite run and require narrower or longer
  reruns before final client use.
