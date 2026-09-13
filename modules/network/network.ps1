# ARGONOV SHELL · network

function myip {
    try {
        $r = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 5
        Write-Host "  External IP: " -NoNewline -ForegroundColor Yellow
        Write-Host $r.ip -ForegroundColor Cyan
    } catch {
        Write-Host "  No connection" -ForegroundColor Red
    }
}

function localip {
    $ips = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" } |
        Select-Object IPAddress, InterfaceAlias
    $ips | Format-Table -AutoSize
}

function ping-http {
    param([Parameter(Mandatory)][string]$Url)
    try {
        $t0 = Get-Date
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        $ms = [math]::Round(((Get-Date) - $t0).TotalMilliseconds)
        Write-Host "  OK  " -NoNewline -ForegroundColor Green
        Write-Host "$Url " -NoNewline -ForegroundColor White
        Write-Host "HTTP $($r.StatusCode)  |  $ms ms" -ForegroundColor Cyan
    } catch {
        Write-Host "  ERR $Url  -  $($_.Exception.Message)" -ForegroundColor Red
    }
}

function ports {
    param([string]$Filter = "")
    $conns = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
    if ($Filter) {
        $conns = $conns | Where-Object { $_.LocalPort -like "*$Filter*" }
    }
    $conns | Select-Object LocalAddress, LocalPort, OwningProcess,
        @{N='Process';E={(Get-Process -Id $_.OwningProcess -EA SilentlyContinue).ProcessName}} |
        Sort-Object LocalPort | Format-Table -AutoSize
}

function is-port {
    param([Parameter(Mandatory)][int]$Port, [string]$HostName = "127.0.0.1")
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect($HostName, $Port)
        Write-Host "  $HostName`:$Port  OPEN" -ForegroundColor Green
        $client.Close()
    } catch {
        Write-Host "  $HostName`:$Port  closed" -ForegroundColor Red
    }
}

function wget {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$Out = ""
    )
    if (-not $Out) { $Out = Split-Path $Url -Leaf }
    try {
        Write-Host "  Downloading $Url" -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing
        $size = (Get-Item $Out).Length
        Write-Host "  Saved: $Out  ($([math]::Round($size/1KB,1)) KB)" -ForegroundColor Green
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function dns {
    param([Parameter(Mandatory)][string]$Name)
    try {
        Resolve-DnsName -Name $Name -ErrorAction Stop |
            Select-Object Name, Type, IPAddress, NameHost | Format-Table -AutoSize
    } catch {
        Write-Host "  DNS error: $($_.Exception.Message)" -ForegroundColor Red
    }
}