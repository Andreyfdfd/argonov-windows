# ARGONOV SHELL profile

# ─── Загрузка модулей по категориям ───
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
    Get-ChildItem $ArgRoot -Filter *.ps1 -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}

# ─── Приветствие ───
if (Get-Command Show-ArgonovBanner -ErrorAction SilentlyContinue) {
    Show-ArgonovBanner
}

# ─── Каталог команд ───
if (Get-Command Show-ArgonovCommands -ErrorAction SilentlyContinue) {
    Show-ArgonovCommands
}

# ─── Тихая проверка безопасности ───
if (Get-Command security-quick -ErrorAction SilentlyContinue) {
    security-quick -Silent
}