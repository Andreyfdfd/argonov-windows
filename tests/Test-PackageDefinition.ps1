# Static checks for the ARGONOV SHELL Setup.exe package definition.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$issPath = Join-Path $projectRoot 'installer\ARGONOV.iss'
$startPath = Join-Path $projectRoot 'Start-Argonov.ps1'
$iss = [System.IO.File]::ReadAllText($issPath)
$start = [System.IO.File]::ReadAllText($startPath)
function Assert-PackageTest {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "PACKAGE TEST FAILED: $Message" }
    Write-Host "[PASS] $Message" -ForegroundColor Green
}
Assert-PackageTest (Test-Path -LiteralPath $issPath -PathType Leaf) 'Inno Setup definition exists.'
Assert-PackageTest (Test-Path -LiteralPath $startPath -PathType Leaf) 'Bundled runtime launcher exists.'
Assert-PackageTest ($iss.Contains('PrivilegesRequired=lowest')) 'Installer does not request administrator privileges.'
Assert-PackageTest ($iss.Contains('DefaultDirName={localappdata}\Programs\ARGONOV SHELL')) 'Default install path is user-scoped.'
Assert-PackageTest ($iss.Contains('payload\powershell')) 'Installer includes the bundled PowerShell runtime.'
Assert-PackageTest ($iss.Contains('uninsneveruninstall')) 'User data directories are preserved by uninstall.'
Assert-PackageTest (-not $iss.Contains('$PROFILE')) 'Installer definition does not edit the current PowerShell profile.'
$launcherRuntimePattern = 'Join-Path $PSScriptRoot ''runtime\pwsh.exe'''
Assert-PackageTest ($start.Contains($launcherRuntimePattern)) 'Launcher uses the bundled PowerShell runtime.'
Assert-PackageTest ($start.Contains('. $profile')) 'Launcher loads ARGONOV profile explicitly.'
Write-Host 'PACKAGE DEFINITION TESTS PASSED' -ForegroundColor Green
