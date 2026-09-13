# ARGONOV SHELL · completion

Import-Module PSReadLine -ErrorAction SilentlyContinue

# ─── Предсказания ───
# CompletionPredictor 0.1.1 не работает с PSReadLine 2.4.5,
# поэтому только история.
Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
Set-PSReadLineOption -MaximumHistoryCount 20000 -ErrorAction SilentlyContinue
Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue
Set-PSReadLineOption -BellStyle None -ErrorAction SilentlyContinue

# ─── Клавиши ───
# Tab = меню всех команд (функции, алиасы, cmdlets)
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction SilentlyContinue
Set-PSReadLineKeyHandler -Key Shift+Tab -Function TabCompletePrevious -ErrorAction SilentlyContinue

# Ctrl+Space = Complete (циклическое дополнение)
Set-PSReadLineKeyHandler -Key Ctrl+Spacebar -Function Complete -ErrorAction SilentlyContinue

# ↑↓ — история с фильтром
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward -ErrorAction SilentlyContinue
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward  -ErrorAction SilentlyContinue

# F1 — справка по введённой команде
Set-PSReadLineKeyHandler -Key F1 -Function ShowCommandHelp -ErrorAction SilentlyContinue

# F2 — переключить Inline/ListView предсказаний
Set-PSReadLineKeyHandler -Key F2 -Function SwitchPredictionView -ErrorAction SilentlyContinue

# Ctrl+R — поиск в истории
Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory -ErrorAction SilentlyContinue

# Ctrl+D — выход или удаление
Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit -ErrorAction SilentlyContinue

# Ctrl+Left/Right — переход по словам
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow  -Function BackwardWord -ErrorAction SilentlyContinue
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord  -ErrorAction SilentlyContinue

# ─── Цвета ───
try {
    Set-PSReadLineOption -Colors @{
        Command          = 'BrightGreen'
        Parameter        = 'Gray'
        Operator         = 'BrightYellow'
        Variable         = 'BrightCyan'
        String           = 'BrightYellow'
        Number           = 'BrightMagenta'
        Type             = 'BrightBlue'
        Comment          = 'DarkGray'
        Keyword          = 'BrightBlue'
        Error            = 'BrightRed'
        ListPrediction   = 'DarkGray'
        InlinePrediction = 'DarkGray'
    }
} catch {}