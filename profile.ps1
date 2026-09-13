# ARGONOV SHELL profile

$PSVersionTable.PSVersion.ToString()

if (Get-Command py -ErrorAction SilentlyContinue) {
    py --version
} else {
    "Python: not installed"
}

"Started: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"User: $env:USERNAME@$env:COMPUTERNAME"

# Загрузка модулей
$ArgRoot = "C:\ARGONOV\modules"
if (Test-Path $ArgRoot) {
    Get-ChildItem $ArgRoot -Filter *.ps1 | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

# Список всех наших команд
if (Get-Command Show-ArgonovCommands -ErrorAction SilentlyContinue) {
    Show-ArgonovCommands
}