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

# ARGONOV_SAFE_WGET_PATCH_07
# Deliberately overrides the built-in wget alias so the documented shell command resolves here.
Remove-Item -Path Alias:\wget -Force -ErrorAction SilentlyContinue

function wget {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$Out = '',
        [switch]$Force,
        [ValidateRange(1, 600)][int]$TimeoutSec = 30
    )

    $parsedUri = $null
    if (-not [System.Uri]::TryCreate($Url.Trim(), [System.UriKind]::Absolute, [ref]$parsedUri) -or
        $parsedUri.Scheme -notin @('http', 'https')) {
        Write-Host '  Error: only absolute HTTP and HTTPS URLs are supported.' -ForegroundColor Red
        return
    }

    if ([string]::IsNullOrWhiteSpace($Out)) {
        $lastSegment = $parsedUri.AbsolutePath.TrimEnd('/').Split('/')[-1]
        try { $fileName = [System.Uri]::UnescapeDataString($lastSegment) }
        catch {
            Write-Host '  Error: could not determine a safe filename from the URL; specify -Out.' -ForegroundColor Red
            return
        }
        if ([string]::IsNullOrWhiteSpace($fileName) -or $fileName -in @('.', '..') -or $fileName -match '[\\/:*?"<>|\x00-\x1F]') {
            Write-Host '  Error: URL has no safe filename; specify -Out with a destination file.' -ForegroundColor Red
            return
        }
        $Out = $fileName
    }

    try {
        # .NET GetFullPath(relativePath) uses the process working directory, which can
        # differ from PowerShell's current provider location after Set-Location/Push-Location.
        # Resolve relative destinations against PowerShell's current filesystem location.
        $currentLocation = Get-Location
        if ($currentLocation.Provider.Name -ne 'FileSystem' -or [string]::IsNullOrWhiteSpace($currentLocation.ProviderPath)) {
            throw 'The current location is not a filesystem directory.'
        }
        $pathToResolve = if ([System.IO.Path]::IsPathRooted($Out)) {
            $Out
        } else {
            Join-Path -Path $currentLocation.ProviderPath -ChildPath $Out
        }
        $targetPath = [System.IO.Path]::GetFullPath($pathToResolve)
    } catch {
        Write-Host "  Error: invalid destination path: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    $targetDirectory = [System.IO.Path]::GetDirectoryName($targetPath)
    if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
        Write-Host "  Error: destination directory does not exist: $targetDirectory" -ForegroundColor Red
        return
    }
    if (Test-Path -LiteralPath $targetPath -PathType Container) {
        Write-Host '  Error: destination path is a directory, not a file.' -ForegroundColor Red
        return
    }
    if ((Test-Path -LiteralPath $targetPath -PathType Leaf) -and -not $Force) {
        Write-Host "  Error: destination already exists: $targetPath. Use -Force to overwrite it." -ForegroundColor Yellow
        return
    }

    if (-not $PSCmdlet.ShouldProcess($targetPath, "Download $($parsedUri.AbsoluteUri)")) { return }

    # Download to a temporary file beside the destination; only move it into place after success.
    $temporaryPath = Join-Path $targetDirectory ('.argonov-download-{0}.tmp' -f [guid]::NewGuid().ToString('N'))
    try {
        Write-Host "  Downloading $($parsedUri.AbsoluteUri)" -ForegroundColor Yellow
        Invoke-WebRequest -Uri $parsedUri.AbsoluteUri -OutFile $temporaryPath -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
            throw 'The request completed but did not produce a download file.'
        }
        if ((Test-Path -LiteralPath $targetPath -PathType Leaf) -and -not $Force) {
            throw "Destination appeared during download; refusing to overwrite it: $targetPath"
        }
        Move-Item -LiteralPath $temporaryPath -Destination $targetPath -Force:$Force -ErrorAction Stop
        $size = (Get-Item -LiteralPath $targetPath -ErrorAction Stop).Length
        Write-Host "  Saved: $targetPath  ($([math]::Round($size / 1KB, 1)) KB)" -ForegroundColor Green
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
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