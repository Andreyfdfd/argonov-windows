# Static checks for the ARGONOV SHELL Setup.exe package definition.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$issPath = Join-Path $projectRoot 'installer\ARGONOV.iss'
$startPath = Join-Path $projectRoot 'Start-Argonov.ps1'
$cmdPath = Join-Path $projectRoot 'Start-Argonov.cmd'
$launchPath = Join-Path $projectRoot 'Launch-Argonov.cmd'
$dependencyCmdPath = Join-Path $projectRoot 'Install-ArgonovDependencies.cmd'
$dependencyScriptPath = Join-Path $projectRoot 'setup\Install-ArgonovDependencies.ps1'
$iss = [System.IO.File]::ReadAllText($issPath)
$start = [System.IO.File]::ReadAllText($startPath)
$cmd = [System.IO.File]::ReadAllText($cmdPath)
$launch = [System.IO.File]::ReadAllText($launchPath)
$dependencyCmd = [System.IO.File]::ReadAllText($dependencyCmdPath)
$dependencyScript = [System.IO.File]::ReadAllText($dependencyScriptPath)
function Assert-PackageTest {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "PACKAGE TEST FAILED: $Message" }
    Write-Host "[PASS] $Message" -ForegroundColor Green
}
Assert-PackageTest (Test-Path -LiteralPath $issPath -PathType Leaf) 'Inno Setup definition exists.'
Assert-PackageTest (Test-Path -LiteralPath $startPath -PathType Leaf) 'PowerShell launcher exists.'
Assert-PackageTest (Test-Path -LiteralPath $cmdPath -PathType Leaf) 'Runtime bootstrap command exists.'
Assert-PackageTest (Test-Path -LiteralPath $launchPath -PathType Leaf) 'Windows Terminal launcher exists.'
Assert-PackageTest (Test-Path -LiteralPath $dependencyCmdPath -PathType Leaf) 'Dependency bootstrap command exists.'
Assert-PackageTest (Test-Path -LiteralPath $dependencyScriptPath -PathType Leaf) 'Dependency bootstrap script exists.'
Assert-PackageTest ($iss.Contains('PrivilegesRequired=lowest')) 'Installer does not request administrator privileges.'
Assert-PackageTest ($iss.Contains('DefaultDirName={localappdata}\Programs\ARGONOV SHELL')) 'Default install path is user-scoped.'
Assert-PackageTest ($iss.Contains('payload\powershell')) 'Installer includes the PowerShell runtime.'
Assert-PackageTest ($iss.Contains('payload\dotnet')) 'Installer includes a private .NET runtime.'
Assert-PackageTest ($iss.Contains('Start-Argonov.cmd')) 'Shortcuts use the runtime bootstrap command.'
Assert-PackageTest ($cmd.Contains('DOTNET_ROOT_X64')) 'Bootstrap points .NET host resolution to the private runtime.'
Assert-PackageTest ($launch.Contains('wt.exe -p')) 'Desktop launcher opens the ARGONOV profile in Windows Terminal.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installGit')")) 'Installer provides a Git dependency selection.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installPython')")) 'Installer provides a Python dependency selection.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installTerminal')")) 'Installer provides a Windows Terminal dependency selection.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installSensors')")) 'Installer provides a sensor backend selection.'
Assert-PackageTest ($dependencyScript.Contains('Get-GitHubLatestRelease')) 'Dependency bootstrap retrieves maintained GitHub releases.'
Assert-PackageTest ($dependencyScript.Contains('Invoke-VerifiedDownload')) 'External installers are SHA-256 verified before execution.'
Assert-PackageTest ($dependencyScript.Contains('qrcode[pil]')) 'Python QR dependencies are installed automatically.'
Assert-PackageTest ($dependencyScript.Contains('LibreHardwareMonitor')) 'SYSINFO sensor backend is installed automatically.'
Assert-PackageTest ($dependencyScript.Contains('Microsoft.WindowsTerminal')) 'Windows Terminal is configured during dependency setup.'
Assert-PackageTest ($cmd.Contains('-NoProfile')) 'Dedicated shell launch does not load the user PowerShell profile first.'
Assert-PackageTest ($iss.Contains('uninsneveruninstall')) 'User data directories are preserved by uninstall.'
Assert-PackageTest (-not $iss.Contains('$PROFILE')) 'Installer definition does not edit the current PowerShell profile.'
$launcherRuntimePattern = 'Join-Path $PSScriptRoot ''runtime\pwsh.exe'''
Assert-PackageTest ($start.Contains($launcherRuntimePattern)) 'Launcher uses the bundled PowerShell runtime.'
Assert-PackageTest ($start.Contains('. $argonovProfile')) 'Launcher loads ARGONOV profile explicitly.'
Write-Host 'PACKAGE DEFINITION TESTS PASSED' -ForegroundColor Green
