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
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [switch]$Execute,
        [ValidateRange(1, 3650)][int]$OlderThanDays = 1
    )

    $rawTempPath = $env:TEMP
    if ([string]::IsNullOrWhiteSpace($rawTempPath)) {
        Write-Host '  Error: TEMP environment variable is empty.' -ForegroundColor Red
        return
    }

    try {
        $root = [System.IO.Path]::GetFullPath($rawTempPath)
    } catch {
        Write-Host "  Error: invalid TEMP path: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        Write-Host "  Error: TEMP directory does not exist: $root" -ForegroundColor Red
        return
    }

    try {
        $rootItem = Get-Item -LiteralPath $root -Force -ErrorAction Stop
    } catch {
        Write-Host "  Error: cannot inspect TEMP directory: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Write-Host '  Error: TEMP itself is a reparse point; refusing recursive cleanup.' -ForegroundColor Red
        return
    }

    $cutoff = (Get-Date).AddDays(-$OlderThanDays)
    $candidates = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    $pendingDirectories = [System.Collections.Generic.Stack[string]]::new()
    $pendingDirectories.Push($root)

    # Traverse explicitly instead of using a blind recursive delete. Never follow links/junctions.
    while ($pendingDirectories.Count -gt 0) {
        $directory = $pendingDirectories.Pop()
        try {
            $children = @(Get-ChildItem -LiteralPath $directory -ErrorAction Stop)
        } catch {
            Write-Warning "Skipping inaccessible directory '$directory': $($_.Exception.Message)"
            continue
        }

        foreach ($item in $children) {
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                Write-Host "  Skipping linked item: $($item.FullName)" -ForegroundColor DarkGray
                continue
            }
            if ($item.PSIsContainer) {
                $pendingDirectories.Push($item.FullName)
                continue
            }
            if ($item -is [System.IO.FileInfo] -and $item.LastWriteTime -lt $cutoff) {
                $candidates.Add($item)
            }
        }
    }

    $totalBytes = 0L
    foreach ($file in $candidates) { $totalBytes += $file.Length }
    $size = if ($totalBytes -ge 1MB) {
        "$([math]::Round($totalBytes / 1MB, 1)) MB"
    } else {
        "$([math]::Round($totalBytes / 1KB, 1)) KB"
    }

    Write-Host "  TEMP: $root" -ForegroundColor Gray
    Write-Host "  Age threshold: older than $OlderThanDays day(s) (before $($cutoff.ToString('yyyy-MM-dd HH:mm:ss')))" -ForegroundColor Gray
    Write-Host "  Eligible files: $($candidates.Count)  ($size)" -ForegroundColor Cyan

    if (-not $Execute) {
        Write-Host '  Preview only. Use cleanup -Execute to request deletion.' -ForegroundColor DarkGray
        return
    }
    if ($candidates.Count -eq 0) {
        Write-Host '  Nothing to delete.' -ForegroundColor DarkGray
        return
    }

    if (-not $PSCmdlet.ShouldProcess($root, "Delete $($candidates.Count) file(s) older than $OlderThanDays day(s)")) {
        return
    }

    $rootPrefix = $root.TrimEnd([char[]]@('\', '/')) + [System.IO.Path]::DirectorySeparatorChar
    $deleted = 0
    $failed = 0
    foreach ($file in $candidates) {
        try {
            $candidateFull = [System.IO.Path]::GetFullPath($file.FullName)
            if (-not $candidateFull.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Warning "Refusing path outside TEMP: $candidateFull"
                $failed++
                continue
            }
            if (-not (Test-Path -LiteralPath $candidateFull -PathType Leaf)) { continue }
            $current = Get-Item -LiteralPath $candidateFull -Force -ErrorAction Stop
            if (($current.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            if ($current.LastWriteTime -ge $cutoff) { continue }
            Remove-Item -LiteralPath $candidateFull -Force -ErrorAction Stop
            $deleted++
        } catch {
            $failed++
            Write-Warning "Could not delete '$($file.FullName)': $($_.Exception.Message)"
        }
    }

    Write-Host "  Deleted: $deleted file(s)." -ForegroundColor Green
    if ($failed -gt 0) {
        Write-Host "  Failed or skipped: $failed file(s)." -ForegroundColor Yellow
    }
    Write-Host '  Directories and linked items were not deleted.' -ForegroundColor DarkGray
}

function uptime {
    $os = Get-CimInstance Win32_OperatingSystem
    $up = (Get-Date) - $os.LastBootUpTime
    Write-Host "  Uptime: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($up.Days)d $($up.Hours)h $($up.Minutes)m" -ForegroundColor White
    Write-Host "  Boot:   " -NoNewline -ForegroundColor Yellow
    Write-Host "$($os.LastBootUpTime)" -ForegroundColor Gray
}