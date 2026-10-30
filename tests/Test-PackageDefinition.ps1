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
$repairCmdPath = Join-Path $projectRoot 'Repair-ArgonovDependencies.cmd'
$dependencyScriptPath = Join-Path $projectRoot 'setup\Install-ArgonovDependencies.ps1'
$iss = [System.IO.File]::ReadAllText($issPath)
$start = [System.IO.File]::ReadAllText($startPath)
$cmd = [System.IO.File]::ReadAllText($cmdPath)
$launch = [System.IO.File]::ReadAllText($launchPath)
$dependencyCmd = [System.IO.File]::ReadAllText($dependencyCmdPath)
$repairCmd = [System.IO.File]::ReadAllText($repairCmdPath)
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
Assert-PackageTest (Test-Path -LiteralPath $repairCmdPath -PathType Leaf) 'Dependency repair command exists.'
Assert-PackageTest (Test-Path -LiteralPath $dependencyScriptPath -PathType Leaf) 'Dependency bootstrap script exists.'
Assert-PackageTest ($iss.Contains('PrivilegesRequired=lowest')) 'Installer does not request administrator privileges.'
Assert-PackageTest ($iss.Contains('DefaultDirName={localappdata}\Programs\ARGONOV SHELL')) 'Default install path is user-scoped.'
Assert-PackageTest ($iss.Contains('payload\powershell')) 'Installer includes the PowerShell runtime.'
Assert-PackageTest ($iss.Contains('payload\dotnet')) 'Installer includes a private .NET runtime.'
Assert-PackageTest ($iss.Contains('Start-Argonov.cmd')) 'Shortcuts use the runtime bootstrap command.'
Assert-PackageTest ($cmd.Contains('DOTNET_ROOT_X64')) 'Bootstrap points .NET host resolution to the private runtime.'
Assert-PackageTest ($launch.Contains('wt.exe -d')) 'Desktop launcher opens a working-directory command tab in Windows Terminal.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installGit')")) 'Installer provides a Git dependency selection.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installPython')")) 'Installer provides a Python dependency selection.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installTerminal')")) 'Installer provides a Windows Terminal dependency selection.'
Assert-PackageTest ($dependencyScript.Contains('WindowsTerminal.exe')) 'Windows Terminal executable is checked during dependency setup.'
Assert-PackageTest (-not $dependencyScript.Contains('settings.json')) 'Windows Terminal user settings are not rewritten by the installer.'
Assert-PackageTest ($launch.Contains('wt.exe -d')) 'Launcher opens ARGONOV as a command tab in an existing Windows Terminal.'
Assert-PackageTest ($launch.Contains('WindowsTerminal\\wt.exe')) 'Launcher also supports the ARGONOV-managed portable Windows Terminal.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installSensors')")) 'Installer provides a sensor backend selection.'
Assert-PackageTest ($dependencyScript.Contains('Get-GitHubLatestRelease')) 'Dependency bootstrap retrieves maintained GitHub releases.'
Assert-PackageTest ($dependencyScript.Contains('PortableGit-.+-64-bit')) 'Git is deployed from the official portable distribution without admin installation.'
Assert-PackageTest ($dependencyScript.Contains('$startInfo.Arguments = ''-y -o"')) 'PortableGit uses the current 7-Zip SFX extraction switches.'
Assert-PackageTest ($dependencyScript.Contains("Test-Path -LiteralPath (Join-Path `$stagingRoot 'post-install.bat')")) 'PortableGit post-install launcher is verified before accepting Git.'
Assert-PackageTest (-not $dependencyScript.Contains("Join-Path `$stagingRoot 'etc\post-install')))")) 'PortableGit persistent post-install script directory is not incorrectly treated as a failure.'
Assert-PackageTest ($dependencyScript.Contains('$bashVersion = (& $stagedBash --version')) 'PortableGit Bash is probed in addition to git.exe.'
Assert-PackageTest ($dependencyScript.Contains('Invoke-VerifiedDownload')) 'External installers are SHA-256 verified before execution.'
Assert-PackageTest ($dependencyScript.Contains('qrcode[pil]')) 'Python QR dependencies are installed automatically.'
Assert-PackageTest ($dependencyScript.Contains('LibreHardwareMonitor')) 'SYSINFO sensor backend is installed automatically.'
Assert-PackageTest ($dependencyScript.Contains('Get-AppxPackage -Name Microsoft.WindowsTerminal')) 'Existing Microsoft Store Windows Terminal is detected and reused.'
Assert-PackageTest ($dependencyScript.Contains('WindowsTerminal.exe')) 'Portable Windows Terminal is downloaded and verified when required.'
Assert-PackageTest ($cmd.Contains('-NoProfile')) 'Dedicated shell launch does not load the user PowerShell profile first.'
Assert-PackageTest ($iss.Contains('uninsneveruninstall')) 'User data directories are preserved by uninstall.'
Assert-PackageTest (-not $iss.Contains('$PROFILE')) 'Installer definition does not edit the current PowerShell profile.'
Assert-PackageTest ($start.Contains("Join-Path `$PSHOME 'pwsh.exe'")) 'Shell launcher uses the shared PowerShell runtime.'
Assert-PackageTest ($start.Contains('. $argonovProfile')) 'Launcher loads ARGONOV profile explicitly.'
Assert-PackageTest ($iss.Contains('DestDir: "{localappdata}\Programs\ARGONOV-Dependencies\PowerShell"')) 'PowerShell runtime is installed in shared dependency storage.'
Assert-PackageTest ($iss.Contains('DestDir: "{localappdata}\Programs\ARGONOV-Dependencies\dotnet"')) '.NET runtime is installed in shared dependency storage.'
Assert-PackageTest ($iss.Contains('uninsneveruninstall')) 'Shared runtime files survive ARGONOV uninstallation.'
Assert-PackageTest ($cmd.Contains('ARGONOV_PWSH=%ARGONOV_DEPENDENCY_ROOT%\PowerShell\pwsh.exe')) 'Shell launcher resolves and starts the persistent shared PowerShell runtime.'
Assert-PackageTest ($dependencyCmd.Contains('ARGONOV_PWSH=%ARGONOV_DEPENDENCY_ROOT%\PowerShell\pwsh.exe')) 'Dependency setup resolves the persistent shared PowerShell runtime.'
Assert-PackageTest ($iss.Contains('Repair-ArgonovDependencies.cmd')) 'Start menu includes an automatic dependency repair option.'
Assert-PackageTest ($repairCmd.Contains('-InstallGit -InstallPython -InstallTerminal -InstallSensors')) 'Repair command retries all selected prerequisite installations.'
Assert-PackageTest ($dependencyScript.Contains("Add-UserPathEntry -Path `$sharedPowerShell")) 'Shared PowerShell is added to current-user PATH.'
Assert-PackageTest ($cmd.Contains('DOTNET_ROOT=%ARGONOV_DEPENDENCY_ROOT%\dotnet')) 'Shell launcher resolves the shared .NET runtime.'
Assert-PackageTest ($cmd.Contains('Git\usr\bin')) 'Shell launcher exposes the bundled Git OpenSSH client.'
Write-Host 'PACKAGE DEFINITION TESTS PASSED' -ForegroundColor Green
