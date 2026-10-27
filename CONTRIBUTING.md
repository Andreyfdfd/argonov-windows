# Contributing

Thank you for helping improve ARGONOV SHELL.

## Supported environment

- Windows 10/11; Windows 11 is the primary target.
- PowerShell 7.6 or newer. Windows PowerShell 5.1 is not supported.

## Before submitting changes

Run these commands from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File .\install.ps1 -ValidateOnly
pwsh -NoLogo -NoProfile -File .\tests\Test-Sysinfo.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-AISandbox.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-Backup.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-Reorganize.ps1
```

Tests should use temporary directories and avoid changing the host's real profile, registry, startup entries, services or files. Do not add tests that require administrator privileges or external network access unless they are explicitly separated from the offline smoke-test suite.

## Pull requests

- Keep each change focused.
- Describe user-visible behaviour and any compatibility impact.
- Include or update tests for changed behaviour.
- Do not commit local markers, generated reports, backup archives, credentials or machine-specific paths.
