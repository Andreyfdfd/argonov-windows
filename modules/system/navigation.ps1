# ARGONOV SHELL · navigation & aliases

# ─── Переходы вверх ───
function ..    { Set-Location .. }
function ...   { Set-Location ..\.. }
function ....  { Set-Location ..\..\.. }
function ..... { Set-Location ..\..\..\.. }

# ─── Быстрые точки ───
function ~     { Set-Location $HOME }
function home  { Set-Location $HOME }
function root  { Set-Location C:\ }

function up {
    param([int]$N = 1)
    $p = (Get-Location).Path
    for ($i = 0; $i -lt $N; $i++) { $p = Split-Path -Parent $p }
    Set-Location $p
}

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Set-Location $Path
}

# ─── Файлы ───
function ll {
    Get-ChildItem -Force @args | Format-Table Mode, LastWriteTime, Length, Name -AutoSize
}

function la {
    Get-ChildItem -Force @args
}

function touch {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType File -Path $Path | Out-Null
    } else {
        (Get-Item $Path).LastWriteTime = Get-Date
    }
}

function sizeof {
    param([string]$Path = ".")
    $sum = (Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    if ($sum) {
        if ($sum -gt 1GB) { "{0:N2} GB" -f ($sum / 1GB) }
        elseif ($sum -gt 1MB) { "{0:N2} MB" -f ($sum / 1MB) }
        elseif ($sum -gt 1KB) { "{0:N2} KB" -f ($sum / 1KB) }
        else { "$sum B" }
    } else { "0 B" }
}

function find-file {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [string]$Path = "."
    )
    Get-ChildItem -Path $Path -Recurse -Filter $Pattern -ErrorAction SilentlyContinue |
        Select-Object FullName, Length, LastWriteTime
}

# ─── Алиасы ───
Set-Alias -Name which -Value Get-Command   -Force
Set-Alias -Name grep  -Value Select-String -Force
Set-Alias -Name cur   -Value Get-Location  -Force