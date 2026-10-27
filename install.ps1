# ARGONOV SHELL installer
[CmdletBinding()]
param(
    # Re-run validation and refresh the managed profile entry.
    [switch]$Force,

    # Validate scripts without editing the PowerShell profile.
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

function Write-InstallHeader {
    Write-Host ''
    Write-Host '  ========================================' -ForegroundColor DarkCyan
    Write-Host '   ARGONOV SHELL - installer' -ForegroundColor Cyan
    Write-Host '  ========================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Write-Ok   { param([string]$Message) Write-Host "  [OK]   $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
function Write-Err  { param([string]$Message) Write-Host "  [ERR]  $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "  [..]   $Message" -ForegroundColor DarkGray }
function Write-Step { param([string]$Message) Write-Host "`n  --- $Message ---" -ForegroundColor Cyan }

Write-InstallHeader

# Windows PowerShell 5.1 is not a supported runtime for ARGONOV SHELL.
if ($PSVersionTable.PSVersion -lt [version]'7.6') {
    Write-Err ("This installer requires PowerShell 7.6 or newer. Current version: {0}." -f $PSVersionTable.PSVersion)
    Write-Host "  Run it from PowerShell 7.6+: pwsh -NoLogo -NoProfile -File `"$PSCommandPath`"" -ForegroundColor Yellow
    exit 1
}

$sourceRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$moduleRoot = Join-Path -Path $sourceRoot -ChildPath 'modules'
$profilePath = $PROFILE
$profileScript = Join-Path -Path $sourceRoot -ChildPath 'profile.ps1'
$startMarker = '# >>> ARGONOV SHELL (managed by install.ps1) >>>'
$endMarker = '# <<< ARGONOV SHELL (managed by install.ps1) <<<'

Write-Step 'Project files'
if (-not (Test-Path -LiteralPath $profileScript -PathType Leaf)) {
    Write-Err "profile.ps1 was not found in the project folder: $sourceRoot"
    exit 1
}
if (-not (Test-Path -LiteralPath $moduleRoot -PathType Container)) {
    Write-Err "modules folder was not found: $moduleRoot"
    exit 1
}

$scriptFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Filter '*.ps1' -File -Recurse | Sort-Object FullName)
if ($scriptFiles.Count -eq 0) {
    Write-Err 'No PowerShell scripts were found to validate.'
    exit 1
}
Write-Ok ("Project root: {0}" -f $sourceRoot)
Write-Ok ("PowerShell scripts found: {0}" -f $scriptFiles.Count)

Write-Step 'PowerShell syntax validation'
$parseFailures = [System.Collections.Generic.List[string]]::new()
foreach ($file in $scriptFiles) {
    $tokens = $null
    $parseErrors = $null
    try {
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
        if ($parseErrors) {
            foreach ($parseError in $parseErrors) {
                $relativePath = [System.IO.Path]::GetRelativePath($sourceRoot, $file.FullName)
                $parseFailures.Add("{0}:{1}: {2}" -f $relativePath, $parseError.Extent.StartLineNumber, $parseError.Message)
            }
        }
    }
    catch {
        $relativePath = [System.IO.Path]::GetRelativePath($sourceRoot, $file.FullName)
        $parseFailures.Add("{0}: could not parse file: {1}" -f $relativePath, $_.Exception.Message)
    }
}

if ($parseFailures.Count -gt 0) {
    Write-Err ("Syntax validation failed in {0} location(s). The profile was not changed." -f $parseFailures.Count)
    foreach ($failure in $parseFailures) { Write-Host "    $failure" -ForegroundColor Red }
    exit 1
}
Write-Ok 'All PowerShell scripts passed parser validation.'

if ($ValidateOnly) {
    Write-Host ''
    Write-Ok 'Validation-only mode completed. The PowerShell profile was not changed.'
    exit 0
}

if ($Force) { Write-Info 'Force mode: refreshing the managed profile entry after validation.' }

Write-Step 'Optional integrations'
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Ok ((& git --version 2>$null | Select-Object -First 1).ToString())
} else {
    Write-Info 'Git not found. Git aliases and repository status display will be limited.'
}
if (Get-Command py -ErrorAction SilentlyContinue) {
    $pythonVersion = & py --version 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Ok "Python available: $pythonVersion" }
    else { Write-Info 'Python launcher found, but a default Python runtime was not detected.' }
} else {
    Write-Info 'Python not found. Python-dependent optional integrations will be unavailable.'
}
if (Test-Path -LiteralPath (Join-Path $HOME '.lmstudio\bin\lms.exe') -PathType Leaf) {
    Write-Ok 'LM Studio CLI found.'
} else {
    Write-Info 'LM Studio CLI not found. AI commands require LM Studio to be installed and configured.'
}

Write-Step 'PowerShell profile'
if (-not $profilePath) {
    Write-Err 'PowerShell did not provide a profile path for the current host.'
    exit 1
}

$profileDirectory = Split-Path -Parent $profilePath
if (-not (Test-Path -LiteralPath $profileDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
}

$originalProfile = ''
$profileExists = Test-Path -LiteralPath $profilePath -PathType Leaf
if ($profileExists) {
    $originalProfile = [System.IO.File]::ReadAllText($profilePath)
}

$rootQuoted = $profileScript.Replace("'", "''")
$managedBlock = @(
    $startMarker,
    ". '$rootQuoted'",
    $endMarker
) -join "`r`n"

# Remove an older managed block and exact legacy import lines, preserving other profile content.
$legacyImports = @(
    ". $profileScript",
    ". '$profileScript'",
    '. "' + $profileScript + '"',
    '. C:\ARGONOV\profile.ps1',
    ". 'C:\ARGONOV\profile.ps1'",
    '. "C:\ARGONOV\profile.ps1"'
)
$remainingLines = [System.Collections.Generic.List[string]]::new()
$insideManagedBlock = $false
$foundStartMarker = $false
$foundEndMarker = $false

foreach ($line in @($originalProfile -split '\r?\n')) {
    $trimmedLine = $line.Trim()
    if ($trimmedLine -eq $startMarker) {
        if ($insideManagedBlock) {
            Write-Err 'The PowerShell profile contains nested ARGONOV installer markers. No changes were made.'
            exit 1
        }
        $insideManagedBlock = $true
        $foundStartMarker = $true
        continue
    }
    if ($insideManagedBlock) {
        if ($trimmedLine -eq $endMarker) {
            $insideManagedBlock = $false
            $foundEndMarker = $true
        }
        continue
    }
    if ($trimmedLine -eq $endMarker) {
        Write-Err 'The PowerShell profile contains an unmatched ARGONOV end marker. No changes were made.'
        exit 1
    }
    if ($legacyImports -contains $trimmedLine) { continue }
    $remainingLines.Add($line)
}

if ($insideManagedBlock -or ($foundStartMarker -and -not $foundEndMarker)) {
    Write-Err 'The PowerShell profile contains an incomplete ARGONOV installer block. No changes were made.'
    Write-Info "Inspect or restore the profile manually: $profilePath"
    exit 1
}

$cleanProfile = ($remainingLines.ToArray() -join "`r`n").TrimEnd([char[]]"`r`n")
if ($cleanProfile.Length -gt 0) {
    $cleanProfile += "`r`n`r`n"
}
$updatedProfile = $cleanProfile + $managedBlock + "`r`n"

if ($updatedProfile -ceq $originalProfile) {
    Write-Ok 'ARGONOV profile entry is already up to date.'
} else {
    if ($profileExists -and $originalProfile.Length -gt 0) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupPath = "$profilePath.argonov-backup-$timestamp"
        [System.IO.File]::Copy($profilePath, $backupPath, $false)
        Write-Info "Profile backup: $backupPath"
    }
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($profilePath, $updatedProfile, $utf8NoBom)
    Write-Ok "ARGONOV profile entry installed in: $profilePath"
}

Write-Host ''
Write-Ok 'Installation checks completed.'
Write-Info 'ExecutionPolicy was not changed. No administrator privileges are required.'
Write-Host '  Restart PowerShell 7 to load ARGONOV SHELL.' -ForegroundColor Cyan
Write-Host '  Use PowerShell 7.6+ (pwsh), not Windows PowerShell 5.1 (powershell).' -ForegroundColor Cyan
Write-Host ''
exit 0
