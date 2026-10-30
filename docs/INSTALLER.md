# ARGONOV SHELL — installer and dependency management

## Supported platform

The current packaged installer targets Windows x64. The supported baseline is Windows 10 build 19041 or later / Windows 11. Windows Terminal portable mode also requires build 19041 or later. A separate ARM64 package will be maintained independently.

The installer is per-user and does not require administrator privileges. It does not change the system-wide ExecutionPolicy, Windows services, or system PATH.

## What the Setup.exe contains

- ARGONOV SHELL profile, command modules, launchers and documentation.
- Portable PowerShell 7.6.9.
- App-local .NET Runtime 10.x required by that PowerShell release.
- The dependency bootstrap scripts.

The bundled PowerShell and .NET runtime are installed into the shared per-user dependency folder:
- %LOCALAPPDATA%\Programs\ARGONOV-Dependencies\PowerShell
- %LOCALAPPDATA%\Programs\ARGONOV-Dependencies\dotnet

They are separate from the shell application directory and are marked uninsneveruninstall, so they survive removal of ARGONOV.

## Optional dependency tasks

The installer wizard offers these default-selected tasks. The dependency bootstrap detects existing components where supported and reuses them instead of installing another copy.

| Component | Deployment | Purpose |
|---|---|---|
| Git for Windows | SHA-256-verified MinGit ZIP under %LOCALAPPDATA%\Programs\ARGONOV-Dependencies\Git | Non-interactive Git commands, OpenSSH client and Git aliases |
| Python 3.14 | Per-user Python install under %LOCALAPPDATA%\Programs\ARGONOV-Dependencies\Python314 | Python-based shell utilities |
| qrcode and Pillow | Per-user pip package installation | QR generation and PNG image output |
| Windows Terminal | Existing MSIX package if present; otherwise portable ZIP under %LOCALAPPDATA%\Programs\ARGONOV-Dependencies\WindowsTerminal | Terminal host and ARGONOV profile |
| LibreHardwareMonitor | Installed by the SYSINFO sensor setup to %LOCALAPPDATA%\ARGONOV\tools\LibreHardwareMonitor | Hardware sensor readings in SYSINFO |

The Git and Windows Terminal archives are downloaded from their official project release channels and checked against the SHA-256 digest published with the release. Python packages are installed with pip --target into the shared ARGONOV package folder; the installer does not modify another Python installation's global or user site-packages. Python's installer hash is pinned to the official Python 3.14.10 x64 distribution. The .NET runtime archive is checked against the SHA-512 published in Microsoft's release metadata.

The installer does not rewrite the user's settings.json or register an AppX extension. The Start menu launcher opens a new Windows Terminal tab and runs Start-Argonov.cmd directly. This works with an existing Store/unpackaged Terminal and with the ARGONOV-managed portable copy while leaving the user's profiles, themes, shortcuts and comments untouched.

## Optional integrations that remain user-managed

LM Studio is not downloaded by Setup.exe. It is a sizeable local AI application and model selection depends on available RAM/VRAM and user preference. The AI commands report the missing backend until LM Studio is configured.

An SSH private/public key pair is not generated automatically. Users can configure SSH themselves, or use HTTPS Git remotes without an SSH key.

CAD/CAM programs are not installed or modified. ARGONOV only detects and launches those already installed on the computer.

## Recovery and diagnostics

The Start menu entry ARGONOV SHELL → Repair dependencies reruns the dependency bootstrap for Git, Python, Windows Terminal and LibreHardwareMonitor.

Logs and a JSON summary are written to:

- %LOCALAPPDATA%\ARGONOV\installer\dependency-install.log
- %LOCALAPPDATA%\ARGONOV\installer\dependency-report.json

If an optional component fails to download or install, ARGONOV itself remains installed and can run. Check the log, repair the network connection, then use the Start menu repair action.

## Uninstallation policy

The packaged installer is structured so the app directory is independent from shared runtimes and tools. Shared PowerShell, .NET, Git, Python and Windows Terminal files are marked to survive uninstallation.

A future dedicated ARGONOV uninstaller must remove only the shell, shell shortcuts, ARGONOV Terminal profile fragment and shell-specific sensor backend/logs. It must never recursively delete the shared dependency directory. The music, vendor, data and config directories must remain user-controlled and must not be deleted without an explicit user choice.
