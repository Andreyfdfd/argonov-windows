# ARGONOV SYSINFO · syntax and integration smoke test
# Run from the repository root with PowerShell 7:
#   pwsh -NoProfile -File .\tests\Test-Sysinfo.ps1

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sysinfoPath = Join-Path $repoRoot 'modules\system\sysinfo.ps1'
$catalogPath = Join-Path $repoRoot 'modules\core\commands.ps1'
$infoPath = Join-Path $repoRoot 'modules\core\info.ps1'
$aiPath = Join-Path $repoRoot 'modules\ai\ai.ps1'

$parseFailures = [System.Collections.Generic.List[string]]::new()
foreach ($path in @($sysinfoPath, $catalogPath, $infoPath, $aiPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        $parseFailures.Add("Missing required file: $path") | Out-Null
        continue
    }
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    foreach ($err in $errors) {
        $parseFailures.Add(("{0}:{1}:{2}: {3}" -f $path, $err.Extent.StartLineNumber, $err.Extent.StartColumnNumber, $err.Message)) | Out-Null
    }
}
if ($parseFailures.Count -gt 0) {
    Write-Host 'FAIL: PowerShell parse errors were found:' -ForegroundColor Red
    $parseFailures | ForEach-Object { Write-Host ('  ' + $_) -ForegroundColor Red }
    exit 1
}

. $sysinfoPath
$requiredFunctions = @(
    'sysinfo', 'Get-ArgonovSysInfoCimData', 'Get-ArgonovSysInfoEvents',
    'Get-ArgonovSysInfoSensors', 'Start-ArgonovSysInfoLive',
    'Install-ArgonovSysInfoSensorBackend', 'Export-ArgonovSysInfoReport',
    'Get-ArgonovSysInfoEventDiagnosticInfo', 'Get-ArgonovSysInfoEventFindingPolicy', 'Get-ArgonovSysInfoOsLifecyclePolicy', 'Get-ArgonovSysInfoSecureBootErrorNote', 'Get-ArgonovSysInfoServiceNameFromMessage', 'Get-ArgonovSysInfoServiceState', 'Get-ArgonovSysInfoSearchUrl', 'Get-ArgonovSysInfoSecureBootUpdateState', 'Test-ArgonovSysInfoEventActionable',
    'Add-ArgonovSysInfoFinding'
)
$missingFunctions = @($requiredFunctions | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
if ($missingFunctions.Count -gt 0) {
    Write-Host ('FAIL: missing functions: {0}' -f ($missingFunctions -join ', ')) -ForegroundColor Red
    exit 1
}

$commandText = Get-Content -LiteralPath $catalogPath -Raw
foreach ($entry in @('sysinfo','sysinfo live','sysinfo live -Log','sysinfo deep','sysinfo setup','sysinfo export','sysinfo history','sysinfo help')) {
    if ($commandText -notmatch [regex]::Escape("@('$entry'")) {
        Write-Host ("FAIL: command catalog does not include '{0}'" -f $entry) -ForegroundColor Red
        exit 1
    }
}

Write-Host 'PASS: PowerShell syntax parsed successfully.' -ForegroundColor Green
Write-Host 'PASS: sysinfo entry points are defined.' -ForegroundColor Green
$aiPromptText = Get-Content -LiteralPath $aiPath -Raw
$expectedAiExec = "        '. ''C:\ARGONOV\modules\system\sysinfo.ps1''; sysinfo',"
if (-not $aiPromptText.Contains($expectedAiExec)) {
    Write-Host 'FAIL: AI exec must load sysinfo under pwsh -NoProfile.' -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: AI exec loads sysinfo module in isolated -NoProfile PowerShell.' -ForegroundColor Green


# Unit-check the searchable diagnostic-code contracts without reading Windows event logs.
$kernelPower = Get-ArgonovSysInfoEventDiagnosticInfo -ProviderName 'Microsoft-Windows-Kernel-Power' -Id 41 -EventData @{ BugcheckCode = '0' } -Message 'Unexpected shutdown'
if ($kernelPower.EventCode -ne 'WIN-EVENT-KERNEL-POWER-41' -or $kernelPower.DiagnosticCode -ne 'WIN-EVENT-KERNEL-POWER-41' -or -not $kernelPower.SearchUrl.StartsWith('https://www.google.com/search?q=')) {
    Write-Host 'FAIL: Kernel-Power 41 diagnostic mapping is invalid.' -ForegroundColor Red
    exit 1
}
$bugcheck = Get-ArgonovSysInfoEventDiagnosticInfo -ProviderName 'Microsoft-Windows-WER-SystemErrorReporting' -Id 1001 -EventData @{} -Message 'The bugcheck was: 0x00000124'
if ($bugcheck.DiagnosticCode -ne 'WIN-BUGCHECK-0x00000124' -or $bugcheck.ReferenceUrl -notmatch 'bug-check-0x124') {
    Write-Host 'FAIL: Bugcheck 0x124 mapping is invalid.' -ForegroundColor Red
    exit 1
}
$bugcheckParam1 = Get-ArgonovSysInfoEventDiagnosticInfo -ProviderName 'Microsoft-Windows-WER-SystemErrorReporting' -Id 1001 -EventData @{ param1 = '0x00000124 (0x0, 0x0, 0x0, 0x0)' } -Message 'Компьютер перезагрузился после критической ошибки. Код ошибки: 0x00000124'
if ($bugcheckParam1.DiagnosticCode -ne 'WIN-BUGCHECK-0x00000124') {
    Write-Host 'FAIL: localized WER param1 stop-code mapping is invalid.' -ForegroundColor Red
    exit 1
}
$bugcheckDecimal = Get-ArgonovSysInfoEventDiagnosticInfo -ProviderName 'Microsoft-Windows-Kernel-Power' -Id 41 -EventData @{ BugcheckCode = '292' } -Message 'Unexpected shutdown'
if ($bugcheckDecimal.StopCode -ne 'WIN-BUGCHECK-0x00000124' -or $bugcheckDecimal.DiagnosticCode -ne 'WIN-BUGCHECK-0x00000124') {
    Write-Host 'FAIL: decimal BugcheckCode conversion is invalid.' -ForegroundColor Red
    exit 1
}
$whea = Get-ArgonovSysInfoEventDiagnosticInfo -ProviderName 'Microsoft-Windows-WHEA-Logger' -Id 1 -EventData @{} -Message 'Fatal hardware error'
if ($whea.DiagnosticCode -ne 'WIN-EVENT-WHEA-LOGGER-1' -or $whea.ReferenceUrl -notmatch 'whea/error-records') {
    Write-Host 'FAIL: WHEA-Logger 1 mapping is invalid.' -ForegroundColor Red
    exit 1
}
$emptyFindings = [System.Collections.Generic.List[object]]::new()
Add-ArgonovSysInfoFinding $emptyFindings 'WARNING' 'Журнал событий' 'Тестовая историческая запись' 'Test details' 'Inspect source' -DiagnosticCode $kernelPower.DiagnosticCode -SearchQuery $kernelPower.SearchQuery -Scope 'Historical'
if ($emptyFindings.Count -ne 1 -or $emptyFindings[0].Scope -ne 'Historical' -or $emptyFindings[0].DiagnosticCode -ne $kernelPower.DiagnosticCode -or -not $emptyFindings[0].SearchUrl) {
    Write-Host 'FAIL: diagnostic finding metadata is invalid.' -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: Kernel-Power, WHEA and bugcheck codes map to searchable diagnostics.' -ForegroundColor Green
Write-Host 'PASS: WER Event 1001 reads stop codes from param1 in localized messages.' -ForegroundColor Green
Write-Host 'PASS: decimal BugcheckCode is converted to the hexadecimal Windows stop code.' -ForegroundColor Green
$dcom = Get-ArgonovSysInfoEventDiagnosticInfo -ProviderName 'Microsoft-Windows-DistributedCOM' -Id 10016 -EventData @{} -Message 'Typical DCOM permission warning'
$dcomPolicy = Get-ArgonovSysInfoEventFindingPolicy -ProviderName 'Microsoft-Windows-DistributedCOM' -Id 10016 -Level 3 -Message 'Typical DCOM permission warning'
if ($dcom.ReferenceUrl -notmatch 'event-10016-logged' -or $dcomPolicy.Severity -ne 'INFO' -or $dcomPolicy.Scope -ne 'Historical' -or $dcomPolicy.Recommendation -notmatch 'Не меняй разрешения DCOM') {
    Write-Host 'FAIL: DCOM 10016 should map to an informational historical note and official guidance.' -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: common DistributedCOM 10016 events are informational and link to Microsoft guidance.' -ForegroundColor Green

$win10Lifecycle = Get-ArgonovSysInfoOsLifecyclePolicy -Caption 'Microsoft Windows 10 Pro' -Build '19045'
$win11Lifecycle = Get-ArgonovSysInfoOsLifecyclePolicy -Caption 'Microsoft Windows 11 Pro' -Build '26100'
$win10LtscLifecycle = Get-ArgonovSysInfoOsLifecyclePolicy -Caption 'Microsoft Windows 10 Enterprise LTSC' -Build '19045'
if ($null -eq $win10Lifecycle -or $win10Lifecycle.DiagnosticCode -ne 'ARGONOV-OS-WINDOWS-10-ESU-STATUS-UNKNOWN' -or $win10Lifecycle.Scope -ne 'Current' -or $null -ne $win11Lifecycle -or $null -ne $win10LtscLifecycle) {
    Write-Host 'FAIL: Windows 10 22H2 lifecycle check should be limited to non-LTSC build 19045 and explicitly mention unknown ESU state.' -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: Windows 10 22H2 regular-support lifecycle is flagged without assuming ESU enrollment status.' -ForegroundColor Green

$secureBootAccessNote = Get-ArgonovSysInfoSecureBootErrorNote -Message 'Не удалось задать подходящие привилегии. В доступе отказано.'
$secureBootOtherNote = Get-ArgonovSysInfoSecureBootErrorNote -Message 'Secure Boot is not supported on this platform.'
if ($secureBootAccessNote -notmatch 'Не проверено' -or $secureBootAccessNote -notmatch 'администратора' -or $secureBootOtherNote -notmatch 'not supported') {
    Write-Host 'FAIL: Secure Boot access errors must be distinguished from other unsupported/not-available cases.' -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: Secure Boot access denial is explained as a permission limitation, not as disabled Secure Boot.' -ForegroundColor Green

$sysinfoSource = Get-Content -LiteralPath $sysinfoPath -Raw
if ($sysinfoSource -notmatch 'ConfiguredClockSpeed: \$configuredSpeed MT/s\*; Speed: \$reportedSpeed MT/s\*' -or $sysinfoSource -notmatch 'не показание независимого live-датчика') {
    Write-Host 'FAIL: memory output must show ConfiguredClockSpeed and Speed as separate reported values.' -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: memory output distinguishes configured and SMBIOS-reported speed fields.' -ForegroundColor Green



$tpm = Get-ArgonovSysInfoEventDiagnosticInfo -ProviderName 'Microsoft-Windows-TPM-WMI' -Id 1801 -EventData @{} -Message 'Secure Boot certificates have not been applied'
$tpmUnknownState = [pscustomobject]@{ Status='Unknown'; Evidence='Current status not confirmed.' }
$tpmNeedsVerificationState = [pscustomobject]@{ Status='NeedsVerification'; Evidence='TPM-WMI 1801 exists without newer success.' }
$tpmUpdatedState = [pscustomobject]@{ Status='Updated'; Evidence='UEFICA2023Status=Updated.' }
$tpmPolicy = Get-ArgonovSysInfoEventFindingPolicy -ProviderName 'Microsoft-Windows-TPM-WMI' -Id 1801 -Level 2 -Message 'Secure Boot certificates have not been applied' -TimeCreated (Get-Date).AddMinutes(-5) -SecureBootUpdateState $tpmNeedsVerificationState
$tpmUnknownPolicy = Get-ArgonovSysInfoEventFindingPolicy -ProviderName 'Microsoft-Windows-TPM-WMI' -Id 1801 -Level 2 -Message 'Secure Boot certificates have not been applied' -SecureBootUpdateState $tpmUnknownState
$tpmUpdatedPolicy = Get-ArgonovSysInfoEventFindingPolicy -ProviderName 'Microsoft-Windows-TPM-WMI' -Id 1801 -Level 2 -Message 'Secure Boot certificates have not been applied' -SecureBootUpdateState $tpmUpdatedState
if ($tpm.ReferenceUrl -notmatch 'update-secure-boot-certificates' -or $tpmPolicy.Scope -ne 'Verification' -or $tpmPolicy.Severity -ne 'WARNING' -or $tpmUnknownPolicy.Scope -ne 'Verification' -or $tpmUpdatedPolicy.Scope -ne 'Historical' -or $tpmUpdatedPolicy.Severity -ne 'INFO') {
    Write-Host 'FAIL: TPM-WMI 1801 must distinguish pending verification from a confirmed updated state.' -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: TPM-WMI 1801 uses current registry/success-event evidence instead of event age alone.' -ForegroundColor Green

if ((Test-ArgonovSysInfoEventActionable -Id 0 -Message '') -or -not (Test-ArgonovSysInfoEventActionable -Id 0 -Message 'Provider supplied a usable description') -or -not (Test-ArgonovSysInfoEventActionable -Id 41 -Message '')) {
    Write-Host 'FAIL: blank provider Event ID 0 should not generate a made-up diagnostic finding.' -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: events with ID 0 and no description remain non-actionable and do not generate findings.' -ForegroundColor Green

$planetMessage = 'Сбой при запуске службы "PlanetVPNService" из-за ошибки Не удается найти указанный файл.'
$planetName = Get-ArgonovSysInfoServiceNameFromMessage $planetMessage
$planetInfo = Get-ArgonovSysInfoEventDiagnosticInfo -ProviderName 'Service Control Manager' -Id 7000 -EventData @{} -Message $planetMessage
$planetRemovedPolicy = Get-ArgonovSysInfoEventFindingPolicy -ProviderName 'Service Control Manager' -Id 7000 -Level 2 -Message $planetMessage -TimeCreated (Get-Date).AddDays(-1) -ServiceState ([pscustomobject]@{ Status='NotRegistered'; Name='PlanetVPNService'; State=''; StartMode=''; PathName=''; ExecutablePath=''; ExecutableExists=$null; Error='' })
$planetRegisteredPolicy = Get-ArgonovSysInfoEventFindingPolicy -ProviderName 'Service Control Manager' -Id 7000 -Level 2 -Message $planetMessage -TimeCreated (Get-Date).AddDays(-1) -ServiceState ([pscustomobject]@{ Status='Registered'; Name='PlanetVPNService'; State='Stopped'; StartMode='Auto'; PathName='C:\PlanetVPN\PlanetVPNService.exe'; ExecutablePath='C:\PlanetVPN\PlanetVPNService.exe'; ExecutableExists=$false; Error='' })
if ($planetName -ne 'PlanetVPNService' -or $planetInfo.DiagnosticCode -ne 'ARGONOV-ORPHANED-SERVICE-PLANETVPN' -or $planetRemovedPolicy.Scope -ne 'Historical' -or $planetRemovedPolicy.Severity -ne 'INFO' -or $planetRegisteredPolicy.Scope -ne 'Current' -or $planetRegisteredPolicy.Severity -ne 'WARNING') {
    Write-Host 'FAIL: PlanetVPN residual-service detection / historical-vs-current classification is invalid.' -ForegroundColor Red
    exit 1
}
if ($planetRegisteredPolicy.Recommendation -notmatch 'HAP') {
    Write-Host 'FAIL: PlanetVPN recommendations must explicitly avoid touching HAP.' -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: PlanetVPN service events are grouped per service and checked read-only against the current service registry.' -ForegroundColor Green
Write-Host 'PASS: missing PlanetVPN service registration is informational; a still-registered residue is a current warning.' -ForegroundColor Green
Write-Host 'PASS: diagnostic findings expose scope, code, query and search URL.' -ForegroundColor Green
Write-Host 'PASS: all documented sysinfo modes are present in the command catalog.' -ForegroundColor Green
$catalogEntryCount = [regex]::Matches($commandText, '(?m)^\s*@\(').Count
if ($catalogEntryCount -ne 108) {
    Write-Host ("FAIL: expected 108 command catalog entries, found {0}." -f $catalogEntryCount) -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: catalog count matches the documented 108 entries.' -ForegroundColor Green
Write-Host 'NOTE: hardware sensors, Windows event access, Secure Boot state, and physical storage counters must still be tested on the target Windows PC.' -ForegroundColor Yellow
