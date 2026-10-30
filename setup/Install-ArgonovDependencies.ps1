# ARGONOV SHELL dependency bootstrap.
# Shared runtimes and tools are installed outside the ARGONOV application directory.
[CmdletBinding()]
param(
    [switch]$InstallGit,
    [switch]$InstallPython,
    [switch]$InstallTerminal,
    [switch]$InstallSensors,
    [switch]$ForceComponents,
    [switch]$NoUserPathChanges,
    [string]$InstallRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$DependencyRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)

if ([string]::IsNullOrWhiteSpace($DependencyRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($env:ARGONOV_DEPENDENCY_ROOT)) {
        $DependencyRoot = $env:ARGONOV_DEPENDENCY_ROOT
    } else {
        $DependencyRoot = Join-Path $env:LOCALAPPDATA 'Programs\ARGONOV-Dependencies'
    }
}
$DependencyRoot = [System.IO.Path]::GetFullPath($DependencyRoot)

$testMode = $env:ARGONOV_INSTALLER_TEST -eq '1'
if ($testMode) {
    $ForceComponents = $true
    $NoUserPathChanges = $true
}

$logRoot = Join-Path $env:LOCALAPPDATA 'ARGONOV\installer'
if ($testMode) {
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
    $normal = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')

    if ($NoUserPathChanges) {
        $presentInProcess = @($env:PATH -split ';' | Where-Object { $_.TrimEnd('\') -ieq $normal })
        if (-not $presentInProcess) { $env:PATH = "$normal;$env:PATH" }
        return
    }

    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    if (-not $key) { $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment') }
    try {
        $current = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $entries = @($current -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $present = $false
        foreach ($entry in $entries) {
            try {
                $expanded = [Environment]::ExpandEnvironmentVariables($entry)
                if ([System.IO.Path]::GetFullPath($expanded).TrimEnd('\') -ieq $normal) {
                    $present = $true
                    break
                }
            } catch {}
        }
        if (-not $present) {
            $key.SetValue('Path', ((@($entries) + $normal) -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
        }
    } finally {
        $key.Dispose()
    }

    $processEntries = @($env:PATH -split ';' | Where-Object { $_.TrimEnd('\') -ieq $normal })
    if (-not $processEntries) { $env:PATH = "$normal;$env:PATH" }
}

function Invoke-VerifiedDownload {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Label
    )
    if ($ExpectedSha256 -notmatch '^[0-9a-fA-F]{64}$') {
        throw ("{0}: no trusted SHA-256 digest was supplied." -f $Label)
    }

    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Write-DependencyLog "Downloading $Label..."
    Invoke-WebRequest -Uri $Uri -OutFile $Destination -TimeoutSec 240 -ErrorAction Stop
    $actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($actual -ine $ExpectedSha256) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        throw ("{0} SHA-256 mismatch. Expected {1}; received {2}." -f $Label, $ExpectedSha256, $actual)
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
    Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers $headers -TimeoutSec 30 -ErrorAction Stop
}

function Invoke-ExternalInstaller {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "$Label installer file was not found: $FilePath"
    }

    Write-DependencyLog "Installing $Label..."
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $false
    foreach ($argument in $ArgumentList) {
        [void]$startInfo.ArgumentList.Add([string]$argument)
    }

    $process = [System.Diagnostics.Process]::Start($startInfo)
    if (-not $process) { throw "Could not start the $Label installer." }
    try {
        $process.WaitForExit()
        $code = $process.ExitCode
    } finally {
        $process.Dispose()
    }

    if ($code -notin @(0, 1641, 3010)) {
        throw "$Label installer returned exit code $code."
    }
    Write-DependencyLog "$Label installer completed (exit code $code)." 'OK'
}

function Install-ArgonovGit {
    $managedGit = Join-Path $DependencyRoot 'Git'
    $managedGitExe = Join-Path $managedGit 'cmd\git.exe'

    if (-not $ForceComponents) {
        $existing = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existing) {
            $version = (& $existing.Source --version 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $version -match '^git version ') {
                $script:Results.Git = [ordered]@{ Status = 'Existing'; Version = $version; Path = $existing.Source }
                Write-DependencyLog "Git already available: $version." 'OK'
                return
            }
        }
        if (Test-Path -LiteralPath $managedGitExe -PathType Leaf) {
            Add-UserPathEntry -Path (Join-Path $managedGit 'cmd')
            $version = (& $managedGitExe --version 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $version -match '^git version ') {
                $script:Results.Git = [ordered]@{ Status = 'Existing'; Version = $version; Path = $managedGitExe }
                Write-DependencyLog "Managed MinGit already available: $version." 'OK'
                return
            }
        }
    }

    $release = Get-GitHubLatestRelease -Repository 'git-for-windows/git'
    $asset = $release.assets | Where-Object { $_.name -match '^MinGit-.+-64-bit\.zip$' } | Select-Object -First 1
    if (-not $asset -or -not $asset.browser_download_url) {
        throw 'Latest MinGit x64 ZIP archive was not found in the official Git for Windows release.'
    }
    $digestMatch = [regex]::Match([string]$asset.digest, '^sha256:(?<hash>[0-9a-fA-F]{64})$')
    if (-not $digestMatch.Success) {
        throw 'GitHub release did not provide a SHA-256 digest for MinGit.'
    }

    $minGitHash = $digestMatch.Groups['hash'].Value
    $archive = Join-Path $env:TEMP $asset.name
    Invoke-VerifiedDownload -Uri $asset.browser_download_url -Destination $archive -ExpectedSha256 $minGitHash -Label "MinGit $($release.tag_name)" | Out-Null

    $parent = Split-Path -Parent $managedGit
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $stagingRoot = "$managedGit.staging-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
    try {
        Write-DependencyLog "Extracting MinGit $($release.tag_name) into the per-user dependency directory..."
        Expand-Archive -LiteralPath $archive -DestinationPath $stagingRoot -Force

        $stagedGitExe = Join-Path $stagingRoot 'cmd\git.exe'
        if (-not (Test-Path -LiteralPath $stagedGitExe -PathType Leaf)) {
            throw 'MinGit extraction completed, but cmd\git.exe was not found.'
        }

        $sshCandidates = @(
            (Join-Path $stagingRoot 'usr\bin\ssh.exe'),
            (Join-Path $stagingRoot 'mingw64\bin\ssh.exe'),
            (Join-Path $stagingRoot 'ucrt64\bin\ssh.exe')
        )
        $stagedSsh = $sshCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
        if (-not $stagedSsh) {
            throw 'MinGit archive did not include an OpenSSH client. Git was not accepted as fully configured.'
        }

        $gitVersion = (& $stagedGitExe --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $gitVersion -notmatch '\.windows\.\d+$') {
            throw "MinGit Git version probe failed: $gitVersion"
        }
        $sshVersion = (& $stagedSsh -V 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $sshVersion -notmatch 'OpenSSH') {
            throw "MinGit OpenSSH client probe failed: $sshVersion"
        }
        Write-DependencyLog "$gitVersion; $sshVersion verified." 'OK'

        $sshRelativePath = [System.IO.Path]::GetRelativePath($stagingRoot, $stagedSsh)
        $meta = [ordered]@{
            Name = 'MinGit'
            Version = $release.tag_name
            Source = $asset.browser_download_url
            SHA256 = $minGitHash
            SshRelativePath = $sshRelativePath
            ManagedBy = 'ARGONOV SHELL installer'
            InstalledAt = (Get-Date).ToString('o')
        }
        $meta | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stagingRoot 'argonov-dependency.json') -Encoding utf8

        if (Test-Path -LiteralPath $managedGit) {
            $backup = "$managedGit.backup-$([guid]::NewGuid().ToString('N'))"
            Move-Item -LiteralPath $managedGit -Destination $backup
            try {
                Move-Item -LiteralPath $stagingRoot -Destination $managedGit
                Remove-Item -LiteralPath $backup -Recurse -Force
            } catch {
                if (-not (Test-Path -LiteralPath $managedGit)) {
                    Move-Item -LiteralPath $backup -Destination $managedGit
                }
                throw
            }
        } else {
            Move-Item -LiteralPath $stagingRoot -Destination $managedGit
        }
    } finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path -LiteralPath $managedGitExe -PathType Leaf)) {
        throw 'MinGit was not installed correctly.'
    }
    Add-UserPathEntry -Path (Join-Path $managedGit 'cmd')
    $version = (& $managedGitExe --version 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^git version ') {
        throw 'MinGit verification failed after extraction.'
    }

    $managedSshCandidates = @(
        (Join-Path $managedGit 'usr\bin\ssh.exe'),
        (Join-Path $managedGit 'mingw64\bin\ssh.exe'),
        (Join-Path $managedGit 'ucrt64\bin\ssh.exe')
    )
    $managedSsh = $managedSshCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $managedSsh) {
        throw 'MinGit OpenSSH client is missing after installation.'
    }

    $script:Results.Git = [ordered]@{
        Status = 'Installed'
        Version = $version
        Path = $managedGitExe
        SshPath = $managedSsh
        Flavor = 'MinGit'
    }
    Write-DependencyLog "$version (MinGit) and bundled OpenSSH client verified." 'OK'
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
        $launcher = Get-Command py.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($launcher) {
            $resolvedPython = (& $launcher.Source -3.14 -c 'import sys; print(sys.executable)' 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $resolvedPython -PathType Leaf)) {
                $version = (& $resolvedPython -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>$null | Out-String).Trim()
                if ($LASTEXITCODE -eq 0 -and $version -eq '3.14') { return $resolvedPython }
            }
        }
    }
    return $null
}

function Install-ArgonovPython {
    $pythonExe = Get-Python314
    if (-not $pythonExe) {
        $pythonExe = Join-Path $DependencyRoot 'Python314\python.exe'
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

    $pythonPackagesRoot = Join-Path $DependencyRoot 'PythonPackages'
    New-Item -ItemType Directory -Path $pythonPackagesRoot -Force | Out-Null
    $previousPythonPath = $env:PYTHONPATH
    try {
        $env:PYTHONPATH = if ($previousPythonPath) { "$pythonPackagesRoot;$previousPythonPath" } else { $pythonPackagesRoot }
        Write-DependencyLog "Installing qrcode and Pillow into the shared dependency directory: $pythonPackagesRoot"
        & $pythonExe -m pip install --disable-pip-version-check --upgrade --target $pythonPackagesRoot 'qrcode[pil]'
        if ($LASTEXITCODE -ne 0) { throw 'pip could not install qrcode[pil] into the managed dependency directory.' }
        & $pythonExe -c 'import qrcode; from PIL import Image'
        if ($LASTEXITCODE -ne 0) { throw 'Python QR dependencies failed their import test.' }
    } finally {
        $env:PYTHONPATH = $previousPythonPath
    }

    $script:Results.Python = [ordered]@{
        Status = 'Ready'
        Version = $version
        Path = $pythonExe
        Packages = @('qrcode','Pillow')
    }
    Write-DependencyLog "$version and qrcode/Pillow verified." 'OK'
}

function Install-ArgonovTerminal {
    $portableRoot = Join-Path $DependencyRoot 'WindowsTerminal'
    $terminalExe = Join-Path $portableRoot 'WindowsTerminal.exe'
    $terminalCli = Join-Path $portableRoot 'wt.exe'
    $appxPackage = $null

    if (-not $ForceComponents) {
        $appxPackage = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if (-not $ForceComponents -and -not $appxPackage) {
        $existingTerminal = Get-Command wt.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existingTerminal) {
            $script:Results.WindowsTerminal = [ordered]@{
                Status = 'Existing'
                Version = 'Unpackaged'
                Mode = 'Unpackaged'
                Path = $existingTerminal.Source
                SettingsModified = $false
            }
            Write-DependencyLog "Using existing unpackaged Windows Terminal at $($existingTerminal.Source). User settings will not be modified." 'OK'
            return
        }
    }

    if ($appxPackage) {
        $version = [string]$appxPackage.Version
        $script:Results.WindowsTerminal = [ordered]@{
            Status = 'Existing'
            Version = $version
            Mode = 'AppX'
            SettingsModified = $false
        }
        Write-DependencyLog "Using existing Microsoft Store Windows Terminal $version. User settings will not be modified." 'OK'
        return
    }

    if ((Test-Path -LiteralPath $terminalExe -PathType Leaf) -and (Test-Path -LiteralPath $terminalCli -PathType Leaf) -and -not $ForceComponents) {
        $manifest = Join-Path $portableRoot 'argonov-dependency.json'
        $version = 'managed'
        if (Test-Path -LiteralPath $manifest -PathType Leaf) {
            try {
                $metadata = Get-Content -LiteralPath $manifest -Raw -Encoding utf8 | ConvertFrom-Json
                if ($metadata.Version) { $version = [string]$metadata.Version }
            } catch {}
        }
        $script:Results.WindowsTerminal = [ordered]@{
            Status = 'Existing'
            Version = $version
            Mode = 'Portable'
            Path = $terminalCli
            SettingsModified = $false
        }
        Write-DependencyLog "ARGONOV-managed portable Windows Terminal $version is already available." 'OK'
        return
    }

    $build = [Environment]::OSVersion.Version.Build
    if ($build -lt 19041) {
        throw "Windows Terminal portable mode requires Windows 10 build 19041 or newer. Current build: $build."
    }

    $release = Get-GitHubLatestRelease -Repository 'microsoft/terminal'
    $asset = $release.assets | Where-Object { $_.name -match '^Microsoft\.WindowsTerminal_.+_x64\.zip$' } | Select-Object -First 1
    if (-not $asset -or -not $asset.browser_download_url) {
        throw 'Latest stable Windows Terminal x64 ZIP was not found.'
    }
    $digestMatch = [regex]::Match([string]$asset.digest, '^sha256:(?<hash>[0-9a-fA-F]{64})$')
    if (-not $digestMatch.Success) {
        throw 'GitHub release did not provide a SHA-256 digest for Windows Terminal.'
    }
    $terminalHash = $digestMatch.Groups['hash'].Value
    $archive = Join-Path $env:TEMP $asset.name
    Invoke-VerifiedDownload -Uri $asset.browser_download_url -Destination $archive -ExpectedSha256 $terminalHash -Label "Windows Terminal $($release.tag_name)" | Out-Null

    $tempExtract = Join-Path $env:TEMP ('ARGONOV-WT-' + [guid]::NewGuid().ToString('N'))
    $stagingRoot = "$portableRoot.staging-$([guid]::NewGuid().ToString('N'))"
    try {
        Expand-Archive -LiteralPath $archive -DestinationPath $tempExtract -Force
        $exe = Get-ChildItem -LiteralPath $tempExtract -Filter 'WindowsTerminal.exe' -File -Recurse | Select-Object -First 1
        $cli = Get-ChildItem -LiteralPath $tempExtract -Filter 'wt.exe' -File -Recurse | Select-Object -First 1
        if (-not $exe -or -not $cli) {
            throw 'Verified Windows Terminal archive did not contain WindowsTerminal.exe and wt.exe.'
        }

        New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
        Copy-Item -Path (Join-Path $exe.DirectoryName '*') -Destination $stagingRoot -Recurse -Force
        New-Item -ItemType File -Path (Join-Path $stagingRoot '.portable') -Force | Out-Null
        @{
            Name = 'Windows Terminal'
            Version = $release.tag_name
            Source = $asset.browser_download_url
            SHA256 = $terminalHash
            ManagedBy = 'ARGONOV SHELL installer'
            InstalledAt = (Get-Date).ToString('o')
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stagingRoot 'argonov-dependency.json') -Encoding utf8

        $stagedTerminal = Join-Path $stagingRoot 'WindowsTerminal.exe'
        $stagedCli = Join-Path $stagingRoot 'wt.exe'
        if (-not (Test-Path -LiteralPath $stagedTerminal -PathType Leaf) -or -not (Test-Path -LiteralPath $stagedCli -PathType Leaf)) {
            throw 'Portable Windows Terminal files failed the post-copy validation.'
        }

        if (Test-Path -LiteralPath $portableRoot) {
            $backup = "$portableRoot.backup-$([guid]::NewGuid().ToString('N'))"
            Move-Item -LiteralPath $portableRoot -Destination $backup
            try {
                Move-Item -LiteralPath $stagingRoot -Destination $portableRoot
                Remove-Item -LiteralPath $backup -Recurse -Force
            } catch {
                if (-not (Test-Path -LiteralPath $portableRoot)) {
                    Move-Item -LiteralPath $backup -Destination $portableRoot
                }
                throw
            }
        } else {
            Move-Item -LiteralPath $stagingRoot -Destination $portableRoot
        }
    } finally {
        if (Test-Path -LiteralPath $tempExtract) {
            Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path -LiteralPath $terminalExe -PathType Leaf) -or -not (Test-Path -LiteralPath $terminalCli -PathType Leaf)) {
        throw 'Windows Terminal portable installation did not pass its executable checks.'
    }

    # WindowsTerminal.exe is a GUI application. Do not execute it during setup
    # merely to read its version; inspect PE version metadata without opening a window.
    $terminalVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($terminalExe).FileVersion
    if ([string]::IsNullOrWhiteSpace($terminalVersion)) {
        $terminalVersion = [string]$release.tag_name
    }
    Write-DependencyLog "Portable Windows Terminal file version: $terminalVersion (release $($release.tag_name)); archive SHA-256 verified." 'OK'

    $script:Results.WindowsTerminal = [ordered]@{
        Status = 'Installed'
        Version = [string]$release.tag_name
        Mode = 'Portable'
        Path = $terminalCli
        SettingsModified = $false
    }
    Write-DependencyLog "Portable Windows Terminal $($release.tag_name) installed. No user settings files were modified." 'OK'
}

function Install-ArgonovSensors {
    $modulePath = Join-Path $InstallRoot 'modules\system\sysinfo.ps1'
    $sensorRoot = if (-not [string]::IsNullOrWhiteSpace($env:ARGONOV_SYSINFO_LHM_DIR)) {
        [System.IO.Path]::GetFullPath($env:ARGONOV_SYSINFO_LHM_DIR)
    } else {
        Join-Path $env:LOCALAPPDATA 'ARGONOV\tools\LibreHardwareMonitor'
    }
    $env:ARGONOV_SYSINFO_LHM_DIR = $sensorRoot
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        throw "SYSINFO module not found: $modulePath"
    }

    . $modulePath
    $installer = Get-Command Install-ArgonovSysInfoSensorBackend -ErrorAction SilentlyContinue
    if (-not $installer) {
        throw 'SYSINFO sensor installer function was not loaded.'
    }

    Install-ArgonovSysInfoSensorBackend
    $library = Join-Path $sensorRoot 'LibreHardwareMonitorLib.dll'
    if (-not (Test-Path -LiteralPath $library -PathType Leaf)) {
        throw 'LibreHardwareMonitor backend was not installed. See dependency-install.log for details.'
    }

    $script:Results.Sensors = [ordered]@{ Status = 'Installed'; Path = $library }
    Write-DependencyLog 'LibreHardwareMonitor backend verified.' 'OK'
}

$sharedPowerShell = Join-Path $DependencyRoot 'PowerShell'
$sharedDotnet = Join-Path $DependencyRoot 'dotnet'
if (Test-Path -LiteralPath (Join-Path $sharedPowerShell 'pwsh.exe') -PathType Leaf) {
    Add-UserPathEntry -Path $sharedPowerShell
    Write-DependencyLog 'Shared PowerShell runtime is available on the current-user PATH.' 'OK'
}
if (Test-Path -LiteralPath (Join-Path $sharedDotnet 'dotnet.exe') -PathType Leaf) {
    Add-UserPathEntry -Path $sharedDotnet
    Write-DependencyLog 'Shared .NET runtime is available on the current-user PATH.' 'OK'
}

Write-DependencyLog "Starting dependency setup. InstallRoot=$InstallRoot; DependencyRoot=$DependencyRoot"

if ($InstallGit) {
    try { Install-ArgonovGit }
    catch {
        $script:Failures.Add("Git: $($_.Exception.Message)")
        $script:Results.Git = @{ Status = 'Failed'; Error = $_.Exception.Message }
        Write-DependencyLog $script:Failures[-1] 'ERROR'
    }
}
if ($InstallPython) {
    try { Install-ArgonovPython }
    catch {
        $script:Failures.Add("Python: $($_.Exception.Message)")
        $script:Results.Python = @{ Status = 'Failed'; Error = $_.Exception.Message }
        Write-DependencyLog $script:Failures[-1] 'ERROR'
    }
}
if ($InstallTerminal) {
    try { Install-ArgonovTerminal }
    catch {
        $script:Failures.Add("Windows Terminal: $($_.Exception.Message)")
        $script:Results.WindowsTerminal = @{ Status = 'Failed'; Error = $_.Exception.Message }
        Write-DependencyLog $script:Failures[-1] 'ERROR'
    }
}
if ($InstallSensors) {
    try { Install-ArgonovSensors }
    catch {
        $script:Failures.Add("LibreHardwareMonitor: $($_.Exception.Message)")
        $script:Results.Sensors = @{ Status = 'Failed'; Error = $_.Exception.Message }
        Write-DependencyLog $script:Failures[-1] 'ERROR'
    }
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
