# ARGONOV SHELL · hacktool (OSINT multi-tool)

# ─── ПРОВЕРКА ЗАВИСИМОСТЕЙ ───
function Test-HacktoolDeps {
    $deps = @(
        @{ Name = "nmap";  Cmd = "nmap";  Hint = "winget install --id Insecure.Nmap" },
        @{ Name = "whois"; Cmd = "whois"; Hint = "Скачай с https://learn.microsoft.com/sysinternals/downloads/whois" }
    )
    $missing = @()
    foreach ($d in $deps) {
        if (-not (Get-Command $d.Cmd -ErrorAction SilentlyContinue)) {
            $missing += $d
        }
    }
    return $missing
}

# ─── IP-РАЗВЕДКА ───
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
        Write-Host "  Не удалось получить данные: $($r.message)" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  🌐 IP:        " -NoNewline -ForegroundColor Yellow
    Write-Host $r.query -ForegroundColor White
    Write-Host "  🏳  Страна:    " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.country) ($($r.countryCode))" -ForegroundColor White
    Write-Host "  🏙  Регион:    " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.regionName)" -ForegroundColor White
    Write-Host "  📍 Город:      " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.city)  $($r.zip)" -ForegroundColor White
    Write-Host "  🧭 Координаты: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.lat), $($r.lon)" -ForegroundColor Cyan
    Write-Host "  ⏰ TZ:         " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.timezone)" -ForegroundColor White
    Write-Host "  📡 Провайдер:  " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.isp)" -ForegroundColor White
    Write-Host "  🏢 Орг:        " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.org)" -ForegroundColor White
    Write-Host "  🔢 ASN:        " -NoNewline -ForegroundColor Yellow
    Write-Host "$($r.as)" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""
}

# ─── DNS-РАЗВЕДКА ───
function scan-dns {
    param([Parameter(Mandatory)][string]$Domain)

    Write-Host ""
    Write-Host "  DNS для ${Domain}:" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan

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
        } catch {
            # тип отсутствует — молча пропускаем
        }
    }

    Write-Host ""
    Write-Host "  Безопасность:" -ForegroundColor Yellow
    try {
        $txt = (Resolve-DnsName -Name $Domain -Type TXT -ErrorAction SilentlyContinue |
                Where-Object { $_.Text -match "v=spf1" }).Text
        if ($txt) { Write-Host "  ✓ SPF:    " -NoNewline -ForegroundColor Green; Write-Host $txt -ForegroundColor Gray }
        else      { Write-Host "  ✗ SPF:    отсутствует" -ForegroundColor Red }
    } catch {}
    try {
        $dmarc = (Resolve-DnsName -Name "_dmarc.$Domain" -Type TXT -ErrorAction SilentlyContinue).Text
        if ($dmarc) { Write-Host "  ✓ DMARC:  " -NoNewline -ForegroundColor Green; Write-Host $dmarc -ForegroundColor Gray }
        else        { Write-Host "  ✗ DMARC:  отсутствует" -ForegroundColor Red }
    } catch {}
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""
}

# ─── WHOIS ───
function scan-whois {
    param([Parameter(Mandatory)][string]$Domain)

    if (-not (Get-Command whois -ErrorAction SilentlyContinue)) {
        Write-Host "  whois не установлен" -ForegroundColor Red
        Write-Host "  Скачай: https://learn.microsoft.com/sysinternals/downloads/whois" -ForegroundColor DarkGray
        return
    }
    Write-Host ""
    Write-Host "  WHOIS для ${Domain}:" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
    & whois $Domain 2>&1 | Select-String -Pattern "Registrar:|Creation Date:|Registry Expiry|Name Server:|Registrant" | Select-Object -First 20 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""
}

# ─── СКАН ПОРТОВ ───
function scan-ports {
    param(
        [Parameter(Mandatory)][string]$Host_,
        [string]$Ports = "21,22,23,25,53,80,110,143,443,445,3306,3389,5432,6379,8080,8443,27017"
    )

    $Host_ = $Host_.Trim()

    Write-Host ""
    Write-Host "  Быстрый скан портов для ${Host_}:" -ForegroundColor Yellow
    Write-Host "  (socket-based, быстро, без nmap)" -ForegroundColor DarkGray
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan

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
                Write-Host "  ✓ $($p.PadRight(6)) " -NoNewline -ForegroundColor Green
                Write-Host "OPEN" -ForegroundColor White
                $open += $port
            }
            $client.Close()
        } catch {}
    }

    Write-Host ""
    if ($open.Count -gt 0) {
        Write-Host "  Открыто: $($open.Count) портов" -ForegroundColor Cyan
    } else {
        Write-Host "  Открытых портов не найдено" -ForegroundColor DarkGray
    }
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""
}

# ─── ХЭШИ ───
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

    foreach ($t in $types) {
        Write-Host "  → $t" -ForegroundColor Green
    }
    Write-Host ""
}

# ─── ПАРОЛЬ ───
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
    Write-Host "  🎲 Новый пароль ($Length символов):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  $pass" -ForegroundColor Green
    Write-Host ""
    try {
        Set-Clipboard -Value $pass
        Write-Host "  Скопирован в буфер обмена" -ForegroundColor DarkGray
    } catch {}
    Write-Host ""
}

# ─── QR-КОД ───
function hack-qr {
    param([Parameter(Mandatory)][string]$Text)

    $encoded = [uri]::EscapeDataString($Text)
    $url = "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=$encoded"

    Write-Host ""
    Write-Host "  QR-код для: $Text" -ForegroundColor Yellow
    Write-Host "  URL: $url" -ForegroundColor DarkGray
    Write-Host ""
    Start-Process $url
    Write-Host "  Открыто в браузере. Сохрани картинку вручную (правый клик → Сохранить)." -ForegroundColor DarkGray
    Write-Host ""
}

# ─── СОКРАЩЕНИЕ URL ───
function hack-short {
    param([Parameter(Mandatory)][string]$Url)

    Write-Host ""
    Write-Host "  Сокращаю: $Url" -ForegroundColor Yellow
    try {
        $short = Invoke-RestMethod -Uri "https://tinyurl.com/api-create.php?url=$([uri]::EscapeDataString($Url))" -TimeoutSec 10
        Write-Host "  → $short" -ForegroundColor Green
        try {
            Set-Clipboard -Value $short.Trim()
            Write-Host "  Скопирован в буфер" -ForegroundColor DarkGray
        } catch {}
    } catch {
        Write-Host "  Ошибка: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# ─── СПРАВКА ───
function hack-help {
    Write-Host ""
    Write-Host "  OSINT Multi-Tool" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  Разведка:" -ForegroundColor Yellow
    Write-Host "    scan-ip [IP]           IP-геолокация" -ForegroundColor Gray
    Write-Host "    scan-dns <домен>       DNS-записи + SPF/DMARC" -ForegroundColor Gray
    Write-Host "    scan-whois <домен>     WHOIS (Sysinternals)" -ForegroundColor Gray
    Write-Host "    scan-ports <хост>      Быстрый скан портов" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Крипто:" -ForegroundColor Yellow
    Write-Host "    hash-text <текст>      MD5/SHA1/SHA256" -ForegroundColor Gray
    Write-Host "    hash-file <файл>       Хэши файла" -ForegroundColor Gray
    Write-Host "    hash-identify <хэш>    Определить тип" -ForegroundColor Gray
    Write-Host "    hack-pass [длина]      Сгенерировать пароль" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Утилиты:" -ForegroundColor Yellow
    Write-Host "    hack-qr <текст>        QR-код (браузер)" -ForegroundColor Gray
    Write-Host "    hack-short <url>       Сократить ссылку" -ForegroundColor Gray
    Write-Host "    hack-help              Эта справка" -ForegroundColor Gray
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""
}

Set-Alias -Name "hack" -Value "hack-help" -Force