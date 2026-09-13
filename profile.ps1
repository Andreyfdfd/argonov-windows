# ARGONOV SHELL profile

$PSVersionTable.PSVersion.ToString()

if (Get-Command py -ErrorAction SilentlyContinue) {
    py --version
} else {
    "Python: not installed"
}

"Started: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"User: $env:USERNAME@$env:COMPUTERNAME"

# Загрузка модулей с сохранением порядка категорий
$ArgRoot = "C:\ARGONOV\modules"
if (Test-Path $ArgRoot) {
    $categoryOrder = @("core", "system", "network", "ai", "tools", "dev", "osint", "fun")
    foreach ($cat in $categoryOrder) {
        $catPath = Join-Path $ArgRoot $cat
        if (Test-Path $catPath) {
            Get-ChildItem $catPath -Filter *.ps1 -ErrorAction SilentlyContinue |
                Sort-Object Name |
                ForEach-Object { . $_.FullName }
        }
    }
    # Fallback: файлы в корне modules
    Get-ChildItem $ArgRoot -Filter *.ps1 -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}

# Каталог команд
if (Get-Command Show-ArgonovCommands -ErrorAction SilentlyContinue) {
    Show-ArgonovCommands
}

# Проверка безопасности при старте (тихо)
if (Get-Command security-quick -ErrorAction SilentlyContinue) {
    security-quick -Silent
}