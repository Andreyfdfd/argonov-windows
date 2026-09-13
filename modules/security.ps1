# ARGONOV SHELL · security & antivirus

$script:SEC_DIR = "$HOME\.argonov-security"
$script:SEC_LOG = "$script:SEC_DIR\last-scan.log"

if (-not (Test-Path $script:SEC_DIR)) {
    New-Item -ItemType Directory -Force -Path $script:SEC_DIR | Out-Null
}

# Пути к инструментам
$script:DEFENDER = "${env:ProgramFiles}\Windows Defender\MpCmdRun.exe"
$script:MINERSEARCH = "$HOME\Tools\MinerSearch\MinerSearch.exe"
$script:DRWEB = "$HOME\Tools\DrWeb\cureit.exe"
$script:ESET = "$HOME\Tools\ESET\eset_online_scanner.exe"
$script:KVRT = "$HOME\Tools\KVRT\kvrt.run"
$script:CLAMAV = "$HOME\Tools\ClamAV\clamscan.exe"

# ═══ ЛОГИРОВАНИЕ ═══
function Write-SecLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $script:SEC_LOG -Value $line -Encoding UTF8
}

# ═══ WINDOWS DEFENDER ═══
function security-defender {
    param([string]$Path = "")
    
    Write-Host ""
    Write-Host "  🛡  Windows Defender" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan
    
    if (-not (Test-Path $script:DEFENDER)) {
        Write-Host "  ❌ MpCmdRun.exe не найден" -ForegroundColor Red
        return $null
    }
    
    $start = Get-Date
    $args = if ($Path) {
        @("-Scan", "-ScanType", "3", "-File", $Path, "-DisableRemediation")
    } else {
        @("-Scan", "-ScanType", "1")
    }
    
    Write-Host "  ⏳ Сканирую..." -ForegroundColor Yellow
    $out = & $script:DEFENDER $args 2>&1 | Out-String
    $el = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    
    $threats = @()
    if ($out -match "Threat") {
        $threats = ($out | Select-String -Pattern "Threat\s+:\s+(.+)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() }
    }
    
    Write-Host "  ✅ Готово за $el сек" -ForegroundColor Green
    if ($threats.Count -gt 0) {
        Write-Host "  🔴 Угроз: $($threats.Count)" -ForegroundColor Red
        foreach ($t in $threats) { Write-Host "     - $t" -ForegroundColor Red }
    } else {
        Write-Host "  🟢 Угроз не найдено" -ForegroundColor Green
    }
    
    Write-SecLog "Defender scan done: $($threats.Count) threats, $el sec"
    return [PSCustomObject]@{ Tool = "Defender"; Threats = $threats; Time = $el }
}

# ═══ MINERSEARCH ═══
function security-miner {
    Write-Host ""
    Write-Host "  ⛏  MinerSearch (поиск майнеров)" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan
    
    if (-not (Test-Path $script:MINERSEARCH)) {
        Write-Host "  ❌ MinerSearch.exe не найден" -ForegroundColor Red
        Write-Host "  📥 Скачай: https://github.com/BlendLog/MinerSearch/releases" -ForegroundColor DarkGray
        Write-Host "  📂 Распакуй в: $HOME\Tools\MinerSearch\" -ForegroundColor DarkGray
        return $null
    }
    
    Write-Host "  ⏳ Сканирую (silent + full scan)..." -ForegroundColor Yellow
    $start = Get-Date
    $out = & $script:MINERSEARCH -silent -accepteula -full-scan 2>&1 | Out-String
    $el = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    
    $threats = ($out | Select-String -Pattern "(?i)(malware|miner|suspicious|threat|detected)" -AllMatches).Matches.Count
    
    Write-Host "  ✅ Готово за $el сек" -ForegroundColor Green
    if ($threats -gt 0) {
        Write-Host "  🔴 Найдено подозрительного: $threats" -ForegroundColor Red
    } else {
        Write-Host "  🟢 Майнеров не найдено" -ForegroundColor Green
    }
    
    Write-SecLog "MinerSearch scan done: $threats detections, $el sec"
    return [PSCustomObject]@{ Tool = "MinerSearch"; Threats = $threats; Time = $el }
}

# ═══ DR.WEB CUREIT ═══
function security-drweb {
    param([string]$Path = "")
    
    Write-Host ""
    Write-Host "  🕷  Dr.Web CureIt!" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan
    
    if (-not (Test-Path $script:DRWEB)) {
        Write-Host "  ❌ cureit.exe не найден" -ForegroundColor Red
        Write-Host "  📥 Скачай: https://free.drweb.ru/download+cureit+free/" -ForegroundColor DarkGray
        Write-Host "  📂 Распакуй в: $HOME\Tools\DrWeb\" -ForegroundColor DarkGray
        return $null
    }
    
    $target = if ($Path) { $Path } else { "C:\" }
    Write-Host "  ⏳ Сканирую: $target" -ForegroundColor Yellow
    Write-Host "  ⚠  Может занять 5-15 минут" -ForegroundColor DarkGray
    
    $start = Get-Date
    & $script:DRWEB $target /SHELL /AA /AR 2>&1 | Out-Null
    $el = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    
    Write-Host "  ✅ Готово за $el сек" -ForegroundColor Green
    Write-Host "  📋 Отчёт: %USERPROFILE%\Doctor Web\DrWeb CureIt Quarantine" -ForegroundColor DarkGray
    
    Write-SecLog "Dr.Web CureIt scan done in $el sec"
    return [PSCustomObject]@{ Tool = "Dr.Web"; Threats = "см. отчёт"; Time = $el }
}

# ═══ ESET ONLINE SCANNER ═══
function security-eset {
    param([string]$Path = "")
    
    Write-Host ""
    Write-Host "  🧪 ESET Online Scanner" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan
    
    if (-not (Test-Path $script:ESET)) {
        Write-Host "  ❌ eset_online_scanner.exe не найден" -ForegroundColor Red
        Write-Host "  📥 Скачай: https://www.eset.com/int/home/online-scanner/" -ForegroundColor DarkGray
        Write-Host "  📂 Распакуй в: $HOME\Tools\ESET\" -ForegroundColor DarkGray
        return $null
    }
    
    $target = if ($Path) { $Path } else { "C:\" }
    Write-Host "  ⏳ Сканирую: $target" -ForegroundColor Yellow
    
    $start = Get-Date
    & $script:ESET /base-dir="$HOME\Tools\ESET\Modules" /auto /log-file="$script:SEC_DIR\eset.log" $target 2>&1 | Out-Null
    $el = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    
    Write-Host "  ✅ Готово за $el сек" -ForegroundColor Green
    Write-Host "  📋 Лог: $script:SEC_DIR\eset.log" -ForegroundColor DarkGray
    
    Write-SecLog "ESET scan done in $el sec"
    return [PSCustomObject]@{ Tool = "ESET"; Threats = "см. лог"; Time = $el }
}

# ═══ KASPERSKY VIRUS REMOVAL TOOL ═══
function security-kvrt {
    param([string]$Path = "")
    
    Write-Host ""
    Write-Host "  💊 Kaspersky Virus Removal Tool" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan
    
    if (-not (Test-Path $script:KVRT)) {
        Write-Host "  ❌ kvrt.run не найден" -ForegroundColor Red
        Write-Host "  📥 Скачай: https://www.kaspersky.ru/downloads/virus-removal-tool" -ForegroundColor DarkGray
        Write-Host "  📂 Распакуй в: $HOME\Tools\KVRT\" -ForegroundColor DarkGray
        return $null
    }
    
    $target = if ($Path) { $Path } else { "C:\" }
    Write-Host "  ⏳ Сканирую (silent): $target" -ForegroundColor Yellow
    
    $start = Get-Date
    & $script:KVRT -accepteula -silent -customonly -custom $target -d "$script:SEC_DIR\kvrt-report" 2>&1 | Out-Null
    $el = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    
    Write-Host "  ✅ Готово за $el сек" -ForegroundColor Green
    Write-Host "  📋 Отчёт: $script:SEC_DIR\kvrt-report" -ForegroundColor DarkGray
    
    Write-SecLog "KVRT scan done in $el sec"
    return [PSCustomObject]@{ Tool = "KVRT"; Threats = "см. отчёт"; Time = $el }
}

# ═══ CLAMAV ═══
function security-clamav {
    param([string]$Path = "")
    
    Write-Host ""
    Write-Host "  🧬 ClamAV" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan
    
    if (-not (Test-Path $script:CLAMAV)) {
        Write-Host "  ❌ clamscan.exe не найден" -ForegroundColor Red
        Write-Host "  📥 Скачай: https://www.clamav.net/downloads" -ForegroundColor DarkGray
        Write-Host "  📂 Распакуй в: $HOME\Tools\ClamAV\" -ForegroundColor DarkGray
        return $null
    }
    
    $target = if ($Path) { $Path } else { "C:\" }
    $dbPath = "$HOME\Tools\ClamAV\database"
    
    Write-Host "  ⏳ Сканирую (recursive): $target" -ForegroundColor Yellow
    
    $start = Get-Date
    $out = & $script:CLAMAV --database="$dbPath" --recursive $target 2>&1 | Out-String
    $el = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    
    $infected = ($out | Select-String -Pattern "Infected files:\s+(\d+)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
    
    Write-Host "  ✅ Готово за $el сек" -ForegroundColor Green
    if ($infected -and [int]$infected -gt 0) {
        Write-Host "  🔴 Заражённых файлов: $infected" -ForegroundColor Red
    } else {
        Write-Host "  🟢 Угроз не найдено" -ForegroundColor Green
    }
    
    Write-SecLog "ClamAV scan done in $el sec"
    return [PSCustomObject]@{ Tool = "ClamAV"; Threats = $infected; Time = $el }
}

# ═══ БЫСТРАЯ ПРОВЕРКА ПРИ СТАРТЕ ═══
function security-quick {
    param([switch]$Silent)
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "  ⚡ Быстрая проверка безопасности..." -ForegroundColor Cyan
    }
    
    $results = @()
    
    # Windows Defender Quick Scan
    if (Test-Path $script:DEFENDER) {
        try {
            $out = & $script:DEFENDER -Scan -ScanType 1 2>&1 | Out-String
            $threats = ($out | Select-String -Pattern "Threat\s+:\s+(.+)" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() }
            $results += [PSCustomObject]@{
                Tool = "Defender"
                Threats = $threats
                Critical = $threats.Count -gt 0
            }
        } catch {
            Write-SecLog "Defender quick scan failed: $($_.Exception.Message)" "ERROR"
        }
    }
    
    # MinerSearch (только процессы — быстро)
    if (Test-Path $script:MINERSEARCH) {
        try {
            $out = & $script:MINERSEARCH -silent -accepteula -nstm 2>&1 | Out-String
            $suspicious = ($out | Select-String -Pattern "(?i)(malware|miner|suspicious)" -AllMatches).Matches.Count
            $results += [PSCustomObject]@{
                Tool = "MinerSearch"
                Threats = if ($suspicious -gt 0) { $suspicious } else { @() }
                Critical = $suspicious -gt 0
            }
        } catch {
            Write-SecLog "MinerSearch quick scan failed: $($_.Exception.Message)" "ERROR"
        }
    }
    
    # Вывод результатов
    $critical = $results | Where-Object { $_.Critical }
    
    if ($critical.Count -gt 0) {
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  " -NoNewline -ForegroundColor Red
        Write-Host "🔴 ОБНАРУЖЕНЫ УГРОЗЫ! НЕМЕДЛЕННО УДАЛИТЬ!" -NoNewline -ForegroundColor Red
        Write-Host "          ║" -ForegroundColor Red
        Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Red
        foreach ($r in $critical) {
            Write-Host "     ⚠  $($r.Tool): $($r.Threats -join ', ')" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "     Запусти полную проверку: " -NoNewline -ForegroundColor DarkGray
        Write-Host "security-all" -ForegroundColor Yellow
        Write-Host ""
    } elseif (-not $Silent) {
        Write-Host "  🟢 Угроз не обнаружено" -ForegroundColor Green
        Write-Host ""
    }
    
    Write-SecLog "Quick security scan: $($critical.Count) critical"
}

# ═══ ПОЛНАЯ ПРОВЕРКА ═══
function security-all {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "  ║  " -NoNewline -ForegroundColor DarkCyan
    Write-Host "🛡  ПОЛНАЯ ПРОВЕРКА БЕЗОПАСНОСТИ" -NoNewline -ForegroundColor Cyan
    Write-Host "                ║" -ForegroundColor DarkCyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    Write-Host ""
    
    $results = @()
    
    $results += security-defender
    $results += security-miner
    $results += security-clamav
    
    # Проверяем, установлены ли остальные
    if (Test-Path $script:DRWEB) { $results += security-drweb }
    if (Test-Path $script:ESET) { $results += security-eset }
    if (Test-Path $script:KVRT) { $results += security-kvrt }
    
    # Итог
    Write-Host ""
    Write-Host "  ═══════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "   ИТОГ ПРОВЕРКИ" -ForegroundColor Cyan
    Write-Host "  ═══════════════════════════════════════" -ForegroundColor DarkCyan
    
    $totalThreats = 0
    foreach ($r in $results) {
        if ($r) {
            $threatCount = if ($r.Threats -is [array]) { $r.Threats.Count } else { 0 }
            $totalThreats += $threatCount
            $status = if ($threatCount -gt 0) { "🔴 $threatCount угроз" } else { "🟢 чисто" }
            Write-Host "     $($r.Tool.PadRight(15)) $status  ($($r.Time) сек)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    if ($totalThreats -gt 0) {
        Write-Host "  🔴 Всего угроз: $totalThreats" -ForegroundColor Red
        Write-Host "  ⚠  Рекомендуется немедленное удаление!" -ForegroundColor Red
    } else {
        Write-Host "  🟢 Угроз не обнаружено" -ForegroundColor Green
    }
    Write-Host ""
    
    Write-SecLog "Full security scan: $totalThreats threats total"
}

function security-help {
    Write-Host ""
    Write-Host "  🛡  Security Module" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  security-quick       быстрая проверка (при старте)" -ForegroundColor Gray
    Write-Host "  security-all         полная проверка всеми инструментами" -ForegroundColor Gray
    Write-Host "  security-defender    Windows Defender" -ForegroundColor Gray
    Write-Host "  security-miner       MinerSearch (майнеры)" -ForegroundColor Gray
    Write-Host "  security-drweb       Dr.Web CureIt" -ForegroundColor Gray
    Write-Host "  security-eset        ESET Online Scanner" -ForegroundColor Gray
    Write-Host "  security-kvrt        Kaspersky Virus Removal Tool" -ForegroundColor Gray
    Write-Host "  security-clamav      ClamAV" -ForegroundColor Gray
    Write-Host "  security-log         показать лог проверок" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Инструменты ищутся в: $HOME\Tools\" -ForegroundColor DarkGray
    Write-Host "  Лог: $script:SEC_LOG" -ForegroundColor DarkGray
    Write-Host ""
}

function security-log {
    if (Test-Path $script:SEC_LOG) {
        Get-Content $script:SEC_LOG -Tail 30
    } else {
        Write-Host "  Лог пуст" -ForegroundColor DarkGray
    }
}