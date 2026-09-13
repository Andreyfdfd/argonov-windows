# ARGONOV SHELL · proxy

$script:PROXY_DIR  = "$HOME\.argonov-proxy"
$script:PROXY_LIST = "$script:PROXY_DIR\list.txt"
$script:PROXY_OK   = "$script:PROXY_DIR\working.txt"

if (-not (Test-Path $script:PROXY_DIR)) {
    New-Item -ItemType Directory -Force -Path $script:PROXY_DIR | Out-Null
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
    param([Parameter(Mandatory)][int]$Index = 1)

    if (-not (Test-Path $script:PROXY_OK)) {
        Write-Host "  No tested proxies. Run proxy-test first." -ForegroundColor Red
        return
    }

    $lines = Get-Content $script:PROXY_OK -Encoding UTF8
    if ($Index -lt 1 -or $Index -gt $lines.Count) {
        Write-Host "  Index out of range (1..$($lines.Count))" -ForegroundColor Red
        return
    }

    $line = $lines[$Index - 1]
    $proxyRaw = ($line -split " \| ")[0]

    if ($proxyRaw -match '^socks5://') {
        Write-Host "  SOCKS5 не работает как системный прокси Windows." -ForegroundColor Yellow
        Write-Host "  Используй HTTP-прокси (из списка http://)." -ForegroundColor DarkGray
        return
    }

    $addr = $proxyRaw -replace '^http://',''
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty -Path $key -Name ProxyEnable  -Value 1
    Set-ItemProperty -Path $key -Name ProxyServer  -Value $addr
    Set-ItemProperty -Path $key -Name ProxyOverride -Value "<local>"

    Write-Host "  System proxy set to: $addr" -ForegroundColor Green
    Write-Host "  Проверь: curl.exe https://api.ipify.org" -ForegroundColor DarkGray
}

function proxy-clear {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty -Path $key -Name ProxyEnable -Value 0
    Write-Host "  System proxy disabled" -ForegroundColor Green
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