# ARGONOV SHELL · hacktool (OSINT multi-tool)

# ─── IP ───
function scan-ip {
    param([string]$IP = "")
    if (-not $IP) {
        try {
            $IP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5).Trim()
            Write-Host "  Твой внешний IP: $IP" -ForegroundColor DarkGray
        } catch {
            Write-Host "  Не удалось определить внешний IP" -ForegroundColor Red
            return
        }
    }
    Write-Host ""
    Write-Host "  Scanning $IP ..." -ForegroundColor Yellow
    try {
        $r = Invoke-RestMethod -Uri "http://ip-api.com/json/$IP?fields=status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,query" -TimeoutSec 8
    } catch {
        Write-Host "  API error: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    if ($r.status -ne "success") {
        Write-Host "  Не удалось: $($r.message)" -ForegroundColor Red
        return
    }
    Write-Host ""
    Write-Host "  -----------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  IP:        " -NoNewline -ForegroundColor Yellow
    Write-Host $r.query -ForegroundColor White
    Write-Host "  Страна:    " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.country) ($($r.countryCode))" -ForegroundColor White
    Write-Host "  Регион:    " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.regionName)" -ForegroundColor White
    Write-Host "  Город:     " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.city)  $($r.zip)" -ForegroundColor White
    Write-Host "  Коорд.:    " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.lat), $($r.lon)" -ForegroundColor Cyan
    Write-Host "  TZ:        " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.timezone)" -ForegroundColor White
    Write-Host "  Провайдер: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.isp)" -ForegroundColor White
    Write-Host "  Орг:       " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.org)" -ForegroundColor White
    Write-Host "  ASN:       " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.as)" -ForegroundColor White
    Write-Host "  -----------------------------------------" -ForegroundColor DarkCyan
    Write-Host ""
}

# ─── DNS ───
function scan-dns {
    param([Parameter(Mandatory)][string]$Domain)
    Write-Host ""
    Write-Host "  DNS для ${Domain}:" -ForegroundColor Yellow
    Write-Host "  -----------------------------------------" -ForegroundColor DarkCyan
    $types = @("A", "AAAA", "MX", "NS", "TXT", "SOA", "CNAME")
    foreach ($t in $types) {
        try {
            $res = Resolve-DnsName -Name $Domain -Type $t -ErrorAction Stop
            foreach ($r in $res) {
                $val = $r.IPAddress
                if (-not $val) { $val = $r.NameHost }
                if (-not $val) { $val = $r.NameExchange }
                if (-not $val) { $val = $r.Name }
                if (-not $val) { $val = $r.PrimaryServer }
                if (-not $val) { $val = $r.Text }
                if ($val) {
                    Write-Host "  $($t.PadRight(6)) " -NoNewline -ForegroundColor Cyan
                    Write-Host $val -ForegroundColor White
                }
            }
        } catch {}
    }
    Write-Host ""
    Write-Host "  Безопасность:" -ForegroundColor Yellow
    try {
        $txt = (Resolve-DnsName -Name $Domain -Type TXT -ErrorAction SilentlyContinue |
                Where-Object { $_.Text -match "v=spf1" }).Text
        if ($txt) { Write-Host "  OK SPF:   " -NoNewline -ForegroundColor Green; Write-Host $txt -ForegroundColor Gray }
        else      { Write-Host "  -- SPF:   отсутствует" -ForegroundColor Red }
    } catch {}
    try {
        $dmarc = (Resolve-DnsName -Name "_dmarc.$Domain" -Type TXT -ErrorAction SilentlyContinue).Text
        if ($dmarc) { Write-Host "  OK DMARC: " -NoNewline -ForegroundColor Green; Write-Host $dmarc -ForegroundColor Gray }
        else        { Write-Host "  -- DMARC: отсутствует" -ForegroundColor Red }
    } catch {}
    Write-Host "  -----------------------------------------" -ForegroundColor DarkCyan
    Write-Host ""
}

# ─── WHOIS / RDAP ───
function scan-whois {
    param([Parameter(Mandatory)][string]$Domain)

    $inputDomain = $Domain.Trim().TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($inputDomain)) {
        Write-Host "  Укажи доменное имя: scan-whois example.com" -ForegroundColor Yellow
        return
    }

    try {
        $idn = [System.Globalization.IdnMapping]::new()
        $queryDomain = $idn.GetAscii($inputDomain).ToLowerInvariant()
    } catch {
        Write-Host "  Некорректное доменное имя: $inputDomain" -ForegroundColor Red
        return
    }

    if ([uri]::CheckHostName($queryDomain) -ne [System.UriHostNameType]::Dns -or $queryDomain -notmatch '\.') {
        Write-Host "  Некорректное доменное имя: $inputDomain" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "  WHOIS / RDAP для $queryDomain:" -ForegroundColor Yellow
    Write-Host "  -----------------------------------------" -ForegroundColor DarkCyan

    # Keep support for a classic WHOIS client when the user already has one.
    $whoisCommand = Get-Command whois.exe -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($whoisCommand) {
        $whoisOutput = @(& $whoisCommand.Source $queryDomain 2>&1)
        $filteredOutput = @($whoisOutput | Select-String -Pattern 'Registrar:|Creation Date:|Registry Expiry|Name Server:|Registrant|Domain Status')
        if ($filteredOutput.Count -gt 0) {
            $filteredOutput | Select-Object -First 24 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Gray
            }
        } else {
            $whoisOutput | Select-Object -First 16 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Gray
            }
        }
        Write-Host ""
        return
    }

    # RDAP is the standardized, machine-readable successor to WHOIS.
    # rdap.org redirects the query to the authoritative registry service.
    try {
        $rdapUrl = 'https://rdap.org/domain/' + [uri]::EscapeDataString($queryDomain)
        $rdap = Invoke-RestMethod -Uri $rdapUrl -Headers @{
            Accept = 'application/rdap+json, application/json'
            'User-Agent' = 'ARGONOV-SHELL/1.0'
        } -TimeoutSec 20 -ErrorAction Stop

        if (-not $rdap.ldhName) {
            throw 'RDAP response did not contain a domain name.'
        }

        Write-Host ("  Домен:     {0}" -f $rdap.ldhName) -ForegroundColor White

        $registrarEntity = @($rdap.entities | Where-Object { @($_.roles) -contains 'registrar' } |
            Select-Object -First 1)
        if ($registrarEntity.Count -gt 0 -and $registrarEntity[0].vcardArray.Count -ge 2) {
            $registrarName = @($registrarEntity[0].vcardArray[1] | Where-Object {
                $_ -is [array] -and $_.Count -ge 4 -and $_[0] -in @('fn','org')
            } | ForEach-Object { [string]$_.Item(3) } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -First 1)
            if ($registrarName.Count -gt 0) {
                Write-Host ("  Регистратор: {0}" -f $registrarName[0]) -ForegroundColor Gray
            }
        }

        $eventLabels = @{
            registration = 'Регистрация'
            expiration = 'Истечение срока'
            'last changed' = 'Последнее изменение'
            transfer = 'Передача'
        }
        foreach ($event in @($rdap.events)) {
            if ($event.eventAction -in $eventLabels.Keys -and $event.eventDate) {
                Write-Host ("  {0}: {1}" -f $eventLabels[$event.eventAction], $event.eventDate) -ForegroundColor Gray
            }
        }

        $statuses = @($rdap.status | Where-Object { $_ })
        if ($statuses.Count -gt 0) {
            Write-Host ("  Статус: {0}" -f ($statuses -join ', ')) -ForegroundColor Gray
        }

        $nameServers = @($rdap.nameservers | ForEach-Object { $_.ldhName } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 12)
        if ($nameServers.Count -gt 0) {
            Write-Host "  DNS-серверы:" -ForegroundColor Cyan
            foreach ($nameServer in $nameServers) {
                Write-Host ("    {0}" -f $nameServer) -ForegroundColor Gray
            }
        }

        if ($nameServers.Count -eq 0 -and $statuses.Count -eq 0 -and $rdap.events.Count -eq 0) {
            Write-Host "  RDAP-сервер вернул запись, но публичные регистрационные поля скрыты." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host ("  Не удалось получить регистрационные данные: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host "  Проверь домен и подключение к интернету." -ForegroundColor DarkGray
    }

    Write-Host ""
}

# ─── PORTS ───
function scan-ports {
    param(
        [Parameter(Mandatory)][string]$Host_,
        [string]$Ports = "21,22,23,25,53,80,110,143,443,445,3306,3389,5432,6379,8080,8443,27017"
    )
    $Host_ = $Host_.Trim()
    Write-Host ""
    Write-Host "  Скан портов для ${Host_}:" -ForegroundColor Yellow
    Write-Host "  -----------------------------------------" -ForegroundColor DarkCyan
    $portList = $Ports -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $open = @()
    foreach ($p in $portList) {
        $port = [int]$p
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $client.ReceiveTimeout = 800
            $client.SendTimeout = 800
            $task = $client.ConnectAsync($Host_, $port)
            if ($task.Wait(800) -and $client.Connected) {
                Write-Host "  OK $($p.PadRight(6)) " -NoNewline -ForegroundColor Green
                Write-Host "OPEN" -ForegroundColor White
                $open += $port
            }
            $client.Close()
        } catch {}
    }
    Write-Host ""
    if ($open.Count -gt 0) {
        Write-Host "  Открыто: $($open.Count)" -ForegroundColor Cyan
    } else {
        Write-Host "  Открытых не найдено" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ─── HASHES ───
function hash-text {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ""
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $md5    = [System.BitConverter]::ToString([System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)).Replace("-","").ToLower()
    $sha1   = [System.BitConverter]::ToString([System.Security.Cryptography.SHA1]::Create().ComputeHash($bytes)).Replace("-","").ToLower()
    $sha256 = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)).Replace("-","").ToLower()
    Write-Host "  MD5:    " -NoNewline -ForegroundColor Cyan
    Write-Host $md5 -ForegroundColor White
    Write-Host "  SHA1:   " -NoNewline -ForegroundColor Cyan
    Write-Host $sha1 -ForegroundColor White
    Write-Host "  SHA256: " -NoNewline -ForegroundColor Cyan
    Write-Host $sha256 -ForegroundColor White
    Write-Host ""
}

function hash-file {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "  Файл не найден: $Path" -ForegroundColor Red
        return
    }
    Write-Host ""
    Write-Host "  Файл: $Path" -ForegroundColor Yellow
    Write-Host "  Размер: $([math]::Round((Get-Item $Path).Length/1KB, 2)) KB" -ForegroundColor DarkGray
    $h1 = (Get-FileHash $Path -Algorithm MD5).Hash.ToLower()
    $h2 = (Get-FileHash $Path -Algorithm SHA1).Hash.ToLower()
    $h3 = (Get-FileHash $Path -Algorithm SHA256).Hash.ToLower()
    Write-Host "  MD5:    " -NoNewline -ForegroundColor Cyan
    Write-Host $h1 -ForegroundColor White
    Write-Host "  SHA1:   " -NoNewline -ForegroundColor Cyan
    Write-Host $h2 -ForegroundColor White
    Write-Host "  SHA256: " -NoNewline -ForegroundColor Cyan
    Write-Host $h3 -ForegroundColor White
    Write-Host ""
}

function hash-identify {
    param([Parameter(Mandatory)][string]$Hash)
    $h = $Hash.Trim()
    $len = $h.Length
    $isHex    = $h -match '^[0-9a-fA-F]+$'
    $isBase64 = $h -match '^[A-Za-z0-9+/=]+$'
    Write-Host ""
    Write-Host "  Hash identification" -ForegroundColor Yellow
    Write-Host "  Длина: $len, Hex: $isHex, Base64: $isBase64" -ForegroundColor DarkGray
    Write-Host ""
    $types = @()
    if ($isHex) {
        switch ($len) {
            16  { $types += "MySQL (OLD), DES (Unix)" }
            32  { $types += "MD5, NTLM, LM, MD4" }
            40  { $types += "SHA-1, MySQL5, RIPEMD-160" }
            56  { $types += "SHA-224" }
            64  { $types += "SHA-256, Blake2s, Keccak-256" }
            96  { $types += "SHA-384" }
            128 { $types += "SHA-512, Whirlpool" }
            default { $types += "Неизвестный hex-хэш ($len символов)" }
        }
    }
    if ($isBase64 -and -not $isHex) {
        if ($len -eq 60 -and $h -match '^\$2[aby]\$') { $types += "bcrypt" }
        elseif ($len -eq 24) { $types += "crypt (DES), bcrypt (краткий)" }
        else { $types += "Возможно Base64 ($len символов)" }
    }
    if (-not $types) { $types += "Не удалось определить" }
    foreach ($t in $types) { Write-Host "  -> $t" -ForegroundColor Green }
    Write-Host ""
}

# ─── PASSWORD ───
function hack-pass {
    param([int]$Length = 20)
    if ($Length -lt 4)   { $Length = 4 }
    if ($Length -gt 128) { $Length = 128 }
    $alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{};:,.<>?"
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $chars = @()
    for ($i = 0; $i -lt $Length; $i++) {
        $chars += $alphabet[$bytes[$i] % $alphabet.Length]
    }
    $pass = -join $chars
    Write-Host ""
    Write-Host "  Новый пароль ($Length символов):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  $pass" -ForegroundColor Green
    Write-Host ""
    try {
        Set-Clipboard -Value $pass
        Write-Host "  Скопирован в буфер обмена" -ForegroundColor DarkGray
    } catch {}
    Write-Host ""
}

# ─── QR (локально, без внешнего API) ───
function hack-qr {
    $text = ($args -join " ").Trim()
    if (-not $text) {
        Write-Host "  Использование: hack-qr <текст или URL>" -ForegroundColor Yellow
        return
    }

    # Prefer the interpreter installed and verified by the ARGONOV bootstrap.
    $dependencyRoot = if ($env:ARGONOV_DEPENDENCY_ROOT) {
        $env:ARGONOV_DEPENDENCY_ROOT
    } else {
        Join-Path $env:LOCALAPPDATA 'Programs\ARGONOV-Dependencies'
    }
    $pythonExe = Join-Path $dependencyRoot 'Python314\python.exe'
    if (-not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
        $launcher = Get-Command py.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($launcher) {
            $pythonExe = $launcher.Source
            $pythonArgs = @('-3.14')
        } else {
            $pythonExe = Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
            $pythonArgs = @()
        }
    } else {
        $pythonArgs = @()
    }
    if (-not $pythonExe -or -not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
        Write-Host "  Python 3.14 не найден. Повтори установку компонента Python через ARGONOV Setup." -ForegroundColor Red
        return
    }

    # Load QR packages from the isolated ARGONOV dependency directory.
    $pythonPackagesRoot = Join-Path $dependencyRoot 'PythonPackages'
    if (Test-Path -LiteralPath $pythonPackagesRoot -PathType Container) {
        $env:PYTHONPATH = if ($env:PYTHONPATH) { "$pythonPackagesRoot;$env:PYTHONPATH" } else { $pythonPackagesRoot }
    }
    & $pythonExe @pythonArgs -c "import qrcode; from PIL import Image" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Модули qrcode/Pillow не установлены. Повтори установку компонента Python через ARGONOV Setup." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "  QR для: $text" -ForegroundColor Yellow
    Write-Host ""

    # Папка для сохранения
    $qrDir = Join-Path (Get-PicturesPath) "ARGONOV QR"
    if (-not (Test-Path $qrDir)) {
        New-Item -ItemType Directory -Force -Path $qrDir | Out-Null
    }
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $pngPath = Join-Path $qrDir "qr_$stamp.png"

    # Python-скрипт: рисует ASCII QR и сохраняет PNG
    $pyScript = @"
import sys
import qrcode

text = sys.argv[1]
png_path = sys.argv[2]

qr = qrcode.QRCode(border=1, box_size=1)
qr.add_data(text)
qr.make(fit=True)

# ASCII в терминал — используем пробел и Unicode full block
matrix = qr.get_matrix()
for row in matrix:
    line = []
    for cell in row:
        if cell:
            line.append('██')
        else:
            line.append('  ')
    print('  ' + ''.join(line))
print()

# Сохраняем PNG отдельно
qr2 = qrcode.QRCode(border=4, box_size=10)
qr2.add_data(text)
qr2.make(fit=True)
img = qr2.make_image(fill_color='black', back_color='white')
img.save(png_path)
print(f'  PNG: {png_path}')
"@

    # Записываем скрипт во временный файл
    $tmp = [System.IO.Path]::GetTempFileName() + ".py"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tmp, $pyScript, $utf8NoBom)

    try {
        & $pythonExe @pythonArgs $tmp $text $pngPath
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
}

# ─── SHORT URL ───
function hack-short {
    $url = ($args -join " ").Trim()
    if (-not $url) {
        Write-Host "  Использование: hack-short <URL>" -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "  Сокращаю: $url" -ForegroundColor Yellow
    try {
        $encoded = [uri]::EscapeDataString($url)
        $short = Invoke-RestMethod -Uri "https://tinyurl.com/api-create.php?url=$encoded" -TimeoutSec 10
        Write-Host "  -> $short" -ForegroundColor Green
        try {
            Set-Clipboard -Value $short.Trim()
            Write-Host "  Скопирован в буфер" -ForegroundColor DarkGray
        } catch {}
    } catch {
        Write-Host "  Ошибка: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# ─── HELP ───
function hack-help {
    Write-Host ""
    Write-Host "  OSINT Multi-Tool" -ForegroundColor Cyan
    Write-Host "  -----------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  Разведка:" -ForegroundColor Yellow
    Write-Host "    scan-ip [IP]           IP-геолокация" -ForegroundColor Gray
    Write-Host "    scan-dns <домен>       DNS + SPF/DMARC" -ForegroundColor Gray
    Write-Host "    scan-whois <домен>     WHOIS" -ForegroundColor Gray
    Write-Host "    scan-ports <хост>      Быстрый скан портов" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Крипто:" -ForegroundColor Yellow
    Write-Host "    hash-text <текст>      MD5/SHA1/SHA256" -ForegroundColor Gray
    Write-Host "    hash-file <файл>       Хэши файла" -ForegroundColor Gray
    Write-Host "    hash-identify <хэш>    Определить тип" -ForegroundColor Gray
    Write-Host "    hack-pass [длина]      Генератор паролей" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Утилиты:" -ForegroundColor Yellow
    Write-Host "    hack-qr <текст/URL>    QR-код (локально)" -ForegroundColor Gray
    Write-Host "    hack-short <URL>       Сократить ссылку" -ForegroundColor Gray
    Write-Host "    hack-help              Эта справка" -ForegroundColor Gray
    Write-Host "  -----------------------------------------" -ForegroundColor DarkCyan
    Write-Host ""
}

Set-Alias -Name "hack" -Value "hack-help" -Force