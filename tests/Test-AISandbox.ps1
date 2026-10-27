# ARGONOV SHELL - AI sandbox path-boundary smoke test
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$global:ARGONOV_ROOT = $projectRoot

. (Join-Path $projectRoot 'modules\ai\ai.ps1')

$insidePath = Join-Path $projectRoot 'profile.ps1'
if (-not (ai-is-sandbox -Path $insidePath)) {
    throw "Expected the project profile to be inside the AI sandbox: $insidePath"
}

# Isolate the project root so broader home-folder allowances cannot mask a prefix bug.
$originalSandbox = @($script:AI_SANDBOX)
try {
    $script:AI_SANDBOX = @($projectRoot)
    $prefixLookalike = "$projectRoot-OUTSIDE\secret.txt"
    if (ai-is-sandbox -Path $prefixLookalike) {
        throw "A sibling path sharing the project-root prefix was incorrectly allowed: $prefixLookalike"
    }

    $outsidePath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '..\ARGONOV-OUTSIDE\secret.txt'))
    if (ai-is-sandbox -Path $outsidePath) {
        throw "A path outside the project root was incorrectly allowed: $outsidePath"
    }
} finally {
    $script:AI_SANDBOX = $originalSandbox
}

Write-Host 'AI sandbox boundary tests passed.' -ForegroundColor Green