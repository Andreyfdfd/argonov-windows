# ARGONOV SHELL · custom prompt

function prompt {
    # Сохраняем статус последней команды в самом начале,
    # пока не перезаписали его вызовами git
    $lastOK = $?

    # Путь (сокращаем $HOME до ~)
    $pwd = $PWD.Path
    if ($pwd -eq $HOME) {
        $pwd = "~"
    } elseif ($pwd.StartsWith($HOME)) {
        $pwd = "~" + $pwd.Substring($HOME.Length)
    }

    # Git-ветка и статус (если есть функция git-branch)
    $branch = $null
    $dirty = $false
    if (Get-Command git-branch -ErrorAction SilentlyContinue) {
        $branch = git-branch
        if ($branch) { $dirty = git-dirty }
    }

    # Время
    $time = Get-Date -Format "HH:mm:ss"

    # ─── Строка 1: user path branch time ───
    Write-Host ""
    Write-Host "$env:USERNAME" -NoNewline -ForegroundColor Cyan
    Write-Host "  " -NoNewline
    Write-Host "$pwd" -NoNewline -ForegroundColor Green

    if ($branch) {
        Write-Host "  " -NoNewline
        if ($dirty) {
            Write-Host "[$branch*]" -NoNewline -ForegroundColor Yellow
        } else {
            Write-Host "[$branch]" -NoNewline -ForegroundColor Magenta
        }
    }

    Write-Host "  " -NoNewline
    Write-Host "$time" -NoNewline -ForegroundColor DarkGray
    Write-Host ""

    # ─── Строка 2: стрелка ───
    if ($lastOK) {
        Write-Host "> " -NoNewline -ForegroundColor DarkCyan
    } else {
        Write-Host "> " -NoNewline -ForegroundColor Red
    }

    return " "
}