# ARGONOV installer integration tests.
# All profile writes target unique temporary files, never the real PowerShell profile.
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion -lt [version]'7.6') {
    Write-Warning ("Installer integration tests require PowerShell 7.6+. Test host is {0}; integration tests skipped." -f $PSVersionTable.PSVersion)
    exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$installPath = Join-Path $repoRoot 'install.ps1'
if (-not (Test-Path -LiteralPath $installPath -PathType Leaf)) {
    throw "Missing installer: $installPath"
}

$tempRoot = Join-Path $env:TEMP ("argonov-install-test_{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$startMarker = '# >>> ARGONOV SHELL (managed by install.ps1) >>>'
$endMarker = '# <<< ARGONOV SHELL (managed by install.ps1) <<<'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Invoke-InstallerTest {
    param(
        [Parameter(Mandatory)][string]$TargetProfile,
        [string[]]$ExtraArgs = @()
    )

    $arguments = @('-NoLogo', '-NoProfile', '-File', $installPath, '-ProfilePath', $TargetProfile) + $ExtraArgs
    $output = & pwsh @arguments 2>&1 | Out-String
    return [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Get-TextCount {
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Value)
    return [regex]::Matches($Text, [regex]::Escape($Value)).Count
}

try {
    # ValidateOnly must leave an existing target profile untouched.
    $validateProfile = Join-Path $tempRoot 'validate-profile.ps1'
    $validateFixture = "# validation fixture`r`n`$global:KeepValidateOnly = `$true`r`n"
    [System.IO.File]::WriteAllText($validateProfile, $validateFixture, $utf8NoBom)
    $result = Invoke-InstallerTest -TargetProfile $validateProfile -ExtraArgs @('-ValidateOnly')
    if ($result.ExitCode -ne 0) { throw "ValidateOnly failed (exit $($result.ExitCode)):`n$($result.Output)" }
    if ([System.IO.File]::ReadAllText($validateProfile) -cne $validateFixture) { throw 'ValidateOnly changed the target profile.' }

    # A normal install must preserve unrelated profile content, migrate a legacy import,
    # and create a backup before modifying a non-empty profile.
    $profilePath = Join-Path $tempRoot 'profile.ps1'
    $fixtureLines = @(
        '# Existing profile header',
        '$global:BeforeArgonov = $true',
        ". 'C:\ARGONOV\profile.ps1'",
        '$global:AfterArgonov = $true'
    )
    $fixture = $fixtureLines -join "`r`n"
    [System.IO.File]::WriteAllText($profilePath, $fixture, $utf8NoBom)

    $result = Invoke-InstallerTest -TargetProfile $profilePath
    if ($result.ExitCode -ne 0) { throw "Initial install failed (exit $($result.ExitCode)):`n$($result.Output)" }
    $installed = [System.IO.File]::ReadAllText($profilePath)
    if ((Get-TextCount -Text $installed -Value $startMarker) -ne 1 -or (Get-TextCount -Text $installed -Value $endMarker) -ne 1) {
        throw 'Installer did not create exactly one well-formed managed block.'
    }
    if (-not $installed.Contains('# Existing profile header') -or -not $installed.Contains('$global:BeforeArgonov = $true') -or -not $installed.Contains('$global:AfterArgonov = $true')) {
        throw 'Installer removed profile content outside the managed block.'
    }
    if ((Get-TextCount -Text $installed -Value ". 'C:\ARGONOV\profile.ps1'") -gt 1) {
        throw 'Installer left a duplicate legacy profile import.'
    }
    $backups = @(Get-ChildItem -LiteralPath $tempRoot -Filter 'profile.ps1.argonov-backup-*' -File)
    if ($backups.Count -ne 1) { throw "Expected one initial profile backup, found $($backups.Count)." }

    # Re-running install must be idempotent and must not create another backup.
    $beforeSecondInstall = [System.IO.File]::ReadAllText($profilePath)
    $result = Invoke-InstallerTest -TargetProfile $profilePath
    if ($result.ExitCode -ne 0) { throw "Second install failed (exit $($result.ExitCode)):`n$($result.Output)" }
    if ([System.IO.File]::ReadAllText($profilePath) -cne $beforeSecondInstall) { throw 'Second install changed an already-correct profile.' }
    $backupsAfterSecond = @(Get-ChildItem -LiteralPath $tempRoot -Filter 'profile.ps1.argonov-backup-*' -File)
    if ($backupsAfterSecond.Count -ne 1) { throw 'Second install unexpectedly created another profile backup.' }

    # Malformed managed markers must fail closed and leave the profile untouched.
    $malformedPath = Join-Path $tempRoot 'malformed-profile.ps1'
    $malformedFixture = "# Preserve this`r`n$startMarker`r`n. 'C:\ARGONOV\profile.ps1'`r`n"
    [System.IO.File]::WriteAllText($malformedPath, $malformedFixture, $utf8NoBom)
    $result = Invoke-InstallerTest -TargetProfile $malformedPath
    if ($result.ExitCode -eq 0) { throw 'Installer unexpectedly accepted malformed profile markers.' }
    if ([System.IO.File]::ReadAllText($malformedPath) -cne $malformedFixture) { throw 'Installer changed a malformed profile.' }
    if (Get-ChildItem -LiteralPath $tempRoot -Filter 'malformed-profile.ps1.argonov-backup-*' -File) { throw 'Installer created a backup for a profile it refused to modify.' }

    Write-Host 'Installer ValidateOnly preservation test passed.' -ForegroundColor Green
    Write-Host 'Installer profile-preservation and backup test passed.' -ForegroundColor Green
    Write-Host 'Installer idempotency test passed.' -ForegroundColor Green
    Write-Host 'Installer malformed-marker safety test passed.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
