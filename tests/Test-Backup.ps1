# ARGONOV SHELL - backup archive structure smoke test
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("argonov-backup-test_{0}" -f [guid]::NewGuid().ToString('N'))
$projectRoot = Join-Path $testRoot 'project'
$backupRoot = Join-Path $testRoot 'backups'
$modulePath = Join-Path $projectRoot 'modules\tools\backup.ps1'

try {
    New-Item -ItemType Directory -Path (Split-Path -Parent $modulePath) -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $projectRoot 'modules\core') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $projectRoot 'docs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $projectRoot '.git') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $projectRoot 'tests') -Force | Out-Null

    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\modules\tools\backup.ps1') -Destination $modulePath -Force
    Set-Content -LiteralPath (Join-Path $projectRoot 'profile.ps1') -Value '# profile fixture' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $projectRoot 'modules\core\sample.ps1') -Value '# nested module fixture' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $projectRoot 'docs\sample.md') -Value 'documentation fixture' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $projectRoot '.git\config') -Value 'git metadata must be excluded' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $projectRoot '.installed') -Value 'local-only marker' -Encoding utf8

    $global:ARGONOV_ROOT = $projectRoot
    $global:ARGONOV_BACKUP_DIR = $backupRoot
    . $modulePath

    backup 'smoke-test' | Out-Null
    $archives = @(Get-ChildItem -LiteralPath $backupRoot -Filter 'argonov_*.zip' -File)
    if ($archives.Count -ne 1) { throw "Expected one archive, found $($archives.Count)." }

    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    $archive = [System.IO.Compression.ZipFile]::OpenRead($archives[0].FullName)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
        foreach ($required in @('profile.ps1', 'modules/core/sample.ps1', 'docs/sample.md')) {
            if ($entryNames -notcontains $required) { throw "Archive is missing required nested file: $required" }
        }
        foreach ($forbidden in @('.git/config', '.installed')) {
            if ($entryNames -contains $forbidden) { throw "Archive should exclude local artifact: $forbidden" }
        }
    } finally {
        $archive.Dispose()
    }

    Write-Host 'Backup archive structure tests passed.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name ARGONOV_ROOT -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name ARGONOV_BACKUP_DIR -Scope Global -ErrorAction SilentlyContinue
}