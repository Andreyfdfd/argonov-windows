# ARGONOV SHELL · admin utilities

function env {
    param([string]$Filter = "")
    Get-ChildItem Env: |
        Where-Object { $_.Name -like "*$Filter*" -or $_.Value -like "*$Filter*" } |
        Sort-Object Name |
        Format-Table Name, Value -AutoSize
}

function path {
    $env:Path -split ";" | Where-Object { $_ } | ForEach-Object { "  $_" }
}

function svc {
    param(
        [string]$Filter = "",
        [string]$State = ""
    )
    $services = Get-Service
    if ($Filter) {
        $services = $services | Where-Object { $_.Name -like "*$Filter*" -or $_.DisplayName -like "*$Filter*" }
    }
    if ($State) {
        $services = $services | Where-Object { $_.Status -eq $State }
    }
    $services | Sort-Object Status, Name |
        Select-Object Status, Name, DisplayName |
        Format-Table -AutoSize
}

function startup {
    Write-Host ""
    Write-Host "  Startup entries:" -ForegroundColor Cyan
    Write-Host "  -----------------" -ForegroundColor DarkCyan

    $keys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($key in $keys) {
        $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($props) {
            $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                Write-Host "  " -NoNewline
                Write-Host $_.Name.PadRight(22) -NoNewline -ForegroundColor Yellow
                Write-Host " -> " -NoNewline -ForegroundColor DarkGray
                Write-Host $_.Value -ForegroundColor White
            }
        }
    }
    Write-Host ""
}

function cleanup {
    param([switch]$Execute)
    $paths = @("$env:TEMP")
    $totalBytes = 0
    foreach ($p in $paths) {
        if (Test-Path $p) {
            try {
                $files = Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue
                $size = ($files | Measure-Object -Property Length -Sum).Sum
                if (-not $size) { $size = 0 }
                $totalBytes += $size
                $sz = if ($size -ge 1MB) { "$([math]::Round($size / 1MB, 1)) MB" } else { "$([math]::Round($size / 1KB, 1)) KB" }
                Write-Host "  $p  ($sz)" -ForegroundColor Gray
            } catch {}
        }
    }
    $total = if ($totalBytes -ge 1MB) { "$([math]::Round($totalBytes / 1MB, 1)) MB" } else { "$([math]::Round($totalBytes / 1KB, 1)) KB" }
    Write-Host ""
    Write-Host "  Total: $total" -ForegroundColor Cyan

    if (-not $Execute) {
        Write-Host "  (preview only, use cleanup -Execute to delete)" -ForegroundColor DarkGray
        return
    }

    Write-Host ""
    $a = Read-Host "  Delete? (y/N)"
    if ($a -ne "y") {
        Write-Host "  Cancelled" -ForegroundColor DarkGray
        return
    }
    foreach ($p in $paths) {
        if (Test-Path $p) {
            try {
                Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }
    Write-Host "  Done" -ForegroundColor Green
}

function uptime {
    $os = Get-CimInstance Win32_OperatingSystem
    $up = (Get-Date) - $os.LastBootUpTime
    Write-Host "  Uptime: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($up.Days)d $($up.Hours)h $($up.Minutes)m" -ForegroundColor White
    Write-Host "  Boot:   " -NoNewline -ForegroundColor Yellow
    Write-Host "$($os.LastBootUpTime)" -ForegroundColor Gray
}