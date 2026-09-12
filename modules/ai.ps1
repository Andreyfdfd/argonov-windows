# ARGONOV SHELL · ai (LM Studio)

$script:AI_URL = "http://localhost:1234/v1"
$script:AI_MODEL = $null
$script:AI_HISTORY = @()

function ai-list {
    try {
        $r = Invoke-RestMethod -Uri "$script:AI_URL/models" -TimeoutSec 5
        if (-not $r.data -or $r.data.Count -eq 0) {
            Write-Host "  No models in LM Studio" -ForegroundColor Yellow
            return
        }
        Write-Host ""
        Write-Host "  LM Studio models:" -ForegroundColor Cyan
        $i = 1
        foreach ($m in $r.data) {
            Write-Host "    [$i] $($m.id)" -ForegroundColor White
            $i++
        }
        Write-Host ""
    } catch {
        Write-Host "  LM Studio not running (start server on port 1234)" -ForegroundColor Red
    }
}

function ai-model {
    param([string]$Name)
    if (-not $Name) {
        Write-Host "  Current model: " -NoNewline -ForegroundColor Yellow
        if ($script:AI_MODEL) {
            Write-Host $script:AI_MODEL -ForegroundColor Cyan
        } else {
            Write-Host "(auto - first available)" -ForegroundColor Gray
        }
        return
    }
    $script:AI_MODEL = $Name
    Write-Host "  Model set to: $Name" -ForegroundColor Green
}

function ai-reset {
    $script:AI_HISTORY = @()
    Write-Host "  Chat history cleared" -ForegroundColor Green
}

function ai {
    $list = @()
    foreach ($a in $args) { $list += [string]$a }

    if ($list.Count -eq 0) {
        Write-Host "  Usage: ai <question>" -ForegroundColor Yellow
        Write-Host "         ai -List" -ForegroundColor Gray
        Write-Host "         ai -Chat" -ForegroundColor Gray
        Write-Host "         ai -Model <name>" -ForegroundColor Gray
        Write-Host "         ai -Reset" -ForegroundColor Gray
        return
    }

    $first = $list[0]
    if ($first -eq "-List" -or $first -eq "-l") { ai-list; return }
    if ($first -eq "-Chat" -or $first -eq "-c") { ai-chat; return }
    if ($first -eq "-Reset" -or $first -eq "-r") { ai-reset; return }
    if ($first -eq "-Model" -or $first -eq "-m") {
        if ($list.Count -ge 2) { ai-model $list[1] } else { ai-model }
        return
    }

    $question = ($list -join " ").Trim()
    if (-not $question) {
        Write-Host "  No question" -ForegroundColor Yellow
        return
    }

    $modelId = $script:AI_MODEL
    if (-not $modelId) {
        try {
            $r = Invoke-RestMethod -Uri "$script:AI_URL/models" -TimeoutSec 5
            if ($r.data -and $r.data.Count -gt 0) {
                $modelId = $r.data[0].id
            } else {
                Write-Host "  No model loaded in LM Studio" -ForegroundColor Red
                return
            }
        } catch {
            Write-Host "  LM Studio not running (start server on port 1234)" -ForegroundColor Red
            return
        }
    }

    $messages = @()
    foreach ($h in $script:AI_HISTORY) { $messages += $h }
    $messages += @{ role = "user"; content = $question }

    $body = @{
        model = $modelId
        messages = $messages
        stream = $false
        temperature = 0.6
        max_tokens = 4096
    } | ConvertTo-Json -Depth 10 -Compress

    Write-Host ""
    Write-Host "  Asking $modelId..." -ForegroundColor DarkGray

    try {
        $t0 = Get-Date
        $r = Invoke-RestMethod -Uri "$script:AI_URL/chat/completions" `
            -Method Post -Body $body -ContentType "application/json" -TimeoutSec 300
        $el = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)

        $answer = $r.choices[0].message.content
        $reasoning = $r.choices[0].message.reasoning_content

        Write-Host ""
        if ($reasoning) {
            $short = $reasoning.Substring(0, [Math]::Min(400, $reasoning.Length))
            Write-Host "  [thinking] $short..." -ForegroundColor DarkYellow
            Write-Host ""
        }
        Write-Host $answer
        Write-Host ""
        Write-Host "  ($el sec)" -ForegroundColor DarkGray
        Write-Host ""

        $script:AI_HISTORY += @{ role = "user"; content = $question }
        $script:AI_HISTORY += @{ role = "assistant"; content = $answer }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function ai-chat {
    Write-Host ""
    Write-Host "  ARGONOV AI chat" -NoNewline -ForegroundColor Cyan
    Write-Host "  (type 'exit' to quit, 'reset' to clear)" -ForegroundColor DarkGray
    Write-Host ""
    while ($true) {
        try {
            $line = Read-Host "you"
        } catch { break }
        if (-not $line) { continue }
        if ($line -eq "exit" -or $line -eq "q") { break }
        if ($line -eq "reset") { ai-reset; continue }
        ai $line
    }
    Write-Host "  Bye" -ForegroundColor DarkGray
}