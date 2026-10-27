# ARGONOV SHELL profile
# Supported runtime: PowerShell 7 or newer.

if ($PSVersionTable.PSVersion -lt [version]'7.6') {
    Write-Warning ("ARGONOV SHELL requires PowerShell 7.6+. Current version: {0}. Start it with 'pwsh' instead of 'powershell'." -f $PSVersionTable.PSVersion)
    return
}

# Keep the installation path relative to this file. Do not assume C:\ARGONOV.
$global:ARGONOV_ROOT = [System.IO.Path]::GetFullPath($PSScriptRoot)
$global:ARGONOV_MODULE_ROOT = Join-Path -Path $global:ARGONOV_ROOT -ChildPath 'modules'

if (-not (Test-Path -LiteralPath $global:ARGONOV_MODULE_ROOT -PathType Container)) {
    Write-Warning "ARGONOV SHELL: modules folder was not found: $global:ARGONOV_MODULE_ROOT"
    return
}

$categoryOrder = @('core', 'system', 'network', 'ai', 'tools', 'dev', 'osint', 'fun')
$moduleFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

foreach ($category in $categoryOrder) {
    $categoryPath = Join-Path -Path $global:ARGONOV_MODULE_ROOT -ChildPath $category
    if (Test-Path -LiteralPath $categoryPath -PathType Container) {
        foreach ($file in (Get-ChildItem -LiteralPath $categoryPath -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $moduleFiles.Add($file)
        }
    }
}

# Also support optional modules placed directly in modules\.
foreach ($file in (Get-ChildItem -LiteralPath $global:ARGONOV_MODULE_ROOT -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $moduleFiles.Add($file)
}

foreach ($moduleFile in $moduleFiles) {
    try {
        . $moduleFile.FullName
    }
    catch {
        $relativePath = $moduleFile.FullName.Substring($global:ARGONOV_MODULE_ROOT.Length).TrimStart([char[]]@('\', '/'))
        Write-Warning ("ARGONOV SHELL: failed to load module '{0}': {1}" -f $relativePath, $_.Exception.Message)
    }
}

# Optional startup UI: a missing or failing optional function must not break the shell.
if (Get-Command Show-ArgonovBanner -ErrorAction SilentlyContinue) {
    try { Show-ArgonovBanner } catch { Write-Warning "ARGONOV SHELL: banner failed: $($_.Exception.Message)" }
}

if (Get-Command Show-ArgonovCommands -ErrorAction SilentlyContinue) {
    try { Show-ArgonovCommands } catch { Write-Warning "ARGONOV SHELL: command catalog failed: $($_.Exception.Message)" }
}

if (Get-Command security-quick -ErrorAction SilentlyContinue) {
    try { security-quick -Silent } catch { Write-Warning "ARGONOV SHELL: quick security check failed: $($_.Exception.Message)" }
}
