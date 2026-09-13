# ARGONOV SHELL · installer

param([switch]$Force)

$ErrorActionPreference = "Continue"

function W-Head {
    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor DarkCyan
    Write-Host "   ARGONOV SHELL - installer" -ForegroundColor Cyan
    Write-Host "  ========================================" -ForegroundColor DarkCyan
    Write-Host ""
}
function W-Ok    { param($m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function W-Warn  { param($m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function W-Err   { param($m) Write-Host "  [ERR]  $m" -ForegroundColor Red }
function W-Info  { param($m) Write-Host "  [..]   $m" -ForegroundColor DarkGray }
function W-Step  { param($m) Write-Host ""; Write-Host "  --- $m ---" -ForegroundColor Cyan }

$ArgDir   = "C:\ARGONOV"
$marker   = "$ArgDir\.installed"
$profileP = $PROFILE
$expected = ". C:\ARGONOV\profile.ps1"

$alreadyInstalled = Test-Path $marker

if ($alreadyInstalled -and -not $Force) {
    W-Head
    $when = (Get-Content $marker -Raw -ErrorAction SilentlyContinue).Trim()
    Write-Host "  ARGONOV SHELL уже установлен." -ForegroundColor Green
    Write-Host "  Дата установки: $when" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Переустановить: pwsh -ExecutionPolicy Bypass -File $ArgDir\install.ps1 -Force" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

W-Head
if ($alreadyInstalled -and $Force) {
    Write-Host "  ПЕРЕУСТАНОВКА (-Force)" -ForegroundColor Yellow
    Write-Host ""
}

$issues = @()
$warnings = @()

W-Step "PowerShell"
$psMajor = $PSVersionTable.PSVersion.Major
$psVer = $PSVersionTable.PSVersion.ToString()
if ($psMajor -ge 7) { W-Ok "PowerShell $psVer" }
else { W-Warn "PowerShell $psVer (рекомендуется 7+)"; $warnings += "PowerShell 7 не установлен" }

W-Step "Python 3.14"
$pyOk = $false
try {
    $pyVer = & py -3.14 --version 2>&1
    if ($LASTEXITCODE -eq 0) { W-Ok "$pyVer"; $pyOk = $true }
} catch {}
if (-not $pyOk) { W-Warn "Python 3.14 не найден"; $warnings += "Python 3.14 не установлен" }

W-Step "Git"
$gitOk = $false
try {
    $gitVer = & git --version 2>&1
    if ($LASTEXITCODE -eq 0) { W-Ok "$gitVer"; $gitOk = $true }
} catch {}
if (-not $gitOk) { W-Warn "Git не установлен"; $warnings += "Git не установлен" }

W-Step "SSH (для GitHub)"
if (Test-Path "$HOME\.ssh\id_ed25519.pub") { W-Ok "SSH-ключ найден" }
else { W-Warn "SSH-ключ не найден"; $warnings += "SSH-ключ не настроен" }

W-Step "LM Studio"
if (Test-Path "$HOME\.lmstudio\bin\lms.exe") { W-Ok "lms.exe найден" }
else { W-Warn "lms.exe не найден"; $warnings += "LM Studio не установлен" }

W-Step "Структура проекта"
if (Test-Path $ArgDir) { W-Ok "Папка: $ArgDir" }
else {
    W-Err "Папка $ArgDir не найдена"
    W-Info "git clone git@github.com:Andreyfdfd/argonov-windows.git C:\ARGONOV"
    exit 1
}

if (Test-Path "$ArgDir\profile.ps1") { W-Ok "profile.ps1" }
else { W-Err "profile.ps1 не найден"; $issues += "profile.ps1 не найден" }

W-Step "Реорганизация modules"
$reorgScript = "$ArgDir\reorganize.ps1"
if (Test-Path $reorgScript) {
    $loosePs1 = Get-ChildItem "$ArgDir\modules" -Filter *.ps1 -File -ErrorAction SilentlyContinue
    if ($loosePs1 -and $loosePs1.Count -gt 0) {
        W-Info "Найдено $($loosePs1.Count) файлов в корне modules - реорганизую..."
        & $reorgScript
    } else {
        W-Ok "modules уже структурированы"
    }
} else {
    W-Warn "reorganize.ps1 не найден"
    $warnings += "reorganize.ps1 отсутствует"
}

if (Test-Path "$ArgDir\modules") {
    $modCount = (Get-ChildItem "$ArgDir\modules" -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue).Count
    $catCount = (Get-ChildItem "$ArgDir\modules" -Directory -ErrorAction SilentlyContinue).Count
    W-Ok "modules\ - $modCount файлов в $catCount категориях"
} else {
    W-Warn "Папка modules не найдена"
    $warnings += "Папка modules пустая"
}

W-Step "Профиль PowerShell"
if (-not (Test-Path $profileP)) {
    New-Item -ItemType File -Path $profileP -Force | Out-Null
}
$profileContent = Get-Content $profileP -ErrorAction SilentlyContinue

$hasLine = $false
if ($profileContent) {
    foreach ($line in $profileContent) {
        if ($line.Trim() -eq $expected.Trim()) { $hasLine = $true; break }
    }
}

if ($hasLine) {
    W-Ok "ARGONOV уже в профиле"
} else {
    W-Info "Добавляю строку в профиль..."
    Add-Content -Path $profileP -Value "" -Encoding UTF8
    Add-Content -Path $profileP -Value $expected -Encoding UTF8
    W-Ok "Добавлено: $expected"
}

W-Step "ExecutionPolicy"
$policy = Get-ExecutionPolicy -Scope CurrentUser
W-Info "Текущая политика: $policy"

if ($policy -eq "RemoteSigned" -or $policy -eq "Unrestricted" -or $policy -eq "Bypass") {
    W-Ok "Разрешает запуск скриптов"
} elseif ($policy -eq "Restricted" -or $policy -eq "Undefined") {
    W-Info "Устанавливаю RemoteSigned..."
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
        W-Ok "ExecutionPolicy: RemoteSigned"
    } catch {
        W-Warn "Не удалось: $($_.Exception.Message)"
        $warnings += "ExecutionPolicy не установлен (не критично)"
    }
} else {
    W-Ok "Политика: $policy"
}

W-Step "Проверка синтаксиса модулей"
if (Test-Path "$ArgDir\modules") {
    $mods = Get-ChildItem "$ArgDir\modules" -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue
    foreach ($mod in $mods) {
        try {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $mod.FullName -Raw -Encoding UTF8), [ref]$null)
            $relPath = $mod.FullName.Replace("$ArgDir\modules\", "")
            W-Ok $relPath
        } catch {
            W-Err "$($mod.Name) - ошибка синтаксиса"
            $issues += "$($mod.Name) - ошибка синтаксиса"
        }
    }
}

if ($issues.Count -eq 0) {
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-Content -Path $marker -Value $now -Encoding UTF8
    W-Info "Маркер: $marker"
}

Write-Host ""
Write-Host "  ========================================" -ForegroundColor DarkCyan
Write-Host "   ИТОГ" -ForegroundColor Cyan
Write-Host "  ========================================" -ForegroundColor DarkCyan
Write-Host ""

if ($issues.Count -gt 0) {
    Write-Host "  КРИТИЧНЫЕ ПРОБЛЕМЫ:" -ForegroundColor Red
    foreach ($i in $issues) { Write-Host "    - $i" -ForegroundColor Red }
    Write-Host ""
}
if ($warnings.Count -gt 0) {
    Write-Host "  ПРЕДУПРЕЖДЕНИЯ:" -ForegroundColor Yellow
    foreach ($w in $warnings) { Write-Host "    - $w" -ForegroundColor Yellow }
    Write-Host ""
}

if ($issues.Count -eq 0) {
    Write-Host "  Оболочка готова. Перезапусти терминал." -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "  Сначала реши критичные проблемы." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}