# ARGONOV SHELL · info command

function info {
    Write-Host ""
    Write-Host "  ARGONOV SHELL" -NoNewline -ForegroundColor Cyan
    Write-Host "  info" -ForegroundColor DarkGray
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkCyan

    Write-Host "  NAVIGATION" -ForegroundColor Yellow
    Write-Host "    .. ... .... .....    go up 1-4 levels" -ForegroundColor Gray
    Write-Host "    ~ home root          home / C:\" -ForegroundColor Gray
    Write-Host "    up N                 go up N levels" -ForegroundColor Gray
    Write-Host "    mkcd PATH            make dir and cd into it" -ForegroundColor Gray

    Write-Host "  FILES" -ForegroundColor Yellow
    Write-Host "    ll                   list with details" -ForegroundColor Gray
    Write-Host "    la                   list all (incl. hidden)" -ForegroundColor Gray
    Write-Host "    touch FILE           create / update timestamp" -ForegroundColor Gray
    Write-Host "    sizeof PATH          folder size" -ForegroundColor Gray
    Write-Host "    find-file PATTERN    recursive search" -ForegroundColor Gray
    Write-Host "    which CMD            where is a command" -ForegroundColor Gray
    Write-Host "    grep TEXT FILE       search in file" -ForegroundColor Gray

    Write-Host "  SYSTEM" -ForegroundColor Yellow
    Write-Host "    sysinfo              system info panel" -ForegroundColor Gray

    Write-Host "  GIT" -ForegroundColor Yellow
    Write-Host "    gs                   git status" -ForegroundColor Gray
    Write-Host "    ga .                 git add all" -ForegroundColor Gray
    Write-Host "    gc TEXT              git commit -m TEXT" -ForegroundColor Gray
    Write-Host "    gp                   git push" -ForegroundColor Gray
    Write-Host "    gpl                  git pull" -ForegroundColor Gray
    Write-Host "    gd                   git diff" -ForegroundColor Gray
    Write-Host "    gl                   git log (graph, 20)" -ForegroundColor Gray
    Write-Host "    gb                   git branch" -ForegroundColor Gray
    Write-Host "    gco BRANCH           git checkout" -ForegroundColor Gray
    Write-Host "    gcl URL              git clone" -ForegroundColor Gray
    Write-Host "    git-branch           current branch name" -ForegroundColor Gray
    Write-Host "    git-dirty            true if uncommitted changes" -ForegroundColor Gray

    Write-Host "  KEYS" -ForegroundColor Yellow
    Write-Host "    Tab                  auto-complete" -ForegroundColor Gray
    Write-Host "    Ctrl+R               search history" -ForegroundColor Gray
    Write-Host "    Ctrl+C               cancel current line" -ForegroundColor Gray

    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host ""
}