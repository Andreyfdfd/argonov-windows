# ARGONOV SHELL · reorganize
# Структурирует modules/ по категориям

param([switch]$DryRun)

$ErrorActionPreference = "Continue"
$ArgRoot = "C:\ARGONOV"
$ModRoot = Join-Path $ArgRoot "modules"

if (-not (Test-Path $ModRoot)) {
    Write-Host "  Папка modules не найдена: $ModRoot" -ForegroundColor Red
    exit 1
}

$mapping = [ordered]@{
    "completion.ps1"  = "core"
    "commands.ps1"    = "core"
    "info.ps1"        = "core"
    "prompt.ps1"      = "core"
    "sysinfo.ps1"     = "system"
    "dashboard.ps1"   = "system"
    "processes.ps1"   = "system"
    "admin.ps1"       = "system"
    "autostart.ps1"   = "system"
    "security.ps1"    = "system"
    "navigation.ps1"  = "system"
    "network.ps1"     = "network"
    "proxy.ps1"       = "network"
    "ai.ps1"          = "ai"
    "lmstudio.ps1"    = "ai"
    "backup.ps1"      = "tools"
    "cad.ps1"         = "tools"
    "screenshot.ps1"  = "tools"
    "git-aliases.ps1" = "dev"
    "hacktool.ps1"    = "osint"
    "matrix.ps1"      = "fun"
}

Write-Host ""
Write-Host "  ==============================================" -ForegroundColor DarkCyan
Write-Host "   РЕСТРУКТУРИЗАЦИЯ MODULES" -ForegroundColor Cyan
Write-Host "  ==============================================" -ForegroundColor DarkCyan
Write-Host ""

if ($DryRun) {
    Write-Host "  DRY RUN — ничего не будет изменено" -ForegroundColor Yellow
    Write-Host ""
}

foreach ($cat in ($mapping.Values | Select-Object -Unique)) {
    $catPath = Join-Path $ModRoot $cat
    if (-not (Test-Path $catPath)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path $catPath | Out-Null
        }
    }
}

$moved = 0
$skipped = 0
$missing = 0

foreach ($file in $mapping.Keys) {
    $category = $mapping[$file]
    $sourcePath = Join-Path $ModRoot $file
    $targetDir = Join-Path $ModRoot $category
    $targetPath = Join-Path $targetDir $file

    if (Test-Path $sourcePath) {
        if (-not $DryRun) {
            Move-Item $sourcePath $targetPath -Force
        }
        Write-Host "  [OK]   $file  ->  modules\$category\" -ForegroundColor Green
        $moved++
    } elseif (Test-Path $targetPath) {
        Write-Host "  [skip] $file  (уже в modules\$category\)" -ForegroundColor DarkGray
        $skipped++
    } else {
        Write-Host "  [WARN] $file  (не найден)" -ForegroundColor Yellow
        $missing++
    }
}

Write-Host ""
Write-Host "  ----------------------------------------" -ForegroundColor DarkCyan
Write-Host "  Перемещено:  $moved" -ForegroundColor Green
Write-Host "  На месте:    $skipped" -ForegroundColor Gray
Write-Host "  Не найдено:  $missing" -ForegroundColor Yellow
Write-Host ""

if ($DryRun) {
    Write-Host "  DRY RUN завершён." -ForegroundColor Yellow
} else {
    Write-Host "  Структура готова!" -ForegroundColor Green
}
Write-Host ""