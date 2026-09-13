# ARGONOV SHELL · prompt (v2)

if (-not $global:ArgonovLastPrompt) { $global:ArgonovLastPrompt = Get-Date }
if (-not $global:ArgonovLastCmdDuration) { $global:ArgonovLastCmdDuration = 0 }

function Get-GitInfo {
    if (-not (Test-Path ".git")) { return $null }
    try {
        $branch = & git symbolic-ref --short HEAD 2>$null
        if (-not $branch) { $branch = & git rev-parse --short HEAD 2>$null }
        if (-not $branch) { return $null }

        $status = & git status --porcelain 2>$null
        $dirty = ($status -ne $null -and $status.Length -gt 0)
        $modified = 0
        $untracked = 0
        if ($status) {
            foreach ($line in $status) {
                if ($line -match "^\s*\?\?") { $untracked++ } else { $modified++ }
            }
        }
        return [PSCustomObject]@{
            Branch    = $branch.Trim()
            Dirty     = $dirty
            Modified  = $modified
            Untracked = $untracked
        }
    } catch { return $null }
}

function Get-ProjectIcon {
    if (Test-Path ".venv" -PathType Container) { return "[py]" }
    if (Test-Path "venv" -PathType Container)  { return "[py]" }
    if (Test-Path "package.json")              { return "[js]" }
    if (Test-Path "Cargo.toml")                { return "[rs]" }
    if (Test-Path "go.mod")                    { return "[go]" }
    if (Test-Path "requirements.txt")          { return "[py]" }
    if (Test-Path "Dockerfile")                { return "[dk]" }
    if (Test-Path "pyproject.toml")            { return "[py]" }
    return ""
}

function Format-Duration {
    param([double]$Seconds)
    if ($Seconds -lt 1)    { return "" }
    if ($Seconds -lt 60)   { return ("{0:N1}s" -f $Seconds) }
    if ($Seconds -lt 3600) {
        $min = [math]::Floor($Seconds / 60)
        $sec = [int]($Seconds % 60)
        return "${min}m${sec}s"
    }
    $h = [math]::Floor($Seconds / 3600)
    $m = [math]::Floor(($Seconds % 3600) / 60)
    return "${h}h${m}m"
}

function prompt {
    $now = Get-Date
    $lastDuration = ($now - $global:ArgonovLastPrompt).TotalSeconds
    $global:ArgonovLastPrompt = $now
    $global:ArgonovLastCmdDuration = $lastDuration

    $lastOK = $?

    $pwd = $PWD.Path
    if ($pwd -eq $HOME) {
        $pwd = "~"
    } elseif ($pwd.StartsWith($HOME)) {
        $pwd = "~" + $pwd.Substring($HOME.Length)
    }

    $git = Get-GitInfo
    $projIcon = Get-ProjectIcon
    $time = $now.ToString("HH:mm:ss")

    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { $isAdmin = $false }

    # Строка 1
    Write-Host "[" -NoNewline -ForegroundColor DarkCyan
    Write-Host "$env:USERNAME" -NoNewline -ForegroundColor Cyan
    Write-Host "@" -NoNewline -ForegroundColor DarkGray
    Write-Host "$env:COMPUTERNAME" -NoNewline -ForegroundColor Cyan
    Write-Host "]" -NoNewline -ForegroundColor DarkCyan

    Write-Host "  " -NoNewline
    if ($projIcon) {
        Write-Host "$projIcon " -NoNewline -ForegroundColor Yellow
    }
    Write-Host "$pwd" -NoNewline -ForegroundColor Green

    if ($git) {
        Write-Host "  " -NoNewline
        Write-Host "(" -NoNewline -ForegroundColor DarkGray
        if ($git.Dirty) {
            Write-Host "$($git.Branch)" -NoNewline -ForegroundColor Yellow
            Write-Host " !" -NoNewline -ForegroundColor Red
            if ($git.Modified -gt 0 -or $git.Untracked -gt 0) {
                $summary = ""
                if ($git.Modified -gt 0)  { $summary += "~$($git.Modified)" }
                if ($git.Untracked -gt 0) {
                    if ($summary) { $summary += " " }
                    $summary += "?$($git.Untracked)"
                }
                Write-Host " $summary" -NoNewline -ForegroundColor DarkYellow
            }
        } else {
            Write-Host "$($git.Branch)" -NoNewline -ForegroundColor Magenta
            Write-Host " ok" -NoNewline -ForegroundColor Green
        }
        Write-Host ")" -NoNewline -ForegroundColor DarkGray
    }

    if ($isAdmin) {
        Write-Host "  " -NoNewline
        Write-Host "ADMIN" -NoNewline -ForegroundColor Red
    }

    Write-Host ""

    # Строка 2
    Write-Host "$time" -NoNewline -ForegroundColor DarkGray
    if ($lastDuration -gt 2) {
        Write-Host "  " -NoNewline
        Write-Host "$(Format-Duration $lastDuration)" -NoNewline -ForegroundColor DarkYellow
    }
    Write-Host " " -NoNewline

    if ($lastOK) {
        Write-Host "> " -NoNewline -ForegroundColor Green
    } else {
        Write-Host "> " -NoNewline -ForegroundColor Red
    }

    return " "
}