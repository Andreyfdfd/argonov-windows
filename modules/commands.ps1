# ARGONOV SHELL · commands catalog

$script:ARGONOV_CATALOG = @(
    @{ Group='НАВИГАЦИЯ И ФАЙЛЫ'; Items=@(
        @('..  ...  ....  .....', 'вверх по дереву', 'up the tree'),
        @('~ home root',          'домашняя / корень', 'home / drive root'),
        @('up N',                 'вверх на N уровней', 'up N levels'),
        @('mkcd PATH',            'создать папку и войти', 'mkdir and cd'),
        @('ll la',                'список файлов', 'list files'),
        @('touch FILE',           'создать / обновить', 'create / touch'),
        @('sizeof PATH',          'размер папки', 'folder size'),
        @('find-file PATTERN',    'рекурсивный поиск', 'recursive search'),
        @('which CMD',            'где команда', 'command location'),
        @('grep TEXT FILE',       'поиск в файле', 'search in file')
    )},
    @{ Group='СИСТЕМА'; Items=@(
        @('sysinfo',              'информация о ПК', 'system info'),
        @('top',                  'топ процессов по RAM', 'top by RAM'),
        @('psg NAME',             'процессы по имени', 'processes by name'),
        @('pskill NAME',          'убить процесс', 'kill process'),
        @('bigfiles PATH',        'крупные файлы', 'largest files'),
        @('disks',                'все диски', 'all disks'),
        @('env FILTER',           'переменные окружения', 'environment vars'),
        @('path',                 'содержимое PATH', 'PATH entries'),
        @('svc FILTER',           'службы Windows', 'Windows services'),
        @('startup',              'автозагрузка', 'autorun entries'),
        @('cleanup',              'размер temp', 'temp size preview'),
        @('cleanup -Execute',     'очистить temp', 'clean temp'),
        @('uptime',               'аптайм системы', 'system uptime')
    )},
    @{ Group='СЕТЬ'; Items=@(
        @('myip',                 'внешний IP', 'external IP'),
        @('localip',              'локальные IP', 'local IPs'),
        @('ping-http URL',        'проверить URL', 'ping URL'),
        @('dns NAME',             'DNS-запрос', 'DNS lookup'),
        @('ports FILTER',         'занятые порты', 'listening ports'),
        @('is-port N',            'проверить порт', 'check port'),
        @('wget URL',             'скачать файл', 'download file')
    )},
    @{ Group='ПРОКСИ'; Items=@(
        @('proxy-fetch',          'скачать прокси-листы', 'fetch proxy list'),
        @('proxy-test',           'проверить все', 'test all proxies'),
        @('proxy-test-one PROXY', 'проверить один', 'test one proxy'),
        @('proxy-top',            'лучшие прокси', 'top proxies'),
        @('proxy-use N',          'включить прокси #N', 'use proxy #N'),
        @('proxy-clear',          'отключить прокси', 'disable proxy'),
        @('proxy-status',         'текущий статус', 'proxy status'),
        @('proxy-count',          'сколько в списке', 'count proxies')
    )},
    @{ Group='OSINT'; Items=@(
        @('scan-ip [IP]',         'IP-геолокация', 'IP geolocation'),
        @('scan-dns DOMAIN',      'DNS-записи + SPF/DMARC', 'DNS + SPF/DMARC'),
        @('scan-whois DOMAIN',    'WHOIS информация', 'WHOIS lookup'),
        @('scan-ports HOST',      'быстрый скан портов', 'quick port scan'),
        @('hash-text TEXT',       'MD5/SHA1/SHA256 текста', 'text hashes'),
        @('hash-file FILE',       'хэши файла', 'file hashes'),
        @('hash-identify HASH',   'определить тип хэша', 'identify hash type'),
        @('hack-pass [N]',        'генератор паролей', 'password generator'),
        @('hack-qr TEXT',         'QR-код', 'QR code'),
        @('hack-short URL',       'сократить ссылку', 'shorten URL'),
        @('hack',                 'справка OSINT', 'OSINT help')
    )},
    @{ Group='AI'; Items=@(
        @('ai Q',                 'задать вопрос модели', 'ask AI'),
        @('ai -Chat',             'интерактивный чат', 'interactive chat'),
        @('ai -Model NAME',       'выбрать модель', 'select model'),
        @('ai -Reset',            'очистить историю', 'clear history'),
        @('ai -Yolo',             'без подтверждений', 'no confirmations'),
        @('ai -Dry',              'режим предпросмотра', 'dry-run mode'),
        @('ai -List',             'список моделей', 'list models')
    )},
    @{ Group='LM STUDIO'; Items=@(
        @('lm-up',                'загрузить модель в VRAM', 'load model'),
        @('lm-down',              'выгрузить модели', 'unload models'),
        @('lm-status',            'статус сервера', 'server status'),
        @('lm-models',            'список моделей на диске', 'list models on disk')
    )},
    @{ Group='GIT'; Items=@(
        @('gs',                   'git status', 'git status'),
        @('ga .',                 'git add', 'git add'),
        @('gc MSG',               'git commit', 'git commit'),
        @('gp',                   'git push', 'git push'),
        @('gpl',                  'git pull', 'git pull'),
        @('gd',                   'git diff', 'git diff'),
        @('gl',                   'красивая история', 'git log (graph)'),
        @('gb',                   'список веток', 'git branch'),
        @('gco BRANCH',           'переключить ветку', 'git checkout'),
        @('gcl URL',              'клонировать репо', 'git clone'),
        @('git-branch',           'текущая ветка', 'current branch'),
        @('git-dirty',            'есть ли изменения', 'uncommitted changes')
    )},
    @{ Group='СКРИНШОТЫ'; Items=@(
        @('screenshot',           'снимок всего экрана', 'full screen shot'),
        @('screenshot-window',    'снимок активного окна', 'window shot'),
        @('screenshot-list',      'список последних', 'list shots'),
        @('screenshot-folder',    'открыть папку', 'open folder'),
        @('screenshot-clean [N]', 'удалить старые', 'clean old shots')
    )},
    @{ Group='BACKUP'; Items=@(
        @('backup [метка]',       'резервная копия', 'create backup'),
        @('backup-list',          'список архивов', 'list backups'),
        @('backup-restore',       'восстановить', 'restore backup'),
        @('backup-delete',        'удалить архив', 'delete backup')
    )},
    @{ Group='CAD/CAM'; Items=@(
        @('cad',                  'краткая подсказка', 'short help'),
        @('cad list',             'что установлено', 'list installed'),
        @('cad kompas',           'запустить программу', 'launch app'),
        @('cad-files [путь]',     'найти проекты', 'find projects'),
        @('cad-open FILE',        'открыть проект', 'open project')
    )},
    @{ Group='РАЗВЛЕЧЕНИЯ'; Items=@(
        @('matrix',               'цифровой дождь (30 FPS)', 'digital rain'),
        @('м',                    'то же (кириллица)', 'same (cyrillic)'),
        @('matrix-fast',          'быстрая (45 FPS)', 'fast (45 FPS)'),
        @('matrix-slow',          'медленная (12 FPS)', 'slow (12 FPS)'),
        @('matrix-long',          'длинные хвосты', 'long tails'),
        @('matrix-wide',          'CJK-набор', 'wide charset')
    )},
    @{ Group='СПРАВКА'; Items=@(
        @('info',                 'полная справка по командам', 'full help'),
        @('commands',             'этот список', 'this list'),
        @('commands -Ru',         'только русский', 'russian only'),
        @('commands -En',         'только английский', 'english only')
    )}
)

function Show-ArgonovCommands {
    param(
        [switch]$Ru,
        [switch]$En
    )

    $showRu = $true
    $showEn = $true
    if ($Ru -and -not $En) { $showEn = $false }
    if ($En -and -not $Ru) { $showRu = $false }

    $total = 0
    foreach ($g in $script:ARGONOV_CATALOG) { $total += $g.Items.Count }

    Write-Host ""
    Write-Host "  ⚡ ARGONOV SHELL" -NoNewline -ForegroundColor Cyan
    Write-Host "  ·  " -NoNewline -ForegroundColor DarkGray
    Write-Host "$total команд" -NoNewline -ForegroundColor White
    Write-Host "  ·  " -NoNewline -ForegroundColor DarkGray
    Write-Host "PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    Write-Host ""

    foreach ($g in $script:ARGONOV_CATALOG) {
        Write-Host "  ▬ $($g.Group)" -ForegroundColor Magenta
        foreach ($item in $g.Items) {
            $cmd     = $item[0]
            $descRu  = $item[1]
            $descEn  = $item[2]
            $line = "    " + $cmd.PadRight(28)

            if ($showRu -and $showEn) {
                Write-Host $line -NoNewline -ForegroundColor Yellow
                Write-Host $descRu -NoNewline -ForegroundColor Gray
                Write-Host "  ($descEn)" -ForegroundColor DarkGray
            }
            elseif ($showRu) {
                Write-Host $line -NoNewline -ForegroundColor Yellow
                Write-Host $descRu -ForegroundColor Gray
            }
            else {
                Write-Host $line -NoNewline -ForegroundColor Yellow
                Write-Host $descEn -ForegroundColor Gray
            }
        }
        Write-Host ""
    }

    Write-Host "  ──────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  " -NoNewline
    Write-Host "Tab" -NoNewline -ForegroundColor Yellow
    Write-Host " — автодополнение  ·  " -NoNewline -ForegroundColor DarkGray
    Write-Host "↑↓" -NoNewline -ForegroundColor Yellow
    Write-Host " — история  ·  " -NoNewline -ForegroundColor DarkGray
    Write-Host "info" -NoNewline -ForegroundColor Yellow
    Write-Host " — полная справка  ·  " -NoNewline -ForegroundColor DarkGray
    Write-Host "commands -Ru" -NoNewline -ForegroundColor Yellow
    Write-Host " — только русский" -ForegroundColor DarkGray
    Write-Host ""
}

Set-Alias -Name "commands" -Value "Show-ArgonovCommands" -Force