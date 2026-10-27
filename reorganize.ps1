# ARGONOV SHELL - reorganize module files safely
[CmdletBinding()]
param(
    # Actually move files. Without this switch the script only previews changes.
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$moduleRoot = Join-Path $projectRoot 'modules'

if (-not (Test-Path -LiteralPath $moduleRoot -PathType Container)) {
    Write-Error "Modules folder was not found: $moduleRoot"
    exit 1
}

$mapping = [ordered]@{
    'completion.ps1'  = 'core'
    'commands.ps1'    = 'core'
    'info.ps1'        = 'core'
    'prompt.ps1'      = 'core'
    'banner.ps1'      = 'core'
    'sysinfo.ps1'     = 'system'
    'dashboard.ps1'   = 'system'
    'processes.ps1'   = 'system'
    'admin.ps1'       = 'system'
    'autostart.ps1'   = 'system'
    'security.ps1'    = 'system'
    'navigation.ps1'  = 'system'
    'network.ps1'     = 'network'
    'proxy.ps1'       = 'network'
    'ai.ps1'          = 'ai'
    'lmstudio.ps1'    = 'ai'
    'backup.ps1'      = 'tools'
    'cad.ps1'         = 'tools'
    'screenshot.ps1'  = 'tools'
    'git-aliases.ps1' = 'dev'
    'hacktool.ps1'    = 'osint'
    'matrix.ps1'      = 'fun'
}

$planned = [System.Collections.Generic.List[object]]::new()
$conflicts = [System.Collections.Generic.List[string]]::new()
$missing = [System.Collections.Generic.List[string]]::new()

Write-Host ''
Write-Host '  ==============================================' -ForegroundColor DarkCyan
Write-Host '   ARGONOV SHELL - module reorganization' -ForegroundColor Cyan
Write-Host '  ==============================================' -ForegroundColor DarkCyan
Write-Host "  Project root: $projectRoot" -ForegroundColor DarkGray
if (-not $Execute) {
    Write-Host '  PREVIEW ONLY - no files will be moved.' -ForegroundColor Yellow
    Write-Host '  Add -Execute to apply the listed moves.' -ForegroundColor Yellow
}
Write-Host ''

foreach ($fileName in $mapping.Keys) {
    $source = Join-Path $moduleRoot $fileName
    $destinationDirectory = Join-Path $moduleRoot $mapping[$fileName]
    $destination = Join-Path $destinationDirectory $fileName

    if (Test-Path -LiteralPath $source -PathType Leaf) {
        if (Test-Path -LiteralPath $destination) {
            $conflicts.Add("$fileName exists both at modules\ and modules\$($mapping[$fileName])\")
            Write-Host "  [CONFLICT] $fileName - target already exists; neither file will be overwritten" -ForegroundColor Yellow
            continue
        }
        $planned.Add([pscustomobject]@{ Source = $source; Destination = $destination; Name = $fileName; Category = $mapping[$fileName] })
        Write-Host "  [MOVE] modules\$fileName -> modules\$($mapping[$fileName])\$fileName" -ForegroundColor Cyan
    } elseif (Test-Path -LiteralPath $destination -PathType Leaf) {
        Write-Host "  [OK]   $fileName is already categorized" -ForegroundColor Green
    } else {
        $missing.Add($fileName)
        Write-Host "  [SKIP] $fileName was not found" -ForegroundColor DarkGray
    }
}

if ($Execute -and $planned.Count -gt 0) {
    foreach ($move in $planned) {
        $destinationDirectory = Split-Path -Parent $move.Destination
        if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force -ErrorAction Stop | Out-Null
        }
        Move-Item -LiteralPath $move.Source -Destination $move.Destination -ErrorAction Stop
    }
    Write-Host ''
    Write-Host "  Moved $($planned.Count) file(s)." -ForegroundColor Green
} else {
    Write-Host ''
    Write-Host "  Planned moves: $($planned.Count)" -ForegroundColor Cyan
}
if ($conflicts.Count -gt 0) {
    Write-Host "  Conflicts: $($conflicts.Count) (review manually; files were not overwritten)" -ForegroundColor Yellow
}
if ($missing.Count -gt 0) {
    Write-Host "  Unmapped source files missing: $($missing.Count)" -ForegroundColor DarkGray
}
Write-Host ''