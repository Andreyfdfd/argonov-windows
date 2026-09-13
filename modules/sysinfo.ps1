# ARGONOV SHELL · sysinfo
function sysinfo {
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = (Get-CimInstance Win32_VideoController |
            Where-Object { $_.Name -notmatch "Basic|Remote" } |
            Select-Object -First 1).Name

    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $usedGB  = [math]::Round($totalGB - $freeGB, 1)
    $ramPct  = [math]::Round(($usedGB / $totalGB) * 100, 0)

    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskTotalGB = [math]::Round($disk.Size / 1GB, 0)
    $diskFreeGB  = [math]::Round($disk.FreeSpace / 1GB, 0)
    $diskPct     = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 0)

    Write-Host ""
    Write-Host "  SYSTEM ------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  OS    " -NoNewline -ForegroundColor Yellow
    Write-Host "$($os.Caption)" -ForegroundColor White
    Write-Host "  Host  " -NoNewline -ForegroundColor Yellow
    Write-Host "$env:COMPUTERNAME  |  " -NoNewline -ForegroundColor White
    Write-Host "$env:USERNAME" -ForegroundColor Cyan
    Write-Host "  CPU   " -NoNewline -ForegroundColor Yellow
    Write-Host "$($cpu.Name.Trim())" -ForegroundColor White
    Write-Host "  GPU   " -NoNewline -ForegroundColor Yellow
    Write-Host "$gpu" -ForegroundColor White
    Write-Host "  RAM   " -NoNewline -ForegroundColor Yellow
    Write-Host "$usedGB GB / $totalGB GB  " -NoNewline -ForegroundColor White
    Write-Host "($ramPct percent used)" -ForegroundColor DarkGray
    Write-Host "  Disk  " -NoNewline -ForegroundColor Yellow
    Write-Host "C: $diskFreeGB GB free / $diskTotalGB GB total  " -NoNewline -ForegroundColor White
    Write-Host "($diskPct percent used)" -ForegroundColor DarkGray
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host ""
}