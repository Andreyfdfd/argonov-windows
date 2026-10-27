# ARGONOV SHELL uninstaller smoke tests
# All tests use temporary profile files and do not modify the real user profile.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$uninstallPath = Join-Path $repoRoot 'uninstall.ps1'
if (-not (Test-Path -LiteralPath $uninstallPath -PathType Leaf)) {
    throw "Missing uninstaller: $uninstallPath"
}

$tempRoot = Join-Path $env:TEMP ("argonov-uninstall-test_{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

$startMarker = '# >>> ARGONOV SHELL (managed by install.ps1) >>>'
$endMarker = '# <<< ARGONOV SHELL (managed by install.ps1) <<<'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

try {
    # Normal uninstall removes only the managed block and preserves surrounding profile content.
    $profilePath = Join-Path $tempRoot 'profile.ps1'
    $quotedRepoRoot = $repoRoot.Replace("'", "''")
    $fixtureLines = @(
        '# User profile header',
        '$global:BeforeArgonov = $true',
        $startMarker,
        ". '$quotedRepoRoot\profile.ps1'",
        $endMarker,
        '$global:AfterArgonov = $true'
    )
    $fixture = $fixtureLines -join "`r`n"
    [System.IO.File]::WriteAllText($profilePath, $fixture, $utf8NoBom)

    $output = & pwsh -NoLogo -NoProfile -File $uninstallPath -ProfilePath $profilePath 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) { throw "Normal uninstall failed (exit $exitCode):`n$output" }

    $updated = [System.IO.File]::ReadAllText($profilePath)
    if ($updated.Contains($startMarker) -or $updated.Contains($endMarker) -or $updated.Contains('profile.ps1')) {
        throw 'Managed profile entry was not removed.'
    }
    if (-not $updated.Contains('$global:BeforeArgonov = $true') -or -not $updated.Contains('$global:AfterArgonov = $true')) {
        throw 'Uninstaller removed profile content outside the managed block.'
    }
    if (-not (Get-ChildItem -LiteralPath $tempRoot -Filter 'profile.ps1.argonov-uninstall-backup-*' -File)) {
        throw 'Uninstaller did not create a profile backup.'
    }

    # WhatIf must not modify the profile or create a backup.
    $whatIfPath = Join-Path $tempRoot 'whatif-profile.ps1'
    $whatIfFixture = @('# keep this', $startMarker, '. C:\ARGONOV\profile.ps1', $endMarker, '# keep that') -join "`r`n"
    [System.IO.File]::WriteAllText($whatIfPath, $whatIfFixture, $utf8NoBom)
    $output = & pwsh -NoLogo -NoProfile -File $uninstallPath -ProfilePath $whatIfPath -WhatIf 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) { throw "WhatIf uninstall failed (exit $exitCode):`n$output" }
    if ([System.IO.File]::ReadAllText($whatIfPath) -cne $whatIfFixture) { throw 'WhatIf changed the profile file.' }
    if (Get-ChildItem -LiteralPath $tempRoot -Filter 'whatif-profile.ps1.argonov-uninstall-backup-*' -File) { throw 'WhatIf unexpectedly created a backup.' }

    # Malformed markers must fail closed and preserve the original profile.
    $malformedPath = Join-Path $tempRoot 'malformed-profile.ps1'
    $malformedFixture = @('# preserve me', $startMarker, ". '$repoRoot\profile.ps1'") -join "`r`n"
    [System.IO.File]::WriteAllText($malformedPath, $malformedFixture, $utf8NoBom)
    $output = & pwsh -NoLogo -NoProfile -File $uninstallPath -ProfilePath $malformedPath 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) { throw 'Malformed profile markers unexpectedly succeeded.' }
    if [System.IO.File]::ReadAllText($malformedPath) -cne $malformedFixture) { throw 'Malformed profile was changed despite a marker error.' }

    Write-Host 'Uninstaller profile-preservation tests passed.' -ForegroundColor Green
    Write-Host 'Uninstaller WhatIf test passed.' -ForegroundColor Green
    Write-Host 'Uninstaller malformed-marker safety test passed.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
