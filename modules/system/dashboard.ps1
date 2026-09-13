# ARGONOV SHELL · dashboard v2

function dash {
    Clear-Host

    $now = Get-Date
    $hostname = $env:COMPUTERNAME
    $user = $env:USERNAME

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "  ║  " -NoNewline -ForegroundColor DarkCyan
    Write-Host "⚡ ARGONOV DASHBOARD" -NoNewline -ForegroundColor Cyan
    Write-Host (" " * (36 - "⚡ ARGONOV DASHBOARD".Length)) -NoNewline
    Write-Host "$($now.ToString('HH:mm:ss'))  ║" -ForegroundColor DarkGray
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    Write-Host ""

    # ═══ ЖЕЛЕЗО ═══
    Write-Host "  ▬ ЖЕЛЕЗО" -ForegroundColor Magenta

    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $mb = Get-CimInstance Win32_BaseBoard
    $bios = Get-CimInstance Win32_BIOS

    # CPU
    $cpuCores = $cpu.NumberOfCores
    $cpuThreads = $cpu.NumberOfLogicalProcessors
    $cpuClock = $cpu.MaxClockSpeed
    Write-Host "    🧠 CPU:     " -NoNewline
    Write-Host "$($cpu.Name.Trim())" -ForegroundColor White
    Write-Host "                " -NoNewline
    Write-Host "$cpuCores ядер / $cpuThreads потоков @ $cpuClock MHz" -ForegroundColor Gray

    # RAM + тип
    $memModules = Get-CimInstance Win32_PhysicalMemory
    $ramTotal = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $ramSpeed = if ($memModules) { ($memModules | Select-Object -First 1).Speed } else { "?" }
    $ramType = if ($memModules) {
        switch ((($memModules | Select-Object -First 1).SMBIOSMemoryType)) {
            20 { "DDR" }; 21 { "DDR2" }; 24 { "DDR3" }; 26 { "DDR4" }; 34 { "DDR5" }
            default { "DDR$($_)" }
        }
    } else { "?" }
    $ramChannels = if ($memModules) { $memModules.Count } else { "?" }
    Write-Host "    💾 RAM:     " -NoNewline
    Write-Host "$ramTotal GB $ramType @ $ramSpeed MHz" -NoNewline -ForegroundColor White
    Write-Host "  ($ramChannels module(s))" -ForegroundColor Gray

    # GPU (все)
    $gpus = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch "Basic|Remote" }
    foreach ($gpu in $gpus) {
        # VRAM — через реестр (AdapterRAM overflow после 4 ГБ)
        $vram = "?"
        try {
            $regKey = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue |
                Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DriverDesc -eq $gpu.Name }
            if ($regKey) {
                $qw = (Get-ItemProperty $regKey.PSPath -ErrorAction SilentlyContinue)."HardwareInformation.qwMemorySize"
                if ($qw) { $vram = "$([math]::Round($qw / 1GB, 1)) GB" }
            }
        } catch {}
        if ($vram -eq "?") {
            try { $vram = "$([math]::Round($gpu.AdapterRAM / 1GB, 1)) GB" } catch {}
        }
        Write-Host "    🎮 GPU:     " -NoNewline
        Write-Host "$($gpu.Name)" -NoNewline -ForegroundColor White
        Write-Host "  ($vram, driver $($gpu.DriverVersion))" -ForegroundColor Gray
    }

    # Материнка + BIOS
    Write-Host "    🔧 Мат.плата: " -NoNewline
    Write-Host "$($mb.Manufacturer.Trim()) $($mb.Product.Trim())" -ForegroundColor Gray
    Write-Host "    ⚙  BIOS:    " -NoNewline
    $biosDate = try { ([Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate)).ToString("yyyy-MM-dd") } catch { $bios.ReleaseDate }
    Write-Host "$($bios.Manufacturer.Trim()) $($bios.SMBIOSBIOSVersion) ($biosDate)" -ForegroundColor Gray
    Write-Host ""

    # ═══ РЕСУРСЫ ═══
    Write-Host "  ▬ РЕСУРСЫ" -ForegroundColor Magenta

    $ramFree = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $ramUsed = [math]::Round($ramTotal - $ramFree, 1)
    $ramPct = [math]::Round(($ramUsed / $ramTotal) * 100, 0)
    $ramBar = "█" * [int]($ramPct / 4) + "░" * (25 - [int]($ramPct / 4))
    $ramColor = if ($ramPct -lt 60) { "Green" } elseif ($ramPct -lt 85) { "Yellow" } else { "Red" }
    Write-Host "    💻 RAM:  " -NoNewline
    Write-Host "$ramUsed GB / $ramTotal GB  " -NoNewline -ForegroundColor White
    Write-Host "$ramBar " -NoNewline -ForegroundColor $ramColor
    Write-Host "$ramPct%" -ForegroundColor DarkGray

    # Все диски
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Sort-Object DeviceID
    foreach ($disk in $disks) {
        $total = [math]::Round($disk.Size / 1GB, 0)
        $free  = [math]::Round($disk.FreeSpace / 1GB, 0)
        $used  = $total - $free
        $pct   = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 0) } else { 0 }
        $bar   = "█" * [int]($pct / 4) + "░" * (25 - [int]($pct / 4))
        $color = if ($pct -lt 75) { "Green" } elseif ($pct -lt 90) { "Yellow" } else { "Red" }
        $label = if ($disk.VolumeName) { " $($disk.VolumeName)" } else { "" }
        $devLabel = "$($disk.DeviceID)$label"
        Write-Host "    💾 $($devLabel.PadRight(8))" -NoNewline
        Write-Host "$free GB free / $total GB  " -NoNewline -ForegroundColor White
        Write-Host "$bar " -NoNewline -ForegroundColor $color
        Write-Host "$pct%" -ForegroundColor DarkGray
    }
    Write-Host ""

    # ═══ WINDOWS ═══
    Write-Host "  ▬ WINDOWS" -ForegroundColor Magenta

    try {
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $edition = if ($reg.DisplayVersion) { "$($reg.ProductName) $($reg.DisplayVersion)" } else { $reg.ProductName }
        $build = "$($reg.CurrentBuildNumber).$($reg.UBR)"
    } catch {
        $edition = $os.Caption
        $build = $os.BuildNumber
    }
    $arch = $os.OSArchitecture
    $install = $os.InstallDate

    $up = (Get-Date) - $os.LastBootUpTime

    Write-Host "    🪟 Редакция:  " -NoNewline
    Write-Host $edition -ForegroundColor White
    Write-Host "    🔨 Build:     " -NoNewline
    Write-Host "$build  ($arch)" -ForegroundColor Gray
    Write-Host "    📅 Установлена: " -NoNewline
    Write-Host $install.ToString("yyyy-MM-dd") -ForegroundColor Gray
    Write-Host "    ⏱  Аптайм:    " -NoNewline
    Write-Host "$($up.Days)д $($up.Hours)ч $($up.Minutes)м" -ForegroundColor Gray

    # Активация
    try {
        $lic = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" -ErrorAction Stop | Select-Object -First 1
        $actStatus = switch ($lic.LicenseStatus) {
            0 { "Unlicensed" }
            1 { "Activated" }
            2 { "Grace period" }
            3 { "Out of tolerance" }
            4 { "Non-genuine" }
            5 { "Notification" }
            6 { "Extended grace" }
            default { "Unknown ($($lic.LicenseStatus))" }
        }
        $color = if ($lic.LicenseStatus -eq 1) { "Green" } else { "Yellow" }
        Write-Host "    🔑 Активация: " -NoNewline
        Write-Host $actStatus -ForegroundColor $color
    } catch {
        Write-Host "    🔑 Активация: (не удалось определить)" -ForegroundColor DarkGray
    }
    Write-Host ""

    # ═══ ARGONOV SHELL ═══
    Write-Host "  ▬ ARGONOV SHELL" -ForegroundColor Magenta

    if (Test-Path "C:\ARGONOV\.git") {
        Push-Location "C:\ARGONOV"
        $branch = & git symbolic-ref --short HEAD 2>$null
        $status = & git status --porcelain 2>$null
        $dirty = ($status -ne $null -and $status.Length -gt 0)
        $lastCommit = & git log -1 --pretty=format:"%h %s" 2>$null
        $commitCount = (& git rev-list --count HEAD 2>$null)
        Pop-Location

        Write-Host "    📁 C:\ARGONOV  [" -NoNewline
        if ($dirty) {
            Write-Host "$branch*" -NoNewline -ForegroundColor Yellow
        } else {
            Write-Host $branch -NoNewline -ForegroundColor Green
        }
        Write-Host "]" -NoNewline -ForegroundColor DarkGray
        Write-Host "  $commitCount commits" -ForegroundColor DarkGray

        if ($lastCommit) {
            Write-Host "    └─ $lastCommit" -ForegroundColor Gray
        }
    } else {
        Write-Host "    📁 C:\ARGONOV: не git-репозиторий" -ForegroundColor Red
    }
    Write-Host ""

    # ═══ LM STUDIO ═══
    Write-Host "  ▬ LM STUDIO / AI" -ForegroundColor Magenta

    $lmsProc = Get-Process -Name "lms", "LM Studio" -ErrorAction SilentlyContinue
    $llamaProc = Get-Process -Name "llama-server" -ErrorAction SilentlyContinue
    $portListening = $false
    try {
        $test = Test-NetConnection -ComputerName "127.0.0.1" -Port 1234 -WarningAction SilentlyContinue
        $portListening = $test.TcpTestSucceeded
    } catch {}

    if ($portListening) {
        Write-Host "    ✅ Сервер:   " -NoNewline
        Write-Host "запущен на :1234" -ForegroundColor Green
        try {
            $models = Invoke-RestMethod -Uri "http://localhost:1234/v1/models" -TimeoutSec 3
            foreach ($m in $models.data) {
                Write-Host "    🧠 Модель:   " -NoNewline
                Write-Host $m.id -ForegroundColor Cyan
            }
        } catch {}
    } else {
        Write-Host "    ⭕ Сервер:   " -NoNewline
        Write-Host "не запущен" -ForegroundColor DarkGray
    }

    if ($llamaProc) {
        $mem = [math]::Round(($llamaProc | Measure-Object WS -Sum).Sum / 1MB, 0)
        Write-Host "    🔥 llama-server: " -NoNewline
        Write-Host "$($llamaProc.Count) процесс(ов), $mem MB" -ForegroundColor Yellow
    }
    Write-Host ""

    # ═══ АВТОЗАГРУЗКА ═══
    Write-Host "  ▬ АВТОЗАГРУЗКА" -ForegroundColor Magenta

    $startupItems = @()
    $startupKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($key in $startupKeys) {
        $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($props) {
            $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                $startupItems += [PSCustomObject]@{
                    Name  = $_.Name
                    Value = $_.Value
                    Scope = if ($key -like "*HKCU*") { "HKCU" } else { "HKLM" }
                }
            }
        }
    }
    $startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $startupFolder) {
        $startupItems += Get-ChildItem $startupFolder -File | ForEach-Object {
            [PSCustomObject]@{ Name = $_.Name; Value = $_.FullName; Scope = "Startup folder" }
        }
    }

    Write-Host "    📋 Всего записей: " -NoNewline
    Write-Host $startupItems.Count -ForegroundColor White
    Write-Host "    " -NoNewline
    Write-Host "Запусти " -NoNewline -ForegroundColor DarkGray
    Write-Host "autostart" -NoNewline -ForegroundColor Yellow
    Write-Host " для полного аудита" -ForegroundColor DarkGray
    Write-Host ""

    # ═══ ТОП-5 ПРОЦЕССОВ ═══
    Write-Host "  ▬ ТОП-5 ПРОЦЕССОВ" -ForegroundColor Magenta
    $procs = Get-Process | Sort-Object WS -Descending | Select-Object -First 5
    foreach ($p in $procs) {
        $mem = [math]::Round($p.WS / 1MB, 1)
        Write-Host "    " -NoNewline
        Write-Host $p.ProcessName.PadRight(24) -NoNewline -ForegroundColor White
        Write-Host "$mem MB" -ForegroundColor DarkGray
    }
    Write-Host ""

    # ═══ СЕТЬ ═══
    Write-Host "  ▬ СЕТЬ" -ForegroundColor Magenta
    try {
        $ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 3).Trim()
        Write-Host "    🌐 Внешний IP: " -NoNewline -ForegroundColor DarkGray
        Write-Host $ip -ForegroundColor Cyan
    } catch {
        Write-Host "    🌐 Внешний IP: " -NoNewline -ForegroundColor DarkGray
        Write-Host "нет соединения" -ForegroundColor Red
    }

    $localIps = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" } |
        Select-Object -ExpandProperty IPAddress
    if ($localIps) {
        Write-Host "    🏠 Локальные:  " -NoNewline -ForegroundColor DarkGray
        Write-Host ($localIps -join ", ") -ForegroundColor Cyan
    }

    $listening = (Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue).Count
    Write-Host "    🔌 Открытых портов: " -NoNewline -ForegroundColor DarkGray
    Write-Host $listening -ForegroundColor White
    Write-Host ""

    # ═══ ФУТЕР ═══
    Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  " -NoNewline
    Write-Host "sysinfo" -NoNewline -ForegroundColor Yellow
    Write-Host " · " -NoNewline -ForegroundColor DarkGray
    Write-Host "autostart" -NoNewline -ForegroundColor Yellow
    Write-Host " · " -NoNewline -ForegroundColor DarkGray
    Write-Host "ai" -NoNewline -ForegroundColor Yellow
    Write-Host " · " -NoNewline -ForegroundColor DarkGray
    Write-Host "commands" -NoNewline -ForegroundColor Yellow
    Write-Host " · " -NoNewline -ForegroundColor DarkGray
    Write-Host "cad list" -NoNewline -ForegroundColor Yellow
    Write-Host " · " -NoNewline -ForegroundColor DarkGray
    Write-Host "matrix" -ForegroundColor Yellow
    Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""
}

Set-Alias -Name "d" -Value "dash" -Force