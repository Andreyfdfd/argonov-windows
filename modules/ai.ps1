# ARGONOV SHELL · ai (LM Studio + agent)

$script:AI_URL = "http://localhost:1234/v1"
$script:AI_MODEL = "deepseek/deepseek-r1-0528-qwen3-8b"
$script:AI_HISTORY = @()
$script:AI_YOLO = $false
$script:AI_DRY = $false
$script:LMS = "$HOME\.lmstudio\bin\lms.exe"

$script:AI_SANDBOX = @(
    "C:\ARGONOV",
    "$HOME",
    "$HOME\Documents",
    "$HOME\Downloads",
    "$HOME\Desktop"
)

$script:AI_DANGER = @(
    "rm\s+-rf\s+[/\\]",
    "format\s+[a-z]:",
    "del\s+/[fFsS].*[a-z]:\\?$",
    "rmdir\s+/[sS].*[a-z]:\\?$",
    "Remove-Item.*-Recurse.*-Force.*[a-z]:\\?$",
    "mkfs",
    "dd\s+if=",
    "shutdown\s+/[sr]",
    "diskpart",
    "Restart-Computer",
    "Stop-Computer"
)

# ═══ SYSTEM PROMPT ═══
# Одиночные кавычки — никакой интерполяции, никаких проблем с backtick

function ai-system-prompt {
    $lines = @(
        'Ты AI-ассистент внутри ARGONOV SHELL на Windows 11.',
        'Отвечай по-русски, кратко и по делу.',
        '',
        'ТЫ УМЕЕШЬ ВЫПОЛНЯТЬ ДЕЙСТВИЯ. Для этого используй специальные блоки:',
        '',
        'СОЗДАТЬ ИЛИ ИЗМЕНИТЬ ФАЙЛ — блок write:',
        '',
        '```write',
        'C:\ARGONOV\hello.ps1',
        'Write-Host "привет, мир"',
        '```',
        '',
        'ПРОЧИТАТЬ ФАЙЛ — блок read:',
        '',
        '```read',
        'C:\ARGONOV\profile.ps1',
        '```',
        '',
        'ЗАПУСТИТЬ КОМАНДУ — блок exec:',
        '',
        '```exec',
        'python C:\ARGONOV\sysinfo.py',
        '```',
        '',
        'КРИТИЧЕСКИ ВАЖНО:',
        '- Когда пользователь просит создать или изменить файл — ВСЕГДА используй блок write.',
        '- НЕ проси пользователя открыть блокнот или сохранить вручную.',
        '- Когда просит прочитать — используй блок read.',
        '- Когда просит запустить — используй блок exec.',
        '- НЕ выдумывай Linux-команды: ls, cat, rm, nano, mkdir.',
        '- Пути только абсолютные, например: C:\ARGONOV\file.ps1',
        '',
        'Пример правильного ответа на "создай hello.ps1 который печатает привет":',
        '',
        'Создаю файл.',
        '',
        '```write',
        'C:\ARGONOV\hello.ps1',
        'Write-Host "привет"',
        '```'
    )

    $prompt = $lines -join "`n"
    $sandbox = ($script:AI_SANDBOX | ForEach-Object { "  - $_" }) -join "`n"
    $prompt += "`n`nРАЗРЕШЁННЫЕ ПАПКИ ДЛЯ ЗАПИСИ:`n$sandbox"
    $prompt += "`n`nЗАПРЕЩЕНО: писать в C:\Windows, C:\Program Files, системные папки. Команды rm -rf, format, shutdown, diskpart."

    return $prompt
}

# ═══ SAFETY ═══

function ai-is-danger {
    param([string]$Cmd)
    foreach ($pat in $script:AI_DANGER) {
        if ($Cmd -match $pat) { return $true }
    }
    return $false
}

function ai-is-sandbox {
    param([string]$Path)
    try { $full = [System.IO.Path]::GetFullPath($Path) } catch { return $false }
    foreach ($root in $script:AI_SANDBOX) {
        try {
            $rootFull = [System.IO.Path]::GetFullPath($root)
            if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        } catch {}
    }
    return $false
}

function ai-server-ok {
    try {
        $null = Invoke-RestMethod -Uri "$script:AI_URL/models" -TimeoutSec 5
        return $true
    } catch { return $false }
}

function ai-ensure-server {
    if (ai-server-ok) { return $true }

    if (-not (Test-Path $script:LMS)) {
        Write-Host "  lms.exe not found" -ForegroundColor Red
        return $false
    }

    Write-Host "  Starting LM Studio..." -ForegroundColor Yellow
    & $script:LMS server start 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    $loaded = $false
    try {
        $r = Invoke-RestMethod -Uri "$script:AI_URL/models" -TimeoutSec 5
        foreach ($m in $r.data) {
            if ($m.id -like "*deepseek-r1-0528*") { $loaded = $true; break }
        }
    } catch {}

    if (-not $loaded) {
        Write-Host "  Loading model..." -ForegroundColor Yellow
        & $script:LMS load $script:AI_MODEL --gpu max -y 2>&1 | Out-Null
        Start-Sleep -Seconds 3
    }

    return (ai-server-ok)
}

# ═══ TOOL ФУНКЦИИ ═══

function ai-exec {
    param([string]$Cmd, [bool]$Auto = $false)
    Write-Host ""
    if (ai-is-danger $Cmd) {
        Write-Host "  BLOCKED (danger): $Cmd" -ForegroundColor Red
        return "[BLOCKED by safety filter]"
    }
    Write-Host "  [exec] " -NoNewline -ForegroundColor Yellow
    Write-Host $Cmd -ForegroundColor Cyan

    if (-not $Auto -and -not $script:AI_YOLO) {
        $a = Read-Host "  Run? (y/N)"
        if ($a -ne "y") {
            Write-Host "  Cancelled" -ForegroundColor DarkGray
            return "[cancelled by user]"
        }
    }

    if ($script:AI_DRY) {
        Write-Host "  (dry-run)" -ForegroundColor DarkGray
        return "[dry-run]"
    }

    try {
        $out = & pwsh -NoProfile -Command $Cmd 2>&1 | Out-String
        Write-Host $out
        return $out
    } catch {
        $err = $_.Exception.Message
        Write-Host "  Error: $err" -ForegroundColor Red
        return "[error] $err"
    }
}

function ai-write {
    param([string]$Path, [string]$Content, [bool]$Auto = $false)
    Write-Host ""
    if (-not (ai-is-sandbox $Path)) {
        Write-Host "  BLOCKED (outside sandbox): $Path" -ForegroundColor Red
        return "[BLOCKED: $Path outside sandbox]"
    }

    Write-Host "  [write] " -NoNewline -ForegroundColor Yellow
    Write-Host $Path -ForegroundColor Cyan
    Write-Host "  Preview:" -ForegroundColor DarkGray
    $lines = $Content -split "`n"
    $preview = $lines | Select-Object -First 15
    foreach ($l in $preview) {
        Write-Host "    | $l" -ForegroundColor DarkGray
    }
    if ($lines.Count -gt 15) {
        Write-Host "    | ... ($($lines.Count - 15) more)" -ForegroundColor DarkGray
    }

    if (-not $Auto -and -not $script:AI_YOLO) {
        $a = Read-Host "  Write? (y/N)"
        if ($a -ne "y") {
            Write-Host "  Cancelled" -ForegroundColor DarkGray
            return "[cancelled by user]"
        }
    }

    if ($script:AI_DRY) {
        Write-Host "  (dry-run)" -ForegroundColor DarkGray
        return "[dry-run]"
    }

    try {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        Set-Content -Path $Path -Value $Content -Encoding UTF8
        Write-Host "  Written: $Path" -ForegroundColor Green
        return "[written OK: $Path]"
    } catch {
        $err = $_.Exception.Message
        Write-Host "  Error: $err" -ForegroundColor Red
        return "[error] $err"
    }
}

function ai-read {
    param([string]$Path)
    Write-Host ""
    if (-not (ai-is-sandbox $Path)) {
        Write-Host "  BLOCKED (outside sandbox): $Path" -ForegroundColor Red
        return "[BLOCKED: $Path outside sandbox]"
    }
    if (-not (Test-Path $Path)) {
        Write-Host "  Not found: $Path" -ForegroundColor Red
        return "[not found: $Path]"
    }
    try {
        $content = Get-Content -Path $Path -Raw -Encoding UTF8
        $len = $content.Length
        if ($len -gt 8000) {
            Write-Host "  [read] $Path (first 8000)" -ForegroundColor Cyan
            return $content.Substring(0, 8000) + "`n[...truncated]"
        }
        Write-Host "  [read] $Path ($len chars)" -ForegroundColor Cyan
        return $content
    } catch {
        return "[error] $($_.Exception.Message)"
    }
}

function ai-handle-response {
    param([string]$Answer)
    $did = $false
    $results = "`n=== TOOL RESULTS ===`n"

    $readMatches = [regex]::Matches($Answer, '(?s)```read\s*\n(.*?)\n```')
    foreach ($m in $readMatches) {
        $path = $m.Groups[1].Value.Trim()
        $r = ai-read -Path $path
        $results += "`n[READ $path]:`n$r`n"
        $did = $true
    }

    $writeMatches = [regex]::Matches($Answer, '(?s)```write\s*\n(.*?)\n(.*?)\n```')
    foreach ($m in $writeMatches) {
        $path = $m.Groups[1].Value.Trim()
        $content = $m.Groups[2].Value
        $r = ai-write -Path $path -Content $content
        $results += "`n[WRITE $path]: $r`n"
        $did = $true
    }

    $execMatches = [regex]::Matches($Answer, '(?s)```exec\s*\n(.*?)\n```')
    foreach ($m in $execMatches) {
        $cmd = $m.Groups[1].Value.Trim()
        if (-not $cmd) { continue }
        $r = ai-exec -Cmd $cmd
        $results += "`n[EXEC '$cmd']:`n$r`n"
        $did = $true
    }

    if ($did) { return $results }
    return $null
}

# ═══ ОСНОВНАЯ ФУНКЦИЯ ═══

function ai-list {
    if (-not (ai-ensure-server)) { return }
    try {
        $r = Invoke-RestMethod -Uri "$script:AI_URL/models" -TimeoutSec 5
        Write-Host ""
        Write-Host "  LM Studio models:" -ForegroundColor Cyan
        $i = 1
        foreach ($m in $r.data) {
            Write-Host "    [$i] $($m.id)" -ForegroundColor White
            $i++
        }
        Write-Host ""
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function ai-model {
    param([string]$Name)
    if (-not $Name) {
        Write-Host "  Current: $script:AI_MODEL" -ForegroundColor Cyan
        return
    }
    $script:AI_MODEL = $Name
    Write-Host "  Model: $Name" -ForegroundColor Green
}

function ai-reset {
    $script:AI_HISTORY = @()
    Write-Host "  History cleared" -ForegroundColor Green
}

function ai-yolo {
    $script:AI_YOLO = -not $script:AI_YOLO
    $s = if ($script:AI_YOLO) { "ON" } else { "OFF" }
    $c = if ($script:AI_YOLO) { "Red" } else { "Green" }
    Write-Host "  Yolo: $s" -ForegroundColor $c
}

function ai-dry {
    $script:AI_DRY = -not $script:AI_DRY
    $s = if ($script:AI_DRY) { "ON" } else { "OFF" }
    Write-Host "  Dry: $s" -ForegroundColor Yellow
}

function ai-request {
    param([array]$Messages)
    $body = @{
        model = $script:AI_MODEL
        messages = $Messages
        stream = $false
        temperature = 0.6
        max_tokens = 4096
    } | ConvertTo-Json -Depth 10 -Compress

    return Invoke-RestMethod -Uri "$script:AI_URL/chat/completions" `
        -Method Post -Body $body -ContentType "application/json" -TimeoutSec 300
}

function ai {
    $list = @()
    foreach ($a in $args) { $list += [string]$a }

    if ($list.Count -eq 0) {
        Write-Host "  Usage: ai <question>" -ForegroundColor Yellow
        Write-Host "         ai -List | -Chat | -Reset | -Model NAME" -ForegroundColor Gray
        Write-Host "         ai -Yolo | -Dry" -ForegroundColor Gray
        return
    }

    $first = $list[0]
    if ($first -eq "-List" -or $first -eq "-l")  { ai-list; return }
    if ($first -eq "-Chat" -or $first -eq "-c")  { ai-chat; return }
    if ($first -eq "-Reset" -or $first -eq "-r") { ai-reset; return }
    if ($first -eq "-Yolo" -or $first -eq "-y")  { ai-yolo; return }
    if ($first -eq "-Dry" -or $first -eq "-d")   { ai-dry; return }
    if ($first -eq "-Model" -or $first -eq "-m") {
        if ($list.Count -ge 2) { ai-model $list[1] } else { ai-model }
        return
    }

    $question = ($list -join " ").Trim()
    if (-not $question) { return }

    if (-not (ai-ensure-server)) { return }

    $messages = @(@{ role = "system"; content = (ai-system-prompt) })
    foreach ($h in $script:AI_HISTORY) { $messages += $h }
    $messages += @{ role = "user"; content = $question }

    Write-Host ""
    Write-Host "  Asking $script:AI_MODEL..." -ForegroundColor DarkGray

    try {
        $t0 = Get-Date
        $r = ai-request -Messages $messages
        $el = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)

        $answer = $r.choices[0].message.content
        $reasoning = $r.choices[0].message.reasoning_content

        Write-Host ""
        if ($reasoning) {
            $short = $reasoning.Substring(0, [Math]::Min(300, $reasoning.Length))
            Write-Host "  [thinking] $short..." -ForegroundColor DarkYellow
            Write-Host ""
        }
        Write-Host $answer
        Write-Host ""
        Write-Host "  ($el sec)" -ForegroundColor DarkGray

        $script:AI_HISTORY += @{ role = "user"; content = $question }
        $script:AI_HISTORY += @{ role = "assistant"; content = $answer }

        $follow = ai-handle-response -Answer $answer
        if ($follow) {
            $script:AI_HISTORY += @{ role = "user"; content = $follow }
            Write-Host ""
            Write-Host "  Sending results back..." -ForegroundColor DarkGray

            $messages2 = @(@{ role = "system"; content = (ai-system-prompt) })
            foreach ($h in $script:AI_HISTORY) { $messages2 += $h }

            try {
                $t1 = Get-Date
                $r2 = ai-request -Messages $messages2
                $el2 = [math]::Round(((Get-Date) - $t1).TotalSeconds, 1)
                $answer2 = $r2.choices[0].message.content
                Write-Host ""
                Write-Host $answer2
                Write-Host ""
                Write-Host "  ($el2 sec)" -ForegroundColor DarkGray
                $script:AI_HISTORY += @{ role = "assistant"; content = $answer2 }
            } catch {
                Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function ai-chat {
    Write-Host ""
    Write-Host "  ARGONOV AI chat" -NoNewline -ForegroundColor Cyan
    Write-Host "  ('exit' quit, 'reset' clear, 'yolo'/'dry' toggle)" -ForegroundColor DarkGray
    Write-Host ""
    while ($true) {
        try { $line = Read-Host "you" } catch { break }
        if (-not $line) { continue }
        if ($line -eq "exit" -or $line -eq "q") { break }
        if ($line -eq "reset") { ai-reset; continue }
        if ($line -eq "yolo")  { ai-yolo; continue }
        if ($line -eq "dry")   { ai-dry; continue }
        ai $line
    }
    Write-Host "  Bye" -ForegroundColor DarkGray
}