# ARGONOV SHELL · info
# One source of truth: reuse the live command catalog instead of maintaining duplicate help.

function info {
    if (Get-Command Show-ArgonovCommands -ErrorAction SilentlyContinue) {
        Show-ArgonovCommands
        return
    }

    Write-Host ''
    Write-Host 'ARGONOV SHELL: каталог команд ещё не загружен.' -ForegroundColor Yellow
    Write-Host 'Перезапусти Windows Terminal или проверь modules/core/commands.ps1.' -ForegroundColor DarkGray
}
