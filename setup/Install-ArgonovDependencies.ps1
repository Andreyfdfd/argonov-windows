# ARGONOV SHELL dependency bootstrap.
# Installs shared tools per-user and leaves them outside the ARGONOV app directory.
[CmdletBinding()]
param(
    [switch]$InstallGit,
    [switch]$InstallPython,
    [switch]$InstallTerminal,
    [switch]$InstallSensors,
    [switch]$SetTerminalDefault,
    [switch]$ForceComponents,
    [switch]$NoUserPathChanges,
    [string]$InstallRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$DependencyRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
if ([string]::IsNullOrWhiteSpace($DependencyRoot)) {
    if ($env:ARGONOV_DEPENDENCY_ROOT) {
        $DependencyRoot = $env:ARGONOV_DEPENDENCY_ROOT
    } else {
        $DependencyRoot = Join-Path $env:LOCALAPPDATA 'Programs\ARGONOV-Dependencies'
    }
}
$DependencyRoot = [System.IO.Path]::GetFullPath($DependencyRoot)

if ($env:ARGONOV_INSTALLER_TEST -eq '1') {
    $ForceComponents = $true
    $NoUserPathChanges = $true
}

$logRoot = Join-Path $env:LOCALAPPDATA 'ARGONOV\installer'
if ($env:ARGONOV_INSTALLER_TEST -eq '1') {
    $logRoot = Join-Path $env:TEMP 'ARGONOV-Installer-Test-Logs'
}
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$logPath = Join-Path $logRoot 'dependency-install.log'
$reportPath = Join-Path $logRoot 'dependency-report.json'
$script:Results = [ordered]@{}
$script:Failures = [System.Collections.Generic.List[string]]::new()

function Write-DependencyLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','OK','WARN','ERROR')][string]$Level = 'INFO'
    )
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding utf8
    $color = switch ($Level) {
        'OK' { 'Green' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
}

function Add-UserPathEntry {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
    if ($NoUserPathChanges) {
        if (($env:PATH -split ';') -notcontains $Path) { $env:PATH = "$Path;$env:PATH" }
        return
    }

    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    if (-not $key) { $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment') }
    try {
        $current = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $entries = @($current -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $normal = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
        $present = $false
        foreach ($entry in $entries) {
            try {
                if ([System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($entry)).TrimEnd('\') -ieq $normal) {
                    $present = $true
                    break
                }
            } catch {}
        }
        if (-not $present) {
            $newValue = (@($entries) + $Path) -join ';'
            $key.SetValue('Path', $newValue, [Microsoft.Win32.RegistryValueKind]::ExpandString)
        }
    } finally {
        $key.Dispose()
    }
    if (($env:PATH -split ';') -notcontains $Path) { $env:PATH = "$Path;$env:PATH" }
}

function Invoke-VerifiedDownload {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Label
    )
    if ($ExpectedSha256 -notmatch '^[0-9a-fA-F]{64}$') {
        throw "$Label: no trusted SHA-256 digest was supplied."
    }
    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Write-DependencyLog "Downloading $Label..."
    Invoke-WebRequest -Uri $Uri -OutFile $Destination -TimeoutSec 180 -ErrorAction Stop
    $actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($actual -ine $ExpectedSha256) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        throw "$Label SHA-256 mismatch. Expected $ExpectedSha256; received $actual."
    }
    Write-DependencyLog "$Label downloaded and SHA-256 verified." 'OK'
    return $Destination
}

function Get-GitHubLatestRelease {
    param([Parameter(Mandatory)][string]$Repository)
    $headers = @{
        'User-Agent' = 'ARGONOV-SHELL-Setup'
        'Accept' = 'application/vnd.github+json'
    }
    return Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers $headers -TimeoutSec 30 -ErrorAction Stop
}

function Invoke-ExternalInstaller {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$Label
    )
    Write-DependencyLog "Installing $Label..."
    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru
    if ($process.ExitCode -notin @(0, 1641, 3010)) {
        throw "$Label installer returned exit code $($process.ExitCode)."
    }
    Write-DependencyLog "$Label installer completed (exit code $($process.ExitCode))." 'OK'
}

function Install-ArgonovGit {
    $managedGit = Join-Path $DependencyRoot 'Git'
    $managedGitExe = Join-Path $managedGit 'cmd\git.exe'
    if (-not $ForceComponents) {
        $existing = Get-Command git.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existing) {
            $version = (& $existing.Source --version 2>$null | Out-String).Trim()
            $script:Results.Git = [ordered]@{ Status = 'Existing'; Version = $version; Path = $existing.Source }
            Write-DependencyLog "Git already available: $version ($($existing.Source))." 'OK'
            return
        }
        if (Test-Path -LiteralPath $managedGitExe -PathType Leaf) {
            Add-UserPathEntry -Path (Join-Path $managedGit 'cmd')
            $version = (& $managedGitExe --version 2>$null | Out-String).Trim()
            $script:Results.Git = [ordered]@{ Status = 'Existing'; Version = $version; Path = $managedGitExe }
            Write-DependencyLog "Managed Git already available: $version." 'OK'
            return
        }
    }

    $release = Get-GitHubLatestRelease -Repository 'git-for-windows/git'
    $asset = $release.assets | Where-Object { $_.name -match '^Git-.+-64-bit\.exe$' } | Select-Object -First 1
    if (-not $asset -or -not $asset.browser_download_url) { throw 'Latest Git for Windows x64 installer was not found.' }
    if ([string]$asset.digest -notmatch '^sha256:([0-9a-fA-F]{64})$') { throw 'GitHub release did not provide a SHA-256 digest for Git installer.' }
    $installer = Join-Path $env:TEMP $asset.name
    Invoke-VerifiedDownload -Uri $asset.browser_download_url -Destination $installer -ExpectedSha256 $Matches[1] -Label "Git for Windows $($release.tag_name)" | Out-Null
    $arguments = @('/VERYSILENT','/NORESTART','/NOCANCEL','/SP-',"/DIR=$managedGit")
    Invoke-ExternalInstaller -FilePath $installer -ArgumentList $arguments -Label 'Git for Windows'
    if (-not (Test-Path -LiteralPath $managedGitExe -PathType Leaf)) { throw 'Git installation finished, but cmd\git.exe was not found.' }
    Add-UserPathEntry -Path (Join-Path $managedGit 'cmd')
    $version = (& $managedGitExe --version 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Git verification failed after installation.' }
    $script:Results.Git = [ordered]@{ Status = 'Installed'; Version = $version; Path = $managedGitExe }
    Write-DependencyLog "Git verified: $version." 'OK'
}

function Get-Python314 {
    $candidates = @(
        (Join-Path $DependencyRoot 'Python314\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python314\python.exe'),
        (Join-Path $env:ProgramFiles 'Python314\python.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $version = (& $candidate -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $version -eq '3.14') { return $candidate }
        }
    }
    if (-not $ForceComponents) {
        $launcher = Get-Command py.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($launcher) {
            $version = (& $launcher.Source -3.14 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $version -eq '3.14') { return $launcher.Source }
        }
    }
    return $null
}

function Install-ArgonovPython {
    $pythonExe = Get-Python314
    if (-not $pythonExe) {
        $pythonExe = Join-Path $DependencyRoot 'Python314\python.exe'
        if (-not $ForceComponents -and (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
            throw 'A managed Python directory exists but does not contain a working Python 3.14 runtime.'
        }
        $installerName = 'python-3.14.10-amd64.exe'
        $installerUri = 'https://www.python.org/ftp/python/3.14.10/python-3.14.10-amd64.exe'
        $installerHash = '92480239264744FE0386A1BD8275786FEFA126E3129E56A68E22B52C73329965'
        $installer = Join-Path $env:TEMP $installerName
        Invoke-VerifiedDownload -Uri $installerUri -Destination $installer -ExpectedSha256 $installerHash -Label 'Python 3.14.10 x64' | Out-Null
        $pythonRoot = Split-Path -Parent $pythonExe
        New-Item -ItemType Directory -Path $pythonRoot -Force | Out-Null
        $arguments = @(
            '/quiet',
            'InstallAllUsers=0',
            "TargetDir=$pythonRoot",
            'PrependPath=0',
            'AppendPath=0',
            'Include_launcher=1',
            'InstallLauncherAllUsers=0',
            'Include_pip=1',
            'Include_test=0',
            'Include_doc=0',
            'Include_tcltk=0',
            'Shortcuts=0'
        )
        Invoke-ExternalInstaller -FilePath $installer -ArgumentList $arguments -Label 'Python 3.14.10'
    }

    if (-not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
        $pythonExe = Get-Python314
    }
    if (-not $pythonExe -or -not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
        throw 'Python 3.14 runtime could not be located after installation.'
    }
    Add-UserPathEntry -Path (Split-Path -Parent $pythonExe)
    $scriptsPath = Join-Path (Split-Path -Parent $pythonExe) 'Scripts'
    Add-UserPathEntry -Path $scriptsPath
    $version = (& $pythonExe --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^Python 3\.14\.') {
        throw "Python verification failed: $version"
    }

    Write-DependencyLog 'Installing the QR-code package and Pillow image backend...'
    & $pythonExe -m pip install --disable-pip-version-check --upgrade 'qrcode[pil]'
    if ($LASTEXITCODE -ne 0) { throw 'pip could not install qrcode[pil].' }
    & $pythonExe -c 'import qrcode; from PIL import Image'
    if ($LASTEXITCODE -ne 0) { throw 'Python QR dependencies failed their import test.' }
    $script:Results.Python = [ordered]@{ Status = 'Ready'; Version = $version; Path = $pythonExe; Packages = @('qrcode','Pillow') }
    Write-DependencyLog "$version and qrcode/Pillow verified." 'OK'
}

function Get-ArgonovTerminalSettingsPath {
    param([string]$PortableRoot)
    if ($PortableRoot) {
        return (Join-Path $PortableRoot 'settings\settings.json')
    }
    $package = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($package) {
        return (Join-Path $env:LOCALAPPDATA "Packages\$($package.PackageFamilyName)\LocalState\settings.json")
    }
    return $null
}

function Install-ArgonovTerminal {
    $portableRoot = Join-Path $DependencyRoot 'WindowsTerminal'
    $terminalExe = Join-Path $portableRoot 'WindowsTerminal.exe'
    $settingsPath = $null
    $appxPackage = $null
    if (-not $ForceComponents) {
        $appxPackage = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if ($appxPackage) {
        $settingsPath = Get-ArgonovTerminalSettingsPath
        Write-DependencyLog "Using existing Windows Terminal package $($appxPackage.Version)." 'OK'
    } else {
        if (-not (Test-Path -LiteralPath $terminalExe -PathType Leaf) -or $ForceComponents) {
            $build = [Environment]::OSVersion.Version.Build
            if ($build -lt 19041) {
                throw "Windows Terminal portable mode requires Windows 10 build 19041 or newer. Current build: $build."
            }
            $release = Get-GitHubLatestRelease -Repository 'microsoft/terminal'
            $asset = $release.assets | Where-Object { $_.name -match '^Microsoft\.WindowsTerminal_.+_x64\.zip$' } | Select-Object -First 1
            if (-not $asset -or -not $asset.browser_download_url) { throw 'Latest stable Windows Terminal x64 ZIP was not found.' }
            if ([string]$asset.digest -notmatch '^sha256:([0-9a-fA-F]{64})$') { throw 'GitHub release did not provide a SHA-256 digest for Windows Terminal.' }
            $archive = Join-Path $env:TEMP $asset.name
            Invoke-VerifiedDownload -Uri $asset.browser_download_url -Destination $archive -ExpectedSha256 $Matches[1] -Label "Windows Terminal $($release.tag_name)" | Out-Null
            $tempExtract = Join-Path $env:TEMP ('ARGONOV-WT-' + [guid]::NewGuid().ToString('N'))
            try {
                Expand-Archive -LiteralPath $archive -DestinationPath $tempExtract -Force
                $exe = Get-ChildItem -LiteralPath $tempExtract -Filter 'WindowsTerminal.exe' -File -Recurse | Select-Object -First 1
                if (-not $exe) { throw 'Verified Windows Terminal archive did not contain WindowsTerminal.exe.' }
                $stagingRoot = "$portableRoot.staging-$([guid]::NewGuid().ToString('N'))"
                New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
                Copy-Item -Path (Join-Path $exe.DirectoryName '*') -Destination $stagingRoot -Recurse -Force
                New-Item -ItemType File -Path (Join-Path $stagingRoot '.portable') -Force | Out-Null
                Set-Content -LiteralPath (Join-Path $stagingRoot 'argonov-dependency.json') -Value (@{
                    Name = 'Windows Terminal'
                    Version = $release.tag_name
                    Source = $asset.browser_download_url
                    SHA256 = $Matches[1]
                    ManagedBy = 'ARGONOV SHELL installer'
                    InstalledAt = (Get-Date).ToString('o')
                } | ConvertTo-Json -Depth 4) -Encoding utf8
                if (Test-Path -LiteralPath $portableRoot) {
                    $backup = "$portableRoot.backup-$([guid]::NewGuid().ToString('N'))"
                    Move-Item -LiteralPath $portableRoot -Destination $backup
                    try {
                        Move-Item -LiteralPath $stagingRoot -Destination $portableRoot
                        Remove-Item -LiteralPath $backup -Recurse -Force
                    } catch {
                        if (-not (Test-Path -LiteralPath $portableRoot)) { Move-Item -LiteralPath $backup -Destination $portableRoot }
                        throw
                    }
                } else {
                    Move-Item -LiteralPath $stagingRoot -Destination $portableRoot
                }
            } finally {
                if (Test-Path -LiteralPath $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
            }
            $terminalExe = Join-Path $portableRoot 'WindowsTerminal.exe'
            if (-not (Test-Path -LiteralPath $terminalExe -PathType Leaf)) { throw 'Windows Terminal was not installed correctly.' }
            $releaseVersion = [string]$release.tag_name
            Write-DependencyLog "Installed portable Windows Terminal $releaseVersion." 'OK'
        } else {
            Write-DependencyLog 'ARGONOV-managed Windows Terminal is already present.' 'OK'
        }
        $settingsPath = Get-ArgonovTerminalSettingsPath -PortableRoot $portableRoot
    }

    if (-not $settingsPath) { throw 'Windows Terminal settings path could not be resolved.' }
    $settingsDirectory = Split-Path -Parent $settingsPath
    New-Item -ItemType Directory -Path $settingsDirectory -Force | Out-Null

    $profileGuid = '{A3D6C31F-5E7B-4F4A-8C2E-ARGONOV00001}'
    # Use a syntactically valid, stable Windows Terminal profile GUID.
    $profileGuid = '{A3D6C31F-5E7B-4F4A-8C2E-9D4F2A6B1C80}'
    $launcher = Join-Path $InstallRoot 'Start-Argonov.cmd'
    $commandLine = 'cmd.exe /d /s /c ""' + $launcher + '""'
    $argonovProfile = [ordered]@{
        guid = $profileGuid
        name = 'ARGONOV SHELL'
        commandline = $commandLine
        startingDirectory = '%USERPROFILE%'
        hidden = $false
    }

    if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.argonov-backup-$stamp" -Force
        try {
            $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
        } catch {
            throw "Windows Terminal settings.json is not valid JSON. Original file was backed up: $settingsPath"
        }
    } else {
        $settings = [ordered]@{
            '$schema' = 'https://aka.ms/terminal-profiles-schema'
            profiles = [ordered]@{ defaults = [ordered]@{}; list = @() }
            schemes = @()
            actions = @()
        }
    }

    if (-not $settings.Contains('profiles') -or $settings.profiles -isnot [System.Collections.IDictionary]) {
        $settings['profiles'] = [ordered]@{ defaults = [ordered]@{}; list = @() }
    }
    if (-not $settings.profiles.Contains('list')) { $settings.profiles['list'] = @() }
    $existingProfiles = @($settings.profiles['list'] | Where-Object { $_ -and $_.guid -ne $profileGuid })
    $settings.profiles['list'] = @($existingProfiles + $argonovProfile)
    if ($SetTerminalDefault -or -not $settings.Contains('defaultProfile') -or [string]::IsNullOrWhiteSpace([string]$settings.defaultProfile)) {
        $settings['defaultProfile'] = $profileGuid
    }
    $json = $settings | ConvertTo-Json -Depth 64
    [System.IO.File]::WriteAllText($settingsPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

    $script:Results.WindowsTerminal = [ordered]@{
        Status = 'Configured'
        Version = if ($appxPackage) { [string]$appxPackage.Version } else { [string]$releaseVersion }
        Settings = $settingsPath
        DefaultProfile = [bool]($settings.defaultProfile -eq $profileGuid)
    }
    Write-DependencyLog "ARGONOV SHELL profile added to Windows Terminal settings: $settingsPath." 'OK'
}

function Install-ArgonovSensors {
    $modulePath = Join-Path $InstallRoot 'modules\system\sysinfo.ps1'
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) { throw "SYSINFO module not found: $modulePath" }
    . $modulePath
    if (-not (Get-Command Install-ArgonovSysInfoSensorBackend -ErrorAction SilentlyContinue)) {
        throw 'SYSINFO sensor installer function was not loaded.'
    }
    Install-ArgonovSysInfoSensorBackend
    $library = Join-Path $env:LOCALAPPDATA 'ARGONOV\tools\LibreHardwareMonitor\LibreHardwareMonitorLib.dll'
    if (-not (Test-Path -LiteralPath $library -PathType Leaf)) {
        throw 'LibreHardwareMonitor backend was not installed. See dependency-install.log for details.'
    }
    $script:Results.Sensors = [ordered]@{ Status = 'Installed'; Path = $library }
    Write-DependencyLog 'LibreHardwareMonitor backend verified.' 'OK'
}

Write-DependencyLog "Starting dependency setup. InstallRoot=$InstallRoot; DependencyRoot=$DependencyRoot"
if ($InstallGit) {
    try { Install-ArgonovGit } catch { $script:Failures.Add("Git: $($_.Exception.Message)"); $script:Results.Git = @{ Status = 'Failed'; Error = $_.Exception.Message }; Write-DependencyLog $script:Failures[-1] 'ERROR' }
}
if ($InstallPython) {
    try { Install-ArgonovPython } catch { $script:Failures.Add("Python: $($_.Exception.Message)"); $script:Results.Python = @{ Status = 'Failed'; Error = $_.Exception.Message }; Write-DependencyLog $script:Failures[-1] 'ERROR' }
}
if ($InstallTerminal) {
    try { Install-ArgonovTerminal } catch { $script:Failures.Add("Windows Terminal: $($_.Exception.Message)"); $script:Results.WindowsTerminal = @{ Status = 'Failed'; Error = $_.Exception.Message }; Write-DependencyLog $script:Failures[-1] 'ERROR' }
}
if ($InstallSensors) {
    try { Install-ArgonovSensors } catch { $script:Failures.Add("LibreHardwareMonitor: $($_.Exception.Message)"); $script:Results.Sensors = @{ Status = 'Failed'; Error = $_.Exception.Message }; Write-DependencyLog $script:Failures[-1] 'ERROR' }
}

$report = [ordered]@{
    Product = 'ARGONOV SHELL'
    InstallRoot = $InstallRoot
    DependencyRoot = $DependencyRoot
    CompletedAt = (Get-Date).ToString('o')
    Results = $script:Results
    Failures = @($script:Failures)
}
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding utf8
Write-DependencyLog "Dependency report saved: $reportPath"
if ($script:Failures.Count -gt 0) {
    Write-DependencyLog "$($script:Failures.Count) component(s) did not complete successfully. ARGONOV can still open; see the report and log." 'WARN'
    exit 1
}
Write-DependencyLog 'All selected dependency tasks completed successfully.' 'OK'
exit 0
