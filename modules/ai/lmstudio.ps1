# ARGONOV SHELL · LM Studio CLI

$script:LMS = "$HOME\.lmstudio\bin\lms.exe"
$script:DEFAULT_MODEL = "deepseek-r1-0528-qwen3-8b"

function lm-status {
    if (-not (Test-Path $script:LMS)) {
        Write-Host "  lms.exe not found at $script:LMS" -ForegroundColor Red
        return
    }
    Write-Host ""
    Write-Host "  LM Studio status:" -ForegroundColor Cyan
    Write-Host "  -----------------" -ForegroundColor DarkCyan
    & $script:LMS server status
    Write-Host ""
    Write-Host "  Loaded models:" -ForegroundColor Cyan
    & $script:LMS ps
    Write-Host ""
}

function lm-models {
    if (-not (Test-Path $script:LMS)) {
        Write-Host "  lms.exe not found" -ForegroundColor Red
        return
    }
    & $script:LMS ls
}

function lm-up {
    param([string]$Model = $script:DEFAULT_MODEL)

    if (-not (Test-Path $script:LMS)) {
        Write-Host "  lms.exe not found" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "  Starting LM Studio server..." -ForegroundColor Yellow
    & $script:LMS server start
    Start-Sleep -Seconds 1

    Write-Host "  Loading model: $Model" -ForegroundColor Yellow
    & $script:LMS load $Model --gpu max -y
    Start-Sleep -Seconds 1

    Write-Host ""
    Write-Host "  Verifying..." -ForegroundColor DarkGray
    try {
        $r = Invoke-RestMethod -Uri "http://localhost:1234/v1/models" -TimeoutSec 5
        if ($r.data) {
            Write-Host "  OK, server ready" -ForegroundColor Green
            foreach ($m in $r.data) {
                Write-Host "    - $($m.id)" -ForegroundColor White
            }
        }
    } catch {
        Write-Host "  Server not responding yet" -ForegroundColor Yellow
    }
    Write-Host ""
}

function lm-down {
    if (-not (Test-Path $script:LMS)) {
        Write-Host "  lms.exe not found" -ForegroundColor Red
        return
    }
    Write-Host "  Unloading all models..." -ForegroundColor Yellow
    & $script:LMS unload --all
    Write-Host "  Done" -ForegroundColor Green
}