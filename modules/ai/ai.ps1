# ARGONOV SHELL · ai (chat-first + auto unload)

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
    "mkfs", "dd\s+if=",
    "shutdown\s+/[sr]", "diskpart",
    "Restart-Computer", "Stop-Computer"
)

function ai-system-prompt {
    $lines = @(
        'Ты AI-ассистент внутри ARGONOV SHELL на Windows 11.',
        'Отвечай по-русски, кратко и по делу.',
        '',
        'ТЫ УМЕЕШЬ ВЫПОЛНЯТЬ ДЕЙСТВИЯ через блоки:',
        '',
        'СОЗДАТЬ/ИЗМЕНИТЬ ФАЙЛ:',
        '```write',
        'C:\ARGONOV\hello.ps1',
        'Write-Host "привет"',
        '```',
        '',
        'ПРОЧИТАТЬ ФАЙЛ:',
        '```read',
        'C:\ARGONOV\profile.ps1',
        '```',
        '',
        'ЗАПУСТИТЬ КОМАНДУ:',
        '```exec',
        'python C:\ARGONOV\sysinfo.py',
        '```',
        '',
        'СОЗДАТЬ ПАПКУ:',
        '```mkdir',
        'C:\ARGONOV\new-project',
        '```',
        '',
        'СПИСОК ФАЙЛОВ:',
        '```list',
        'C:\ARGONOV\modules',
        '```',
        '',
        'УДАЛИТЬ:',
        '```delete',
        'C:\ARGONOV\old-file.txt',
        '```',
        '',
        'КРИТИЧЕСКИ ВАЖНО:',
        '- Не проси пользователя делать что-то вручную — используй блоки.',
        '- Не выдумывай Linux-команды (ls, cat, rm, nano).',
        '- Пути только абсолютные: C:\ARGONOV\file.ps1'
    )
    $prompt = $lines -join "`n"
    $sandbox = ($script:AI_SANDBOX | ForEach-Object { "  - $_" }) -join "`n"
    $prompt += "`n`nРАЗРЕШЁННЫЕ ПАПКИ:`n$sandbox"
    return $prompt
}

function ai-is-danger {
    param([string]$Cmd)
    foreach ($pat in $script:AI_DANGER) { if ($Cmd -match $pat) { return $true } }
    return $false
}

function ai-is-sandbox {
    param([string]$Path)
    try { $full = [System.IO.Path]::GetFullPath($Path) } catch { return $false }
    foreach ($root in $script:AI_SANDBOX) {
        try {
            $rootFull = [System.IO.Path]::GetFullPath($root)
            if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        } catch {}
    }
    return $false
}

function ai-server-ok {
    try {
        $null = Invoke-RestMethod -Uri "$script:AI_URL/models" -TimeoutSec 3
        return $true
    } catch { return $false }
}

function ai-model-loaded {
    try {
        $r = Invoke-RestMethod -Uri "$script:AI_URL/models" -TimeoutSec 3
        foreach ($m in $r.data) { if ($m.id -like "*deepseek-r1-0528*") { return $true } }
        return $false
    } catch { return $false }
}

function ai-ensure-server {
    if (ai-server-ok) {
        if (ai-model-loaded) { return $true }
        if (-not (Test-Path $script:LMS)) { return $false }
        Write-Host "  ⏳ Загрузка модели в VRAM (~5-10 сек)..." -ForegroundColor Yellow
        & $script:LMS load $script:AI_MODEL --gpu max -y 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        return (ai-server-ok)
    }

    if (-not (Test-Path $script:LMS)) {
        Write-Host "  ❌ lms.exe не найден" -ForegroundColor Red
        return $false
    }

    Write-Host "  ⏳ Запуск LM Studio..." -ForegroundColor Yellow
    & $script:LMS server start 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    Write-Host "  ⏳ Загрузка модели в VRAM (~5-10 сек)..." -ForegroundColor Yellow
    & $script:LMS load $script:AI_MODEL --gpu max -y 2>&1 | Out-Null
    Start-Sleep -Seconds 2

    return (ai-server-ok)
}

function ai-unload {
    if (-not (Test-Path $script:LMS)) { return }
    Write-Host "  💤 Выгрузка модели из VRAM..." -ForegroundColor Yellow
    & $script:LMS unload --all 2>&1 | Out-Null
    Write-Host "  ✅ VRAM освобождена" -ForegroundColor Green
}

# ═══ TOOLS ═══

function ai-exec {
    param([string]$Cmd)
    Write-Host ""
    if (ai-is-danger $Cmd) {
        Write-Host "  🛑 BLOCKED: $Cmd" -ForegroundColor Red
        return "[BLOCKED]"
    }
    Write-Host "  [exec] " -NoNewline -ForegroundColor Yellow
    Write-Host $Cmd -ForegroundColor Cyan
    if (-not $script:AI_YOLO) {
        $a = Read-Host "  Run? (y/N)"
        if ($a -ne "y") { return "[cancelled]" }
    }
    if ($script:AI_DRY) { return "[dry-run]" }
    try { return (& pwsh -NoProfile -Command $Cmd 2>&1 | Out-String) }
    catch { return "[error] $($_.Exception.Message)" }
}

function ai-write {
    param([string]$Path, [string]$Content)
    Write-Host ""
    if (-not (ai-is-sandbox $Path)) {
        Write-Host "  🛑 BLOCKED (outside sandbox): $Path" -ForegroundColor Red
        return "[BLOCKED]"
    }
    Write-Host "  [write] " -NoNewline -ForegroundColor Yellow
    Write-Host $Path -ForegroundColor Cyan
    $lines = $Content -split "`n"
    foreach ($l in ($lines | Select-Object -First 15)) { Write-Host "    | $l" -ForegroundColor DarkGray }
    if ($lines.Count -gt 15) { Write-Host "    | ... ($($lines.Count - 15) more)" -ForegroundColor DarkGray }
    if (-not $script:AI_YOLO) {
        $a = Read-Host "  Write? (y/N)"
        if ($a -ne "y") { return "[cancelled]" }
    }
    if ($script:AI_DRY) { return "[dry-run]" }
    try {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Set-Content -Path $Path -Value $Content -Encoding UTF8
        Write-Host "  ✅ Written: $Path" -ForegroundColor Green
        return "[written OK]"
    } catch { return "[error] $($_.Exception.Message)" }
}

function ai-read {
    param([string]$Path)
    Write-Host ""
    if (-not (ai-is-sandbox $Path)) { return "[BLOCKED]" }
    if (-not (Test-Path $Path)) { return "[not found]" }
    try {
        $c = Get-Content -Path $Path -Raw -Encoding UTF8
        if ($c.Length -gt 8000) { return $c.Substring(0, 8000) + "`n[...truncated]" }
        return $c
    } catch { return "[error]" }
}

function ai-mkdir {
    param([string]$Path)
    Write-Host ""
    if (-not (ai-is-sandbox $Path)) { return "[BLOCKED]" }
    Write-Host "  [mkdir] " -NoNewline -ForegroundColor Yellow
    Write-Host $Path -ForegroundColor Cyan
    if (-not $script:AI_YOLO) {
        $a = Read-Host "  Create? (y/N)"
        if ($a -ne "y") { return "[cancelled]" }
    }
    if ($script:AI_DRY) { return "[dry-run]" }
    try {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        Write-Host "  ✅ Created" -ForegroundColor Green
        return "[created OK]"
    } catch { return "[error]" }
}

function ai-list {
    param([string]$Path = ".")
    Write-Host ""
    if (-not (ai-is-sandbox $Path)) { return "[BLOCKED]" }
    if (-not (Test-Path $Path)) { return "[not found]" }
    try {
        $items = Get-ChildItem -Path $Path -Force -ErrorAction Stop
        $out = foreach ($i in $items) {
            $type = if ($i.PSIsContainer) { "DIR " } else { "FILE" }
            $size = if ($i.PSIsContainer) { "" } else { " ($([math]::Round($i.Length / 1KB, 1)) KB)" }
            "$type  $($i.Name)$size"
        }
        return ($out -join "`n")
    } catch { return "[error]" }
}

function ai-delete {
    param([string]$Path)
    Write-Host ""
    if (-not (ai-is-sandbox $Path)) { return "[BLOCKED]" }
    if (-not (Test-Path $Path)) { return "[not found]" }
    $item = Get-Item $Path
    if ($item.PSIsContainer) {
        $cnt = (Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue).Count
        Write-Host "  [delete DIR] $Path ($cnt files)" -ForegroundColor Yellow
    } else {
        Write-Host "  [delete FILE] $Path" -ForegroundColor Yellow
    }
    if (-not $script:AI_YOLO) {
        $a = Read-Host "  Delete? (y/N)"
        if ($a -ne "y") { return "[cancelled]" }
    }
    if ($script:AI_DRY) { return "[dry-run]" }
    try {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        Write-Host "  ✅ Deleted" -ForegroundColor Green
        return "[deleted OK]"
    } catch { return "[error]" }
}

function ai-handle-response {
    param([string]$Answer)
    $did = $false
    $results = "`n=== TOOL RESULTS ===`n"

    foreach ($x in [regex]::Matches($Answer, '(?s)```read\s*\n(.*?)\n```')) {
        $p = $x.Groups[1].Value.Trim(); $r = ai-read -Path $p
        $results += "`n[READ $p]:`n$r`n"; $did = $true
    }
    foreach ($x in [regex]::Matches($Answer, '(?s)```write\s*\n(.*?)\n(.*?)\n```')) {
        $p = $x.Groups[1].Value.Trim(); $c = $x.Groups[2].Value
        $r = ai-write -Path $p -Content $c
        $results += "`n[WRITE $p]: $r`n"; $did = $true
    }
    foreach ($x in [regex]::Matches($Answer, '(?s)```mkdir\s*\n(.*?)\n```')) {
        $p = $x.Groups[1].Value.Trim(); $r = ai-mkdir -Path $p
        $results += "`n[MKDIR $p]: $r`n"; $did = $true
    }
    foreach ($x in [regex]::Matches($Answer, '(?s)```list\s*\n(.*?)\n```')) {
        $p = $x.Groups[1].Value.Trim(); $r = ai-list -Path $p
        $results += "`n[LIST $p]:`n$r`n"; $did = $true
    }
    foreach ($x in [regex]::Matches($Answer, '(?s)```delete\s*\n(.*?)\n```')) {
        $p = $x.Groups[1].Value.Trim(); $r = ai-delete -Path $p
        $results += "`n[DELETE $p]: $r`n"; $did = $true
    }
    foreach ($x in [regex]::Matches($Answer, '(?s)```exec\s*\n(.*?)\n```')) {
        $c = $x.Groups[1].Value.Trim()
        if (-not $c) { continue }
        $r = ai-exec -Cmd $c
        $results += "`n[EXEC '$c']:`n$r`n"; $did = $true
    }

    if ($did) { return $results }
    return $null
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

# ═══ ОТПРАВКА ВОПРОСА ═══

function ai-ask {
    param([string]$Question)

    if (-not (ai-ensure-server)) { return }

    $messages = @(@{ role = "system"; content = (ai-system-prompt) })
    foreach ($h in $script:AI_HISTORY) { $messages += $h }
    $messages += @{ role = "user"; content = $Question }

    Write-Host ""
    Write-Host "  🧠 $script:AI_MODEL" -ForegroundColor DarkGray

    try {
        $t0 = Get-Date
        $r = ai-request -Messages $messages
        $el = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        $answer = $r.choices[0].message.content
        $reasoning = $r.choices[0].message.reasoning_content

        Write-Host ""
        if ($reasoning) {
            $short = $reasoning.Substring(0, [Math]::Min(300, $reasoning.Length))
            Write-Host "  💭 $short..." -ForegroundColor DarkYellow
            Write-Host ""
        }
        Write-Host $answer
        Write-Host ""
        Write-Host "  ⏱ $el сек" -ForegroundColor DarkGray

        $script:AI_HISTORY += @{ role = "user"; content = $Question }
        $script:AI_HISTORY += @{ role = "assistant"; content = $answer }

        $follow = ai-handle-response -Answer $answer
        if ($follow) {
            $script:AI_HISTORY += @{ role = "user"; content = $follow }
            Write-Host ""
            Write-Host "  🔄 Отправляю результаты обратно..." -ForegroundColor DarkGray

            $messages2 = @(@{ role = "system"; content = (ai-system-prompt) })
            foreach ($h in $script:AI_HISTORY) { $messages2 += $h }

            try {
                $r2 = ai-request -Messages $messages2
                $answer2 = $r2.choices[0].message.content
                Write-Host ""
                Write-Host $answer2
                Write-Host ""
                $script:AI_HISTORY += @{ role = "assistant"; content = $answer2 }
            } catch {
                Write-Host "  ❌ Ошибка: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "  ❌ Ошибка: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ═══ ИНТЕРАКТИВНЫЙ ВВОД С ESCAPE ═══

function Read-ChatInput {
    param([string]$Prompt = "you")

    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host $Prompt -NoNewline -ForegroundColor Magenta
    Write-Host " › " -NoNewline -ForegroundColor DarkGray

    $buffer = [System.Text.StringBuilder]::new()

    while ($true) {
        try {
            $key = [System.Console]::ReadKey($true)
        } catch {
            return @{ Text = ""; Exit = $true }
        }

        # Escape → выход
        if ($key.Key -eq [System.ConsoleKey]::Escape) {
            Write-Host ""
            return @{ Text = ""; Exit = $true }
        }

        # Ctrl+C → выход
        if ($key.Key -eq [System.ConsoleKey]::C -and
            ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
            Write-Host ""
            return @{ Text = ""; Exit = $true }
        }

        # Enter → отправить
        if ($key.Key -eq [System.ConsoleKey]::Enter) {
            Write-Host ""
            return @{ Text = $buffer.ToString(); Exit = $false }
        }

        # Backspace → удалить последний символ
        if ($key.Key -eq [System.ConsoleKey]::Backspace) {
            if ($buffer.Length -gt 0) {
                [void]$buffer.Remove($buffer.Length - 1, 1)
                Write-Host "`b `b" -NoNewline
            }
            continue
        }

        # Обычный символ
        if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar) -and [int]$key.KeyChar -ne 0) {
            [void]$buffer.Append($key.KeyChar)
            Write-Host $key.KeyChar -NoNewline
        }
    }
}

# ═══ ЧАТ ═══

function ai-chat {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "  ║  " -NoNewline -ForegroundColor DarkCyan
    Write-Host "🧠 ARGONOV AI CHAT" -NoNewline -ForegroundColor Cyan
    Write-Host (" " * (36 - "🧠 ARGONOV AI CHAT".Length)) -NoNewline
    Write-Host "                ║" -ForegroundColor DarkGray
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Модель: " -NoNewline -ForegroundColor DarkGray
    Write-Host "$script:AI_MODEL" -ForegroundColor White
    Write-Host "  Выход:  " -NoNewline -ForegroundColor DarkGray
    Write-Host "q" -NoNewline -ForegroundColor Yellow
    Write-Host " · " -NoNewline -ForegroundColor DarkGray
    Write-Host "exit" -NoNewline -ForegroundColor Yellow
    Write-Host " · " -NoNewline -ForegroundColor DarkGray
    Write-Host "Esc" -NoNewline -ForegroundColor Yellow
    Write-Host " · " -NoNewline -ForegroundColor DarkGray
    Write-Host "Ctrl+C" -ForegroundColor Yellow
    Write-Host "  Модель будет " -NoNewline -ForegroundColor DarkGray
    Write-Host "выгружена" -NoNewline -ForegroundColor Yellow
    Write-Host " из VRAM при выходе" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (ai-ensure-server)) { return }

    try {
        while ($true) {
            $r = Read-ChatInput -Prompt "you"
            if ($r.Exit) { break }

            $line = $r.Text.Trim()
            if (-not $line) { continue }
            if ($line -eq "q" -or $line -eq "exit") { break }
            if ($line -eq "reset") {
                $script:AI_HISTORY = @()
                Write-Host "  ♻️ История очищена" -ForegroundColor Green
                continue
            }

            ai-ask -Question $line
        }
    } finally {
        Write-Host ""
        ai-unload
        Write-Host ""
        Write-Host "  👋 Пока!" -ForegroundColor DarkGray
        Write-Host ""
    }
}

# ═══ ДИСПЕТЧЕР ═══

function ai {
    $list = @()
    foreach ($a in $args) { $list += [string]$a }

    # AI без аргументов → сразу чат
    if ($list.Count -eq 0) {
        ai-chat
        return
    }

    $first = $list[0]
    if ($first -eq "-Chat" -or $first -eq "-c")    { ai-chat; return }
    if ($first -eq "-Reset" -or $first -eq "-r")   { $script:AI_HISTORY = @(); Write-Host "  ♻️ История очищена" -ForegroundColor Green; return }
    if ($first -eq "-Yolo" -or $first -eq "-y")    { $script:AI_YOLO = -not $script:AI_YOLO; Write-Host "  Yolo: $(if ($script:AI_YOLO) { 'ВКЛ' } else { 'выкл' })" -ForegroundColor Yellow; return }
    if ($first -eq "-Dry" -or $first -eq "-d")     { $script:AI_DRY = -not $script:AI_DRY; Write-Host "  Dry: $(if ($script:AI_DRY) { 'ВКЛ' } else { 'выкл' })" -ForegroundColor Yellow; return }
    if ($first -eq "-Unload" -or $first -eq "-u")  { ai-unload; return }
    if ($first -eq "-Model" -or $first -eq "-m") {
        if ($list.Count -ge 2) { $script:AI_MODEL = $list[1]; Write-Host "  Модель: $($list[1])" -ForegroundColor Green }
        else { Write-Host "  Текущая: $script:AI_MODEL" -ForegroundColor Cyan }
        return
    }
    if ($first -eq "-List" -or $first -eq "-l") {
        if (-not (ai-ensure-server)) { return }
        try {
            $r = Invoke-RestMethod -Uri "$script:AI_URL/models" -TimeoutSec 5
            Write-Host ""
            Write-Host "  Модели в LM Studio:" -ForegroundColor Cyan
            $i = 1
            foreach ($m in $r.data) { Write-Host "    [$i] $($m.id)" -ForegroundColor White; $i++ }
            Write-Host ""
        } catch { Write-Host "  Ошибка: $($_.Exception.Message)" -ForegroundColor Red }
        return
    }

    # Если первый аргумент — текст, значит это одиночный вопрос с выгрузкой
    $question = ($list -join " ").Trim()
    if (-not $question) { return }

    ai-ask -Question $question
    Write-Host ""
    ai-unload
}