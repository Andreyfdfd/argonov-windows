# ARGONOV SHELL uninstaller
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    # ProfilePath is primarily useful for testing or for removing an entry from a specific profile.
    [string]$ProfilePath = $PROFILE
)

$ErrorActionPreference = 'Stop'

function Write-UninstallHeader {
    Write-Host ''
    Write-Host '  ========================================' -ForegroundColor DarkCyan
    Write-Host '   ARGONOV SHELL - uninstaller' -ForegroundColor Cyan
    Write-Host '  ========================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Write-Info { param([string]$Message) Write-Host "  [..]   $Message" -ForegroundColor DarkGray }
function Write-Ok   { param([string]$Message) Write-Host "  [OK]   $Message" -ForegroundColor Green }
function Write-Err  { param([string]$Message) Write-Host "  [ERR]  $Message" -ForegroundColor Red }

Write-UninstallHeader

if ($PSVersionTable.PSVersion -lt [version]'7.6') {
    Write-Err ("This uninstaller requires PowerShell 7.6 or newer. Current version: {0}." -f $PSVersionTable.PSVersion)
    exit 1
}

if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
    Write-Err 'No PowerShell profile path was provided.'
    exit 1
}

$ProfilePath = [System.IO.Path]::GetFullPath($ProfilePath)
if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) {
    Write-Info "Profile does not exist: $ProfilePath"
    Write-Info 'Nothing to uninstall; no files were changed.'
    exit 0
}

$startMarker = '# >>> ARGONOV SHELL (managed by install.ps1) >>>'
$endMarker = '# <<< ARGONOV SHELL (managed by install.ps1) <<<'
$projectProfile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'profile.ps1'))

$legacyImports = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$legacyPaths = @($projectProfile, 'C:\ARGONOV\profile.ps1') | Select-Object -Unique
foreach ($path in $legacyPaths) {
    $singleQuoted = $path.Replace("'", "''")
    [void]$legacyImports.Add(". $path")
    [void]$legacyImports.Add(". '$singleQuoted'")
    [void]$legacyImports.Add('. "' + $path + '"')
}

$original = [System.IO.File]::ReadAllText($ProfilePath)
$lines = $original -split '\r?\n'
$remainingLines = [System.Collections.Generic.List[string]]::new()
$insideBlock = $false
$foundBlock = $false
$foundLegacyImport = $false
$startCount = 0
$endCount = 0

foreach ($line in $lines) {
    $trimmedLine = $line.Trim()

    if ($trimmedLine -eq $startMarker) {
        if ($insideBlock) {
            Write-Err 'Nested ARGONOV profile markers were found. The profile was not changed.'
            exit 1
        }
        $insideBlock = $true
        $foundBlock = $true
        $startCount++
        continue
    }

    if ($trimmedLine -eq $endMarker) {
        if (-not $insideBlock) {
            Write-Err 'An unmatched ARGONOV end marker was found. The profile was not changed.'
            exit 1
        }
        $insideBlock = $false
        $endCount++
        continue
    }

    if ($insideBlock) { continue }

    if ($legacyImports.Contains($trimmedLine)) {
        $foundLegacyImport = $true
        continue
    }

    $remainingLines.Add($line)
}

if ($insideBlock -or $startCount -ne $endCount) {
    Write-Err 'An incomplete ARGONOV profile block was found. The profile was not changed.'
    exit 1
}

if (-not $foundBlock -and -not $foundLegacyImport) {
    Write-Info 'ARGONOV SHELL profile entry was not found.'
    Write-Info 'Nothing to uninstall; no files were changed.'
    exit 0
}

# Keep the original newline convention where possible.
$newline = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
$updated = ($remainingLines.ToArray() -join $newline).TrimEnd([char[]]"`r`n")
if ($updated.Length -gt 0) { $updated += $newline }

if (-not $PSCmdlet.ShouldProcess($ProfilePath, 'Remove ARGONOV SHELL profile entry')) {
    Write-Info 'Preview only. No files were changed.'
    exit 0
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = "$ProfilePath.argonov-uninstall-backup-$timestamp"
[System.IO.File]::Copy($ProfilePath, $backupPath, $false)
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($ProfilePath, $updated, $utf8NoBom)

Write-Ok 'ARGONOV SHELL profile entry removed.'
Write-Info "Profile backup: $backupPath"
Write-Info 'Project files were left in place. No modules, backups, or user data were deleted.'
Write-Info 'To use the shell again, run install.ps1 from the project folder.'
