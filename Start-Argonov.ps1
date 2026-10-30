# Starts the isolated ARGONOV SHELL runtime installed by Setup.exe.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$runtime = Join-Path $PSScriptRoot 'runtime\pwsh.exe'
$argonovProfile = Join-Path $PSScriptRoot 'profile.ps1'
$modules = Join-Path $PSScriptRoot 'modules'
if (-not (Test-Path -LiteralPath $runtime -PathType Leaf)) { throw "Bundled PowerShell runtime was not found: $runtime" }
if (-not (Test-Path -LiteralPath $argonovProfile -PathType Leaf)) { throw "ARGONOV profile was not found: $argonovProfile" }
if (-not (Test-Path -LiteralPath $modules -PathType Container)) { throw "ARGONOV modules folder was not found: $modules" }
. $argonovProfile
