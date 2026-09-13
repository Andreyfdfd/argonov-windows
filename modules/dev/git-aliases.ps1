# ARGONOV SHELL · git aliases

# Снимаем встроенные алиасы PowerShell, которые мешают
Remove-Item Alias:gl -Force -ErrorAction SilentlyContinue
Remove-Item Alias:gc -Force -ErrorAction SilentlyContinue
Remove-Item Alias:gp -Force -ErrorAction SilentlyContinue
Remove-Item Alias:gs -Force -ErrorAction SilentlyContinue
Remove-Item Alias:gb -Force -ErrorAction SilentlyContinue
Remove-Item Alias:gd -Force -ErrorAction SilentlyContinue
Remove-Item Alias:gci -Force -ErrorAction SilentlyContinue

function gs   { git status @args }
function ga   { git add @args }
function gc   { git commit -m @args }
function gp   { git push @args }
function gpl  { git pull @args }
function gd   { git diff @args }
function gco  { git checkout @args }
function gb   { git branch @args }
function gcl  { git clone @args }

function gl {
    git log --oneline -20 --graph --decorate --all @args
}

function git-branch {
    try {
        $b = & git symbolic-ref --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $b) { return $b.Trim() }
    } catch {}
    return $null
}

function git-dirty {
    try {
        $s = & git status --porcelain 2>$null
        return ($s -ne $null -and $s.Length -gt 0)
    } catch { return $false }
}