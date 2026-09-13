# ARGONOV SHELL · installer
# Проверяет и настраивает окружение.
# Идемпотентный: можно запускать сколько угодно раз.
#
# Файл: C:\ARGONOV\install.ps1
# Запуск:  powershell -ExecutionPolicy Bypass -File C:\ARGONOV\install.ps1
#          powershell -ExecutionPolicy Bypass -File C:\ARGONOV\install.ps1 -Force

param(
    [switch]$Force
)

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

# ═══════════════════════════════════════════════════
#  ПУТИ И МАРКЕР
# ═══════════════════════════════════════════════════

$ArgDir   = "C:\ARGONOV"
$marker   = "$ArgDir\.installed"
$profileP = $PROFILE
$expected = ". C:\ARGONOV\profile.ps1"

# ═══════════════════════════════════════════════════
#  ПРОВЕРКА: УЖЕ УСТАНОВЛЕНО?
# ═══════════════════════════════════════════════════

$alreadyInstalled = Test-Path $marker

if ($alreadyInstalled -and -not $Force) {
    W-Head
    $when = (Get-Content $marker -Raw -ErrorAction SilentlyContinue).Trim()
    Write-Host "  ARGONOV SHELL уже установлен." -ForegroundColor Green
    Write-Host "  Дата установки: $when" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Что делать:" -ForegroundColor Cyan
    Write-Host "    - Перезапусти терминал, если что-то не работает" -ForegroundColor White
    Write-Host "    - Запусти с флагом -Force чтобы переустановить:" -ForegroundColor White
    Write-Host "        powershell -ExecutionPolicy Bypass -File $ArgDir\install.ps1 -Force" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

if ($alreadyInstalled -and $Force) {
    W-Head
    Write-Host "  ПЕРЕУСТАНОВКА (-Force)" -ForegroundColor Yellow
    Write-Host ""
}

if (-not $alreadyInstalled) {
    W-Head
}

# ═══════════════════════════════════════════════════
#  ПРОВЕРКИ
# ═══════════════════════════════════════════════════

$issues = @()
$warnings = @()

# ─── 1. PowerShell ───
W-Step "PowerShell"
$psMajor = $PSVersionTable.PSVersion.Major
$psVer = $PSVersionTable.PSVersion.ToString()
if ($psMajor -ge 7) {
    W-Ok "PowerShell $psVer"
} else {
    W-Warn "PowerShell $psVer (рекомендуется 7+)"
    W-Info "Установить: winget install --id Microsoft.PowerShell -e"
    $warnings += "PowerShell 7 не установлен"
}

# ─── 2. Python 3.14 ───
W-Step "Python 3.14"
$pyOk = $false
try {
    $pyVer = & py -3.14 --version 2>&1
    if ($LASTEXITCODE -eq 0) { W-Ok "$pyVer"; $pyOk = $true }
} catch {}
if (-not $pyOk) {
    W-Warn "Python 3.14 не найден"
    W-Info "Скачать: https://www.python.org/downloads/"
    $warnings += "Python 3.14 не установлен"
}

# ─── 3. Git ───
W-Step "Git"
$gitOk = $false
try {
    $gitVer = & git --version 2>&1
    if ($LASTEXITCODE -eq 0) { W-Ok "$gitVer"; $gitOk = $true }
} catch {}
if (-not $gitOk) {
    W-Warn "Git не установлен"
    W-Info "Установить: winget install --id Git.Git -e"
    $warnings += "Git не установлен"
}

# ─── 4. SSH-ключ ───
W-Step "SSH (для GitHub)"
$sshKey = "$HOME\.ssh\id_ed25519.pub"
if (Test-Path $sshKey) {
    W-Ok "SSH-ключ: $sshKey"
} else {
    W-Warn "SSH-ключ не найден"
    W-Info "Создать: ssh-keygen -t ed25519 -C `"your@email.com`""
    W-Info "Добавить на https://github.com/settings/ssh/new"
    $warnings += "SSH-ключ не настроен"
}

# ─── 5. LM Studio ───
W-Step "LM Studio"
$lmsPath = "$HOME\.lmstudio\bin\lms.exe"
if (Test-Path $lmsPath) {
    W-Ok "lms.exe: $lmsPath"
} else {
    W-Warn "lms.exe не найден"
    W-Info "Установить LM Studio: winget install --id ElementLabs.LMStudio -e"
    $warnings += "LM Studio не установлен (AI-команды не будут работать)"
}

# ─── 6. Структура ───
W-Step "Структура проекта"
if (Test-Path $ArgDir) {
    W-Ok "Папка: $ArgDir"
} else {
    W-Err "Папка $ArgDir не найдена"
    W-Info "Склонируй: git clone git@github.com:Andreyfdfd/argonov-windows.git C:\ARGONOV"
    $issues += "Папка ARGONOV не найдена"
}

if (Test-Path "$ArgDir\profile.ps1") {
    W-Ok "profile.ps1"
} else {
    W-Err "profile.ps1 не найден"
    $issues += "profile.ps1 не найден"
}

if (Test-Path "$ArgDir\modules") {
    $modCount = (Get-ChildItem "$ArgDir\modules\*.ps1" -ErrorAction SilentlyContinue).Count
    W-Ok "modules\ ($modCount файлов)"
} else {
    W-Warn "Папка modules не найдена"
    $warnings += "Папка modules пустая"
}

# ─── 7. Профиль PowerShell ───
W-Step "Профиль PowerShell"
if (-not (Test-Path $profileP)) {
    W-Info "Создаю профиль: $profileP"
    New-Item -ItemType File -Path $profileP -Force | Out-Null
}
$profileContent = Get-Content $profileP -ErrorAction SilentlyContinue

# Точная проверка: строка должна быть на своей строке, не подстрокой
$hasLine = $false
if ($profileContent) {
    foreach ($line in $profileContent) {
        if ($line.Trim() -eq $expected.Trim()) { $hasLine = $true; break }
    }
}

if ($hasLine) {
    W-Ok "ARGONOV уже в профиле (дубликат не добавлен)"
} else {
    W-Info "Добавляю строку в профиль..."
    Add-Content -Path $profileP -Value "" -Encoding UTF8
    Add-Content -Path $profileP -Value $expected -Encoding UTF8
    W-Ok "Добавлено: $expected"
}

# ─── 8. ExecutionPolicy ───
W-Step "ExecutionPolicy"
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted" -or $policy -eq "Undefined") {
    W-Info "Устанавливаю RemoteSigned для текущего пользователя..."
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        W-Ok "ExecutionPolicy: RemoteSigned"
    } catch {
        W-Err "Не удалось: $($_.Exception.Message)"
        $issues += "ExecutionPolicy не установлен"
    }
} else {
    W-Ok "ExecutionPolicy: $policy (уже настроен)"
}

# ─── 9. Проверка модулей ───
W-Step "Проверка модулей"
if (Test-Path "$ArgDir\modules") {
    $mods = Get-ChildItem "$ArgDir\modules\*.ps1" -ErrorAction SilentlyContinue
    foreach ($mod in $mods) {
        try {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $mod.FullName -Raw), [ref]$null)
            W-Ok $mod.Name
        } catch {
            W-Err "$($mod.Name) - ошибка синтаксиса"
            $issues += "$($mod.Name) имеет синтаксическую ошибку"
        }
    }
}

# ═══════════════════════════════════════════════════
#  МАРКЕР УСТАНОВКИ
# ═══════════════════════════════════════════════════

if ($issues.Count -eq 0) {
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-Content -Path $marker -Value $now -Encoding UTF8
    W-Info "Маркер установки: $marker"
}

# ═══════════════════════════════════════════════════
#  ИТОГ
# ═══════════════════════════════════════════════════

Write-Host ""
Write-Host "  ========================================" -ForegroundColor DarkCyan
Write-Host "   ИТОГ" -ForegroundColor Cyan
Write-Host "  ========================================" -ForegroundColor DarkCyan
Write-Host ""

if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "  Всё идеально! Перезапусти терминал и набери:" -ForegroundColor Green
    Write-Host "      info" -ForegroundColor White
    Write-Host "      sysinfo" -ForegroundColor White
    Write-Host ""
    exit 0
}

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
    Write-Host "  Сначала реши критичные проблемы, потом запусти снова." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}