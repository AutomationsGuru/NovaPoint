# Post-MVP Roadmap

This roadmap keeps the NovaPoint-derived fork from becoming an unmanaged custom
branch. It is not approval to execute any tenant-connected work or publish a
release.

## Lane 1: Safety And Execution Model

- Implement true `Plan` mode per mutating solution.
- Replace reflection-based mutation classification with explicit solution
  metadata.
- Record `TenantMutationIntent=Attempted` only after a tenant-mutating operation
  actually starts.
- Add per-solution approval copy that names the concrete action and target
  scope.
- Add cancellation-state handling so manifests distinguish `Cancelled` from
  failed startup paths consistently.

## Lane 2: Evidence And Redaction

- Make output root configurable.
- Add a redaction review command for run folders.
- Produce a sanitized evidence summary from a run manifest without copying raw
  logs or reports.
- Add automated checks for known sensitive patterns in generated log files.
- Define a source-safe evidence package shape for internal review.

## Lane 3: Permissions And Authentication

- Verify per-solution least-privilege delegated permissions.
- Verify app-only/certificate support per solution before documenting it as
  operator-ready.
- Add regression coverage for DPAPI-backed password-protected PFX profiles,
  including profile deletion cleanup.
- Document certificate rotation, recovery, and operator handoff steps without
  exposing certificate paths or secrets.
- Document token-cache location and cache-clearing steps with screenshots or
  source-safe examples.
- Add a preflight check for missing app configuration before launching a
  solution.

## Lane 4: Test Coverage And CI

- Add unit tests around run-mode inference, parameter redaction, and manifest
  serialization.
- Add a lightweight WPF smoke harness that does not rely on endpoint-protection
  sensitive dynamic compilation.
- Add GitHub Actions build and package-advisory checks.
- Track compiler warning count in CI without blocking MVP on nullable DTO debt.

## Lane 5: Packaging And Branding

- Decide whether to rename namespaces, library assemblies, output roots,
  resource folders, app icon assets, and setup project internals after
  resource-path, settings/profile, installer, and support documentation testing.
- Evaluate Visual Studio setup project viability.
- Decide MSI/MSIX/portable distribution strategy.
- Decide code-signing requirements before external distribution.
- Replace or supplement upstream social/funding links if the build becomes an
  AutomationsGuru-distributed package.

## Lane 6: Upstream Sync Strategy

- Keep `upstream` fetch-only with push disabled.
- Document a periodic upstream review cadence.
- Isolate AutomationsGuru changes into small, reviewable commits.
- Avoid broad namespace rewrites until sync strategy and tests exist.
- Track local deviations from upstream behavior in a changelog.

## Lane 7: Migration-Practice Integration

- Map NovaPoint reports to AutomationsGuru ShareGate/PnP/Graph migration
  readiness workflows.
- Identify report outputs that can support migration scoping, permission
  cleanup, retention checks, and evidence packs.
- Build ShareGate-adjacent tools only where PnP/Graph fills a real gap and the
  approval model is explicit.
