# ARGONOV cleanup safety tests. All file operations are confined to an isolated temporary directory.
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.6') {
    Write-Warning 'Cleanup safety tests require PowerShell 7.6+; tests skipped.'
    exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot 'modules\system\admin.ps1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) { throw "Missing admin module: $modulePath" }

$originalTemp = $env:TEMP
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('argonov-cleanup-test_{0}' -f [guid]::NewGuid().ToString('N'))
$siblingSentinel = Join-Path ([System.IO.Path]::GetDirectoryName($fixtureRoot)) ('argonov-cleanup-outside_{0}.txt' -f [guid]::NewGuid().ToString('N'))
$oldConfirmPreference = $ConfirmPreference

function Assert-True {
    param([string]$Name, [bool]$Condition)
    if (-not $Condition) { throw "Assertion failed: $Name" }
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    [System.IO.File]::WriteAllText($siblingSentinel, 'outside sentinel')
    $nested = Join-Path $fixtureRoot 'nested'
    New-Item -ItemType Directory -Path $nested -Force | Out-Null

    $oldTenDays = Join-Path $nested 'old-10-days.txt'
    $oldThreeDays = Join-Path $nested 'old-3-days.txt'
    $freshFile = Join-Path $nested 'fresh.txt'
    [System.IO.File]::WriteAllText($oldTenDays, 'delete me')
    [System.IO.File]::WriteAllText($oldThreeDays, 'keep with 7-day threshold')
    [System.IO.File]::WriteAllText($freshFile, 'keep fresh')
    $staleTime = (Get-Date).AddDays(-10).AddMinutes(-5)
    $threeDayTime = (Get-Date).AddDays(-3).AddMinutes(-5)
    [System.IO.File]::SetLastWriteTime($oldTenDays, $staleTime)
    [System.IO.File]::SetLastWriteTime($oldThreeDays, $threeDayTime)

    $env:TEMP = $fixtureRoot
    . $modulePath

    cleanup -OlderThanDays 1
    Assert-True 'preview preserves stale file' (Test-Path -LiteralPath $oldTenDays -PathType Leaf)

    cleanup -Execute -OlderThanDays 7 -WhatIf
    Assert-True 'WhatIf preserves stale file' (Test-Path -LiteralPath $oldTenDays -PathType Leaf)
    Assert-True 'WhatIf preserves 3-day-old file' (Test-Path -LiteralPath $oldThreeDays -PathType Leaf)

    $ConfirmPreference = 'None'
    cleanup -Execute -OlderThanDays 7 -Confirm:$false
    Assert-True '10-day-old file removed with 7-day threshold' (-not (Test-Path -LiteralPath $oldTenDays))
    Assert-True '3-day-old file preserved with 7-day threshold' (Test-Path -LiteralPath $oldThreeDays -PathType Leaf)
    Assert-True 'fresh file preserved' (Test-Path -LiteralPath $freshFile -PathType Leaf)
    Assert-True 'nested directory preserved' (Test-Path -LiteralPath $nested -PathType Container)
    Assert-True 'file outside TEMP preserved' (Test-Path -LiteralPath $siblingSentinel -PathType Leaf)

    $oldThreeDays2 = Join-Path $nested 'old-3-days-second-pass.txt'
    [System.IO.File]::WriteAllText($oldThreeDays2, 'delete with one-day threshold')
    [System.IO.File]::SetLastWriteTime($oldThreeDays2, $threeDayTime)
    cleanup -Execute -OlderThanDays 1 -Confirm:$false
    Assert-True '3-day-old file removed with 1-day threshold' (-not (Test-Path -LiteralPath $oldThreeDays2))
    Assert-True 'fresh file still preserved' (Test-Path -LiteralPath $freshFile -PathType Leaf)

    Write-Host 'cleanup preview-only test passed.' -ForegroundColor Green
    Write-Host 'cleanup -WhatIf safety test passed.' -ForegroundColor Green
    Write-Host 'cleanup age-threshold test passed.' -ForegroundColor Green
    Write-Host 'cleanup scope and directory-preservation tests passed.' -ForegroundColor Green
}
finally {
    $env:TEMP = $originalTemp
    $ConfirmPreference = $oldConfirmPreference
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $siblingSentinel -Force -ErrorAction SilentlyContinue
}
