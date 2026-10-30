# ARGONOV SHELL installer
[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Programs\ARGONOV SHELL'),
    [string]$ProfilePath = $PROFILE,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'

function Write-InstallStep {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ''
    Write-Host ("--- {0} ---" -f $Message) -ForegroundColor Cyan
}
function Write-InstallOk {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ("[OK] {0}" -f $Message) -ForegroundColor Green
}
function Merge-MissingContent {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { return }
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        $target = Join-Path $Destination $item.Name
        if (-not (Test-Path -LiteralPath $target)) {
            Copy-Item -LiteralPath $item.FullName -Destination $target -Recurse -Force
        }
        elseif ($item.PSIsContainer -and (Test-Path -LiteralPath $target -PathType Container)) {
            Merge-MissingContent -Source $item.FullName -Destination $target
        }
    }
}
function Get-ValidatedPowerShellFiles {
    param([string]$Root)
    $failures = [System.Collections.Generic.List[string]]::new()
    $files = @(Get-ChildItem -LiteralPath $Root -Filter '*.ps1' -File -Recurse -Force |
        Where-Object { $_.FullName -notmatch '[\\/](\.git|\.github|tests)[\\/]' })
    foreach ($file in $files) {
        $tokens = $null
        $parseErrors = $null
        try {
            [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
        }
        catch {
            $failures.Add(('{0}: {1}' -f $file.FullName, $_.Exception.Message))
            continue
        }
        foreach ($parseError in @($parseErrors)) {
            $failures.Add(('{0}:{1}: {2}' -f $file.FullName, $parseError.Extent.StartLineNumber, $parseError.Message))
        }
    }
    if ($failures.Count -gt 0) {
        $separator = [Environment]::NewLine + ' - '
        throw ("PowerShell syntax validation failed:{0} - {1}" -f [Environment]::NewLine, ($failures -join $separator))
    }
    return $files
}
function Update-PowerShellProfile {
    param([string]$TargetProfile, [string]$InstalledProfile)
    $startMarker = '# >>> ARGONOV SHELL (managed by installer) >>>'
    $endMarker = '# <<< ARGONOV SHELL (managed by installer) <<<'
    $profileDirectory = Split-Path -Parent $TargetProfile
    if (-not (Test-Path -LiteralPath $profileDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
    }
    $profileExists = Test-Path -LiteralPath $TargetProfile -PathType Leaf
    $original = if ($profileExists) { [System.IO.File]::ReadAllText($TargetProfile) } else { '' }
    $remaining = [System.Collections.Generic.List[string]]::new()
    $insideManagedBlock = $false
    $foundStart = $false
    $foundEnd = $false
    foreach ($line in @($original -split '\r?\n')) {
        $trimmed = $line.Trim()
        if ($trimmed -eq $startMarker) {
            if ($insideManagedBlock) { throw 'Nested ARGONOV profile markers found. No profile changes were made.' }
            $insideManagedBlock = $true
            $foundStart = $true
            continue
        }
        if ($insideManagedBlock) {
            if ($trimmed -eq $endMarker) {
                $insideManagedBlock = $false
                $foundEnd = $true
            }
            continue
        }
        if ($trimmed -eq $endMarker) { throw 'Unmatched ARGONOV end marker found. No profile changes were made.' }
        if ($trimmed -in @('. C:\ARGONOV\profile.ps1', ". 'C:\ARGONOV\profile.ps1'", '. "C:\ARGONOV\profile.ps1"')) { continue }
        $remaining.Add($line)
    }
    if ($insideManagedBlock -or ($foundStart -and -not $foundEnd)) {
        throw 'Incomplete ARGONOV profile block found. No profile changes were made.'
    }
    $quotedProfile = $InstalledProfile.Replace("'", "''")
    $managedBlock = @($startMarker, (". '{0}'" -f $quotedProfile), $endMarker) -join [Environment]::NewLine
    $baseText = ($remaining.ToArray() -join [Environment]::NewLine).TrimEnd([char[]]@([char]13, [char]10))
    if ($baseText.Length -gt 0) { $baseText += [Environment]::NewLine + [Environment]::NewLine }
    $updated = $baseText + $managedBlock + [Environment]::NewLine
    if ($updated -ceq $original) {
        Write-InstallOk "PowerShell profile already points to ARGONOV: $TargetProfile"
        return
    }
    if ($profileExists) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $backupPath = "$TargetProfile.argonov-backup-$stamp"
        [System.IO.File]::Copy($TargetProfile, $backupPath, $false)
        Write-Host "Profile backup: $backupPath" -ForegroundColor DarkGray
    }
    [System.IO.File]::WriteAllText($TargetProfile, $updated, [System.Text.UTF8Encoding]::new($false))
    Write-InstallOk "PowerShell profile updated: $TargetProfile"
}

try {
    Write-Host ''
    Write-Host '  ==========================================' -ForegroundColor DarkCyan
    Write-Host '   ARGONOV SHELL - installer' -ForegroundColor Cyan
    Write-Host '  ==========================================' -ForegroundColor DarkCyan
    if ($PSVersionTable.PSVersion -lt [version]'7.6') {
        throw ("ARGONOV SHELL requires PowerShell 7.6 or newer. Current version: {0}. Start this script with pwsh." -f $PSVersionTable.PSVersion)
    }
    if ([string]::IsNullOrWhiteSpace($InstallRoot)) { throw 'InstallRoot is empty. Specify a destination folder.' }
    if ([string]::IsNullOrWhiteSpace($ProfilePath)) { throw 'PowerShell did not provide a profile path. Specify -ProfilePath.' }

    $sourceRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
    $InstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
    $ProfilePath = [System.IO.Path]::GetFullPath($ProfilePath)
    $profileSource = Join-Path $sourceRoot 'profile.ps1'
    $moduleSource = Join-Path $sourceRoot 'modules'

    Write-InstallStep 'Project validation'
    if (-not (Test-Path -LiteralPath $profileSource -PathType Leaf)) { throw "profile.ps1 not found in: $sourceRoot" }
    if (-not (Test-Path -LiteralPath $moduleSource -PathType Container)) { throw "modules folder not found in: $sourceRoot" }
    if ($InstallRoot -eq $sourceRoot) { throw 'InstallRoot cannot be the source project directory.' }

    $validatedFiles = @(Get-ValidatedPowerShellFiles -Root $sourceRoot)
    Write-InstallOk ("Validated {0} PowerShell files." -f $validatedFiles.Count)
    if ($ValidateOnly) {
        Write-InstallOk 'Validate-only completed. No files or profiles were changed.'
        return
    }

    Write-InstallStep 'Preparing installation'
    $parent = Split-Path -Parent $InstallRoot
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $stageRoot = "$InstallRoot.staging-$([guid]::NewGuid().ToString('N'))"
    $backupRoot = $null
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

    try {
        $excludedNames = @('.git', '.github', 'tests', '.installed', '.argonov-install.json')
        foreach ($item in Get-ChildItem -LiteralPath $sourceRoot -Force) {
            if ($excludedNames -contains $item.Name) { continue }
            Copy-Item -LiteralPath $item.FullName -Destination $stageRoot -Recurse -Force
        }
        if (Test-Path -LiteralPath $InstallRoot -PathType Container) {
            foreach ($dataDirectory in @('music', 'vendor', 'data', 'config')) {
                Merge-MissingContent -Source (Join-Path $InstallRoot $dataDirectory) -Destination (Join-Path $stageRoot $dataDirectory)
            }
        }

        $manifest = [ordered]@{
            product = 'ARGONOV SHELL'
            installedAt = (Get-Date).ToString('o')
            powershellVersion = $PSVersionTable.PSVersion.ToString()
            installRoot = $InstallRoot
        }
        [System.IO.File]::WriteAllText(
            (Join-Path $stageRoot '.argonov-install.json'),
            ($manifest | ConvertTo-Json -Depth 4),
            [System.Text.UTF8Encoding]::new($false)
        )

        if (Test-Path -LiteralPath $InstallRoot) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
            $backupRoot = "$InstallRoot.backup-$stamp"
            [System.IO.Directory]::Move($InstallRoot, $backupRoot)
            Write-Host "Previous installation backup: $backupRoot" -ForegroundColor DarkGray
        }
        [System.IO.Directory]::Move($stageRoot, $InstallRoot)
        Write-InstallOk "ARGONOV files installed to: $InstallRoot"
    }
    catch {
        if ($backupRoot -and (Test-Path -LiteralPath $backupRoot) -and -not (Test-Path -LiteralPath $InstallRoot)) {
            [System.IO.Directory]::Move($backupRoot, $InstallRoot)
        }
        throw
    }
    finally {
        if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Write-InstallStep 'PowerShell profile'
    Update-PowerShellProfile -TargetProfile $ProfilePath -InstalledProfile (Join-Path $InstallRoot 'profile.ps1')

    Write-InstallStep 'Optional integrations'
    foreach ($dependency in @(@{ Name = 'Git'; Command = 'git' }, @{ Name = 'Python launcher'; Command = 'py' })) {
        if (Get-Command $dependency.Command -ErrorAction SilentlyContinue) {
            Write-InstallOk ("{0} detected." -f $dependency.Name)
        }
        else {
            Write-Host ("[OPTIONAL] {0} is not installed. Core shell installation does not require it." -f $dependency.Name) -ForegroundColor DarkYellow
        }
    }
    if (Test-Path -LiteralPath (Join-Path $HOME '.lmstudio\bin\lms.exe') -PathType Leaf) {
        Write-InstallOk 'LM Studio CLI detected.'
    }
    else {
        Write-Host '[OPTIONAL] LM Studio is not installed. AI commands will be unavailable until configured.' -ForegroundColor DarkYellow
    }
    Write-Host ''
    Write-Host 'ARGONOV SHELL installation completed.' -ForegroundColor Green
    Write-Host 'Close and reopen PowerShell 7 to load the shell.' -ForegroundColor Cyan
    Write-Host 'ExecutionPolicy and system-wide security settings were not changed.' -ForegroundColor DarkGray
}
catch {
    Write-Host ''
    Write-Host ("INSTALLATION FAILED: {0}" -f $_.Exception.Message) -ForegroundColor Red
    throw
}
