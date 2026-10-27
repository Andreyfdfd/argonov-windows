# ARGONOV wget safety tests. Downloads are mocked; no external network is used.
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.6') {
    Write-Warning 'wget safety tests require PowerShell 7.6+; tests skipped.'
    exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$networkPath = Join-Path $repoRoot 'modules\network\network.ps1'
if (-not (Test-Path -LiteralPath $networkPath -PathType Leaf)) { throw "Missing network module: $networkPath" }

$tempRoot = Join-Path $env:TEMP ('argonov-wget-test_{0}' -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$script:MockRequestCount = 0
$script:MockFailure = $false
$script:MockPayload = 'simulated download payload'

function Invoke-WebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Uri]$Uri,
        [Parameter(Mandatory)][string]$OutFile,
        [switch]$UseBasicParsing,
        [int]$TimeoutSec = 30
    )
    $script:MockRequestCount++
    if ($script:MockFailure) { throw 'Simulated network failure.' }
    [System.IO.File]::WriteAllText($OutFile, $script:MockPayload)
}

function Assert-Equal {
    param([string]$Name, $Expected, $Actual)
    if ($Expected -cne $Actual) { throw "$Name mismatch. Expected=[$Expected], Actual=[$Actual]" }
}

try {
    Push-Location $tempRoot
    . $networkPath

    $resolved = Get-Command wget -ErrorAction Stop
    Assert-Equal 'wget must resolve to the ARGONOV function' 'Function' $resolved.CommandType.ToString()

    # Reject non-HTTP schemes without invoking the download command.
    wget -Url 'file:///C:/Windows/win.ini' -Out (Join-Path $tempRoot 'rejected.txt')
    Assert-Equal 'Unsafe scheme must not trigger download' 0 $script:MockRequestCount
    if (Test-Path -LiteralPath (Join-Path $tempRoot 'rejected.txt')) { throw 'Unsafe scheme created a destination file.' }

    # Query strings do not become part of the default filename.
    wget -Url 'https://example.invalid/assets/sample.txt?token=ignored'
    $samplePath = Join-Path $tempRoot 'sample.txt'
    if (-not (Test-Path $samplePath -PathType Leaf)) { throw 'URL query handling did not create sample.txt.' }
    Assert-Equal 'Mock payload saved' $script:MockPayload ([System.IO.File]::ReadAllText($samplePath))
    Assert-Equal 'One successful mock download' 1 $script:MockRequestCount

    # Existing files are preserved unless -Force was explicitly supplied.
    $existingPath = Join-Path $tempRoot 'existing.txt'
    [System.IO.File]::WriteAllText($existingPath, 'preserve original', [System.Text.UTF8Encoding]::new($false))
    wget -Url 'https://example.invalid/assets/new.txt' -Out $existingPath
    Assert-Equal 'Existing output preserved by default' 'preserve original' ([System.IO.File]::ReadAllText($existingPath))
    Assert-Equal 'No download when output exists without Force' 1 $script:MockRequestCount

    # -WhatIf never invokes the downloader or changes a destination.
    $whatIfPath = Join-Path $tempRoot 'whatif.txt'
    wget -Url 'https://example.invalid/whatif.txt' -Out $whatIfPath -WhatIf
    if (Test-Path -LiteralPath $whatIfPath) { throw '-WhatIf unexpectedly created an output file.' }
    Assert-Equal 'WhatIf does not invoke downloader' 1 $script:MockRequestCount

    # An explicit -Force allows replacement, but only after a successful temp-file download.
    wget -Url 'https://example.invalid/new-payload.txt?x=1' -Out $existingPath -Force
    Assert-Equal 'Force replacement payload' $script:MockPayload ([System.IO.File]::ReadAllText($existingPath))
    Assert-Equal 'Force invoked downloader once' 2 $script:MockRequestCount

    # A failed download must not destroy an existing destination or leave temp files.
    [System.IO.File]::WriteAllText($existingPath, 'must survive failure', [System.Text.UTF8Encoding]::new($false))
    $script:MockFailure = $true
    wget -Url 'https://example.invalid/fails.txt' -Out $existingPath -Force
    Assert-Equal 'Existing output survives failed download' 'must survive failure' ([System.IO.File]::ReadAllText($existingPath))
    $tempFiles = @(Get-ChildItem -LiteralPath $tempRoot -Filter '.argonov-download-*.tmp' -File -ErrorAction SilentlyContinue)
    if ($tempFiles.Count -ne 0) { throw 'A temporary download file was left after failure.' }

    Write-Host 'wget HTTP/HTTPS validation test passed.' -ForegroundColor Green
    Write-Host 'wget query-string filename test passed.' -ForegroundColor Green
    Write-Host 'wget no-overwrite and -Force tests passed.' -ForegroundColor Green
    Write-Host 'wget -WhatIf test passed.' -ForegroundColor Green
    Write-Host 'wget failed-download preservation test passed.' -ForegroundColor Green
}
finally {
    if ((Get-Location).Path -eq $tempRoot) { Pop-Location }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
