# ARGONOV SHELL · proxy

$script:PROXY_DIR = if ($global:ARGONOV_PROXY_DIR) {
    [System.IO.Path]::GetFullPath($global:ARGONOV_PROXY_DIR)
} else {
    Join-Path $HOME '.argonov-proxy'
}
$script:PROXY_LIST = Join-Path $script:PROXY_DIR 'list.txt'
$script:PROXY_OK = Join-Path $script:PROXY_DIR 'working.txt'
$script:PROXY_REGISTRY_PATH = if ($global:ARGONOV_PROXY_REGISTRY_PATH) {
    [string]$global:ARGONOV_PROXY_REGISTRY_PATH
} else {
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
}
$script:PROXY_STATE_FILE = if ($global:ARGONOV_PROXY_STATE_FILE) {
    [System.IO.Path]::GetFullPath($global:ARGONOV_PROXY_STATE_FILE)
} else {
    Join-Path $script:PROXY_DIR 'original-settings.json'
}

if (-not (Test-Path -LiteralPath $script:PROXY_DIR -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $script:PROXY_DIR | Out-Null
}

function Save-ProxySettingsSnapshot {
    if (Test-Path -LiteralPath $script:PROXY_STATE_FILE -PathType Leaf) { return }
    $properties = Get-ItemProperty -LiteralPath $script:PROXY_REGISTRY_PATH -ErrorAction Stop
    $values = [ordered]@{}
    foreach ($name in @('ProxyEnable', 'ProxyServer', 'ProxyOverride')) {
        $property = $properties.PSObject.Properties[$name]
        $propertyValue = $null
        if ($null -ne $property) { $propertyValue = $property.Value }
        $values[$name] = [ordered]@{
            Exists = ($null -ne $property)
            Value = $propertyValue
        }
    }
    $snapshot = [ordered]@{
        Version = 1
        RegistryPath = $script:PROXY_REGISTRY_PATH
        SavedAt = (Get-Date).ToString('o')
        Values = $values
    }
    $json = ConvertTo-Json -InputObject $snapshot -Depth 6
    $temporaryPath = "$script:PROXY_STATE_FILE.tmp"
    [System.IO.File]::WriteAllText($temporaryPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryPath -Destination $script:PROXY_STATE_FILE -Force
}

function Restore-ProxySettingsSnapshot {
    if (-not (Test-Path -LiteralPath $script:PROXY_STATE_FILE -PathType Leaf)) { return $false }
    $snapshot = Get-Content -LiteralPath $script:PROXY_STATE_FILE -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if (-not [string]::Equals([string]$snapshot.RegistryPath, [string]$script:PROXY_REGISTRY_PATH, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Saved proxy settings belong to a different registry path. No settings were restored.'
    }
    foreach ($name in @('ProxyEnable', 'ProxyServer', 'ProxyOverride')) {
        $entry = $snapshot.Values.PSObject.Properties[$name].Value
        if ($entry.Exists) {
            Set-ItemProperty -LiteralPath $script:PROXY_REGISTRY_PATH -Name $name -Value $entry.Value -ErrorAction Stop
        } else {
            Remove-ItemProperty -LiteralPath $script:PROXY_REGISTRY_PATH -Name $name -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -LiteralPath $script:PROXY_STATE_FILE -Force -ErrorAction Stop
    return $true
}

function proxy-fetch {
    Write-Host ""
    Write-Host "  Fetching proxy lists from GitHub..." -ForegroundColor Yellow

    $urls = @(
        @{ url = "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks5.txt"; type = "socks5" },
        @{ url = "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt";   type = "http"   },
        @{ url = "https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/socks5.txt"; type = "socks5" },
        @{ url = "https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/http.txt";   type = "http"   }
    )

    $all = @()
    foreach ($item in $urls) {
        try {
            Write-Host "    $($item.url.Split('/')[-1]) ... " -NoNewline -ForegroundColor DarkGray
            $r = Invoke-WebRequest -Uri $item.url -TimeoutSec 15 -UseBasicParsing
            $lines = $r.Content -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+:\d+$' }
            foreach ($line in $lines) {
                $all += "$($item.type)://$line"
            }
            Write-Host "$($lines.Count) proxies" -ForegroundColor Green
        } catch {
            Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    $all = $all | Sort-Object -Unique
    Set-Content -Path $script:PROXY_LIST -Value $all -Encoding UTF8
    Write-Host ""
    Write-Host "  Total: $($all.Count) unique proxies" -ForegroundColor Cyan
    Write-Host "  Saved: $script:PROXY_LIST" -ForegroundColor DarkGray
    Write-Host ""
}

function proxy-test {
    param(
        [int]$Max = 0,
        [int]$Threads = 30,
        [int]$TimeoutSec = 5
    )

    if (-not (Test-Path $script:PROXY_LIST)) {
        Write-Host "  No list. Run proxy-fetch first." -ForegroundColor Red
        return
    }

    $list = Get-Content $script:PROXY_LIST -Encoding UTF8
    if ($Max -gt 0) { $list = $list | Select-Object -First $Max }
    $total = $list.Count

    Write-Host ""
    Write-Host "  Testing $total proxies (threads: $Threads, timeout: ${TimeoutSec}s)" -ForegroundColor Yellow
    Write-Host "  This may take several minutes..." -ForegroundColor DarkGray
    Write-Host ""

    $results = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    $counter = [ref]0
    $t0 = Get-Date

    $pool = [runspacefactory]::CreateRunspacePool(1, $Threads)
    $pool.Open()

    $jobs = @()
    foreach ($proxy in $list) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        $null = $ps.AddScript({
            param($p, $timeout)
            $proxyUri = $p
            try {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $r = Invoke-WebRequest -Uri "https://api.ipify.org" -Proxy $proxyUri -TimeoutSec $timeout -UseBasicParsing
                $sw.Stop()
                $ms = [int]$sw.ElapsedMilliseconds
                if ($r.StatusCode -eq 200 -and $r.Content -match '^\d+\.\d+\.\d+\.\d+$') {
                    return [PSCustomObject]@{
                        Proxy  = $p
                        IP     = $r.Content.Trim()
                        TimeMs = $ms
                        OK     = $true
                    }
                }
            } catch {}
            return [PSCustomObject]@{ Proxy = $p; OK = $false; TimeMs = 0; IP = "" }
        }).AddArgument($proxy).AddArgument($TimeoutSec)
        $jobs += @{ PS = $ps; Handle = $ps.BeginInvoke() }
    }

    $done = 0
    foreach ($j in $jobs) {
        $out = $j.PS.EndInvoke($j.Handle)
        $j.PS.Dispose()
        foreach ($o in $out) {
            if ($o.OK) { $results.Add($o) }
        }
        $done++
        if ($done % 50 -eq 0 -or $done -eq $total) {
            $el = [math]::Round(((Get-Date) - $t0).TotalSeconds, 0)
            Write-Host "    $done / $total  ($el s, $($results.Count) OK)" -ForegroundColor DarkGray
        }
    }
    $pool.Close()
    $pool.Dispose()

    $sorted = $results | Sort-Object TimeMs
    $okLines = $sorted | ForEach-Object { "$($_.Proxy) | $($_.TimeMs) ms | $($_.IP)" }
    Set-Content -Path $script:PROXY_OK -Value $okLines -Encoding UTF8

    Write-Host ""
    Write-Host "  Working: $($sorted.Count) / $total" -ForegroundColor Green
    Write-Host "  Saved: $script:PROXY_OK" -ForegroundColor DarkGray
    Write-Host ""
}

function proxy-top {
    param([int]$N = 20)
    if (-not (Test-Path $script:PROXY_OK)) {
        Write-Host "  No tested proxies. Run proxy-test first." -ForegroundColor Red
        return
    }
    $lines = Get-Content $script:PROXY_OK -Encoding UTF8 | Select-Object -First $N
    if (-not $lines) {
        Write-Host "  No working proxies found." -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "  TOP $N proxies:" -ForegroundColor Cyan
    Write-Host "  -----------------" -ForegroundColor DarkCyan
    $i = 1
    foreach ($l in $lines) {
        $parts = $l -split " \| "
        Write-Host "  [$i] " -NoNewline -ForegroundColor Yellow
        Write-Host "$($parts[0])" -NoNewline -ForegroundColor White
        Write-Host "  $($parts[1])" -ForegroundColor DarkGray
        $i++
    }
    Write-Host ""
}

function proxy-test-one {
    param([Parameter(Mandatory)][string]$Proxy)
    Write-Host "  Testing $Proxy ..." -ForegroundColor Yellow
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-WebRequest -Uri "https://api.ipify.org" -Proxy $Proxy -TimeoutSec 10 -UseBasicParsing
        $sw.Stop()
        Write-Host "  OK: $($r.Content)  ($($sw.ElapsedMilliseconds) ms)" -ForegroundColor Green
    } catch {
        Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function proxy-use {
    [CmdletBinding()]
    param(
        [ValidateRange(1, 2147483647)][int]$Index = 1,
        [switch]$Force
    )

    if (-not (Test-Path -LiteralPath $script:PROXY_OK -PathType Leaf)) {
        Write-Host "  No tested proxies. Run proxy-fetch and proxy-test first." -ForegroundColor Red
        return
    }

    $lines = @(Get-Content -LiteralPath $script:PROXY_OK -Encoding UTF8)
    if ($Index -lt 1 -or $Index -gt $lines.Count) {
        Write-Host "  Index out of range (1..$($lines.Count))" -ForegroundColor Red
        return
    }

    $line = $lines[$Index - 1]
    $proxyRaw = ($line -split ' \| ', 2)[0].Trim()

    if ($proxyRaw -match '^socks5://') {
        Write-Host '  SOCKS5 не работает как системный прокси Windows.' -ForegroundColor Yellow
        Write-Host '  Используй HTTP-прокси (из списка http://).' -ForegroundColor DarkGray
        return
    }

    if ($proxyRaw -notmatch '^http://(\d{1,3}(?:\.\d{1,3}){3}):(\d{1,5})$') {
        Write-Host '  Invalid proxy entry. Expected http://IPv4:port.' -ForegroundColor Red
        return
    }
    $ipText = $Matches[1]
    $portText = $Matches[2]
    $ipAddress = $null
    $portNumber = 0
    if (-not [System.Net.IPAddress]::TryParse($ipText, [ref]$ipAddress) -or
        $ipAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or
        -not [int]::TryParse($portText, [ref]$portNumber) -or $portNumber -lt 1 -or $portNumber -gt 65535) {
        Write-Host '  Invalid IPv4 address or port (port must be 1..65535).' -ForegroundColor Red
        return
    }
    $addr = "$ipText`:$portNumber"

    Write-Host '  WARNING: a public proxy is untrusted and may observe or alter traffic that is not protected by end-to-end TLS.' -ForegroundColor Yellow
    Write-Host '  Do not use it for passwords, banking or sensitive activity.' -ForegroundColor Yellow
    if (-not $Force) {
        $answer = Read-Host '  Apply this proxy to Windows user settings? Type y to continue'
        if ($answer -cne 'y') {
            Write-Host '  Cancelled; Windows proxy settings were not changed.' -ForegroundColor DarkGray
            return
        }
    }

    try {
        if (-not (Test-Path -LiteralPath $script:PROXY_REGISTRY_PATH)) {
            throw "Proxy registry key not found: $script:PROXY_REGISTRY_PATH"
        }
        Save-ProxySettingsSnapshot
        Set-ItemProperty -LiteralPath $script:PROXY_REGISTRY_PATH -Name ProxyServer -Value $addr -ErrorAction Stop
        Set-ItemProperty -LiteralPath $script:PROXY_REGISTRY_PATH -Name ProxyOverride -Value '<local>' -ErrorAction Stop
        Set-ItemProperty -LiteralPath $script:PROXY_REGISTRY_PATH -Name ProxyEnable -Value 1 -ErrorAction Stop
    } catch {
        try { Restore-ProxySettingsSnapshot | Out-Null } catch {}
        Write-Host "  Could not apply proxy: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    Write-Host "  System proxy set to: $addr" -ForegroundColor Green
    Write-Host '  Original proxy settings saved. Run proxy-clear to restore them.' -ForegroundColor Cyan
    Write-Host '  Проверь: curl.exe https://api.ipify.org' -ForegroundColor DarkGray
}

function proxy-clear {
    [CmdletBinding()]
    param([switch]$Force)

    if (Test-Path -LiteralPath $script:PROXY_STATE_FILE -PathType Leaf) {
        try {
            if (Restore-ProxySettingsSnapshot) {
                Write-Host '  Original Windows proxy settings restored.' -ForegroundColor Green
            }
        } catch {
            Write-Host "  Could not restore saved proxy settings: $($_.Exception.Message)" -ForegroundColor Red
        }
        return
    }

    Write-Host '  No saved original proxy settings were found.' -ForegroundColor Yellow
    if (-not $Force) {
        $answer = Read-Host '  Disable the current Windows user proxy without restoring a snapshot? Type y to continue'
        if ($answer -cne 'y') {
            Write-Host '  Cancelled; Windows proxy settings were not changed.' -ForegroundColor DarkGray
            return
        }
    }
    try {
        Set-ItemProperty -LiteralPath $script:PROXY_REGISTRY_PATH -Name ProxyEnable -Value 0 -ErrorAction Stop
        Write-Host '  Windows user proxy disabled. ProxyServer and ProxyOverride values were retained.' -ForegroundColor Green
    } catch {
        Write-Host "  Could not disable proxy: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function proxy-status {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $enabled = (Get-ItemProperty -Path $key).ProxyEnable
    $server  = (Get-ItemProperty -Path $key).ProxyServer
    Write-Host ""
    if ($enabled -eq 1 -and $server) {
        Write-Host "  Proxy: ENABLED  ($server)" -ForegroundColor Green
    } else {
        Write-Host "  Proxy: DISABLED" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function proxy-count {
    if (Test-Path $script:PROXY_LIST) {
        $total = (Get-Content $script:PROXY_LIST).Count
        Write-Host "  List: $total proxies" -ForegroundColor Cyan
    }
    if (Test-Path $script:PROXY_OK) {
        $ok = (Get-Content $script:PROXY_OK).Count
        Write-Host "  Working: $ok proxies" -ForegroundColor Green
    }
}