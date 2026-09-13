# ARGONOV SHELL · completion

Import-Module PSReadLine -ErrorAction SilentlyContinue

# ─── Серые подсказки отключены ───
Set-PSReadLineOption -PredictionSource None -ErrorAction SilentlyContinue
Set-PSReadLineOption -BellStyle None -ErrorAction SilentlyContinue
Set-PSReadLineOption -MaximumHistoryCount 20000 -ErrorAction SilentlyContinue
Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue

# ─── Tab = меню с навигацией ───
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction SilentlyContinue

# ↑↓ в меню, Enter выбрать, Esc закрыть — встроено в MenuComplete

# ─── История ───
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward -ErrorAction SilentlyContinue
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward  -ErrorAction SilentlyContinue
Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory -ErrorAction SilentlyContinue

# ─── Прочее ───
Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit -ErrorAction SilentlyContinue
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow  -Function BackwardWord -ErrorAction SilentlyContinue
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord  -ErrorAction SilentlyContinue

# ─── Цвета ───
try {
    Set-PSReadLineOption -Colors @{
        Command   = 'BrightGreen'
        Parameter = 'Gray'
        Operator  = 'BrightYellow'
        Variable  = 'BrightCyan'
        String    = 'BrightYellow'
        Number    = 'BrightMagenta'
        Type      = 'BrightBlue'
        Comment   = 'DarkGray'
        Keyword   = 'BrightBlue'
        Error     = 'BrightRed'
        Selection = 'BrightCyan'
    }
} catch {}