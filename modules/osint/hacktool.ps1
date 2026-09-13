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

# ─── WHOIS ───
function scan-whois {
    param([Parameter(Mandatory)][string]$Domain)
    if (-not (Get-Command whois -ErrorAction SilentlyContinue)) {
        Write-Host "  whois не установлен" -ForegroundColor Red
        return
    }
    Write-Host ""
    Write-Host "  WHOIS для ${Domain}:" -ForegroundColor Yellow
    Write-Host "  -----------------------------------------" -ForegroundColor DarkCyan
    & whois $Domain 2>&1 | Select-String -Pattern "Registrar:|Creation Date:|Registry Expiry|Name Server:|Registrant" | Select-Object -First 20 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
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

    # Проверка Python
    $py = Get-Command py -ErrorAction SilentlyContinue
    if (-not $py) {
        Write-Host "  Python не найден" -ForegroundColor Red
        return
    }

    # Проверка библиотеки qrcode
    $check = & py -3.14 -c "import qrcode" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Библиотека qrcode не установлена" -ForegroundColor Yellow
        Write-Host "  Установи: py -3.14 -m pip install qrcode" -ForegroundColor Cyan
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
        & py -3.14 $tmp $text $pngPath
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