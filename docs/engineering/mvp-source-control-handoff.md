# MVP Source-Control Handoff

Created: 2026-06-10

This handoff prepares the NovaPoint-derived MVP for Matthew review and a later
source-control action. It is not approval to stage, commit, push, open a pull
request, publish, release, sign, or distribute the package.

## Current Branch

```text
codex/novapoint-mvp-foundation
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

## Suggested Commit Shape

If Matthew approves source-control handling, keep the first commit as one
coherent MVP foundation commit unless review asks for smaller commits.

Suggested commit title:

```text
feat: add AutomationsGuru SPO Toolkit MVP foundation
```

Suggested commit body:

```text
- add reproducible restore/build/publish/validation scripts
- brand WPF shell and portable executable for AutomationsGuru
- preserve upstream NovaPoint feature surface with source checks
- add app-only certificate profile support with DPAPI-backed PFX password state
- add run manifests, safer REST logging defaults, and report conversion tooling
- document report scenarios, output handling, permissions, risk, and MVP review evidence
```

## Stage Intentionally

Stage source, scripts, and docs from the working tree. Include these categories:

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

Before committing, inspect staged files with:

```powershell
git diff --cached --name-status
git diff --cached --check
```

## Do Not Stage

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

## Pre-Commit Checks

Run these before staging approval is used:

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

If Matthew approves a PR, include:

- Link to `docs\engineering\mvp-evidence-package-index.md`.
- Link to `docs\engineering\mvp-requirements-traceability.md`.
- Latest `validate-mvp-local.ps1` result.
- Statement that client tenant access, tenant mutation, publishing, release,
  installer distribution, and signing are not included.
- Known partial full-tenant report evidence: `Item` and `Permissions` timed out
  on the approved AutomationsGuru full-suite run and require narrower or longer
  reruns before final client use.
