# Downloads and tests an ARGONOV SHELL branch in an isolated temporary folder.
[CmdletBinding()]
param(
    [string]$Repository = 'Andreyfdfd/argonov-windows',
    [string]$Branch = 'feature/installer-bootstrap',
    [switch]$KeepFiles
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.6') {
    throw ("Run this tester in PowerShell 7.6+. Current version: {0}. Open PowerShell with 'pwsh' and retry." -f $PSVersionTable.PSVersion)
}
if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "Invalid repository name: $Repository" }
if ([string]::IsNullOrWhiteSpace($Branch)) { throw 'Branch cannot be empty.' }
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ARGONOV-Branch-Test-" + [guid]::NewGuid().ToString('N'))
$archivePath = Join-Path $testRoot 'branch.zip'
$extractPath = Join-Path $testRoot 'source'
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
try {
    $archiveUri = "https://codeload.github.com/$Repository/zip/refs/heads/$Branch"
    Write-Host "Downloading $Repository ($Branch)..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $archiveUri -OutFile $archivePath -MaximumRedirection 5
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force
    $projectFolder = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1
    if (-not $projectFolder) { throw 'GitHub archive did not contain a project directory.' }
    $projectRoot = $projectFolder.FullName
    $testScript = Join-Path $projectRoot 'tests\Test-Installer.ps1'
    if (-not (Test-Path -LiteralPath $testScript -PathType Leaf)) {
        throw 'Installer test suite was not found in the downloaded branch.'
    }
    Write-Host "Downloaded source: $projectRoot" -ForegroundColor DarkGray
    Write-Host 'Running isolated installer tests...' -ForegroundColor Cyan
    & $testScript
    Write-Host ''
    Write-Host "BRANCH TEST PASSED: $Branch" -ForegroundColor Green
    if ($KeepFiles) { Write-Host "Files retained at: $testRoot" -ForegroundColor DarkGray }
}
finally {
    if (-not $KeepFiles -and (Test-Path -LiteralPath $testRoot)) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
