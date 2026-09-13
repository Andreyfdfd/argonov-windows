# ARGONOV SHELL · security & antivirus

$script:SEC_DIR = "$HOME\.argonov-security"
$script:SEC_LOG = "$script:SEC_DIR\last-scan.log"

if (-not (Test-Path $script:SEC_DIR)) {
    New-Item -ItemType Directory -Force -Path $script:SEC_DIR | Out-Null
}

# Пути к инструментам
$script:DEFENDER   = "${env:ProgramFiles}\Windows Defender\MpCmdRun.exe"
$script:MINERSEARCH = "$HOME\Tools\MinerSearch\MinerSearch.exe"
$script:DRWEB      = "$HOME\Tools\DrWeb\cureit.exe"
$script:ESET       = "$HOME\Tools\ESET\eset_online_scanner.exe"
$script:KVRT       = "$HOME\Tools\KVRT\kvrt.exe"
$script:CLAMAV     = "$HOME\Tools\ClamAV\clamscan.exe"

function Write-SecLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $script:SEC_LOG -Value "[$ts] [$Level] $Message" -Encoding UTF8
}

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
    $scanArgs = if ($Path) {
        @("-Scan", "-ScanType", "3", "-File", $Path, "-DisableRemediation")
    } else {
        @("-Scan", "-ScanType", "1")
    }

    Write-Host "  ⏳ Сканирую..." -ForegroundColor Yellow
    $out = & $script:DEFENDER $scanArgs 2>&1 | Out-String
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

    Write-SecLog "Defender scan: $($threats.Count) threats, $el sec"
    return [PSCustomObject]@{ Tool = "Defender"; Threats = $threats; Time = $el }
}

function security-miner {
    Write-Host ""
    Write-Host "  ⛏  MinerSearch" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan

    if (-not (Test-Path $script:MINERSEARCH)) {
        Write-Host "  ❌ MinerSearch.exe не найден" -ForegroundColor Red
        Write-Host "  📥 Скачай: https://github.com/BlendLog/MinerSearch/releases" -ForegroundColor DarkGray
        Write-Host "  📂 Положи в: $HOME\Tools\MinerSearch\" -ForegroundColor DarkGray
        return $null
    }

    Write-Host "  ⏳ Сканирую (silent + full scan)..." -ForegroundColor Yellow
    Write-Host "  ⚠  Первый запуск может занять 3-10 минут" -ForegroundColor DarkGray

    $start = Get-Date
    $out = & $script:MINERSEARCH -silent -accepteula -full-scan 2>&1 | Out-String
    $el = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)

    # Проверяем итоговый отчёт
    $reportPath = "$HOME\Tools\MinerSearch\MinerSearch.log"
    $detections = 0
    if (Test-Path $reportPath) {
        $report = Get-Content $reportPath -Raw -ErrorAction SilentlyContinue
        $detections = ($report | Select-String -Pattern "(?i)(detected|suspicious|threat|miner)" -AllMatches).Matches.Count
    }

    Write-Host "  ✅ Готово за $el сек" -ForegroundColor Green
    if ($detections -gt 0) {
        Write-Host "  🔴 Найдено подозрительного: $detections" -ForegroundColor Red
        Write-Host "  📋 Подробности: $reportPath" -ForegroundColor DarkGray
    } else {
        Write-Host "  🟢 Угроз не найдено" -ForegroundColor Green
    }

    Write-SecLog "MinerSearch scan: $detections detections, $el sec"
    return [PSCustomObject]@{ Tool = "MinerSearch"; Threats = $detections; Time = $el }
}

function security-drweb {
    Write-Host ""
    Write-Host "  🕷  Dr.Web CureIt!" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan

    if (-not (Test-Path $script:DRWEB)) {
        Write-Host "  ❌ cureit.exe не найден" -ForegroundColor Red
        Write-Host "  📥 Скачай: https://free.drweb.ru/download+cureit+free/" -ForegroundColor DarkGray
        Write-Host "  📂 Положи в: $HOME\Tools\DrWeb\" -ForegroundColor DarkGray
        return $null
    }

    Write-Host "  ⚠  Dr.Web CureIt! запустится в GUI-режиме" -ForegroundColor Yellow
    Write-Host "  ⚠  В окне сам выбери объекты и запусти сканирование" -ForegroundColor DarkGray
    Write-Host ""
    Start-Process $script:DRWEB
    Write-Host "  ✅ Dr.Web CureIt! запущен" -ForegroundColor Green
    Write-Host "  📋 Отчёт будет в: %USERPROFILE%\Doctor Web\DrWeb CureIt Quarantine" -ForegroundColor DarkGray

    Write-SecLog "Dr.Web CureIt launched"
    return [PSCustomObject]@{ Tool = "Dr.Web"; Threats = "GUI"; Time = 0 }
}

function security-eset {
    param([string]$Path = "")
    Write-Host ""
    Write-Host "  🧪 ESET Online Scanner" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan

    if (-not (Test-Path $script:ESET)) {
        Write-Host "  ❌ eset_online_scanner.exe не найден" -ForegroundColor Red
        Write-Host "  📥 Скачай: https://www.eset.com/int/home/online-scanner/" -ForegroundColor DarkGray
        Write-Host "  📂 Положи в: $HOME\Tools\ESET\" -ForegroundColor DarkGray
        return $null
    }

    Write-Host "  ⚠  ESET запустится в GUI-режиме" -ForegroundColor Yellow
    Write-Host ""
    Start-Process $script:ESET
    Write-Host "  ✅ ESET Online Scanner запущен" -ForegroundColor Green

    Write-SecLog "ESET launched"
    return [PSCustomObject]@{ Tool = "ESET"; Threats = "GUI"; Time = 0 }
}

function security-kvrt {
    param([string]$Path = "")
    Write-Host ""
    Write-Host "  💊 Kaspersky Virus Removal Tool" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan

    if (-not (Test-Path $script:KVRT)) {
        Write-Host "  ❌ kvrt.exe не найден" -ForegroundColor Red
        Write-Host "  📥 Скачай: https://www.kaspersky.ru/downloads/virus-removal-tool" -ForegroundColor DarkGray
        Write-Host "  📂 Положи в: $HOME\Tools\KVRT\" -ForegroundColor DarkGray
        return $null
    }

    Write-Host "  ⚠  KVRT запустится в GUI-режиме" -ForegroundColor Yellow
    Write-Host ""
    Start-Process $script:KVRT -ArgumentList "-accepteula"
    Write-Host "  ✅ KVRT запущен" -ForegroundColor Green

    Write-SecLog "KVRT launched"
    return [PSCustomObject]@{ Tool = "KVRT"; Threats = "GUI"; Time = 0 }
}

function security-clamav {
    param([string]$Path = "")
    Write-Host ""
    Write-Host "  🧬 ClamAV" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan

    if (-not (Test-Path $script:CLAMAV)) {
        Write-Host "  ❌ clamscan.exe не найден" -ForegroundColor Red
        return $null
    }

    $target = if ($Path) { $Path } else { "C:\" }
    $dbPath = "$HOME\Tools\ClamAV\database"

    Write-Host "  ⏳ Сканирую: $target" -ForegroundColor Yellow

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

    Write-SecLog "ClamAV scan: $infected infected, $el sec"
    return [PSCustomObject]@{ Tool = "ClamAV"; Threats = $infected; Time = $el }
}

function security-quick {
    param([switch]$Silent)

    if (-not $Silent) {
        Write-Host ""
        Write-Host "  ⚡ Быстрая проверка безопасности..." -ForegroundColor Cyan
    }

    $critical = @()

    # Только процессы на майнеры (быстро)
    if (Test-Path $script:MINERSEARCH) {
        try {
            $out = & $script:MINERSEARCH -silent -accepteula -nstm 2>&1 | Out-String
            $suspicious = ($out | Select-String -Pattern "(?i)(malware|miner|suspicious)" -AllMatches).Matches.Count
            if ($suspicious -gt 0) {
                $critical += [PSCustomObject]@{ Tool = "MinerSearch"; Count = $suspicious }
            }
        } catch {
            Write-SecLog "Quick MinerSearch failed: $($_.Exception.Message)" "ERROR"
        }
    }

    if ($critical.Count -gt 0) {
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  " -NoNewline -ForegroundColor Red
        Write-Host "🔴 ОБНАРУЖЕНЫ УГРОЗЫ — УДАЛИТЬ НЕМЕДЛЕННО!" -NoNewline -ForegroundColor Red
        Write-Host "        ║" -ForegroundColor Red
        Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Red
        foreach ($c in $critical) {
            Write-Host "     ⚠  $($c.Tool): $($c.Count)" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "     Полная проверка: " -NoNewline -ForegroundColor DarkGray
        Write-Host "security-all" -ForegroundColor Yellow
        Write-Host ""
    } elseif (-not $Silent) {
        Write-Host "  🟢 Угроз не обнаружено" -ForegroundColor Green
        Write-Host ""
    }

    Write-SecLog "Quick scan: $($critical.Count) critical"
}

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

    if (Test-Path $script:DRWEB) { $results += security-drweb }
    if (Test-Path $script:ESET)  { $results += security-eset }
    if (Test-Path $script:KVRT)  { $results += security-kvrt }
    if (Test-Path $script:CLAMAV){ $results += security-clamav }

    Write-Host ""
    Write-Host "  ═══════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "   ИТОГ ПРОВЕРКИ" -ForegroundColor Cyan
    Write-Host "  ═══════════════════════════════════════" -ForegroundColor DarkCyan

    $totalThreats = 0
    foreach ($r in $results) {
        if ($r) {
            $cnt = if ($r.Threats -is [int]) { $r.Threats } elseif ($r.Threats -is [array]) { $r.Threats.Count } else { 0 }
            $totalThreats += $cnt
            $status = if ($cnt -gt 0) { "🔴 $cnt" } else { "🟢 чисто" }
            Write-Host "     $($r.Tool.PadRight(15)) $status  ($($r.Time) сек)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    if ($totalThreats -gt 0) {
        Write-Host "  🔴 Всего угроз: $totalThreats" -ForegroundColor Red
    } else {
        Write-Host "  🟢 Угроз не обнаружено" -ForegroundColor Green
    }
    Write-Host ""

    Write-SecLog "Full scan: $totalThreats threats total"
}

function security-help {
    Write-Host ""
    Write-Host "  🛡  Security Module" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  security-quick       быстрая проверка (процессы)" -ForegroundColor Gray
    Write-Host "  security-all         полная проверка" -ForegroundColor Gray
    Write-Host "  security-defender    Windows Defender" -ForegroundColor Gray
    Write-Host "  security-miner       MinerSearch" -ForegroundColor Gray
    Write-Host "  security-drweb       Dr.Web CureIt (GUI)" -ForegroundColor Gray
    Write-Host "  security-eset        ESET Online Scanner (GUI)" -ForegroundColor Gray
    Write-Host "  security-kvrt        Kaspersky VRT (GUI)" -ForegroundColor Gray
    Write-Host "  security-log         лог проверок" -ForegroundColor Gray
    Write-Host ""
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