# ARGONOV SHELL profile
$PSVersionTable.PSVersion.ToString()

if (Get-Command py -ErrorAction SilentlyContinue) {
    py --version
} else {
    "Python: not installed"
}

"Started: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

"User: $env:USERNAME@$env:COMPUTERNAME"

# Load modules
$ArgRoot = "C:\ARGONOV\modules"
if (Test-Path $ArgRoot) {
    Get-ChildItem $ArgRoot -Filter *.ps1 | ForEach-Object { . $_.FullName }
}