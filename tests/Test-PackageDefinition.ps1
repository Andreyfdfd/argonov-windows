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
$osintPath = Join-Path $projectRoot 'modules\osint\hacktool.ps1'
$sysinfoPath = Join-Path $projectRoot 'modules\system\sysinfo.ps1'

foreach ($path in @($issPath,$startPath,$cmdPath,$launchPath,$dependencyCmdPath,$repairCmdPath,$dependencyScriptPath,$osintPath,$sysinfoPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required package file is missing: $path" }
}
$iss = [System.IO.File]::ReadAllText($issPath)
$start = [System.IO.File]::ReadAllText($startPath)
$cmd = [System.IO.File]::ReadAllText($cmdPath)
$launch = [System.IO.File]::ReadAllText($launchPath)
$dependencyCmd = [System.IO.File]::ReadAllText($dependencyCmdPath)
$repairCmd = [System.IO.File]::ReadAllText($repairCmdPath)
$dependencyScript = [System.IO.File]::ReadAllText($dependencyScriptPath)
$osintScript = [System.IO.File]::ReadAllText($osintPath)
$sysinfoScript = [System.IO.File]::ReadAllText($sysinfoPath)

function Assert-PackageTest {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "PACKAGE TEST FAILED: $Message" }
    Write-Host "[PASS] $Message" -ForegroundColor Green
}

Assert-PackageTest ($iss.Contains('PrivilegesRequired=lowest')) 'Installer does not request administrator privileges.'
Assert-PackageTest ($iss.Contains('DefaultDirName={localappdata}\Programs\ARGONOV SHELL')) 'Default install path is user-scoped.'
Assert-PackageTest ($iss.Contains('payload\powershell')) 'Installer includes the PowerShell runtime.'
Assert-PackageTest ($iss.Contains('payload\dotnet')) 'Installer includes a private .NET runtime.'
Assert-PackageTest ($iss.Contains('Start-Argonov.cmd')) 'Installer creates the dedicated shell shortcut.'
Assert-PackageTest ($iss.Contains('Launch-Argonov.cmd')) 'Installer creates the Windows Terminal launcher.'
Assert-PackageTest ($iss.Contains('Repair-ArgonovDependencies.cmd')) 'Installer creates the dependency repair shortcut.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installGit')")) 'Installer provides a Git dependency selection.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installPython')")) 'Installer provides a Python dependency selection.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installTerminal')")) 'Installer provides a Windows Terminal dependency selection.'
Assert-PackageTest ($iss.Contains("WizardIsTaskSelected('installSensors')")) 'Installer provides a sensor backend selection.'
Assert-PackageTest ($iss.Contains('uninsneveruninstall')) 'User data and shared dependency directories survive shell uninstall.'

Assert-PackageTest ($cmd.Contains('DOTNET_ROOT_X64')) 'Bootstrap points .NET host resolution to the private runtime.'
Assert-PackageTest ($cmd.Contains('-NoProfile')) 'Dedicated shell launch does not load the user PowerShell profile first.'
Assert-PackageTest ($cmd.Contains('-ExecutionPolicy Bypass')) 'Shell launch uses process-only execution policy bypass.'
Assert-PackageTest ($cmd.Contains('System32\OpenSSH\ssh.exe')) 'Shell launcher prefers native Windows OpenSSH when available.'
Assert-PackageTest ($cmd.Contains('Git\usr\bin\ssh.exe')) 'Shell launcher supports the bundled MinGit OpenSSH client.'
Assert-PackageTest (-not $cmd.Contains('Git\usr\bin;%PATH%')) 'MinGit Unix utilities are not added to PATH.'
Assert-PackageTest ($launch.Contains('wt.exe -d')) 'Desktop launcher opens a Windows Terminal command tab.'
Assert-PackageTest ($launch.Contains('WindowsTerminal\wt.exe')) 'Desktop launcher supports the ARGONOV-managed portable Windows Terminal.'

Assert-PackageTest ($dependencyScript.Contains('Get-GitHubLatestRelease')) 'Dependency bootstrap retrieves maintained upstream releases.'
Assert-PackageTest ($dependencyScript.Contains('MinGit-.+-64-bit\.zip')) 'Git is deployed from the official MinGit ZIP.'
Assert-PackageTest ($dependencyScript.Contains('Expand-Archive -LiteralPath $archive -DestinationPath $stagingRoot')) 'MinGit is extracted with built-in Windows archive support.'
Assert-PackageTest ($dependencyScript.Contains('cmd\git.exe')) 'MinGit git.exe is validated before the dependency is accepted.'
Assert-PackageTest ($dependencyScript.Contains('SSH transport can be enabled later')) 'Missing OpenSSH does not block Git HTTPS transport.'
Assert-PackageTest (-not $dependencyScript.Contains('PortableGit-')) 'Dependency bootstrap does not launch the PortableGit SFX installer.'
Assert-PackageTest ($dependencyScript.Contains('Invoke-VerifiedDownload')) 'External installers and archives are hash-verified.'
Assert-PackageTest ($dependencyScript.Contains('qrcode[pil]')) 'Python QR dependencies are installed automatically.'
Assert-PackageTest ($dependencyScript.Contains('PythonPackages')) 'Python packages are isolated in the shared dependency directory.'
Assert-PackageTest ($dependencyScript.Contains('--target $pythonPackagesRoot')) 'pip installs into the managed packages folder.'
Assert-PackageTest ($dependencyScript.Contains('Get-AppxPackage -Name Microsoft.WindowsTerminal')) 'Existing Microsoft Store Windows Terminal is detected and reused.'
Assert-PackageTest ($dependencyScript.Contains('WindowsTerminal.exe')) 'Portable Windows Terminal is downloaded when required.'
Assert-PackageTest ($dependencyScript.Contains('[System.Diagnostics.FileVersionInfo]::GetVersionInfo($terminalExe).FileVersion')) 'Terminal version is read without starting its GUI.'
Assert-PackageTest (-not $dependencyScript.Contains('$terminalExe --version')) 'Dependency setup never launches the Terminal GUI just to inspect its version.'
Assert-PackageTest ($dependencyScript.Contains('ARGONOV_SYSINFO_LHM_DIR')) 'SYSINFO sensor backend supports an isolated dependency root.'
Assert-PackageTest ($dependencyScript.Contains('LibreHardwareMonitor')) 'SYSINFO sensor backend is installed automatically.'

Assert-PackageTest ($osintScript.Contains('https://rdap.org/domain/')) 'WHOIS lookup has a built-in RDAP fallback.'
Assert-PackageTest ($osintScript.Contains('Get-Command whois.exe')) 'An existing WHOIS client remains supported.'
Assert-PackageTest ($sysinfoScript.Contains('Initialize-ArgonovSysInfoLhmAssembly')) 'SYSINFO can validate the installed sensor assembly.'
$sensorInstallStart = $sysinfoScript.IndexOf('function Install-ArgonovSysInfoSensorBackend')
$sensorInstallEnd = $sysinfoScript.IndexOf('function Export-ArgonovSysInfoReport', $sensorInstallStart)
if ($sensorInstallStart -lt 0 -or $sensorInstallEnd -lt 0) { throw 'SYSINFO sensor installer function boundaries were not found.' }
$sensorInstallBlock = $sysinfoScript.Substring($sensorInstallStart, $sensorInstallEnd - $sensorInstallStart)
Assert-PackageTest (-not $sensorInstallBlock.Contains('Get-ArgonovSysInfoSensors')) 'Sensor installation does not enumerate hardware during setup.'

Assert-PackageTest ($start.Contains('Join-Path $PSHOME')) 'Shell launcher uses the shared PowerShell runtime.'
Assert-PackageTest ($start.Contains('. $argonovProfile')) 'Launcher loads ARGONOV profile explicitly.'
Assert-PackageTest ($iss.Contains('DestDir: "{localappdata}\Programs\ARGONOV-Dependencies\PowerShell"')) 'PowerShell runtime is installed in shared dependency storage.'
Assert-PackageTest ($iss.Contains('DestDir: "{localappdata}\Programs\ARGONOV-Dependencies\dotnet"')) '.NET runtime is installed in shared dependency storage.'
Assert-PackageTest ($cmd.Contains('ARGONOV_PWSH=%ARGONOV_DEPENDENCY_ROOT%\PowerShell\pwsh.exe')) 'Shell launcher resolves the persistent shared PowerShell runtime.'
Assert-PackageTest ($dependencyCmd.Contains('ARGONOV_PWSH=%ARGONOV_DEPENDENCY_ROOT%\PowerShell\pwsh.exe')) 'Dependency setup resolves the persistent shared PowerShell runtime.'
Assert-PackageTest ($iss.Contains('Repair-ArgonovDependencies.cmd')) 'Start menu includes an automatic dependency repair option.'
Assert-PackageTest ($repairCmd.Contains('-InstallGit -InstallPython -InstallTerminal -InstallSensors')) 'Repair command retries all dependency installation tasks.'
Assert-PackageTest ($dependencyScript.Contains('Add-UserPathEntry -Path $sharedPowerShell')) 'Shared PowerShell is added to the current-user PATH.'
Assert-PackageTest (-not $iss.Contains('$PROFILE')) 'Installer does not edit the current PowerShell profile.'
Write-Host 'PACKAGE DEFINITION TESTS PASSED' -ForegroundColor Green
