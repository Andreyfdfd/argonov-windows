# Starts ARGONOV SHELL using the shared, per-user PowerShell runtime.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$runtime = Join-Path $PSHOME 'pwsh.exe'
$argonovProfile = Join-Path $PSScriptRoot 'profile.ps1'
$modules = Join-Path $PSScriptRoot 'modules'
if (-not (Test-Path -LiteralPath $runtime -PathType Leaf)) { throw "Shared PowerShell runtime was not found: $runtime" }
if ($PSVersionTable.PSVersion -lt [version]'7.6') { throw "ARGONOV SHELL requires PowerShell 7.6 or newer. Current runtime: $($PSVersionTable.PSVersion)" }
if (-not (Test-Path -LiteralPath $argonovProfile -PathType Leaf)) { throw "ARGONOV profile was not found: $argonovProfile" }
if (-not (Test-Path -LiteralPath $modules -PathType Container)) { throw "ARGONOV modules folder was not found: $modules" }
. $argonovProfile
