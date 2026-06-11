# Installer Assessment

Created: 2026-06-10

The upstream solution includes a Visual Studio setup project:

```text
src\NovaPointSetup\NovaPointSetup.vdproj
```

## MVP Position

Portable publish is the first MVP packaging target. MSI remains a follow-up
until the local Visual Studio Installer Projects toolchain is confirmed.

## MVP Executable And Assembly Naming

The MVP WPF assembly and published executable are branded as
`AutomationsGuruSPOToolkit.exe`. The visible app identity is handled through
the window title, README, About page, notices, operator runbooks, and package
docs as `AutomationsGuru SPO Toolkit`.

This is a deliberate middle path for the first internal package:

- The operator-facing executable and WPF assembly name are AutomationsGuru
  branded.
- Namespaces, solution class names, `NovaPointLibrary.dll`, app icon resources,
  and the existing Documents/LocalAppData NovaPoint output roots remain
  unchanged for MVP compatibility.
- Saved app-only profiles use the library-managed local configuration path and
  are not tied to the WPF executable name.
- The upstream setup project, app icon, and deeper resource names still need a
  focused packaging pass before a full product rename.

Do not rename namespaces, library assemblies, setup project internals, output
roots, or resource folders as part of MVP stabilization unless that work is
separately scoped and validated.

## Open Checks

- Confirm whether Visual Studio Installer Projects is installed.
- Confirm whether the setup project builds on Matthew's machine.
- Confirm whether the MSI should be signed before any external distribution.
- Confirm branding/version fields before generating an installer.
