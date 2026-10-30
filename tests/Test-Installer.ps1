# ARGONOV SHELL installer tests
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $projectRoot 'install.ps1'
$profileSource = Join-Path $projectRoot 'profile.ps1'
function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "TEST FAILED: $Message" }
    Write-Host "[PASS] $Message" -ForegroundColor Green
}
if ($PSVersionTable.PSVersion -lt [version]'7.6') {
    throw ("Tests require PowerShell 7.6+. Current version: {0}" -f $PSVersionTable.PSVersion)
}
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw 'install.ps1 is missing.' }
if (-not (Test-Path -LiteralPath $profileSource -PathType Leaf)) { throw 'profile.ps1 is missing.' }

Write-Host 'ARGONOV SHELL installer test suite' -ForegroundColor Cyan
$allScripts = @(Get-ChildItem -LiteralPath $projectRoot -Filter '*.ps1' -File -Recurse -Force |
    Where-Object { $_.FullName -notmatch '[\\/](\.git|\.github)[\\/]' })
foreach ($file in $allScripts) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if (@($parseErrors).Count -gt 0) {
        $first = @($parseErrors)[0]
        throw ("Syntax error in {0}:{1}: {2}" -f $file.FullName, $first.Extent.StartLineNumber, $first.Message)
    }
}
Assert-Test ($allScripts.Count -gt 0) ("PowerShell parser accepted {0} project scripts." -f $allScripts.Count)

$profileText = [System.IO.File]::ReadAllText($profileSource)
Assert-Test ($profileText -notmatch 'C:\\ARGONOV') 'Profile resolves paths relatively; no hard-coded C:\ARGONOV remains.'

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("ARGONOV-Installer-Test-" + [guid]::NewGuid().ToString('N'))
$installRoot = Join-Path $sandbox 'Installed Shell'
$profilePath = Join-Path $sandbox 'PowerShell\Microsoft.PowerShell_profile.ps1'
New-Item -ItemType Directory -Path (Split-Path -Parent $profilePath) -Force | Out-Null
$initialProfile = '# User profile content' + [Environment]::NewLine + "Write-Output 'KEEP_THIS_LINE'" + [Environment]::NewLine
[System.IO.File]::WriteAllText($profilePath, $initialProfile, [System.Text.UTF8Encoding]::new($false))
try {
    & $installer -InstallRoot $installRoot -ProfilePath $profilePath
    Assert-Test (Test-Path -LiteralPath (Join-Path $installRoot 'profile.ps1') -PathType Leaf) 'Installer copied profile.ps1.'
    Assert-Test (Test-Path -LiteralPath (Join-Path $installRoot 'modules') -PathType Container) 'Installer copied modules.'
    Assert-Test (Test-Path -LiteralPath (Join-Path $installRoot '.argonov-install.json') -PathType Leaf) 'Installer wrote its manifest.'
    $profileAfterInstall = [System.IO.File]::ReadAllText($profilePath)
    Assert-Test ($profileAfterInstall.Contains('KEEP_THIS_LINE')) 'Existing user profile content was preserved.'
    Assert-Test (($profileAfterInstall -split [regex]::Escape('# >>> ARGONOV SHELL (managed by installer) >>>')).Count -eq 2) 'One managed ARGONOV profile block was added.'

    & $installer -InstallRoot $installRoot -ProfilePath $profilePath
    $profileAfterSecondInstall = [System.IO.File]::ReadAllText($profilePath)
    Assert-Test (($profileAfterSecondInstall -split [regex]::Escape('# >>> ARGONOV SHELL (managed by installer) >>>')).Count -eq 2) 'Second install did not duplicate the profile block.'
    Assert-Test ((Get-ChildItem -LiteralPath $sandbox -Directory -Filter 'Installed Shell.backup-*').Count -eq 1) 'Previous installation was backed up before replacement.'

    $validateOnlyRoot = Join-Path $sandbox 'ValidateOnly'
    & $installer -InstallRoot $validateOnlyRoot -ProfilePath (Join-Path $sandbox 'unused-profile.ps1') -ValidateOnly
    Assert-Test (-not (Test-Path -LiteralPath $validateOnlyRoot)) 'ValidateOnly did not create an installation directory.'
    Assert-Test (-not (Test-Path -LiteralPath (Join-Path $sandbox 'unused-profile.ps1'))) 'ValidateOnly did not modify a profile.'
    Write-Host ''
    Write-Host 'ALL INSTALLER TESTS PASSED' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $sandbox) {
        Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }
}
