# ARGONOV SHELL - PSReadLine configuration

try {
    Import-Module PSReadLine -ErrorAction Stop
} catch {
    # PSReadLine is optional in non-interactive or minimal PowerShell installations.
    return
}

$optionCommand = Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue
$keyHandlerCommand = Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue

if ($optionCommand) {
    $optionNames = $optionCommand.Parameters

    # PredictionSource is not present in every PSReadLine release.
    if ($optionNames.ContainsKey('PredictionSource')) {
        Set-PSReadLineOption -PredictionSource None -ErrorAction SilentlyContinue
    }
    if ($optionNames.ContainsKey('BellStyle')) {
        Set-PSReadLineOption -BellStyle None -ErrorAction SilentlyContinue
    }
    if ($optionNames.ContainsKey('MaximumHistoryCount')) {
        Set-PSReadLineOption -MaximumHistoryCount 20000 -ErrorAction SilentlyContinue
    }
    if ($optionNames.ContainsKey('HistorySearchCursorMovesToEnd')) {
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue
    }

    if ($optionNames.ContainsKey('Colors')) {
        try {
            Set-PSReadLineOption -Colors @{
                Command   = 'Green'
                Parameter = 'Gray'
                Operator  = 'Yellow'
                Variable  = 'Cyan'
                String    = 'Yellow'
                Number    = 'Magenta'
                Type      = 'Blue'
                Comment   = 'DarkGray'
                Keyword   = 'Blue'
                Error     = 'Red'
                Selection = 'Cyan'
            } -ErrorAction Stop
        } catch {
            # Theme configuration must never prevent the terminal from starting.
        }
    }
}

if ($keyHandlerCommand) {
    $keyHandlers = @(
        @{ Key = 'Tab';             Function = 'MenuComplete' },
        @{ Key = 'UpArrow';         Function = 'HistorySearchBackward' },
        @{ Key = 'DownArrow';       Function = 'HistorySearchForward' },
        @{ Key = 'Ctrl+r';          Function = 'ReverseSearchHistory' },
        @{ Key = 'Ctrl+d';          Function = 'DeleteCharOrExit' },
        @{ Key = 'Ctrl+LeftArrow';  Function = 'BackwardWord' },
        @{ Key = 'Ctrl+RightArrow'; Function = 'ForwardWord' }
    )

    foreach ($handler in $keyHandlers) {
        try {
            Set-PSReadLineKeyHandler -Key $handler.Key -Function $handler.Function -ErrorAction Stop
        } catch {
            # Some hosts or PSReadLine versions do not support all key bindings.
        }
    }
}
