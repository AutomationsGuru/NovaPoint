# Warning Baseline

Created: 2026-06-10

This file tracks compiler warnings observed during the AutomationsGuru MVP
adaptation. Warnings are not treated as proof of runtime safety.

## Current Baseline

Validated on 2026-06-10:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

Result: build succeeded with 361 warnings and 0 errors in the final MSBuild
summary.

Known warning families:

- Nullable DTO/model properties initialized by JSON/XML/Graph/REST
  deserialization.
- Nullable WPF control bindings and optional filter inputs.
- Possible null dereferences in legacy Graph/REST helper paths.
- Unused fields in copy/logging paths.
- Async methods that currently run synchronously.

## MVP Policy

The MVP may ship with a documented warning backlog, but it must not ship with
build errors or undisclosed high-severity dependency advisories.
