# Changelog

All notable project changes will be recorded here.

## Unreleased

- Made profile module loading relative to the project directory.
- Made the installer validate PowerShell syntax before modifying the profile.
- Added a validation-only installer mode and idempotent, marked profile integration.
- Made PSReadLine configuration tolerant of missing options and unsupported key bindings.
- Hardened AI sandbox path-boundary checks and removed fixed project paths from the AI prompt.
- Made banner and dashboard Git status detection relative to the actual repository.
- Reworked backup creation and restore to preserve nested files and reject unsafe archive paths.
- Changed module reorganization to preview-only by default; moving files requires `-Execute`.
- Added smoke tests for AI sandbox boundaries, backup archives and module reorganization.
- Completed installation and safety documentation and expanded GitHub Actions validation.
