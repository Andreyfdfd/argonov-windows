# ARGONOV SHELL - safe reorganization smoke test
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("argonov-reorganize-test_{0}" -f [guid]::NewGuid().ToString('N'))
$moduleRoot = Join-Path $testRoot 'modules'
$testScript = Join-Path $testRoot 'reorganize.ps1'

try {
    New-Item -ItemType Directory -Path (Join-Path $moduleRoot 'core') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $moduleRoot 'system') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\reorganize.ps1') -Destination $testScript -Force

    Set-Content -LiteralPath (Join-Path $moduleRoot 'completion.ps1') -Value '# move fixture' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $moduleRoot 'sysinfo.ps1') -Value '# move fixture' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $moduleRoot 'commands.ps1') -Value '# source conflict must be preserved' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $moduleRoot 'core\commands.ps1') -Value '# destination conflict must be preserved' -Encoding utf8

    # Default mode must be preview-only.
    & $testScript
    if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot 'completion.ps1'))) {
        throw 'Preview mode moved a file unexpectedly.'
    }
    if (Test-Path -LiteralPath (Join-Path $moduleRoot 'core\completion.ps1')) {
        throw 'Preview mode created a target file unexpectedly.'
    }

    # Execute mode should move non-conflicting files and leave conflicts untouched.
    & $testScript -Execute
    if (Test-Path -LiteralPath (Join-Path $moduleRoot 'completion.ps1')) {
        throw 'Execute mode did not move completion.ps1.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot 'core\completion.ps1'))) {
        throw 'Execute mode did not create modules/core/completion.ps1.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot 'system\sysinfo.ps1'))) {
        throw 'Execute mode did not create modules/system/sysinfo.ps1.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot 'commands.ps1'))) {
        throw 'Conflict source was overwritten or removed.'
    }
    if ((Get-Content -LiteralPath (Join-Path $moduleRoot 'core\commands.ps1') -Raw) -notmatch 'destination conflict') {
        throw 'Conflict destination was overwritten.'
    }

    Write-Host 'Reorganization safety tests passed.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}