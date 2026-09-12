# ARGONOV SHELL profile
$PSVersionTable.PSVersion.ToString()

if (Get-Command py -ErrorAction SilentlyContinue) {
    py --version
} else {
    "Python: not installed"
}

"Started: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

"User: $env:USERNAME@$env:COMPUTERNAME"