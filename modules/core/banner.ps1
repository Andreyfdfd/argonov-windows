# ARGONOV SHELL · banner

function Show-ArgonovBanner {
    $gitBranch = ""
    $gitClean  = $true
    $commitCount = 0
    if (Test-Path "C:\ARGONOV\.git") {
        try {
            Push-Location "C:\ARGONOV"
            $gitBranch = & git symbolic-ref --short HEAD 2>$null
            $status = & git status --porcelain 2>$null
            $gitClean = ($status -eq $null -or $status.Length -eq 0)
            $commitCount = & git rev-list --count HEAD 2>$null
            Pop-Location
        } catch { Pop-Location }
    }

    $now = Get-Date
    $psVer = $PSVersionTable.PSVersion.ToString()
    $pyVer = try { (& py -3.14 --version 2>&1) -replace "Python ","" } catch { "?" }
    $timeStr = $now.ToString("HH:mm:ss")

    # Внутренняя ширина рамки — 54 знака
    $innerWidth = 54
    $title = "ARGONOV OS"
    $padding = $innerWidth - 2 - $title.Length - $timeStr.Length - 2
    if ($padding -lt 1) { $padding = 1 }

    $topLine    = "  +" + ("=" * $innerWidth) + "+"
    $titleLine  = "  |  " + $title + (" " * $padding) + $timeStr + "  |"
    $botLine    = "  +" + ("=" * $innerWidth) + "+"

    Write-Host ""
    Write-Host $topLine   -ForegroundColor DarkCyan
    Write-Host $titleLine -ForegroundColor Cyan
    Write-Host $botLine   -ForegroundColor DarkCyan

    # Инфо-строка
    Write-Host "     " -NoNewline
    Write-Host "PowerShell " -NoNewline -ForegroundColor DarkGray
    Write-Host "$psVer" -NoNewline -ForegroundColor Cyan
    Write-Host "  .  " -NoNewline -ForegroundColor DarkGray
    Write-Host "Python " -NoNewline -ForegroundColor DarkGray
    Write-Host "$pyVer" -NoNewline -ForegroundColor Yellow

    if ($gitBranch) {
        Write-Host "  .  " -NoNewline -ForegroundColor DarkGray
        Write-Host "ARGONOV " -NoNewline -ForegroundColor DarkGray
        Write-Host "$gitBranch" -NoNewline -ForegroundColor Magenta
        if ($gitClean) {
            Write-Host " ok" -NoNewline -ForegroundColor Green
        } else {
            Write-Host " *" -NoNewline -ForegroundColor Red
        }
        Write-Host " ($commitCount)" -NoNewline -ForegroundColor DarkGray
    }
    Write-Host ""
}