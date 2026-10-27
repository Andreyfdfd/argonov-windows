# ARGONOV proxy settings safety tests.
# Uses a temporary registry key and temporary files; never touches real Internet Settings.
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion -lt [version]'7.6') {
    Write-Warning 'Proxy settings tests require PowerShell 7.6+; tests skipped.'
    exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot 'modules\network\proxy.ps1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) { throw "Missing proxy module: $modulePath" }

$testId = [guid]::NewGuid().ToString('N')
$tempRoot = Join-Path $env:TEMP "argonov-proxy-test_$testId"
$registryPath = "HKCU:\Software\ARGONOV_PROXY_TEST_$testId"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
New-Item -Path $registryPath -Force | Out-Null

$global:ARGONOV_PROXY_DIR = Join-Path $tempRoot 'proxy-data'
$global:ARGONOV_PROXY_REGISTRY_PATH = $registryPath
$global:ARGONOV_PROXY_STATE_FILE = Join-Path $tempRoot 'original-settings.json'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Assert-Equal {
    param([string]$Name, $Expected, $Actual)
    if ($Expected -cne $Actual) { throw "$Name mismatch. Expected=[$Expected], Actual=[$Actual]" }
}

try {
    New-ItemProperty -LiteralPath $registryPath -Name ProxyEnable -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -LiteralPath $registryPath -Name ProxyServer -Value 'original.proxy.invalid:3128' -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $registryPath -Name ProxyOverride -Value 'localhost;*.internal' -PropertyType String -Force | Out-Null

    . $modulePath
    $workingPath = Join-Path $global:ARGONOV_PROXY_DIR 'working.txt'
    $validLines = @(
        'http://192.0.2.10:8080 | 12 ms | 203.0.113.20',
        'http://198.51.100.7:8888 | 20 ms | 203.0.113.21'
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($workingPath, $validLines, $utf8NoBom)

    # Invalid proxy lines must not create snapshots or mutate registry values.
    [System.IO.File]::WriteAllText($workingPath, 'http://999.999.1.1:99999 | 1 ms | 1.1.1.1', $utf8NoBom)
    proxy-use -Index 1 -Force
    $props = Get-ItemProperty -LiteralPath $registryPath
    Assert-Equal 'Invalid entry must not enable proxy' 0 $props.ProxyEnable
    if (Test-Path -LiteralPath $global:ARGONOV_PROXY_STATE_FILE) {
        throw 'Invalid proxy entry unexpectedly created a settings snapshot.'
    }

    # A valid proxy saves the original settings before updating Windows settings.
    [System.IO.File]::WriteAllText($workingPath, $validLines, $utf8NoBom)
    proxy-use -Index 1 -Force
    $props = Get-ItemProperty -LiteralPath $registryPath
    Assert-Equal 'ProxyEnable after apply' 1 $props.ProxyEnable
    Assert-Equal 'ProxyServer after apply' '192.0.2.10:8080' $props.ProxyServer
    Assert-Equal 'ProxyOverride after apply' '<local>' $props.ProxyOverride
    if (-not (Test-Path -LiteralPath $global:ARGONOV_PROXY_STATE_FILE -PathType Leaf)) {
        throw 'No proxy state snapshot was created.'
    }
    $snapshot = Get-Content -LiteralPath $global:ARGONOV_PROXY_STATE_FILE -Raw | ConvertFrom-Json
    Assert-Equal 'Snapshot original ProxyServer' 'original.proxy.invalid:3128' $snapshot.Values.ProxyServer.Value
    Assert-Equal 'Snapshot original ProxyOverride' 'localhost;*.internal' $snapshot.Values.ProxyOverride.Value

    # Switching proxies must not overwrite the first saved baseline.
    proxy-use -Index 2 -Force
    $props = Get-ItemProperty -LiteralPath $registryPath
    Assert-Equal 'ProxyServer after switch' '198.51.100.7:8888' $props.ProxyServer
    $snapshot = Get-Content -LiteralPath $global:ARGONOV_PROXY_STATE_FILE -Raw | ConvertFrom-Json
    Assert-Equal 'Snapshot remains original after switch' 'original.proxy.invalid:3128' $snapshot.Values.ProxyServer.Value

    proxy-clear -Force
    $props = Get-ItemProperty -LiteralPath $registryPath
    Assert-Equal 'ProxyEnable after restore' 0 $props.ProxyEnable
    Assert-Equal 'ProxyServer after restore' 'original.proxy.invalid:3128' $props.ProxyServer
    Assert-Equal 'ProxyOverride after restore' 'localhost;*.internal' $props.ProxyOverride
    if (Test-Path -LiteralPath $global:ARGONOV_PROXY_STATE_FILE) {
        throw 'Snapshot was not removed after successful restore.'
    }

    # Registry values that did not exist originally must be removed during restore.
    Remove-ItemProperty -LiteralPath $registryPath -Name ProxyServer -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $registryPath -Name ProxyOverride -ErrorAction SilentlyContinue
    proxy-use -Index 1 -Force
    proxy-clear -Force
    $props = Get-ItemProperty -LiteralPath $registryPath
    Assert-Equal 'ProxyEnable after absent-value restore' 0 $props.ProxyEnable
    if ($props.PSObject.Properties['ProxyServer']) { throw 'Restore left ProxyServer although it was absent initially.' }
    if ($props.PSObject.Properties['ProxyOverride']) { throw 'Restore left ProxyOverride although it was absent initially.' }

    Write-Host 'Proxy invalid-entry validation test passed.' -ForegroundColor Green
    Write-Host 'Proxy settings snapshot and restore test passed.' -ForegroundColor Green
    Write-Host 'Proxy switch preserves first snapshot test passed.' -ForegroundColor Green
    Write-Host 'Proxy absent-value restoration test passed.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $registryPath -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name ARGONOV_PROXY_DIR -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name ARGONOV_PROXY_REGISTRY_PATH -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name ARGONOV_PROXY_STATE_FILE -Scope Global -ErrorAction SilentlyContinue
}
