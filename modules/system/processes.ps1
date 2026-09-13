# ARGONOV SHELL · processes

function psg {
    param([string]$Name = "")
    $procs = Get-Process -ErrorAction SilentlyContinue
    if ($Name) {
        $procs = $procs | Where-Object { $_.ProcessName -like "*$Name*" }
    }
    $procs | Sort-Object -Property WS -Descending |
        Select-Object -First 25 ProcessName, Id,
            @{N='RAM_MB'; E={[math]::Round($_.WS / 1MB, 1)}},
            @{N='CPU'; E={[math]::Round($_.CPU, 1)}},
            Path |
        Format-Table -AutoSize
}

function pskill {
    param([Parameter(Mandatory)][string]$Name)
    $found = Get-Process -Name $Name -ErrorAction SilentlyContinue
    if (-not $found) {
        Write-Host "  No process named '$Name'" -ForegroundColor Yellow
        return
    }
    Write-Host "  Killing $($found.Count) process(es)..." -ForegroundColor Yellow
    $found | Stop-Process -Force
    Write-Host "  Done: $Name" -ForegroundColor Green
}

function top {
    Get-Process |
        Sort-Object -Property WS -Descending |
        Select-Object -First 15 ProcessName, Id,
            @{N='RAM_MB'; E={[math]::Round($_.WS / 1MB, 1)}},
            @{N='CPU_s';  E={[math]::Round($_.CPU, 1)}} |
        Format-Table -AutoSize
}

function human-size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "$([math]::Round($Bytes / 1GB, 2)) GB" }
    if ($Bytes -ge 1MB) { return "$([math]::Round($Bytes / 1MB, 2)) MB" }
    if ($Bytes -ge 1KB) { return "$([math]::Round($Bytes / 1KB, 1)) KB" }
    return "$Bytes B"
}

function bigfiles {
    param(
        [string]$Path = ".",
        [int]$Top = 20
    )
    if (-not (Test-Path $Path)) {
        Write-Host "  Path not found: $Path" -ForegroundColor Red
        return
    }
    Write-Host "  Scanning $Path ..." -ForegroundColor DarkGray
    Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object -Property Length -Descending |
        Select-Object -First $Top `
            @{N='Size'; E={ human-size $_.Length }},
            FullName |
        Format-Table -AutoSize
}

function disks {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,
            @{N='Label';    E={$_.VolumeName}},
            @{N='Free_GB';  E={[math]::Round($_.FreeSpace / 1GB, 1)}},
            @{N='Total_GB'; E={[math]::Round($_.Size / 1GB, 1)}},
            @{N='Used_pct'; E={[math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 0)}} |
        Format-Table -AutoSize
}