# ARGONOV SHELL · autostart audit

# Известные безопасные записи
$script:SAFE_NAMES = @(
    "SecurityHealth","RtkAudUService","OneDrive","Discord","Steam",
    "MicrosoftEdgeAutoLaunch","Adobe","NVIDIA","Radeon","Realtek",
    "PowerToys","WhatsApp","Telegram","Signal","Zoom","Skype",
    "MicrosoftTeams","Spotify","EpicGames","Battle.net","GalaxyClient",
    "Sunlogin","AnyDesk","TeamViewer","Dropbox","GoogleDrive","Yandex",
    "Opera","Chrome","Firefox","YandexBrowser","SynologyDrive",
    "Microsoft.Lists","SEVPNCLIENT","SoftEther","Radmin VPN","Happ",
    "VpnGate","CodeMeter","Sentinel","Poly","Wispr"
)

# Подозрительные ПОДСТРОКИ (литеральные, регистронезависимые)
$script:SUSPICIOUS_STRINGS = @(
    "\appdata\local\temp\",
    "\windows\temp\",
    "\temp\",
    ".vbs",
    ".js",
    ".wsf",
    ".hta"
)

# Подозрительные REGEX-паттерны
$script:SUSPICIOUS_REGEX = @(
    "powershell.*-enc",
    "cmd.*\/c.*hidden",
    "regsvr32.*http",
    "rundll32.*http"
)

function autostart {
    param([switch]$All)

    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "  ║  " -NoNewline -ForegroundColor DarkCyan
    Write-Host "🔍 АУДИТ АВТОЗАГРУЗКИ" -NoNewline -ForegroundColor Cyan
    Write-Host (" " * (36 - "🔍 АУДИТ АВТОЗАГРУЗКИ".Length)) -NoNewline
    Write-Host "          ║" -ForegroundColor DarkGray
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    Write-Host ""

    $items = @()

    # ── Реестр Run ──
    $regKeys = @(
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run";     Scope = "HKCU Run" },
        @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run";     Scope = "HKLM Run" },
        @{ Path = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; Scope = "HKLM Run (x86)" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"; Scope = "HKCU RunOnce" },
        @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"; Scope = "HKLM RunOnce" }
    )
    foreach ($key in $regKeys) {
        $props = Get-ItemProperty $key.Path -ErrorAction SilentlyContinue
        if ($props) {
            $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                $items += [PSCustomObject]@{
                    Name  = $_.Name
                    Value = [string]$_.Value
                    Scope = $key.Scope
                }
            }
        }
    }

    # ── Startup folder ──
    $folders = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    )
    foreach ($folder in $folders) {
        if (Test-Path $folder) {
            Get-ChildItem $folder -File -ErrorAction SilentlyContinue | ForEach-Object {
                $items += [PSCustomObject]@{
                    Name  = $_.Name
                    Value = $_.FullName
                    Scope = "Startup folder"
                }
            }
        }
    }

    # ── Классификация ──
    $safe       = @()
    $suspicious = @()
    $useless    = @()
    $unknown    = @()

    foreach ($item in $items) {
        $valueLower = $item.Value.ToLower()
        $nameLower  = $item.Name.ToLower()
        $isSafe = $false
        $isSuspicious = $false
        $isUseless = $false

        foreach ($s in $script:SAFE_NAMES) {
            $sl = $s.ToLower()
            if ($nameLower -like "*$sl*" -or $valueLower -like "*$sl*") {
                $isSafe = $true
                break
            }
        }

        foreach ($p in $script:SUSPICIOUS_STRINGS) {
            if ($valueLower.Contains($p)) {
                $isSuspicious = $true
                break
            }
        }

        if (-not $isSuspicious) {
            foreach ($p in $script:SUSPICIOUS_REGEX) {
                if ($valueLower -match $p) {
                    $isSuspicious = $true
                    break
                }
            }
        }

        if ($nameLower -match "update|updater|helper|assistant|launcher") {
            $isUseless = $true
        }

        $risk = if ($isSuspicious) { "HIGH" } elseif ($isUseless) { "LOW" } elseif ($isSafe) { "OK" } else { "?" }

        $classified = [PSCustomObject]@{
            Name  = $item.Name
            Value = $item.Value
            Scope = $item.Scope
            Risk  = $risk
        }

        switch ($risk) {
            "HIGH"  { $suspicious += $classified }
            "LOW"   { $useless    += $classified }
            "OK"    { $safe       += $classified }
            default { $unknown    += $classified }
        }
    }

    # ── Вывод ──
    $total = $items.Count
    Write-Host "  Всего записей: " -NoNewline -ForegroundColor White
    Write-Host "$total" -ForegroundColor Cyan
    Write-Host "    🔴 Подозрительных: $($suspicious.Count)  " -NoNewline -ForegroundColor Red
    Write-Host "🟡 Бесполезных: $($useless.Count)  " -NoNewline -ForegroundColor Yellow
    Write-Host "🟢 Безопасных: $($safe.Count)  " -NoNewline -ForegroundColor Green
    Write-Host "⚪ Неизвестных: $($unknown.Count)" -ForegroundColor DarkGray
    Write-Host ""

    function Show-Group {
        param($Title, $Items, $Color)
        if (-not $Items -or $Items.Count -eq 0) { return }
        Write-Host "  ── $Title ──" -ForegroundColor $Color
        foreach ($i in $Items) {
            Write-Host "    " -NoNewline
            Write-Host "[$($i.Scope)]" -NoNewline -ForegroundColor DarkGray
            Write-Host " $($i.Name)" -NoNewline -ForegroundColor White
            Write-Host "  →  " -NoNewline -ForegroundColor DarkGray
            $shortVal = if ($i.Value.Length -gt 70) { $i.Value.Substring(0, 70) + "..." } else { $i.Value }
            Write-Host $shortVal -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($suspicious.Count -gt 0) {
        Show-Group "🔴 ПОДОЗРИТЕЛЬНЫЕ" $suspicious "Red"
    }
    if ($useless.Count -gt 0) {
        Show-Group "🟡 БЕСПОЛЕЗНЫЕ (обновляторы, хелперы)" $useless "Yellow"
    }
    if ($unknown.Count -gt 0 -or $All) {
        Show-Group "⚪ НЕИЗВЕСТНЫЕ / ВСЕ ОСТАЛЬНЫЕ" $unknown "DarkGray"
    }
    if ($All) {
        Show-Group "🟢 БЕЗОПАСНЫЕ" $safe "Green"
    }

    Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  " -NoNewline
    Write-Host "autostart -All" -NoNewline -ForegroundColor Yellow
    Write-Host " — показать всё, включая безопасные" -ForegroundColor DarkGray
    Write-Host "  " -NoNewline
    Write-Host "autostart-remove <имя>" -NoNewline -ForegroundColor Yellow
    Write-Host " — удалить запись из автозагрузки" -ForegroundColor DarkGray
    Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""
}

function autostart-remove {
    param([Parameter(Mandatory)][string]$Name)

    Write-Host ""
    $found = $false
    $regKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($key in $regKeys) {
        $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($props -and $props.PSObject.Properties.Name -contains $Name) {
            $value = $props.$Name
            Write-Host "  Найдено в: $key" -ForegroundColor Yellow
            Write-Host "  Значение:  $value" -ForegroundColor Gray
            $answer = Read-Host "  Удалить? (y/N)"
            if ($answer -eq "y") {
                try {
                    Remove-ItemProperty -Path $key -Name $Name -Force -ErrorAction Stop
                    Write-Host "  ✅ Удалено: $Name" -ForegroundColor Green
                    $found = $true
                } catch {
                    Write-Host "  ❌ Ошибка (нужны права админа?): $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "  Отменено" -ForegroundColor DarkGray
            }
        }
    }

    if (-not $found) {
        Write-Host "  ⚠ Запись '$Name' не найдена в автозагрузке" -ForegroundColor Yellow
    }
    Write-Host ""
}