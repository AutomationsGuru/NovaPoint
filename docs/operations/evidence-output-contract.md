# Evidence Output Contract

NovaPoint-derived AutomationsGuru runs must keep evidence local by default. Do
not commit raw logs, reports, tenant URLs, user names, file names, or client
content unless Matthew explicitly approves a sanitized artifact.

## Current Output Behavior

The upstream logger writes solution output under the current user's Documents
folder:

```text
Documents\NovaPoint\<SolutionName>\<yyMMddHHmmss>\
```

Each run may produce:

- Text logs.
- CSV or SQLite-backed reports.
- A JSON run manifest.
- UI progress messages.

The source-safe review index is
`docs/engineering/mvp-evidence-package-index.md`. It identifies which evidence
is safe in source, which generated artifacts are ignored, and which raw evidence
must remain local.

## MVP Requirements

- Logs must not include access tokens.
- Logs must not include REST POST bodies.
- Logs must not include full successful Graph or SharePoint REST responses.
- Reports may contain tenant or content metadata and must stay local unless
  sanitized.
- The run manifest records solution name, app version, timestamps, run mode,
  output paths, mutation intent, redacted parameter metadata, and completion
  status.

## Future Hardening

- Make the output root configurable.
- Add a redaction review step before any evidence leaves the operator machine.
