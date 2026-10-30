# ARGONOV SHELL · sysinfo v2.3
# Read-only Windows diagnostics, sensor telemetry, reliability counters, and event analysis.
# Optional sensor backend is installed explicitly by: sysinfo setup

$script:ARGONOV_SYSINFO_ROOT = Join-Path $HOME '.argonov\sysinfo'
$script:ARGONOV_SYSINFO_REPORTS = Join-Path $script:ARGONOV_SYSINFO_ROOT 'reports'
$script:ARGONOV_SYSINFO_LHM_DIR = if (-not [string]::IsNullOrWhiteSpace($env:ARGONOV_SYSINFO_LHM_DIR)) {
    [System.IO.Path]::GetFullPath($env:ARGONOV_SYSINFO_LHM_DIR)
} else {
    Join-Path $env:LOCALAPPDATA 'ARGONOV\tools\LibreHardwareMonitor'
}
$script:ARGONOV_SYSINFO_HISTORY = Join-Path $script:ARGONOV_SYSINFO_ROOT 'history.csv'
$script:ARGONOV_SYSINFO_VERSION = '2.3.0'
$script:ARGONOV_SYSINFO_LHM_RESOLVER_REGISTERED = $false
$script:ARGONOV_SYSINFO_LHM_RESOLVER = $null

function Initialize-ArgonovSysInfoPaths {
    foreach ($path in @($script:ARGONOV_SYSINFO_ROOT, $script:ARGONOV_SYSINFO_REPORTS)) {
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

function Get-ArgonovSysInfoProperty {
    param(
        [AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][object]$Default = $null
    )
    if ($null -eq $InputObject) { return $Default }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    if ($null -eq $property.Value -or [string]::IsNullOrWhiteSpace([string]$property.Value)) { return $Default }
    return $property.Value
}

function Format-ArgonovSysInfoBytes {
    param([AllowNull()][Nullable[long]]$Bytes)
    if ($null -eq $Bytes) { return 'нет данных' }
    if ($Bytes -ge 1TB) { return ('{0:N2} ТБ' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} ГБ' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} МБ' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N1} КБ' -f ($Bytes / 1KB)) }
    return ("{0} Б" -f $Bytes)
}

function Get-ArgonovSysInfoSecureBootErrorNote {
    param([AllowNull()][string]$Message)
    if ([string]::IsNullOrWhiteSpace($Message)) {
        return 'Не проверено: Windows не предоставила статус Secure Boot.'
    }
    if ($Message -match '(?i)access is denied|доступ.{0,25}отказан|привилеги') {
        return 'Не проверено: Windows отказала в доступе. Повтори sysinfo deep из PowerShell 7, запущенного от имени администратора.'
    }
    return ($Message -replace '\s+', ' ').Trim()
}

function Get-ArgonovSysInfoErrorText {
    param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord)
    $message = $ErrorRecord.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { return 'Подробности ошибки недоступны.' }
    return (($message -replace '\s+', ' ').Trim())
}

function Get-ArgonovSysInfoSlug {
    param([AllowNull()][string]$Text)
    $slug = [regex]::Replace(([string]$Text).ToUpperInvariant(), '[^A-Z0-9]+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($slug)) { return 'UNKNOWN' }
    if ($slug.Length -gt 48) { $slug = $slug.Substring(0, 48).Trim('-') }
    return $slug
}

function Get-ArgonovSysInfoSearchUrl {
    param([Parameter(Mandatory)][string]$Query)
    return ('https://www.google.com/search?q={0}' -f [uri]::EscapeDataString($Query))
}

function Get-ArgonovSysInfoDefaultDiagnostic {
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Details
    )

    $code = ''
    $query = ''
    $reference = ''

    if ($Category -eq 'Устройство' -and $Details -match '(?i)Problem\s*=\s*(\d+)') {
        $deviceCode = [int]$Matches[1]
        if ($deviceCode -gt 0) {
            $code = "WIN-DEVICE-MANAGER-CODE-$deviceCode"
            $query = "Microsoft Windows Device Manager error Code $deviceCode"
            $reference = 'https://learn.microsoft.com/en-us/windows-hardware/drivers/install/device-manager-error-messages'
        }
    }

    if (-not $code) {
        switch -Regex ($Category + ' ' + $Title) {
            '(?i)Память.*Критически мало|Критически мало свободной ОЗУ' {
                $code = 'ARGONOV-RAM-CRITICAL-USAGE'; break
            }
            '(?i)Память.*Высокая загрузка|Высокая загрузка ОЗУ' {
                $code = 'ARGONOV-RAM-HIGH-USAGE'; break
            }
            '(?i)Накопитель.*почти закончилось место|почти закончилось место' {
                $code = 'ARGONOV-DISK-FREE-SPACE-CRITICAL'; break
            }
            '(?i)Мало свободного места|мало свободного места' {
                $code = 'ARGONOV-DISK-FREE-SPACE-LOW'; break
            }
            '(?i)диск проблемным|предупреждение о диске' {
                $code = 'ARGONOV-DISK-HEALTH-STATUS'; break
            }
            '(?i)неисправленные ошибки' {
                $code = 'ARGONOV-DISK-UNCORRECTED-IO-ERRORS'; break
            }
            '(?i)температура' {
                $code = 'ARGONOV-HARDWARE-TEMPERATURE-HIGH'; break
            }
            '(?i)аппаратные датчики|сенсорные данные|данных аппаратных датчиков' {
                $code = 'ARGONOV-SENSOR-DATA-UNAVAILABLE'; break
            }
            '(?i)Defender|защита .*выключена' {
                $code = 'ARGONOV-WINDOWS-REALTIME-PROTECTION-OFF'; break
            }
            '(?i)Secure Boot' {
                $code = 'ARGONOV-SECURE-BOOT-DISABLED'; break
            }
            '(?i)не все журналы удалось прочитать' {
                $code = 'ARGONOV-EVENT-LOG-ACCESS-LIMITED'; break
            }
            default {
                $categoryCode = switch ($Category) {
                    'Память' { 'RAM' }
                    'Накопитель' { 'DISK' }
                    'Устройство' { 'DEVICE' }
                    'Журнал событий' { 'EVENT' }
                    'Температура' { 'TEMP' }
                    'Безопасность' { 'SECURITY' }
                    'Аппаратные датчики' { 'SENSOR' }
                    default { 'SYSTEM' }
                }
                $identityBytes = [System.Text.Encoding]::UTF8.GetBytes(($Category + '|' + $Title))
                $identityHash = [System.Security.Cryptography.SHA256]::HashData($identityBytes)
                $shortHash = [Convert]::ToHexString($identityHash).Substring(0, 8)
                $code = "ARGONOV-$categoryCode-$shortHash"
            }
        }
    }

    if (-not $query) {
        $query = ('Windows troubleshooting: {0} — {1}' -f $Category, $Title)
        if ($code -like 'ARGONOV-DISK-*') {
            $query = ('Windows disk troubleshooting: {0}' -f $Title)
        } elseif ($code -like 'ARGONOV-RAM-*') {
            $query = ('Windows RAM usage troubleshooting: {0}' -f $Title)
        } elseif ($code -like 'ARGONOV-HARDWARE-TEMPERATURE-*') {
            $query = ('PC hardware temperature troubleshooting: {0}' -f $Title)
        }
    }

    return [pscustomobject]@{
        DiagnosticCode = $code
        SearchQuery = $query
        SearchUrl = Get-ArgonovSysInfoSearchUrl -Query $query
        ReferenceUrl = $reference
    }
}

function Add-ArgonovSysInfoFinding {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Findings,
        [Parameter(Mandatory)][ValidateSet('CRITICAL','WARNING','INFO','UNKNOWN')][string]$Severity,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Details,
        [string]$Recommendation = '',
        [string]$DiagnosticCode = '',
        [string]$SearchQuery = '',
        [string]$ReferenceUrl = '',
        [ValidateSet('Current','Historical','Verification','DataLimit')][string]$Scope = 'Current'
    )

    $defaults = Get-ArgonovSysInfoDefaultDiagnostic -Category $Category -Title $Title -Details $Details
    if ([string]::IsNullOrWhiteSpace($DiagnosticCode)) { $DiagnosticCode = $defaults.DiagnosticCode }
    if ([string]::IsNullOrWhiteSpace($SearchQuery)) { $SearchQuery = $defaults.SearchQuery }
    $searchUrl = Get-ArgonovSysInfoSearchUrl -Query $SearchQuery
    if ([string]::IsNullOrWhiteSpace($ReferenceUrl)) { $ReferenceUrl = $defaults.ReferenceUrl }

    $Findings.Add([pscustomobject]@{
        Severity = $Severity
        Scope = $Scope
        Category = $Category
        Title = $Title
        Details = $Details
        Recommendation = $Recommendation
        DiagnosticCode = $DiagnosticCode
        SearchQuery = $SearchQuery
        SearchUrl = $searchUrl
        ReferenceUrl = $ReferenceUrl
    }) | Out-Null
}

function Get-ArgonovSysInfoEventData {
    param([Parameter(Mandatory)][object]$EventRecord)

    $values = [ordered]@{}
    $rawDataLength = 0
    try {
        $xmlDocument = [System.Xml.XmlDocument]::new()
        $xmlDocument.LoadXml([string]$EventRecord.ToXml())
        $nodes = $xmlDocument.SelectNodes('/*[local-name()="Event"]/*[local-name()="EventData"]/*[local-name()="Data"]')
        $index = 0
        foreach ($node in $nodes) {
            $index++
            $name = $node.GetAttribute('Name')
            if ([string]::IsNullOrWhiteSpace($name)) { $name = "Data$index" }
            $value = [string]$node.InnerText
            if ($name -eq 'RawData') {
                $rawDataLength = $value.Length
                continue
            }
            if ($value.Length -gt 512) { $value = $value.Substring(0, 512) + '…[truncated]' }
            $values[$name] = $value
        }
    } catch {}

    return [pscustomobject]@{ Values = $values; RawDataLength = $rawDataLength }
}

function Get-ArgonovSysInfoOsLifecyclePolicy {
    param(
        [AllowNull()][string]$Caption,
        [AllowNull()][string]$Build
    )
    # Windows 10 22H2 (19045) has passed regular support. ESU enrollment is
    # not inferable from OS build alone, so this is an enrollment-status check,
    # not a claim that the PC definitely receives no security updates.
    if ($Caption -notmatch '(?i)Windows\s+10' -or $Build -ne '19045' -or $Caption -match '(?i)LTSC|IoT') {
        return $null
    }
    return [pscustomobject]@{
        Severity = 'WARNING'
        Scope = 'Current'
        Category = 'Поддержка Windows'
        Title = 'Windows 10 22H2 — проверь регистрацию в ESU'
        Details = 'Обычная поддержка Windows 10 завершилась 14 октября 2025 года. По версии ОС невозможно установить, зарегистрирован ли компьютер в программе Extended Security Updates (ESU); наличие свежих антивирусных баз само по себе не подтверждает получение системных исправлений безопасности.'
        Recommendation = 'Открой Центр обновления Windows и проверь статус ESU. Если устройство не зарегистрировано, рассмотри регистрацию ESU или переход на поддерживаемую версию Windows. ARGONOV не меняет редакцию, лицензию или обновления.'
        DiagnosticCode = 'ARGONOV-OS-WINDOWS-10-ESU-STATUS-UNKNOWN'
        SearchQuery = 'Microsoft Support Windows 10 support ended October 14 2025 consumer ESU enrollment'
        ReferenceUrl = 'https://support.microsoft.com/en-us/windows/deployment/updates-lifecycle/windows-10-support-has-ended-on-october-14-2025'
    }
}

function Get-ArgonovSysInfoServiceNameFromMessage {
    param([AllowNull()][string]$Message)
    if ([string]::IsNullOrWhiteSpace($Message)) { return '' }
    # Event messages are localized, but the service name itself is typically unchanged.
    if ($Message -match '(?i)(?:служб[аыуе]|service)\s+"(?<name>[^"]+)"') {
        return ([string]$Matches['name']).Trim()
    }
    if ($Message -match "(?i)(?:служб[аыуе]|service)\s+'(?<name>[^']+)'") {
        return ([string]$Matches['name']).Trim()
    }
    return ''
}

function Get-ArgonovSysInfoServiceState {
    param([Parameter(Mandatory)][string]$Name)
    try {
        $escapedName = $Name.Replace("'", "''")
        $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$escapedName'" -ErrorAction Stop | Select-Object -First 1
        if ($null -eq $service) {
            return [pscustomobject]@{ Status = 'NotRegistered'; Name = $Name; State = ''; StartMode = ''; PathName = ''; ExecutablePath = ''; ExecutableExists = $null; Error = '' }
        }

        $pathName = [string]$service.PathName
        $expandedPath = [Environment]::ExpandEnvironmentVariables($pathName)
        $executablePath = ''
        if ($expandedPath -match '^\s*"(?<exe>[^"]+\.exe)"') {
            $executablePath = $Matches['exe']
        } elseif ($expandedPath -match '^\s*(?<exe>.+?\.exe)(?:\s|$)') {
            $executablePath = $Matches['exe']
        }
        $executableExists = $null
        if ($executablePath -and [IO.Path]::IsPathRooted($executablePath)) {
            $executableExists = Test-Path -LiteralPath $executablePath -PathType Leaf
        }
        return [pscustomobject]@{
            Status = 'Registered'
            Name = [string]$service.Name
            State = [string]$service.State
            StartMode = [string]$service.StartMode
            PathName = $pathName
            ExecutablePath = $executablePath
            ExecutableExists = $executableExists
            Error = ''
        }
    } catch {
        return [pscustomobject]@{ Status = 'Unknown'; Name = $Name; State = ''; StartMode = ''; PathName = ''; ExecutablePath = ''; ExecutableExists = $null; Error = (Get-ArgonovSysInfoErrorText $_) }
    }
}

function Get-ArgonovSysInfoSecureBootUpdateState {
    # Read-only assessment. A TPM-WMI 1801 is historical evidence; current status
    # is better inferred from UEFICA2023Status and/or a later successful event 1808.
    $registryStatus = ''
    $registryError = ''
    $servicingError = ''
    $lastFailure = $null
    $lastSuccess = $null
    $secureBootPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'

    try {
        $key = Get-ItemProperty -LiteralPath $secureBootPath -ErrorAction Stop
        if ($key.PSObject.Properties['UEFICA2023Status']) {
            $registryStatus = [string]$key.UEFICA2023Status
        }
    } catch {
        $registryError = Get-ArgonovSysInfoErrorText $_
    }

    try {
        $servicingKey = Get-ItemProperty -LiteralPath (Join-Path $secureBootPath 'Servicing') -ErrorAction Stop
        if ($servicingKey.PSObject.Properties['UEFICA2023Error']) {
            $servicingError = [string]$servicingKey.UEFICA2023Error
        }
    } catch {}

    try {
        $secureBootEvents = @(
            Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                ProviderName = 'Microsoft-Windows-TPM-WMI'
                Id = @(1801, 1808)
                StartTime = (Get-Date).AddDays(-180)
            } -MaxEvents 100 -ErrorAction Stop
        )
        $lastFailure = @($secureBootEvents | Where-Object Id -eq 1801 | Sort-Object TimeCreated -Descending | Select-Object -First 1) | Select-Object -First 1
        $lastSuccess = @($secureBootEvents | Where-Object Id -eq 1808 | Sort-Object TimeCreated -Descending | Select-Object -First 1) | Select-Object -First 1
    } catch {}

    $state = 'Unknown'
    $evidence = 'Не удалось подтвердить текущее состояние сертификатов Secure Boot по доступным данным.'
    if ($registryStatus -ieq 'Updated') {
        $state = 'Updated'
        $evidence = 'Реестр сообщает UEFICA2023Status=Updated.'
    } elseif ($null -ne $lastSuccess -and ($null -eq $lastFailure -or $lastSuccess.TimeCreated -gt $lastFailure.TimeCreated)) {
        $state = 'Updated'
        $evidence = ('Последнее событие TPM-WMI 1808 (успешное применение сертификатов): {0}.' -f $lastSuccess.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))
    } elseif ($null -ne $lastFailure) {
        $state = 'NeedsVerification'
        $evidence = ('Найдено TPM-WMI 1801 от {0}; более позднее подтверждение 1808 или UEFICA2023Status=Updated не обнаружено.' -f $lastFailure.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))
    }

    if (-not [string]::IsNullOrWhiteSpace($servicingError)) {
        $evidence += (' Последняя ошибка обновления UEFICA2023Error={0}.' -f $servicingError)
    }

    $display = switch ($state) {
        'Updated' { 'Подтверждено обновление сертификатов Secure Boot' }
        'NeedsVerification' { 'Требуется проверить применение сертификатов Secure Boot' }
        default { 'Статус сертификатов Secure Boot не подтверждён доступными данными' }
    }

    return [pscustomobject]@{
        Status = $state
        Display = $display
        Evidence = $evidence
        RegistryStatus = $registryStatus
        RegistryError = $registryError
        ServicingError = $servicingError
        LastFailureTime = if ($null -ne $lastFailure) { $lastFailure.TimeCreated } else { $null }
        LastSuccessTime = if ($null -ne $lastSuccess) { $lastSuccess.TimeCreated } else { $null }
    }
}

function Test-ArgonovSysInfoEventActionable {
    param(
        [Parameter(Mandatory)][int]$Id,
        [AllowNull()][string]$Message = ''
    )
    # Some third-party providers emit ID 0 without a rendered message. Keep the
    # raw event visible, but do not manufacture a diagnostic code or finding.
    return -not ($Id -eq 0 -and [string]::IsNullOrWhiteSpace($Message))
}

function Get-ArgonovSysInfoEventFindingPolicy {
    param(
        [Parameter(Mandatory)][string]$ProviderName,
        [Parameter(Mandatory)][int]$Id,
        [Parameter(Mandatory)][int]$Level,
        [AllowNull()][string]$Message = '',
        [AllowNull()][object]$TimeCreated = $null,
        [AllowNull()][object]$ServiceState = $null,
        [AllowNull()][object]$SecureBootUpdateState = $null
    )

    $policy = [ordered]@{
        Severity = if ($Level -le 2) { 'WARNING' } else { 'INFO' }
        Scope = 'Historical'
        Title = "Исторические события: $ProviderName ($Id)"
        DetailsSuffix = ''
        Recommendation = 'Сопоставь время с тем, что происходило в этот момент. Если событие не повторяется после исправления, зафиксируй его как историю; при повторении запусти sysinfo deep и проверь подробную запись.'
        DiagnosticCode = ''
        SearchQuery = ''
        ReferenceUrl = ''
    }

    if ($ProviderName -match '(?i)DistributedCOM' -and $Id -eq 10016) {
        $policy.Severity = 'INFO'
        $policy.Title = 'DistributedCOM 10016 — обычно ожидаемое событие Windows'
        $policy.DetailsSuffix = ' Microsoft описывает типовые DistributedCOM 10016 как поведение по замыслу; если нет связанного сбоя приложения, их обычно можно игнорировать.'
        $policy.Recommendation = 'Не меняй разрешения DCOM ради подавления одной этой записи: Microsoft предупреждает о возможных побочных эффектах. Исследуй конкретное приложение только при совпадающих симптомах.'
        $policy.ReferenceUrl = 'https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/event-10016-logged-when-accessing-dcom'
        $policy.SearchQuery = 'Microsoft Learn DistributedCOM Event ID 10016 can be safely ignored by design'
    }

    if ($ProviderName -match '(?i)TPM-WMI' -and $Id -eq 1801) {
        $policy.Severity = 'WARNING'
        $policy.Scope = 'Verification'
        $policy.Title = 'TPM-WMI 1801 — требуется проверить состояние сертификатов Secure Boot'
        $policy.DetailsSuffix = ' Событие 1801 говорит, что на момент записи обновлённые сертификаты/загрузчик не были применены к прошивке. Оно само по себе не доказывает, что проблема остаётся сейчас.'
        $policy.Recommendation = 'Проверь актуальный статус UEFICA2023Status и наличие более позднего TPM-WMI 1808 в Windows. Если обновление не подтверждено, следуй официальному руководству Microsoft и проверь доступность обновления прошивки платы. Не редактируй Secure Boot DB/DBX/KEK вручную.'
        $policy.ReferenceUrl = 'https://learn.microsoft.com/en-us/troubleshoot/windows-client/windows-security/update-secure-boot-certificates'
        $policy.SearchQuery = 'Microsoft Learn TPM-WMI Event ID 1801 1808 UEFICA2023Status Secure Boot certificates'
        if ($null -ne $SecureBootUpdateState) {
            $policy.DetailsSuffix += (' Текущая проверка: {0}' -f $SecureBootUpdateState.Evidence)
            if ($SecureBootUpdateState.Status -eq 'Updated') {
                $policy.Severity = 'INFO'
                $policy.Scope = 'Historical'
                $policy.Title = 'TPM-WMI 1801 — историческое событие; обновление Secure Boot подтверждено'
                $policy.Recommendation = 'Текущие данные указывают на успешное применение обновления. Сохрани запись как историю; повторных действий не требуется, если новые ошибки не появляются.'
            }
        }
    }

    if ($ProviderName -match '(?i)Service Control Manager' -and $Id -eq 7000) {
        $serviceName = Get-ArgonovSysInfoServiceNameFromMessage $Message
        if ($serviceName -ieq 'PlanetVPNService') {
            $policy.DiagnosticCode = 'ARGONOV-ORPHANED-SERVICE-PLANETVPN'
            $policy.SearchQuery = 'PlanetVPNService service failed to start file not found Windows Event ID 7000'
            $policy.ReferenceUrl = 'https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-query'
            if ($null -eq $ServiceState) { $ServiceState = Get-ArgonovSysInfoServiceState -Name $serviceName }
            if ($ServiceState.Status -eq 'NotRegistered') {
                $policy.Severity = 'INFO'
                $policy.Title = 'Старая запись журнала от удалённой PlanetVPNService'
                $policy.DetailsSuffix = ' Текущая проверка Win32_Service не обнаружила PlanetVPNService среди зарегистрированных служб. Это похоже на исторический журнал после удаления приложения; сейчас удалять нечего.'
                $policy.Recommendation = 'Ничего не удаляй и не меняй. Это историческое событие PlanetVPN, оно не указывает на проблему HAP.'
            } elseif ($ServiceState.Status -eq 'Registered') {
                $policy.Severity = 'WARNING'
                $policy.Scope = 'Current'
                $policy.Title = 'Осталась зарегистрированная служба PlanetVPNService'
                $binaryState = if ($ServiceState.ExecutableExists -eq $false) { 'Файл исполняемого модуля не найден.' } elseif ($ServiceState.ExecutableExists -eq $true) { 'Файл исполняемого модуля существует.' } else { 'Наличие файла исполняемого модуля проверить не удалось.' }
                $policy.DetailsSuffix = (' Служба всё ещё зарегистрирована в Windows: состояние={0}; запуск={1}; путь={2}. {3}' -f $ServiceState.State, $ServiceState.StartMode, $ServiceState.PathName, $binaryState)
                $policy.Recommendation = 'Это не HAP: программа не трогает HAP и ничего не удаляет. Проверь конфигурацию командой sc.exe qc PlanetVPNService. Если это точно остаток удалённой PlanetVPN, используй безопасное удаление/восстановление через источник установки или осознанно удали только эту службу после проверки; SYSINFO не выполняет это автоматически.'
            } else {
                $policy.Severity = 'WARNING'
                $policy.Title = 'Историческая ошибка запуска PlanetVPNService; текущее состояние не подтверждено'
                $policy.DetailsSuffix = (' Текущую регистрацию службы проверить не удалось: {0}. Поэтому событие не объявляется активной неисправностью.' -f $ServiceState.Error)
                $policy.Recommendation = 'При необходимости проверь sc.exe query PlanetVPNService и sc.exe qc PlanetVPNService вручную. ARGONOV ничего не меняет; HAP не затрагивается.'
            }
        }
    }

    return [pscustomobject]$policy
}

function Get-ArgonovSysInfoEventDiagnosticInfo {
    param(
        [Parameter(Mandatory)][string]$ProviderName,
        [Parameter(Mandatory)][int]$Id,
        [System.Collections.IDictionary]$EventData = @{},
        [string]$Message = ''
    )

    $providerSlug = Get-ArgonovSysInfoSlug $ProviderName
    $eventCode = "WIN-EVENT-$providerSlug-$Id"
    $diagnosticCode = $eventCode
    $stopCode = ''
    $reference = ''
    $query = "Windows event $ProviderName Event ID $Id troubleshooting"

    $bugcheckRaw = [string]$EventData['BugcheckCode']
    # WER Event ID 1001 commonly stores the stop code inside param1 rather than BugcheckCode.
    # Parse the first hex value from param1 so localized event messages do not affect detection.
    if ([string]::IsNullOrWhiteSpace($bugcheckRaw) -and $Id -eq 1001) {
        $werParam1 = [string]$EventData['param1']
        if ($werParam1 -match '(?i)(0x[0-9a-f]{1,8})') { $bugcheckRaw = $Matches[1] }
    }
    if ($bugcheckRaw -match '^\s*0x([0-9A-Fa-f]{1,8})\s*$') {
        $hex = $Matches[1].ToUpperInvariant().PadLeft(8, '0')
        if ($hex -ne '00000000') { $stopCode = "WIN-BUGCHECK-0x$hex" }
    } elseif ($bugcheckRaw -match '^\s*\d+\s*$') {
        try {
            $bugcheckDecimal = [long]$bugcheckRaw
            if ($bugcheckDecimal -gt 0) {
                $hex = $bugcheckDecimal.ToString('X8')
                $stopCode = "WIN-BUGCHECK-0x$hex"
            }
        } catch {}
    }

    if ([string]::IsNullOrWhiteSpace($stopCode)) {
        $messageCode = ''
        if ($Id -eq 1001 -and $Message -match '(?i)(0x[0-9a-f]{1,8})') {
            # The WER bugcheck description starts with the stop code in English and localized Windows.
            $messageCode = $Matches[1]
        } elseif ($Message -match '(?i)(?:bugcheck|bug check).*?(0x[0-9a-f]{1,8})') {
            $messageCode = $Matches[1]
        }
        if ($messageCode) {
            $hex = $messageCode.Substring(2).ToUpperInvariant().PadLeft(8, '0')
            if ($hex -ne '00000000') { $stopCode = "WIN-BUGCHECK-0x$hex" }
        }
    }

    if ($ProviderName -match '(?i)Kernel-Power' -and $Id -eq 41) {
        $eventCode = 'WIN-EVENT-KERNEL-POWER-41'
        $reference = 'https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/event-id-41-restart'
        if ($stopCode) {
            $diagnosticCode = $stopCode
            $queryCode = $stopCode -replace '^WIN-BUGCHECK-', ''
            $query = "Windows stop code $queryCode Microsoft Learn Kernel-Power Event ID 41"
            $reference = if ($stopCode -eq 'WIN-BUGCHECK-0x00000124') { 'https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-0x124---whea-uncorrectable-error' } else { 'https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference2' }
        } else {
            $diagnosticCode = $eventCode
            $query = 'Microsoft Learn Windows Kernel-Power Event ID 41 BugcheckCode 0 unexpected shutdown'
        }
    } elseif ($ProviderName -match '(?i)WHEA-Logger' -and $Id -eq 1) {
        $eventCode = 'WIN-EVENT-WHEA-LOGGER-1'
        $diagnosticCode = $eventCode
        $query = 'Microsoft Windows WHEA-Logger Event ID 1 CPER hardware error record'
        $reference = 'https://learn.microsoft.com/en-us/windows-hardware/drivers/whea/error-records'
    } elseif ($ProviderName -match '(?i)^EventLog$' -and $Id -eq 6008) {
        $eventCode = 'WIN-EVENT-EVENTLOG-6008'
        $diagnosticCode = $eventCode
        $query = 'Microsoft Learn Windows Event ID 6008 previous shutdown was unexpected'
        $reference = 'https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-unexpected-reboots-system-event-logs'
    } elseif ($Id -eq 1001 -and $stopCode) {
        $eventCode = 'WIN-EVENT-WER-SYSTEM-ERROR-REPORTING-1001'
        $diagnosticCode = $stopCode
        $queryCode = $stopCode -replace '^WIN-BUGCHECK-', ''
        $query = "Microsoft Windows stop code $queryCode bug check troubleshooting"
        $reference = if ($stopCode -eq 'WIN-BUGCHECK-0x00000124') { 'https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-0x124---whea-uncorrectable-error' } else { 'https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference2' }
    } elseif ($ProviderName -match '(?i)TPM-WMI' -and $Id -eq 1801) {
        $eventCode = 'WIN-EVENT-TPM-WMI-1801'
        $diagnosticCode = $eventCode
        $query = 'Microsoft Learn TPM-WMI Event ID 1801 1808 UEFICA2023Status Secure Boot certificates'
        $reference = 'https://learn.microsoft.com/en-us/troubleshoot/windows-client/windows-security/update-secure-boot-certificates'
    } elseif ($ProviderName -match '(?i)DistributedCOM' -and $Id -eq 10016) {
        $eventCode = 'WIN-EVENT-MICROSOFT-WINDOWS-DISTRIBUTEDCOM-10016'
        $diagnosticCode = $eventCode
        $query = 'Microsoft Learn DistributedCOM Event ID 10016 can be safely ignored by design'
        $reference = 'https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/event-10016-logged-when-accessing-dcom'
    } elseif ($ProviderName -match '(?i)^Application Popup$' -and $Id -eq 56) {
        $eventCode = 'WIN-EVENT-APPLICATION-POPUP-56'
        $diagnosticCode = $eventCode
        $query = 'Windows Application Popup Event ID 56 troubleshooting'
    } elseif ($ProviderName -match '(?i)Service Control Manager' -and $Id -eq 7000) {
        $serviceName = Get-ArgonovSysInfoServiceNameFromMessage $Message
        if ($serviceName -ieq 'PlanetVPNService') {
            $eventCode = 'WIN-EVENT-SERVICE-CONTROL-MANAGER-7000'
            $diagnosticCode = 'ARGONOV-ORPHANED-SERVICE-PLANETVPN'
            $query = 'PlanetVPNService service failed to start file not found Windows Event ID 7000'
            $reference = 'https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-query'
        } else {
            $eventCode = 'WIN-EVENT-SERVICE-CONTROL-MANAGER-7000'
            $diagnosticCode = $eventCode
            $query = 'Windows Service Control Manager Event ID 7000 service failed to start troubleshoot'
        }
    }

    return [pscustomobject]@{
        EventCode = $eventCode
        DiagnosticCode = $diagnosticCode
        StopCode = $stopCode
        SearchQuery = $query
        SearchUrl = Get-ArgonovSysInfoSearchUrl -Query $query
        ReferenceUrl = $reference
    }
}

function Get-ArgonovSysInfoCimData {
    param([int]$Days = 1, [switch]$Deep)

    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $processors = @(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue)
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -and $_.Name -notmatch 'Microsoft Basic|Remote Display' })
    $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
    $memoryModules = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $logicalDisks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)
    $physicalWmi = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)

    $totalBytes = [long]$computer.TotalPhysicalMemory
    $freeBytes = [long]$os.FreePhysicalMemory * 1KB
    $usedBytes = [math]::Max([long]0, $totalBytes - $freeBytes)
    $usedPct = if ($totalBytes -gt 0) { [math]::Round(($usedBytes / $totalBytes) * 100, 1) } else { $null }

    $memory = [pscustomobject]@{
        InstalledBytes = $totalBytes
        Installed = Format-ArgonovSysInfoBytes $totalBytes
        AvailableBytes = $freeBytes
        Available = Format-ArgonovSysInfoBytes $freeBytes
        UsedBytes = $usedBytes
        Used = Format-ArgonovSysInfoBytes $usedBytes
        UsedPercent = $usedPct
        Modules = @($memoryModules | ForEach-Object {
            [pscustomobject]@{
                Locator = $_.DeviceLocator
                Manufacturer = $_.Manufacturer
                PartNumber = ($_.PartNumber -as [string]).Trim()
                CapacityBytes = [long]$_.Capacity
                Capacity = Format-ArgonovSysInfoBytes ([long]$_.Capacity)
                SpeedMTs = $_.Speed
                ConfiguredSpeedMTs = $_.ConfiguredClockSpeed
                SMBIOSType = $_.SMBIOSMemoryType
                FormFactor = $_.FormFactor
            }
        })
    }

    $cpuPerf = $null
    try {
        $cpuPerf = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop
    } catch {}

    $logical = @($logicalDisks | ForEach-Object {
        $size = [long]$_.Size
        $free = [long]$_.FreeSpace
        $pct = if ($size -gt 0) { [math]::Round((($size - $free) / $size) * 100, 1) } else { $null }
        $freePct = if ($size -gt 0) { [math]::Round(($free / $size) * 100, 1) } else { $null }
        [pscustomobject]@{
            Drive = $_.DeviceID
            Label = $_.VolumeName
            FileSystem = $_.FileSystem
            SizeBytes = $size
            Size = Format-ArgonovSysInfoBytes $size
            FreeBytes = $free
            Free = Format-ArgonovSysInfoBytes $free
            UsedPercent = $pct
            FreePercent = $freePct
            Status = $_.Status
        }
    })

    $physical = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($disk in @(Get-PhysicalDisk -ErrorAction Stop)) {
            $counter = $null
            $counterError = $null
            try {
                $counter = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction Stop
            } catch {
                $counterError = Get-ArgonovSysInfoErrorText $_
            }
            $item = [pscustomobject]@{
                FriendlyName = $disk.FriendlyName
                DeviceId = $disk.DeviceId
                MediaType = [string]$disk.MediaType
                BusType = [string]$disk.BusType
                SizeBytes = [long]$disk.Size
                Size = Format-ArgonovSysInfoBytes ([long]$disk.Size)
                HealthStatus = [string]$disk.HealthStatus
                OperationalStatus = (@($disk.OperationalStatus) -join ', ')
                TemperatureC = Get-ArgonovSysInfoProperty $counter 'Temperature'
                TemperatureMaxC = Get-ArgonovSysInfoProperty $counter 'TemperatureMax'
                WearPercent = Get-ArgonovSysInfoProperty $counter 'Wear'
                PowerOnHours = Get-ArgonovSysInfoProperty $counter 'PowerOnHours'
                ReadErrorsTotal = Get-ArgonovSysInfoProperty $counter 'ReadErrorsTotal'
                ReadErrorsUncorrected = Get-ArgonovSysInfoProperty $counter 'ReadErrorsUncorrected'
                WriteErrorsTotal = Get-ArgonovSysInfoProperty $counter 'WriteErrorsTotal'
                WriteErrorsUncorrected = Get-ArgonovSysInfoProperty $counter 'WriteErrorsUncorrected'
                ReliabilityCounterAvailable = ($null -ne $counter)
                ReliabilityCounterError = $counterError
            }
            $physical.Add($item) | Out-Null
        }
    } catch {
        # The storage cmdlets may be unavailable on some Windows installations; Win32_DiskDrive remains a fallback inventory.
    }

    if ($physical.Count -eq 0) {
        foreach ($disk in $physicalWmi) {
            $physical.Add([pscustomobject]@{
                FriendlyName = $disk.Model
                DeviceId = $disk.Index
                MediaType = $disk.MediaType
                BusType = 'Недоступно через Win32_DiskDrive'
                SizeBytes = [long]$disk.Size
                Size = Format-ArgonovSysInfoBytes ([long]$disk.Size)
                HealthStatus = $disk.Status
                OperationalStatus = $disk.Status
                TemperatureC = $null
                TemperatureMaxC = $null
                WearPercent = $null
                PowerOnHours = $null
                ReadErrorsTotal = $null
                ReadErrorsUncorrected = $null
                WriteErrorsTotal = $null
                WriteErrorsUncorrected = $null
                ReliabilityCounterAvailable = $false
                ReliabilityCounterError = 'Get-PhysicalDisk / Get-StorageReliabilityCounter недоступны'
            }) | Out-Null
        }
    }

    $devices = @()
    try {
        $devices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop |
            Where-Object { $_.Status -and $_.Status -ne 'OK' } |
            Select-Object -First 100 @{Name='Name';Expression={$_.FriendlyName}}, Class, Status, Problem, InstanceId)
    } catch {
        try {
            $devices = @(Get-CimInstance Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0' -ErrorAction Stop |
                Select-Object -First 100 @{Name='Name';Expression={$_.Name}}, @{Name='Class';Expression={$_.PNPClass}},
                    @{Name='Status';Expression={$_.Status}}, @{Name='Problem';Expression={$_.ConfigManagerErrorCode}},
                    @{Name='InstanceId';Expression={$_.PNPDeviceID}})
        } catch {}
    }

    $eventResult = Get-ArgonovSysInfoEvents -Days $Days -Deep:$Deep
    $events = @($eventResult.Items)
    $sensorResult = Get-ArgonovSysInfoSensors

    $battery = $null
    try {
        $batteryRaw = Get-CimInstance Win32_Battery -ErrorAction Stop | Select-Object -First 1
        if ($batteryRaw) {
            $battery = [pscustomobject]@{
                EstimatedChargePercent = $batteryRaw.EstimatedChargeRemaining
                StatusCode = $batteryRaw.BatteryStatus
                Status = switch ([int]$batteryRaw.BatteryStatus) {
                    1 { 'Разряжается' }; 2 { 'Подключена к сети' }; 3 { 'Полностью заряжена' }
                    4 { 'Низкий заряд' }; 5 { 'Критически низкий заряд' }; 6 { 'Заряжается' }
                    7 { 'Заряжается и высокий заряд' }; 8 { 'Заряжается и низкий заряд' }
                    9 { 'Заряжается и критически низкий заряд' }; 10 { 'Не определено' }
                    default { 'Неизвестно' }
                }
                DesignVoltageMv = $batteryRaw.DesignVoltage
                EstimatedRuntimeMinutes = $batteryRaw.EstimatedRunTime
            }
        }
    } catch {}

    $processes = @(Get-Process -ErrorAction SilentlyContinue | Sort-Object -Property WorkingSet64 -Descending |
        Select-Object -First 10 @{Name='Name';Expression={$_.ProcessName}}, Id,
            @{Name='MemoryBytes';Expression={[long]$_.WorkingSet64}},
            @{Name='Memory';Expression={Format-ArgonovSysInfoBytes ([long]$_.WorkingSet64)}},
            @{Name='CpuSeconds';Expression={try { [math]::Round($_.CPU, 1) } catch { $null }}})

    $network = @()
    try {
        $network = @(Get-NetAdapter -ErrorAction Stop | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress)
    } catch {
        $network = @((Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.NetEnabled } | Select-Object Name, Manufacturer, NetConnectionStatus, MACAddress))
    }

    $uptime = (Get-Date) - $os.LastBootUpTime
    $biosDate = $bios.ReleaseDate
    try { if ($biosDate -is [string] -and $biosDate.Length -ge 8) { $biosDate = [Management.ManagementDateTimeConverter]::ToDateTime($biosDate) } } catch {}

    $report = [pscustomobject]@{
        SchemaVersion = 2
        SysinfoVersion = $script:ARGONOV_SYSINFO_VERSION
        GeneratedAt = Get-Date
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        IsAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        OS = [pscustomobject]@{
            Caption = $os.Caption
            Version = $os.Version
            Build = $os.BuildNumber
            Architecture = $os.OSArchitecture
            InstallDate = $os.InstallDate
            LastBoot = $os.LastBootUpTime
            Uptime = ('{0} д {1} ч {2} мин' -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
            PowerShell = $PSVersionTable.PSVersion.ToString()
        }
        CPU = @($processors | ForEach-Object {
            [pscustomobject]@{
                Name = ($_.Name -as [string]).Trim()
                Manufacturer = $_.Manufacturer
                Cores = $_.NumberOfCores
                LogicalProcessors = $_.NumberOfLogicalProcessors
                MaxClockMHz = $_.MaxClockSpeed
                CurrentClockMHz = $_.CurrentClockSpeed
                LoadPercent = if ($cpuPerf) { $cpuPerf.PercentProcessorTime } else { $null }
                Socket = $_.SocketDesignation
                Status = $_.Status
            }
        })
        GPUs = @($gpus | ForEach-Object {
            $gpuName = $_.Name
            $vramBytes = $null
            $vramSource = 'недоступно'
            # Win32_VideoController.AdapterRAM is 32-bit and may overflow/cap at 4 GiB.
            try {
                $registryBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
                $registryKey = Get-ChildItem -LiteralPath $registryBase -ErrorAction SilentlyContinue |
                    Where-Object { (Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue).DriverDesc -eq $gpuName } |
                    Select-Object -First 1
                if ($registryKey) {
                    $registryMemory = (Get-ItemProperty -LiteralPath $registryKey.PSPath -ErrorAction SilentlyContinue).'HardwareInformation.qwMemorySize'
                    if ($registryMemory -and [long]$registryMemory -gt 0) { $vramBytes = [long]$registryMemory; $vramSource = 'драйвер/реестр' }
                }
            } catch {}
            if ($null -eq $vramBytes -and $_.AdapterRAM -and [long]$_.AdapterRAM -gt 0) { $vramBytes = [long]$_.AdapterRAM; $vramSource = 'Win32_VideoController (ограничение 32-bit)' }
            [pscustomobject]@{
                Name = $gpuName
                VideoProcessor = $_.VideoProcessor
                DriverVersion = $_.DriverVersion
                DriverDate = $_.DriverDate
                VRAMBytes = $vramBytes
                VRAM = if ($null -ne $vramBytes) { Format-ArgonovSysInfoBytes $vramBytes } else { 'не предоставлена' }
                VRAMSource = $vramSource
                CurrentResolution = if ($_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution) { '{0} x {1}' -f $_.CurrentHorizontalResolution, $_.CurrentVerticalResolution } else { $null }
                Status = $_.Status
            }
        })
        Memory = $memory
        Motherboard = [pscustomobject]@{
            Manufacturer = $board.Manufacturer
            Product = $board.Product
            Version = $board.Version
        }
        BIOS = [pscustomobject]@{
            Manufacturer = $bios.Manufacturer
            Version = $bios.SMBIOSBIOSVersion
            ReleaseDate = $biosDate
        }
        LogicalDisks = $logical
        PhysicalDisks = @($physical.ToArray())
        Sensors = @($sensorResult.Items)
        SensorBackend = [pscustomobject]@{
            Installed = $sensorResult.Installed
            Available = $sensorResult.Available
            Path = $script:ARGONOV_SYSINFO_LHM_DIR
            Message = $sensorResult.Message
        }
        ProblemDevices = $devices
        Events = $events
        EventQueryWarnings = @($eventResult.Warnings)
        TopProcesses = $processes
        NetworkAdapters = $network
        Battery = $battery
        Security = if ($Deep) { Get-ArgonovSysInfoSecurity } else { $null }
        SecureBootUpdate = Get-ArgonovSysInfoSecureBootUpdateState
        Findings = @()
        Summary = $null
    }

    $findings = [System.Collections.Generic.List[object]]::new()
    if ($null -ne $usedPct) {
        if ($usedPct -ge 98) {
            Add-ArgonovSysInfoFinding $findings 'CRITICAL' 'Память' 'Критически мало свободной ОЗУ' ("Использовано {0}% физической памяти." -f $usedPct) 'Закрой ресурсоёмкие приложения и проверь процессы с наибольшим потреблением памяти.'
        } elseif ($usedPct -ge 90) {
            Add-ArgonovSysInfoFinding $findings 'WARNING' 'Память' 'Высокая загрузка ОЗУ' ("Использовано {0}% физической памяти." -f $usedPct) 'Проверь TopProcesses и наблюдай, воспроизводится ли нагрузка постоянно.'
        }
    }
    foreach ($disk in $logical) {
        if ($null -ne $disk.FreePercent -and $disk.FreePercent -lt 5) {
            Add-ArgonovSysInfoFinding $findings 'CRITICAL' 'Накопитель' ("На {0} почти закончилось место" -f $disk.Drive) ("Свободно {0} ({1}% раздела)." -f $disk.Free, $disk.FreePercent) 'Проверь крупные файлы и резервные копии; перед удалением проверь их назначение.'
        } elseif ($null -ne $disk.FreePercent -and $disk.FreePercent -lt 10) {
            Add-ArgonovSysInfoFinding $findings 'WARNING' 'Накопитель' ("Мало свободного места на {0}" -f $disk.Drive) ("Свободно {0} ({1}% раздела)." -f $disk.Free, $disk.FreePercent) 'Освободи место, если проблема сохраняется.'
        }
    }
    foreach ($disk in $report.PhysicalDisks) {
        if ($disk.HealthStatus -eq 'Unhealthy') {
            Add-ArgonovSysInfoFinding $findings 'CRITICAL' 'Накопитель' ("Windows считает диск проблемным: {0}" -f $disk.FriendlyName) ("HealthStatus={0}; OperationalStatus={1}." -f $disk.HealthStatus, $disk.OperationalStatus) 'Сделай резервную копию важных данных и проверь накопитель средствами производителя.'
        } elseif ($disk.HealthStatus -eq 'Warning') {
            Add-ArgonovSysInfoFinding $findings 'WARNING' 'Накопитель' ("Windows сообщает предупреждение о диске: {0}" -f $disk.FriendlyName) ("HealthStatus={0}; OperationalStatus={1}." -f $disk.HealthStatus, $disk.OperationalStatus) 'Проверь резервную копию и отчёт здоровья накопителя.'
        }
        foreach ($counterName in @('ReadErrorsUncorrected','WriteErrorsUncorrected')) {
            $counterValue = Get-ArgonovSysInfoProperty $disk $counterName
            if ($null -ne $counterValue -and [double]$counterValue -gt 0) {
                Add-ArgonovSysInfoFinding $findings 'CRITICAL' 'Накопитель' ("Есть неисправленные ошибки: {0}" -f $disk.FriendlyName) ("{0}={1}." -f $counterName, $counterValue) 'Как можно скорее сохрани важные данные и проведи проверку накопителя.'
            }
        }
        if ($null -ne $disk.WearPercent -and [double]$disk.WearPercent -ge 100) {
            Add-ArgonovSysInfoFinding $findings 'WARNING' 'Накопитель' ("Достигнут предел оценки износа: {0}" -f $disk.FriendlyName) ("Wear={0}%. Показатель зависит от устройства и драйвера." -f $disk.WearPercent) 'Проверь фирменную диагностику и заранее обеспечь актуальную резервную копию.'
        }
    }
    foreach ($device in $report.ProblemDevices) {
        Add-ArgonovSysInfoFinding $findings 'WARNING' 'Устройство' ("Устройство сообщает о проблеме: {0}" -f $device.Name) ("Status={0}; Problem={1}." -f $device.Status, $device.Problem) 'Проверь код проблемы в диспетчере устройств, драйвер и физическое подключение.'
    }
    $osLifecycle = Get-ArgonovSysInfoOsLifecyclePolicy -Caption ([string]$report.OS.Caption) -Build ([string]$report.OS.Build)
    if ($null -ne $osLifecycle) {
        Add-ArgonovSysInfoFinding $findings $osLifecycle.Severity $osLifecycle.Category $osLifecycle.Title $osLifecycle.Details $osLifecycle.Recommendation -DiagnosticCode $osLifecycle.DiagnosticCode -SearchQuery $osLifecycle.SearchQuery -ReferenceUrl $osLifecycle.ReferenceUrl -Scope $osLifecycle.Scope
    }
    $eventGroups = @($events | Group-Object {
        $groupKey = '{0}|{1}' -f $_.Provider, $_.Id
        if ($_.Provider -match '(?i)Service Control Manager' -and $_.Id -eq 7000) {
            $serviceName = Get-ArgonovSysInfoServiceNameFromMessage ([string]$_.Message)
            if ($serviceName) { $groupKey += ('|SERVICE:' + $serviceName.ToUpperInvariant()) }
        }
        $groupKey
    })
    foreach ($eventGroup in $eventGroups) {
        $groupEvents = @($eventGroup.Group | Sort-Object TimeCreated -Descending)
        if ($groupEvents.Count -eq 0) { continue }
        $event = $groupEvents[0]
        if (-not (Test-ArgonovSysInfoEventActionable -Id ([int]$event.Id) -Message ([string]$event.Message))) { continue }
        $eligibleEvent = ($event.Level -eq 1) -or ($event.Level -eq 2 -and ($Deep -or $event.Provider -match 'WHEA|Disk|Ntfs|stornvme|storahci|volmgr|Kernel-Power|Display|BugCheck|WER-SystemErrorReporting|Error Reporting|TPM-WMI|Service Control Manager|Application Popup')) -or ($Deep -and $event.Level -eq 3)
        if (-not $eligibleEvent) { continue }

        # EventLog 6008 is usually corroborating evidence for the same reboot already reported by Kernel-Power 41.
        if ($event.Provider -eq 'EventLog' -and $event.Id -eq 6008) {
            $hasNearbyKernelPower = @($events | Where-Object {
                $_.Provider -match '(?i)Kernel-Power' -and $_.Id -eq 41 -and
                ([math]::Abs(($_.TimeCreated - $event.TimeCreated).TotalMinutes) -le 10)
            }).Count -gt 0
            if ($hasNearbyKernelPower) { continue }
        }

        $eventTimes = @($groupEvents | Select-Object -First 3 | ForEach-Object { $_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') })
        $timeText = $eventTimes -join ', '
        if ($groupEvents.Count -gt 3) { $timeText += (' и ещё {0}' -f ($groupEvents.Count - 3)) }
        $details = ('Записей этого типа за выбранный период: {0}. Время последних записей: {1}.' -f $groupEvents.Count, $timeText)
        if ($event.Message) { $details += (' Последнее описание: {0}' -f $event.Message) }
        if ($event.RawDataLength -gt 0) { $details += (' В журнале присутствуют необработанные аппаратные данные (RawData, {0} hex-символов); они не доказывают неисправность конкретного компонента без разбора записи.' -f $event.RawDataLength) }
        if ($event.Provider -match '(?i)Kernel-Power' -and $event.Id -eq 41) {
            if ($event.StopCode) {
                $details += (' Код остановки Windows: {0}.' -f $event.StopCode)
            } elseif ($event.BugcheckCode -eq '0' -or $event.BugcheckHex -eq '0x00000000') {
                $details += ' BugcheckCode=0: Windows не записала код остановки в эту запись; причина по одному Event ID 41 не определяется.'
            }
            $details += ' Это историческая запись о неожиданном завершении работы, а не доказательство активной неисправности сейчас.'
        } elseif ($event.Provider -match '(?i)WHEA-Logger' -and $event.Id -eq 1) {
            $details += ' WHEA сообщает об аппаратной ошибке; источник необходимо уточнять по структуре CPER/данным события и соседним записям.'
        }

        $serviceName = Get-ArgonovSysInfoServiceNameFromMessage ([string]$event.Message)
        $serviceState = $null
        if ($event.Provider -match '(?i)Service Control Manager' -and $event.Id -eq 7000 -and $serviceName -ieq 'PlanetVPNService') {
            $serviceState = Get-ArgonovSysInfoServiceState -Name $serviceName
        }
        $policy = Get-ArgonovSysInfoEventFindingPolicy -ProviderName $event.Provider -Id $event.Id -Level $event.Level -Message ([string]$event.Message) -TimeCreated $event.TimeCreated -ServiceState $serviceState -SecureBootUpdateState $report.SecureBootUpdate
        if ($policy.DetailsSuffix) { $details += $policy.DetailsSuffix }
        $diagnosticCode = if ($policy.DiagnosticCode) { $policy.DiagnosticCode } else { $event.DiagnosticCode }
        $searchQuery = if ($policy.SearchQuery) { $policy.SearchQuery } else { $event.SearchQuery }
        $referenceUrl = if ($policy.ReferenceUrl) { $policy.ReferenceUrl } else { $event.ReferenceUrl }
        Add-ArgonovSysInfoFinding $findings $policy.Severity 'Журнал событий' $policy.Title $details $policy.Recommendation -DiagnosticCode $diagnosticCode -SearchQuery $searchQuery -ReferenceUrl $referenceUrl -Scope $policy.Scope
    }
    $tpm1801InLookback = @($events | Where-Object { $_.Provider -match '(?i)TPM-WMI' -and $_.Id -eq 1801 }).Count -gt 0
    if (-not $tpm1801InLookback -and $report.SecureBootUpdate.Status -eq 'NeedsVerification') {
        $failureTime = $report.SecureBootUpdate.LastFailureTime
        $timeText = if ($null -ne $failureTime) { $failureTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'время неизвестно' }
        Add-ArgonovSysInfoFinding $findings 'WARNING' 'Безопасность' 'Статус сертификатов Secure Boot требует проверки' ("Последнее событие TPM-WMI 1801: {0}. {1}" -f $timeText, $report.SecureBootUpdate.Evidence) 'Проверь статус UEFICA2023Status и наличие более позднего TPM-WMI 1808; при неподтверждённом обновлении следуй официальному руководству Microsoft.' -DiagnosticCode 'WIN-EVENT-TPM-WMI-1801' -SearchQuery 'Microsoft Learn TPM-WMI Event ID 1801 1808 UEFICA2023Status Secure Boot certificates' -ReferenceUrl 'https://learn.microsoft.com/en-us/troubleshoot/windows-client/windows-security/update-secure-boot-certificates' -Scope 'Verification'
    }

    foreach ($sensor in $report.Sensors) {
        if ($sensor.SensorType -ne 'Temperature' -or $null -eq $sensor.Value) { continue }
        $temp = [double]$sensor.Value
        $hardwareName = [string]$sensor.Hardware
        $sensorName = [string]$sensor.Name
        $severity = $null
        $threshold = $null
        if ($sensor.HardwareType -match '(?i)Cpu' -or $hardwareName -match '(?i)CPU|Processor|Ryzen|Core\s*(i[3579]|Ultra)|Xeon|EPYC') {
            if ($temp -ge 100) { $severity = 'CRITICAL'; $threshold = '100 °C' }
            elseif ($temp -ge 95) { $severity = 'WARNING'; $threshold = '95 °C' }
        } elseif ($sensor.HardwareType -match '(?i)Gpu' -or $hardwareName -match '(?i)GPU|GeForce|Radeon|Arc|NVIDIA|Intel.*Graphics') {
            if ($sensorName -match '(?i)hot.?spot|junction') {
                if ($temp -ge 110) { $severity = 'CRITICAL'; $threshold = '110 °C' }
                elseif ($temp -ge 105) { $severity = 'WARNING'; $threshold = '105 °C' }
            } else {
                if ($temp -ge 100) { $severity = 'CRITICAL'; $threshold = '100 °C' }
                elseif ($temp -ge 90) { $severity = 'WARNING'; $threshold = '90 °C' }
            }
        } elseif ($sensor.HardwareType -match '(?i)Storage' -or $hardwareName -match '(?i)NVMe|SSD|HDD|Storage|Drive') {
            if ($temp -ge 80) { $severity = 'CRITICAL'; $threshold = '80 °C' }
            elseif ($temp -ge 70) { $severity = 'WARNING'; $threshold = '70 °C' }
        }
        if ($severity) {
            Add-ArgonovSysInfoFinding $findings $severity 'Температура' ("Высокая температура: {0} / {1}" -f $hardwareName, $sensorName) ("Показание {0:N1} °C; общий ориентир предупреждения {1}. Порог не заменяет спецификацию производителя." -f $temp, $threshold) 'Сравни показание с документацией производителя и проверь охлаждение/воздушный поток.'
        }
    }

    foreach ($queryWarning in $report.EventQueryWarnings) {
        Add-ArgonovSysInfoFinding $findings 'INFO' 'Журнал событий' 'Не все журналы удалось прочитать' $queryWarning 'Если этот журнал важен для проверки, запусти ARGONOV с нужными правами и повтори диагностику.' -Scope 'DataLimit'
    }
    if (-not $sensorResult.Available) {
        Add-ArgonovSysInfoFinding $findings 'INFO' 'Аппаратные датчики' 'Нет доступных данных аппаратных датчиков' $sensorResult.Message 'Для попытки получить температуры, обороты вентиляторов, напряжения и частоты запусти sysinfo setup. Некоторые датчики могут всё равно оставаться недоступными.' -Scope 'DataLimit'
    }
    if ($Deep -and $null -ne $report.Security) {
        if ($report.Security.DefenderAvailable -and $report.Security.RealTimeProtectionEnabled -eq $false) {
            Add-ArgonovSysInfoFinding $findings 'WARNING' 'Безопасность' 'Защита Microsoft Defender в реальном времени выключена' 'Статус получен из доступного интерфейса Defender.' 'Проверь параметры безопасности Windows и убедись, что защиту обеспечивает другой доверенный продукт.'
        }
        if ($report.Security.SecureBoot -eq $false) {
            Add-ArgonovSysInfoFinding $findings 'INFO' 'Безопасность' 'Secure Boot выключен' 'Статус получен из UEFI API; на системах Legacy/BIOS проверка недоступна.' 'Оцени этот параметр с учётом конфигурации устройства и требований безопасности.'
        }
    }

    $report.Findings = @($findings.ToArray())
    $currentFindings = @($report.Findings | Where-Object Scope -eq 'Current')
    $historicalFindings = @($report.Findings | Where-Object Scope -eq 'Historical')
    $dataLimitFindings = @($report.Findings | Where-Object Scope -eq 'DataLimit')
    $verificationFindings = @($report.Findings | Where-Object Scope -eq 'Verification')
    $criticalCount = @($currentFindings | Where-Object Severity -eq 'CRITICAL').Count
    $warningCount = @($currentFindings | Where-Object Severity -eq 'WARNING').Count
    $historicalSignalCount = @($historicalFindings | Where-Object Severity -in @('CRITICAL','WARNING')).Count
    $infoCount = @($report.Findings | Where-Object Severity -eq 'INFO').Count
    $status = if ($criticalCount -gt 0) { 'CRITICAL' } elseif ($warningCount -gt 0 -or $verificationFindings.Count -gt 0) { 'ATTENTION' } elseif ($historicalSignalCount -gt 0) { 'HISTORICAL_EVENTS' } elseif ($dataLimitFindings.Count -gt 0 -or -not $sensorResult.Available -or @($report.EventQueryWarnings).Count -gt 0) { 'PARTIAL_DATA' } else { 'NO_KNOWN_ISSUES' }
    $report.Summary = [pscustomobject]@{
        Status = $status
        Critical = $criticalCount
        Warnings = $warningCount
        VerificationFindings = $verificationFindings.Count
        Information = $infoCount
        HistoricalFindings = $historicalSignalCount
        DataLimitFindings = $dataLimitFindings.Count
        ProblemDevices = @($report.ProblemDevices).Count
        Events = @($report.Events).Count
        SensorsAvailable = [bool]$sensorResult.Available
    }
    return $report
}

function Get-ArgonovSysInfoEvents {
    param([ValidateRange(1,90)][int]$Days = 1, [switch]$Deep)
    $since = (Get-Date).AddDays(-$Days)
    $logs = @('System')
    if ($Deep) { $logs += 'Application' }
    $levels = if ($Deep) { @(1,2,3) } else { @(1,2) }
    $maxPerQuery = if ($Deep) { 80 } else { 12 }
    $collected = [System.Collections.Generic.List[object]]::new()
    $issues = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($logName in $logs) {
        foreach ($level in $levels) {
            if (-not $Deep -and $logName -eq 'System' -and $level -eq 2) { $maxPerQuery = 25 }
            try {
                $filter = @{ LogName = $logName; StartTime = $since; Level = $level }
                foreach ($event in @(Get-WinEvent -FilterHashtable $filter -MaxEvents $maxPerQuery -ErrorAction Stop)) {
                    $key = '{0}:{1}' -f $event.LogName, $event.RecordId
                    if (-not $seen.Add($key)) { continue }
                    $message = ([string]$event.Message -replace '\s+', ' ').Trim()
                    if ($message.Length -gt 360) { $message = $message.Substring(0,357) + '...' }
                    $eventData = Get-ArgonovSysInfoEventData -EventRecord $event
                    $eventDiagnostic = Get-ArgonovSysInfoEventDiagnosticInfo -ProviderName $event.ProviderName -Id $event.Id -EventData $eventData.Values -Message ([string]$event.Message)
                    if (-not (Test-ArgonovSysInfoEventActionable -Id ([int]$event.Id) -Message ([string]$message))) {
                        $eventDiagnostic = [pscustomobject]@{ EventCode = ''; DiagnosticCode = ''; StopCode = ''; SearchQuery = ''; SearchUrl = ''; ReferenceUrl = '' }
                    }
                    $bugcheckRaw = [string]$eventData.Values['BugcheckCode']
                    $bugcheckHex = ''
                    if (-not [string]::IsNullOrWhiteSpace($bugcheckRaw)) {
                        if ($bugcheckRaw -match '^\s*0x([0-9A-Fa-f]{1,8})\s*$') {
                            $bugcheckHex = '0x' + $Matches[1].ToUpperInvariant().PadLeft(8, '0')
                        } elseif ($bugcheckRaw -match '^\s*\d+\s*$') {
                            try { $bugcheckHex = '0x' + ([long]$bugcheckRaw).ToString('X8') } catch {}
                        }
                    }
                    $collected.Add([pscustomobject]@{
                        TimeCreated = $event.TimeCreated
                        LogName = $event.LogName
                        Level = $event.Level
                        LevelName = if ([string]::IsNullOrWhiteSpace([string]$event.LevelDisplayName)) { 'уровень не указан' } else { [string]$event.LevelDisplayName }
                        Provider = $event.ProviderName
                        Id = $event.Id
                        RecordId = $event.RecordId
                        Message = $message
                        EventData = $eventData.Values
                        RawDataLength = $eventData.RawDataLength
                        BugcheckCode = $bugcheckRaw
                        BugcheckHex = $bugcheckHex
                        EventCode = $eventDiagnostic.EventCode
                        DiagnosticCode = $eventDiagnostic.DiagnosticCode
                        StopCode = $eventDiagnostic.StopCode
                        SearchQuery = $eventDiagnostic.SearchQuery
                        SearchUrl = $eventDiagnostic.SearchUrl
                        ReferenceUrl = $eventDiagnostic.ReferenceUrl
                    }) | Out-Null
                }
            } catch {
                $errorText = Get-ArgonovSysInfoErrorText $_
                if ($_.FullyQualifiedErrorId -notmatch 'NoMatchingEventsFound' -and $errorText -notmatch '(?i)no events were found|no events were found that match|не найдено событий|события не найдены') {
                    $issues.Add(("{0}, уровень {1}: {2}" -f $logName, $level, $errorText)) | Out-Null
                }
            }
        }
    }
    $limit = if ($Deep) { 150 } else { 30 }
    return [pscustomobject]@{
        Items = @($collected | Sort-Object TimeCreated -Descending | Select-Object -First $limit)
        Warnings = @($issues.ToArray())
    }
}

function Initialize-ArgonovSysInfoLhmAssembly {
    $libraryPath = Join-Path $script:ARGONOV_SYSINFO_LHM_DIR 'LibreHardwareMonitorLib.dll'
    if (-not (Test-Path -LiteralPath $libraryPath)) {
        throw 'Библиотека LibreHardwareMonitor не установлена. Выполни sysinfo setup.'
    }
    if (-not $script:ARGONOV_SYSINFO_LHM_RESOLVER_REGISTERED) {
        $script:ARGONOV_SYSINFO_LHM_RESOLVER = [System.ResolveEventHandler] {
            param($sender, $eventArgs)
            $assemblyName = ([System.Reflection.AssemblyName]::new($eventArgs.Name)).Name + '.dll'
            $dependencyPath = Join-Path $script:ARGONOV_SYSINFO_LHM_DIR $assemblyName
            if (Test-Path -LiteralPath $dependencyPath) {
                try { return [System.Reflection.Assembly]::LoadFrom($dependencyPath) } catch { return $null }
            }
            return $null
        }
        [AppDomain]::CurrentDomain.add_AssemblyResolve($script:ARGONOV_SYSINFO_LHM_RESOLVER)
        $script:ARGONOV_SYSINFO_LHM_RESOLVER_REGISTERED = $true
    }
    if (-not ('LibreHardwareMonitor.Hardware.Computer' -as [type])) {
        [void][System.Reflection.Assembly]::LoadFrom($libraryPath)
    }
}

function New-ArgonovSysInfoSensorSession {
    try {
        Initialize-ArgonovSysInfoLhmAssembly
        $computer = [LibreHardwareMonitor.Hardware.Computer]::new()
        $computer.IsCpuEnabled = $true
        $computer.IsGpuEnabled = $true
        $computer.IsMemoryEnabled = $true
        $computer.IsMotherboardEnabled = $true
        $computer.IsControllerEnabled = $true
        $computer.IsNetworkEnabled = $true
        $computer.IsStorageEnabled = $true
        try { $computer.IsPowerMonitorEnabled = $true } catch {}
        $computer.Open()
        return [pscustomobject]@{
            Installed = $true
            Available = $true
            Message = 'Датчики подключены через LibreHardwareMonitorLib.'
            Computer = $computer
        }
    } catch {
        return [pscustomobject]@{
            Installed = (Test-Path -LiteralPath (Join-Path $script:ARGONOV_SYSINFO_LHM_DIR 'LibreHardwareMonitorLib.dll'))
            Available = $false
            Message = ('Не удалось подключить датчики: ' + (Get-ArgonovSysInfoErrorText $_))
            Computer = $null
        }
    }
}

function Read-ArgonovSysInfoSensorSession {
    param([Parameter(Mandatory)][object]$Session)
    if ($null -eq $Session.Computer) {
        return [pscustomobject]@{ Installed = $Session.Installed; Available = $false; Message = $Session.Message; Items = @() }
    }
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($hardware in $Session.Computer.Hardware) {
        Add-ArgonovSysInfoHardwareSensors -Hardware $hardware -Parent '' -Result $items
    }
    $sensors = @($items.ToArray())
    return [pscustomobject]@{
        Installed = $true
        Available = ($sensors.Count -gt 0)
        Message = if ($sensors.Count -gt 0) { 'Датчики прочитаны из LibreHardwareMonitorLib. Доступность зависит от оборудования, драйверов и прав.' } else { 'Библиотека подключена, но показания датчиков не возвращены.' }
        Items = $sensors
    }
}

function Get-ArgonovSysInfoSensors {
    $session = New-ArgonovSysInfoSensorSession
    try {
        return (Read-ArgonovSysInfoSensorSession -Session $session)
    } catch {
        return [pscustomobject]@{
            Installed = $session.Installed
            Available = $false
            Message = ('Не удалось прочитать датчики: ' + (Get-ArgonovSysInfoErrorText $_))
            Items = @()
        }
    } finally {
        if ($null -ne $session.Computer) { try { $session.Computer.Close() } catch {} }
    }
}

function Add-ArgonovSysInfoHardwareSensors {
    param(
        [Parameter(Mandatory)][object]$Hardware,
        [string]$Parent = '',
        [Parameter(Mandatory)][System.Collections.Generic.List[object]]$Result
    )
    try { $Hardware.Update() } catch {}
    $hardwareName = [string]$Hardware.Name
    $fullName = if ($Parent) { "$Parent / $hardwareName" } else { $hardwareName }
    foreach ($sensor in @($Hardware.Sensors)) {
        try {
            if ($null -eq $sensor.Value) { continue }
            $Result.Add([pscustomobject]@{
                Hardware = $fullName
                HardwareType = [string]$Hardware.HardwareType
                Name = [string]$sensor.Name
                SensorType = [string]$sensor.SensorType
                Value = [math]::Round([double]$sensor.Value, 2)
                Unit = switch ([string]$sensor.SensorType) {
                    'Temperature' { '°C' }; 'Fan' { 'RPM' }; 'Voltage' { 'V' }
                    'Load' { '%' }; 'Clock' { 'MHz' }; 'Power' { 'W' }
                    'Data' { 'GB' }; 'SmallData' { 'MB' }; 'Throughput' { 'B/s' }
                    'Level' { '%' }; default { '' }
                }
                Min = if ($null -ne $sensor.Min) { [math]::Round([double]$sensor.Min, 2) } else { $null }
                Max = if ($null -ne $sensor.Max) { [math]::Round([double]$sensor.Max, 2) } else { $null }
            }) | Out-Null
        } catch {}
    }
    foreach ($subHardware in @($Hardware.SubHardware)) {
        Add-ArgonovSysInfoHardwareSensors -Hardware $subHardware -Parent $fullName -Result $Result
    }
}

function Get-ArgonovSysInfoSecurity {
    $defender = $null
    try {
        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            $raw = Get-MpComputerStatus -ErrorAction Stop
            $defender = [pscustomobject]@{
                Available = $true
                RealTimeProtectionEnabled = $raw.RealTimeProtectionEnabled
                AntivirusEnabled = $raw.AntivirusEnabled
                AntispywareEnabled = $raw.AntispywareEnabled
                AntivirusSignatureLastUpdated = $raw.AntivirusSignatureLastUpdated
                QuickScanAgeDays = $raw.QuickScanAge
                FullScanAgeDays = $raw.FullScanAge
            }
        }
    } catch {}

    $secureBoot = $null
    $secureBootNote = 'Недоступно: проверь режим загрузки и поддержку UEFI.'
    try {
        $secureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
        $secureBootNote = if ($secureBoot) { 'Включён' } else { 'Выключен' }
    } catch {
        $secureBootNote = Get-ArgonovSysInfoSecureBootErrorNote -Message (Get-ArgonovSysInfoErrorText $_)
    }

    $tpm = $null
    try {
        if (Get-Command Get-Tpm -ErrorAction SilentlyContinue) {
            $rawTpm = Get-Tpm -ErrorAction Stop
            $tpm = [pscustomobject]@{
                Available = $true
                Present = $rawTpm.TpmPresent
                Ready = $rawTpm.TpmReady
                Enabled = $rawTpm.TpmEnabled
                Activated = $rawTpm.TpmActivated
                ManufacturerId = $rawTpm.ManufacturerIdTxt
                SpecVersion = $rawTpm.SpecVersion
            }
        }
    } catch {}

    return [pscustomobject]@{
        DefenderAvailable = ($null -ne $defender)
        Defender = $defender
        RealTimeProtectionEnabled = if ($defender) { $defender.RealTimeProtectionEnabled } else { $null }
        SecureBoot = $secureBoot
        SecureBootNote = $secureBootNote
        TPM = $tpm
    }
}

function Show-ArgonovSysInfoHeader {
    param([string]$Subtitle = 'Диагностический центр Windows')
    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════════════════════════════════════╗' -ForegroundColor DarkCyan
    Write-Host '  ║  ' -NoNewline -ForegroundColor DarkCyan
    Write-Host '⚡ ARGONOV SYSINFO' -NoNewline -ForegroundColor Cyan
    Write-Host (' ' * [math]::Max(1, 43 - $Subtitle.Length)) -NoNewline
    Write-Host '║' -ForegroundColor DarkCyan
    Write-Host '  ╚══════════════════════════════════════════════════════════════════════╝' -ForegroundColor DarkCyan
    Write-Host ('  {0} · {1}' -f $Subtitle, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor DarkGray
    Write-Host ''
}

function Write-ArgonovSysInfoSection {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ''
    Write-Host ("  ▬ {0}" -f $Title) -ForegroundColor Magenta
    Write-Host ('  ' + ('─' * 72)) -ForegroundColor DarkCyan
}

function Write-ArgonovSysInfoLine {
    param([string]$Label, [AllowNull()][object]$Value, [ConsoleColor]$Color = [ConsoleColor]::White)
    $display = if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { 'не предоставлено' } else { [string]$Value }
    Write-Host ('    {0,-23}' -f ($Label + ':')) -NoNewline -ForegroundColor Yellow
    Write-Host $display -ForegroundColor $Color
}

function Show-ArgonovSysInfoReport {
    param([Parameter(Mandatory)][object]$Report, [switch]$Deep, [ValidateRange(1,90)][int]$Days = 1)
    Show-ArgonovSysInfoHeader -Subtitle 'Полный снимок состояния'

    $statusColor = switch ($Report.Summary.Status) {
        'CRITICAL' { [ConsoleColor]::Red }
        'ATTENTION' { [ConsoleColor]::Yellow }
        'PARTIAL_DATA' { [ConsoleColor]::Cyan }
        'HISTORICAL_EVENTS' { [ConsoleColor]::Yellow }
        default { [ConsoleColor]::Green }
    }
    Write-Host '  СВОДНАЯ ОЦЕНКА' -ForegroundColor Cyan
    Write-Host ('    {0}' -f $Report.Summary.Status) -ForegroundColor $statusColor
    if ($Report.Summary.Status -eq 'PARTIAL_DATA') { Write-Host '    Часть телеметрии/журналов недоступна; статус не означает, что неисправностей нет.' -ForegroundColor DarkGray }
    if ($Report.Summary.Status -eq 'HISTORICAL_EVENTS') { Write-Host '    Обнаружены исторические сигналы в журналах; сами по себе они не доказывают активную неисправность.' -ForegroundColor DarkGray }
    Write-Host ('    Текущие отклонения: критических {0} · предупреждений {1}' -f $Report.Summary.Critical, $Report.Summary.Warnings) -ForegroundColor Gray
    Write-Host ('    Требуют проверки: {0} · Исторических сигналов: {1} · Информационных отметок: {2} · Ограничений данных: {3}' -f $Report.Summary.VerificationFindings, $Report.Summary.HistoricalFindings, $Report.Summary.Information, $Report.Summary.DataLimitFindings) -ForegroundColor Gray
    if (-not $Report.Summary.SensorsAvailable) { Write-Host '    Аппаратные датчики не подключены: оценка температур и вентиляторов неполная.' -ForegroundColor DarkGray }
    Write-Host '    Оценка относится только к доступным показателям; отсутствие ошибок не доказывает идеальное состояние железа.' -ForegroundColor DarkGray

    Write-ArgonovSysInfoSection 'WINDOWS / СИСТЕМА'
    Write-ArgonovSysInfoLine 'Компьютер' $Report.ComputerName
    Write-ArgonovSysInfoLine 'Пользователь' $Report.UserName
    Write-ArgonovSysInfoLine 'ОС' ("{0} ({1})" -f $Report.OS.Caption, $Report.OS.Architecture)
    Write-ArgonovSysInfoLine 'Версия / сборка' ("{0} / {1}" -f $Report.OS.Version, $Report.OS.Build)
    Write-ArgonovSysInfoLine 'Установлена' $Report.OS.InstallDate
    Write-ArgonovSysInfoLine 'Время работы' $Report.OS.Uptime
    Write-ArgonovSysInfoLine 'PowerShell' $Report.OS.PowerShell
    Write-ArgonovSysInfoLine 'Запущено от администратора' $Report.IsAdministrator

    Write-ArgonovSysInfoSection 'ПРОЦЕССОР'
    foreach ($cpu in $Report.CPU) {
        Write-ArgonovSysInfoLine 'Модель' $cpu.Name
        Write-ArgonovSysInfoLine 'Ядра / логические' ("{0} / {1}" -f $cpu.Cores, $cpu.LogicalProcessors)
        Write-ArgonovSysInfoLine 'Частота max / сейчас' ("{0} / {1} MHz" -f $cpu.MaxClockMHz, $cpu.CurrentClockMHz)
        Write-ArgonovSysInfoLine 'Загрузка CPU' $(if ($null -ne $cpu.LoadPercent) { "$($cpu.LoadPercent)%" } else { 'нет данных счётчика' })
    }

    Write-ArgonovSysInfoSection 'ВИДЕОКАРТЫ'
    if (-not $Report.GPUs) { Write-Host '    Видеокарты не обнаружены через WMI.' -ForegroundColor DarkGray }
    foreach ($gpu in $Report.GPUs) {
        Write-ArgonovSysInfoLine 'Модель' $gpu.Name
        Write-ArgonovSysInfoLine 'Видеопроцессор' $gpu.VideoProcessor
        Write-ArgonovSysInfoLine 'Видеопамять' ("{0} ({1})" -f $gpu.VRAM, $gpu.VRAMSource)
        Write-ArgonovSysInfoLine 'Драйвер' ("{0} ({1})" -f $gpu.DriverVersion, $gpu.DriverDate)
        if ($gpu.CurrentResolution) { Write-ArgonovSysInfoLine 'Разрешение' $gpu.CurrentResolution }
    }

    Write-ArgonovSysInfoSection 'ОПЕРАТИВНАЯ ПАМЯТЬ'
    Write-ArgonovSysInfoLine 'Установлено' $Report.Memory.Installed
    Write-ArgonovSysInfoLine 'Используется' ("{0} ({1}%)" -f $Report.Memory.Used, $Report.Memory.UsedPercent)
    Write-ArgonovSysInfoLine 'Доступно' $Report.Memory.Available
    if ($Report.Memory.Modules.Count -gt 0) {
        foreach ($module in $Report.Memory.Modules) {
            $configuredSpeed = if ($module.ConfiguredSpeedMTs -and [int]$module.ConfiguredSpeedMTs -gt 0) { [int]$module.ConfiguredSpeedMTs } else { $null }
            $reportedSpeed = if ($module.SpeedMTs -and [int]$module.SpeedMTs -gt 0) { [int]$module.SpeedMTs } else { $null }
            if ($null -ne $configuredSpeed -and $null -ne $reportedSpeed) {
                $speedText = "ConfiguredClockSpeed: $configuredSpeed MT/s*; Speed: $reportedSpeed MT/s*"
            } elseif ($null -ne $configuredSpeed) {
                $speedText = "ConfiguredClockSpeed: $configuredSpeed MT/s*; Speed: нет данных"
            } elseif ($null -ne $reportedSpeed) {
                $speedText = "ConfiguredClockSpeed: нет данных; Speed: $reportedSpeed MT/s*"
            } else {
                $speedText = 'скорость не предоставлена'
            }
            Write-Host ('    {0}: {1} · {2} · {3}' -f $module.Locator, $module.Capacity, $speedText, $module.Manufacturer) -ForegroundColor Gray
        }
        Write-Host '    * Показания Win32_PhysicalMemory/SMBIOS, не показание независимого live-датчика. Для DDR значение обычно выражает эффективную скорость передачи MT/s, а не физическую тактовую частоту в MHz.' -ForegroundColor DarkGray
    } else { Write-Host '    Детали модулей не предоставлены.' -ForegroundColor DarkGray }

    Write-ArgonovSysInfoSection 'МАТЕРИНСКАЯ ПЛАТА / BIOS'
    Write-ArgonovSysInfoLine 'Плата' ("{0} {1}" -f $Report.Motherboard.Manufacturer, $Report.Motherboard.Product)
    Write-ArgonovSysInfoLine 'Версия платы' $Report.Motherboard.Version
    Write-ArgonovSysInfoLine 'Производитель BIOS' $Report.BIOS.Manufacturer
    Write-ArgonovSysInfoLine 'Версия BIOS/UEFI' $Report.BIOS.Version
    Write-ArgonovSysInfoLine 'Дата BIOS/UEFI' $Report.BIOS.ReleaseDate

    Write-ArgonovSysInfoSection 'ЛОГИЧЕСКИЕ РАЗДЕЛЫ'
    foreach ($disk in $Report.LogicalDisks) {
        $color = if ($null -ne $disk.FreePercent -and $disk.FreePercent -lt 5) { [ConsoleColor]::Red } elseif ($null -ne $disk.FreePercent -and $disk.FreePercent -lt 10) { [ConsoleColor]::Yellow } else { [ConsoleColor]::White }
        Write-Host ('    {0,-7} {1,10} свободно / {2,10} · свободно {3}% · {4}' -f $disk.Drive, $disk.Free, $disk.Size, $disk.FreePercent, $disk.FileSystem) -ForegroundColor $color
    }

    Write-ArgonovSysInfoSection 'ФИЗИЧЕСКИЕ НАКОПИТЕЛИ / SMART-ПОДОБНЫЕ СЧЁТЧИКИ'
    foreach ($disk in $Report.PhysicalDisks) {
        Write-Host ('    {0} · {1} · {2} · {3}' -f $disk.FriendlyName, $disk.Size, $disk.MediaType, $disk.BusType) -ForegroundColor White
        Write-Host ('      Health: {0}; Operational: {1}' -f $disk.HealthStatus, $disk.OperationalStatus) -ForegroundColor Gray
        $details = @()
        if ($null -ne $disk.TemperatureC) { $details += "температура $($disk.TemperatureC) °C" }
        if ($null -ne $disk.TemperatureMaxC) { $details += "макс. температура $($disk.TemperatureMaxC) °C" }
        if ($null -ne $disk.WearPercent) { $details += "износ $($disk.WearPercent)%" }
        if ($null -ne $disk.PowerOnHours) { $details += "работа $($disk.PowerOnHours) ч" }
        if ($null -ne $disk.ReadErrorsUncorrected) { $details += "неисправленные ошибки чтения $($disk.ReadErrorsUncorrected)" }
        if ($null -ne $disk.WriteErrorsUncorrected) { $details += "неисправленные ошибки записи $($disk.WriteErrorsUncorrected)" }
        Write-Host ('      ' + $(if ($details.Count) { $details -join ' · ' } else { 'Надёжность/SMART-счётчики не предоставлены Windows или драйвером.' })) -ForegroundColor DarkGray
    }

    Write-ArgonovSysInfoSection 'АППАРАТНЫЕ ДАТЧИКИ'
    Write-Host ('    {0}' -f $Report.SensorBackend.Message) -ForegroundColor $(if ($Report.SensorBackend.Available) { 'Green' } else { 'Yellow' })
    if ($Report.Sensors.Count -gt 0) {
        $shown = if ($Deep) { $Report.Sensors } else { @($Report.Sensors | Where-Object { $_.SensorType -in @('Temperature','Fan','Voltage','Load','Clock','Power') } | Select-Object -First 50) }
        foreach ($sensor in $shown) {
            $value = if ($null -ne $sensor.Value) { "$($sensor.Value) $($sensor.Unit)" } else { 'нет показания' }
            Write-Host ('    {0,-12} {1,-28} {2,-27} {3}' -f $sensor.SensorType, $sensor.Hardware, $sensor.Name, $value) -ForegroundColor Gray
        }
        if (-not $Deep -and $Report.Sensors.Count -gt $shown.Count) { Write-Host ('    ... и ещё {0} датчиков (sysinfo deep)' -f ($Report.Sensors.Count - $shown.Count)) -ForegroundColor DarkGray }
    }

    if ($Report.Battery) {
        Write-ArgonovSysInfoSection 'БАТАРЕЯ'
        Write-ArgonovSysInfoLine 'Состояние' $Report.Battery.Status
        Write-ArgonovSysInfoLine 'Заряд' ("{0}%" -f $Report.Battery.EstimatedChargePercent)
        Write-ArgonovSysInfoLine 'Оценка времени' $(if ($Report.Battery.EstimatedRuntimeMinutes -and $Report.Battery.EstimatedRuntimeMinutes -lt 71582788) { "$($Report.Battery.EstimatedRuntimeMinutes) мин" } else { 'нет данных' })
    }

    Write-ArgonovSysInfoSection 'СЕТЕВЫЕ АДАПТЕРЫ'
    foreach ($adapter in $Report.NetworkAdapters) {
        Write-Host ('    {0} · {1} · {2} · {3}' -f $adapter.Name, $adapter.Status, $adapter.LinkSpeed, $adapter.MacAddress) -ForegroundColor Gray
    }

    Write-ArgonovSysInfoSection 'УСТРОЙСТВА С ПРОБЛЕМНЫМ СТАТУСОМ'
    if ($Report.ProblemDevices.Count -eq 0) { Write-Host '    Не обнаружены через текущий интерфейс устройств Windows.' -ForegroundColor Green }
    foreach ($device in $Report.ProblemDevices) {
        Write-Host ('    [{0}] {1} · класс {2} · код {3}' -f $device.Status, $device.Name, $device.Class, $device.Problem) -ForegroundColor Yellow
    }

    Write-ArgonovSysInfoSection 'СОБЫТИЯ WINDOWS'
    Write-Host ('    Событий в отчёте: {0} (за последние {1} дней)' -f $Report.Events.Count, $(if ($Deep) { $Days } else { 1 })) -ForegroundColor Gray
    foreach ($queryWarning in $Report.EventQueryWarnings) { Write-Host ('    Ограничение доступа/чтения: {0}' -f $queryWarning) -ForegroundColor Yellow }
    foreach ($event in @($Report.Events | Select-Object -First $(if ($Deep) { 30 } else { 8 }))) {
        $color = if ($event.Level -eq 1) { [ConsoleColor]::Red } elseif ($event.Level -eq 2) { [ConsoleColor]::Yellow } else { [ConsoleColor]::DarkGray }
        Write-Host ('    [{0}] {1:yyyy-MM-dd HH:mm:ss} · {2} · ID {3}' -f $event.LevelName, $event.TimeCreated, $event.Provider, $event.Id) -ForegroundColor $color
        if ($event.DiagnosticCode) { Write-Host ('      Код диагностики: {0}' -f $event.DiagnosticCode) -ForegroundColor Cyan }
        if ($event.StopCode) { Write-Host ('      Код остановки: {0}' -f $event.StopCode) -ForegroundColor Yellow }
        if ($Deep -and $event.Message) { Write-Host ('      ' + $event.Message) -ForegroundColor DarkGray }
    }

    if ($Deep) {
        Write-ArgonovSysInfoSection 'БЕЗОПАСНОСТЬ WINDOWS'
        if ($Report.Security.DefenderAvailable) {
            Write-ArgonovSysInfoLine 'Defender AV' $Report.Security.Defender.AntivirusEnabled
            Write-ArgonovSysInfoLine 'Защита real-time' $Report.Security.Defender.RealTimeProtectionEnabled
            Write-ArgonovSysInfoLine 'Антивирусные базы' $Report.Security.Defender.AntivirusSignatureLastUpdated
        } else { Write-Host '    Get-MpComputerStatus недоступен.' -ForegroundColor DarkGray }
        Write-ArgonovSysInfoLine 'Secure Boot' $Report.Security.SecureBootNote
        Write-ArgonovSysInfoLine 'Сертификаты Secure Boot' $Report.SecureBootUpdate.Display
        if ($Report.Security.TPM) {
            Write-ArgonovSysInfoLine 'TPM установлен' $Report.Security.TPM.Present
            Write-ArgonovSysInfoLine 'TPM готов' $Report.Security.TPM.Ready
            Write-ArgonovSysInfoLine 'TPM спецификация' $Report.Security.TPM.SpecVersion
        } else { Write-Host '    Get-Tpm недоступен.' -ForegroundColor DarkGray }

        Write-ArgonovSysInfoSection 'ТОП ПРОЦЕССОВ ПО ОПЕРАТИВНОЙ ПАМЯТИ'
        foreach ($process in $Report.TopProcesses) {
            Write-Host ('    {0,-28} PID {1,7} · {2,10} · CPU time {3}' -f $process.Name, $process.Id, $process.Memory, $process.CpuSeconds) -ForegroundColor Gray
        }
    }

    Write-ArgonovSysInfoSection 'ДИАГНОСТИЧЕСКИЕ РЕЗУЛЬТАТЫ И КОДЫ ПОИСКА'
    if ($Report.Findings.Count -eq 0) {
        Write-Host '    По доступным метрикам не найдено отклонений, подпадающих под правила ARGONOV.' -ForegroundColor Green
        Write-Host '    Это не гарантирует отсутствие неисправностей: часть датчиков может быть недоступна.' -ForegroundColor DarkGray
    } else {
        foreach ($finding in $Report.Findings) {
            $color = switch ($finding.Severity) { 'CRITICAL' { [ConsoleColor]::Red }; 'WARNING' { [ConsoleColor]::Yellow }; 'INFO' { [ConsoleColor]::Cyan }; default { [ConsoleColor]::Gray } }
            $scopeLabel = switch ($finding.Scope) { 'Historical' { 'ИСТОРИЯ' }; 'Verification' { 'ТРЕБУЕТ ПРОВЕРКИ' }; 'DataLimit' { 'ОГРАНИЧЕНИЕ ДАННЫХ' }; default { 'ТЕКУЩИЙ СНИМОК' } }
            Write-Host ('    [{0} · {1}] {2}: {3}' -f $finding.Severity, $scopeLabel, $finding.Category, $finding.Title) -ForegroundColor $color
            Write-Host ('      {0}' -f $finding.Details) -ForegroundColor Gray
            if ($finding.DiagnosticCode) { Write-Host ('      Код диагностики: {0}' -f $finding.DiagnosticCode) -ForegroundColor Cyan }
            if ($finding.SearchQuery) { Write-Host ('      Запрос для поиска: {0}' -f $finding.SearchQuery) -ForegroundColor Yellow }
            if ($finding.SearchUrl) { Write-Host ('      Поиск в интернете: {0}' -f $finding.SearchUrl) -ForegroundColor DarkGray }
            if ($finding.ReferenceUrl) { Write-Host ('      Официальная справка: {0}' -f $finding.ReferenceUrl) -ForegroundColor DarkGray }
            if ($finding.Recommendation) { Write-Host ('      Рекомендация: {0}' -f $finding.Recommendation) -ForegroundColor DarkGray }
        }
    }

    Write-Host ''
    Write-Host '  РЕЖИМЫ: sysinfo · sysinfo live · sysinfo deep · sysinfo setup · sysinfo export · sysinfo history · sysinfo help' -ForegroundColor Cyan
    Write-Host '  Диагностика только читает данные. Она не исправляет Windows и не запускает стресс-тесты.' -ForegroundColor DarkGray
    Write-Host ''
}

function Show-ArgonovSysInfoHelp {
    Show-ArgonovSysInfoHeader -Subtitle 'Справка по режимам'
    $rows = @(
        @('sysinfo', 'Полный снимок состояния, доступные датчики, накопители и недавние события.'),
        @('sysinfo live', 'Мониторинг нагрузки и датчиков с обновлением; остановить Ctrl+C.'),
        @('sysinfo live -Log', 'То же, но сохранять ряд измерений в локальную историю.'),
        @('sysinfo deep', 'Расширенный анализ событий Windows, устройств и параметров безопасности.'),
        @('sysinfo deep -Days 14', 'Расширенный анализ за указанный период (1–90 дней).'),
        @('sysinfo setup', 'Скачать с официального GitHub и проверить хеш аппаратную библиотеку LibreHardwareMonitor .NET 10.'),
        @('sysinfo export', 'Сохранить локальный отчёт HTML и JSON.'),
        @('sysinfo export -Path C:\Reports\pc', 'Задать базовый путь экспорта; будут добавлены .html и .json.'),
        @('sysinfo history', 'Показать последние строки истории, если включён sysinfo live -Log.'),
        @('Код диагностики', 'Каждое отклонение содержит код, поисковый запрос и, если доступна, официальную справку.'),
        @('sysinfo help', 'Показать эту справку.')
    )
    foreach ($row in $rows) {
        Write-Host ('  {0,-38}' -f $row[0]) -NoNewline -ForegroundColor Yellow
        Write-Host $row[1] -ForegroundColor Gray
    }
    Write-Host ''
    Write-Host 'Показания аппаратных датчиков зависят от устройства, драйверов и прав Windows.' -ForegroundColor DarkGray
}

function Install-ArgonovSysInfoSensorBackend {
    Initialize-ArgonovSysInfoPaths
    Write-Host ''
    Write-Host '  ARGONOV SYSINFO · установка аппаратного backend' -ForegroundColor Cyan
    Write-Host '  Источник: официальный GitHub LibreHardwareMonitor' -ForegroundColor DarkGray
    $api = 'https://api.github.com/repos/LibreHardwareMonitor/LibreHardwareMonitor/releases/latest'
    $headers = @{ 'User-Agent' = 'ARGONOV-SYSINFO'; 'Accept' = 'application/vnd.github+json' }
    $tempRoot = Join-Path $env:TEMP ('argonov-lhm-' + [guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $tempRoot 'LibreHardwareMonitor.NET.10.zip'
    $extractPath = Join-Path $tempRoot 'extracted'
    $stagingPath = $script:ARGONOV_SYSINFO_LHM_DIR + '.staging-' + [guid]::NewGuid().ToString('N')
    $oldBackup = $null
    try {
        New-Item -ItemType Directory -Path (Split-Path -Parent $script:ARGONOV_SYSINFO_LHM_DIR) -Force | Out-Null
        $release = Invoke-RestMethod -Uri $api -Headers $headers -TimeoutSec 20 -ErrorAction Stop
        $asset = $release.assets | Where-Object { $_.name -eq 'LibreHardwareMonitor.NET.10.zip' } | Select-Object -First 1
        if (-not $asset -or -not $asset.browser_download_url) { throw 'В последнем релизе не найден архив LibreHardwareMonitor.NET.10.zip.' }
        if ([string]$asset.digest -notmatch '^sha256:([0-9a-fA-F]{64})$') { throw 'GitHub не предоставил SHA-256 для файла; отказ от установки без проверки целостности.' }
        $expectedHash = $Matches[1].ToUpperInvariant()
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        Write-Host ('  Скачиваю релиз {0}...' -f $release.tag_name) -ForegroundColor Yellow
        Invoke-WebRequest -Uri $asset.browser_download_url -Headers @{ 'User-Agent' = 'ARGONOV-SYSINFO' } -OutFile $zipPath -TimeoutSec 90 -ErrorAction Stop
        $actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
        if ($actualHash -ne $expectedHash) { throw ("SHA-256 не совпал. Ожидался {0}, получен {1}." -f $expectedHash, $actualHash) }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
        $library = Get-ChildItem -LiteralPath $extractPath -Filter 'LibreHardwareMonitorLib.dll' -Recurse -File | Select-Object -First 1
        if (-not $library) { throw 'В проверенном архиве отсутствует LibreHardwareMonitorLib.dll.' }

        New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null
        $packageRoot = $library.DirectoryName
        Copy-Item -Path (Join-Path $packageRoot '*') -Destination $stagingPath -Recurse -Force
        if (-not (Test-Path -LiteralPath (Join-Path $stagingPath 'LibreHardwareMonitorLib.dll'))) {
            throw 'Библиотека не найдена в каталоге установки после распаковки.'
        }

        # Preserve the official notices when they are included in the release archive.
        foreach ($notice in @('LICENSE','LICENSE.txt','THIRD-PARTY-NOTICES.txt','THIRD-PARTY-NOTICES')) {
            $foundNotice = Get-ChildItem -LiteralPath $extractPath -Filter $notice -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($foundNotice) { Copy-Item -LiteralPath $foundNotice.FullName -Destination (Join-Path $stagingPath $foundNotice.Name) -Force }
        }
        $metadata = [pscustomobject]@{
            Provider = 'LibreHardwareMonitor'
            Version = $release.tag_name
            Source = $asset.browser_download_url
            Asset = $asset.name
            SHA256 = $actualHash
            InstalledAt = Get-Date
            License = 'MPL-2.0; see accompanying upstream license and third-party notices.'
        }
        $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stagingPath 'argonov-source.json') -Encoding utf8

        if (Test-Path -LiteralPath $script:ARGONOV_SYSINFO_LHM_DIR) {
            $oldBackup = $script:ARGONOV_SYSINFO_LHM_DIR + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
            Move-Item -LiteralPath $script:ARGONOV_SYSINFO_LHM_DIR -Destination $oldBackup -ErrorAction Stop
            Write-Host ('  Предыдущая версия сохранена: {0}' -f $oldBackup) -ForegroundColor DarkGray
        }
        Move-Item -LiteralPath $stagingPath -Destination $script:ARGONOV_SYSINFO_LHM_DIR -ErrorAction Stop
        Write-Host '  Установка завершена, SHA-256 проверен.' -ForegroundColor Green
        Write-Host '  ARGONOV загружает библиотеку внутри PowerShell; отдельное GUI-окно не запускается.' -ForegroundColor Gray
        Write-Host '  Проверяю загрузку .NET-библиотеки...' -ForegroundColor Yellow
        Initialize-ArgonovSysInfoLhmAssembly
        if (-not ('LibreHardwareMonitor.Hardware.Computer' -as [type])) {
            throw 'LibreHardwareMonitor assembly was copied, but its main type could not be loaded.'
        }
        Write-Host '  .NET-библиотека успешно загружена.' -ForegroundColor Green
        Write-Host '  Опрос конкретных датчиков будет выполнен командой sysinfo; он зависит от оборудования и прав Windows.' -ForegroundColor DarkGray
        return
    } catch {
        if ($oldBackup -and (Test-Path -LiteralPath $oldBackup) -and -not (Test-Path -LiteralPath $script:ARGONOV_SYSINFO_LHM_DIR)) {
            try { Move-Item -LiteralPath $oldBackup -Destination $script:ARGONOV_SYSINFO_LHM_DIR -ErrorAction Stop } catch {}
        }
        Write-Host ('  Ошибка установки backend: {0}' -f (Get-ArgonovSysInfoErrorText $_)) -ForegroundColor Red
        Write-Host '  Данные Windows продолжат работать без внешней библиотеки.' -ForegroundColor Gray
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $stagingPath) { Remove-Item -LiteralPath $stagingPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Export-ArgonovSysInfoReport {
    param([Parameter(Mandatory)][object]$Report, [string]$Path = '')
    Initialize-ArgonovSysInfoPaths
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $base = Join-Path $script:ARGONOV_SYSINFO_REPORTS ('sysinfo-' + $stamp)
    } else {
        $fullPath = [IO.Path]::GetFullPath($Path)
        if ([IO.Path]::HasExtension($fullPath)) {
            $base = [IO.Path]::Combine([IO.Path]::GetDirectoryName($fullPath), [IO.Path]::GetFileNameWithoutExtension($fullPath))
        } else {
            $base = $fullPath
        }
    }
    $parent = Split-Path -Parent $base
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $jsonPath = $base + '.json'
    $htmlPath = $base + '.html'
    $Report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding utf8

    $inventory = [System.Collections.Generic.List[object]]::new()
    foreach ($cpu in $Report.CPU) {
        $inventory.Add([pscustomobject]@{ Component='CPU'; Name=$cpu.Name; State=$cpu.Status; Details=("{0} cores / {1} threads; max {2} MHz; load {3}%" -f $cpu.Cores,$cpu.LogicalProcessors,$cpu.MaxClockMHz,$cpu.LoadPercent) }) | Out-Null
    }
    foreach ($gpu in $Report.GPUs) {
        $inventory.Add([pscustomobject]@{ Component='GPU'; Name=$gpu.Name; State=$gpu.Status; Details=("VRAM {0} ({1}); driver {2}" -f $gpu.VRAM,$gpu.VRAMSource,$gpu.DriverVersion) }) | Out-Null
    }
    foreach ($disk in $Report.PhysicalDisks) {
        $inventory.Add([pscustomobject]@{ Component='Storage'; Name=$disk.FriendlyName; State=$disk.HealthStatus; Details=("{0}; temp {1}; wear {2}" -f $disk.Size,$disk.TemperatureC,$disk.WearPercent) }) | Out-Null
    }

    $resources = [System.Collections.Generic.List[object]]::new()
    $resources.Add([pscustomobject]@{ Resource='RAM'; Capacity=$Report.Memory.Installed; Used=$Report.Memory.Used; Free=$Report.Memory.Available; PercentUsed=$Report.Memory.UsedPercent; FileSystem='' }) | Out-Null
    foreach ($disk in $Report.LogicalDisks) {
        $usedBytes = [math]::Max([long]0, ([long]$disk.SizeBytes - [long]$disk.FreeBytes))
        $resources.Add([pscustomobject]@{ Resource=$disk.Drive; Capacity=$disk.Size; Used=(Format-ArgonovSysInfoBytes $usedBytes); Free=$disk.Free; PercentUsed=$disk.UsedPercent; FileSystem=$disk.FileSystem }) | Out-Null
    }

    $style = @'
<style>
body{font-family:Segoe UI,Arial,sans-serif;background:#0b1012;color:#dce7e5;margin:28px}h1,h2{color:#00d9ff}h1{border-bottom:1px solid #00d9ff;padding-bottom:12px}h2{margin-top:28px}table{border-collapse:collapse;width:100%;margin:10px 0 22px}th,td{border:1px solid #334247;padding:7px 9px;text-align:left;vertical-align:top}th{background:#153036;color:#00ff88}tr:nth-child(even){background:#111a1d}.critical{color:#ff3355}.warning{color:#ffd700}.info{color:#00d9ff}.muted{color:#879795}code{color:#00ff88}
</style>
'@
    $inventoryHtml = (@($inventory.ToArray() | ConvertTo-Html -Fragment) -join [Environment]::NewLine)
    $resourcesHtml = (@($resources.ToArray() | ConvertTo-Html -Fragment) -join [Environment]::NewLine)
    $sensorsHtml = (@($Report.Sensors | Select-Object Hardware,Name,SensorType,Value,Unit,Min,Max | ConvertTo-Html -Fragment) -join [Environment]::NewLine)
    $healthHtml = (@($Report.Findings | Select-Object Severity,Scope,Category,DiagnosticCode,Title,Details,Recommendation,SearchQuery,SearchUrl,ReferenceUrl | ConvertTo-Html -Fragment) -join [Environment]::NewLine) -replace '<td>(https?://[^<]+)</td>', '<td><a href="$1">$1</a></td>'
    $eventsHtml = (@($Report.Events | Select-Object TimeCreated,LogName,LevelName,Provider,Id,DiagnosticCode,StopCode,SearchQuery,SearchUrl,ReferenceUrl,Message | ConvertTo-Html -Fragment) -join [Environment]::NewLine) -replace '<td>(https?://[^<]+)</td>', '<td><a href="$1">$1</a></td>'
    $eventWarningsHtml = if (@($Report.EventQueryWarnings).Count -gt 0) { '<ul>' + ((@($Report.EventQueryWarnings | ForEach-Object { '<li>' + [System.Net.WebUtility]::HtmlEncode([string]$_) + '</li>' })) -join '') + '</ul>' } else { '<p>Нет отмеченных ограничений доступа к журналам.</p>' }
    $html = @"
<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>ARGONOV SYSINFO</title>$style</head><body>
<h1>ARGONOV SYSINFO · Отчёт о состоянии компьютера</h1>
<p class="muted">Создан: $($Report.GeneratedAt) · Компьютер: $($Report.ComputerName) · Windows: $($Report.OS.Caption) · Версия схемы: $($Report.SchemaVersion)</p>
<h2>Сводка</h2><p>Статус: <strong>$($Report.Summary.Status)</strong>; текущих критических отклонений: $($Report.Summary.Critical); текущих предупреждений: $($Report.Summary.Warnings); требуют проверки: $($Report.Summary.VerificationFindings); исторических сигналов: $($Report.Summary.HistoricalFindings); событий в журнале: $($Report.Summary.Events).</p>
<p class="muted">Отчёт включает только доступные Windows и аппаратуре показатели. Отсутствие ошибки не доказывает отсутствие неисправности.</p>
<h2>Аппаратная конфигурация</h2>$inventoryHtml
<h2>Ресурсы и тома</h2>$resourcesHtml
<h2>Аппаратные датчики</h2><p class="muted">$($Report.SensorBackend.Message)</p>$sensorsHtml
<h2>Проблемы и рекомендации</h2>$healthHtml
<h2>События Windows</h2>$eventWarningsHtml$eventsHtml
<p class="muted">Отчёт хранится локально. Проверь его перед публикацией: имя компьютера, модели устройств и системные события могут быть чувствительными данными.</p>
</body></html>
"@
    Set-Content -LiteralPath $htmlPath -Value $html -Encoding utf8
    Write-Host ''
    Write-Host '  Отчёт сохранён:' -ForegroundColor Green
    Write-Host ('    HTML: {0}' -f $htmlPath) -ForegroundColor Cyan
    Write-Host ('    JSON: {0}' -f $jsonPath) -ForegroundColor Cyan
    Write-Host '  Перед публикацией проверь отчёт: он может содержать имя ПК, модели железа и системные события.' -ForegroundColor Yellow
}

function Start-ArgonovSysInfoLive {
    param([ValidateRange(1,60)][int]$Interval = 2, [switch]$Log)
    Initialize-ArgonovSysInfoPaths
    Write-Host 'Запущен режим live. Ctrl+C — остановить.' -ForegroundColor Cyan
    Write-Host 'Системные счётчики опрашиваются периодически; запись на диск идёт только с флагом -Log.' -ForegroundColor DarkGray
    $previousNetwork = @{}
    $sensorSession = New-ArgonovSysInfoSensorSession
    try {
        while ($true) {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            $cpu = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
            $total = if ($os) { [long]$os.TotalVisibleMemorySize * 1KB } else { 0L }
            $free = if ($os) { [long]$os.FreePhysicalMemory * 1KB } else { 0L }
            $used = [math]::Max([long]0, $total - $free)
            $memoryPercent = if ($total -gt 0) { [math]::Round(($used / $total) * 100,1) } else { $null }
            $sensorData = Read-ArgonovSysInfoSensorSession -Session $sensorSession
            $cpuLoad = if ($cpu) { $cpu.PercentProcessorTime } else { $null }
            $network = @{}
            try {
                foreach ($adapter in @(Get-NetAdapterStatistics -ErrorAction Stop)) {
                    $network[$adapter.Name] = [pscustomobject]@{ Received=[long]$adapter.ReceivedBytes; Sent=[long]$adapter.SentBytes }
                }
            } catch {}
            $rxRate = $null; $txRate = $null
            if ($network.Count -gt 0 -and $previousNetwork.Count -gt 0) {
                $rx = 0L; $tx = 0L
                foreach ($name in $network.Keys) {
                    if ($previousNetwork.ContainsKey($name)) {
                        $rx += [math]::Max([long]0, ($network[$name].Received - $previousNetwork[$name].Received))
                        $tx += [math]::Max([long]0, ($network[$name].Sent - $previousNetwork[$name].Sent))
                    }
                }
                $rxRate = [math]::Round($rx / $Interval, 1)
                $txRate = [math]::Round($tx / $Interval, 1)
            }
            $previousNetwork = $network

            Clear-Host
            Show-ArgonovSysInfoHeader -Subtitle 'Live мониторинг'
            Write-ArgonovSysInfoLine 'Время' (Get-Date -Format 'HH:mm:ss') Cyan
            Write-ArgonovSysInfoLine 'CPU' $(if ($null -ne $cpuLoad) { "$cpuLoad%" } else { 'нет счётчика производительности' })
            Write-ArgonovSysInfoLine 'ОЗУ' ("{0} / {1} ({2}%)" -f (Format-ArgonovSysInfoBytes $used), (Format-ArgonovSysInfoBytes $total), $memoryPercent)
            Write-ArgonovSysInfoLine 'Сеть RX / TX' $(if ($null -ne $rxRate) { "$(Format-ArgonovSysInfoBytes ([long]$rxRate)) / $(Format-ArgonovSysInfoBytes ([long]$txRate)) в секунду" } else { 'сбор начат; дельта появится через интервал' })
            Write-Host ''
            Write-Host '  ДАТЧИКИ' -ForegroundColor Magenta
            if ($sensorData.Available) {
                foreach ($sensor in @($sensorData.Items | Where-Object { $_.SensorType -in @('Temperature','Fan','Load','Clock','Power') } | Select-Object -First 30)) {
                    Write-Host ('    {0,-11} {1,-26} {2,-22} {3} {4}' -f $sensor.SensorType,$sensor.Hardware,$sensor.Name,$sensor.Value,$sensor.Unit) -ForegroundColor Gray
                }
            } else { Write-Host ('    {0}' -f $sensorData.Message) -ForegroundColor Yellow }
            if ($Log) {
                $csv = [pscustomobject]@{
                    Timestamp = Get-Date -Format 'o'
                    CpuLoadPercent = $cpuLoad
                    MemoryUsedBytes = $used
                    MemoryTotalBytes = $total
                    MemoryUsedPercent = $memoryPercent
                    NetworkRxBytesPerSecond = $rxRate
                    NetworkTxBytesPerSecond = $txRate
                    Temperatures = (@($sensorData.Items | Where-Object SensorType -eq 'Temperature' | ForEach-Object { '{0}/{1}={2}' -f $_.Hardware,$_.Name,$_.Value }) -join '; ')
                    Fans = (@($sensorData.Items | Where-Object SensorType -eq 'Fan' | ForEach-Object { '{0}/{1}={2}' -f $_.Hardware,$_.Name,$_.Value }) -join '; ')
                }
                if (Test-Path -LiteralPath $script:ARGONOV_SYSINFO_HISTORY) { $csv | Export-Csv -LiteralPath $script:ARGONOV_SYSINFO_HISTORY -Append -NoTypeInformation -Encoding utf8 }
                else { $csv | Export-Csv -LiteralPath $script:ARGONOV_SYSINFO_HISTORY -NoTypeInformation -Encoding utf8 }
                Write-Host ('  Запись истории: {0}' -f $script:ARGONOV_SYSINFO_HISTORY) -ForegroundColor DarkGray
            }
            Write-Host ''
            Write-Host ("  Обновление каждые {0} сек · Ctrl+C — остановить" -f $Interval) -ForegroundColor Yellow
            Start-Sleep -Seconds $Interval
        }
    } catch [System.Management.Automation.PipelineStoppedException] {
        Write-Host ''
        Write-Host '  Live-мониторинг остановлен.' -ForegroundColor DarkGray
    } catch [System.OperationCanceledException] {
        Write-Host ''
        Write-Host '  Live-мониторинг остановлен.' -ForegroundColor DarkGray
    } finally {
        if ($null -ne $sensorSession.Computer) { try { $sensorSession.Computer.Close() } catch {} }
    }
}

function Show-ArgonovSysInfoHistory {
    if (-not (Test-Path -LiteralPath $script:ARGONOV_SYSINFO_HISTORY)) {
        Write-Host 'История пока пуста. Запусти sysinfo live -Log, чтобы начать запись измерений.' -ForegroundColor Yellow
        return
    }
    Write-Host ''
    Write-Host ('  История ARGONOV SYSINFO: {0}' -f $script:ARGONOV_SYSINFO_HISTORY) -ForegroundColor Cyan
    Import-Csv -LiteralPath $script:ARGONOV_SYSINFO_HISTORY -ErrorAction Stop |
        Select-Object -Last 30 Timestamp, CpuLoadPercent, MemoryUsedPercent, NetworkRxBytesPerSecond, NetworkTxBytesPerSecond, Temperatures, Fans |
        Format-Table -AutoSize -Wrap
}

function sysinfo {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [ValidateSet('summary','live','deep','setup','export','history','help')]
        [string]$Mode = 'summary',
        [ValidateRange(1,90)][int]$Days = 7,
        [ValidateRange(1,60)][int]$Interval = 2,
        [switch]$Log,
        [string]$Path = ''
    )

    Initialize-ArgonovSysInfoPaths
    switch ($Mode.ToLowerInvariant()) {
        'help' { Show-ArgonovSysInfoHelp; return }
        'setup' { Install-ArgonovSysInfoSensorBackend; return }
        'history' { Show-ArgonovSysInfoHistory; return }
        'live' { Start-ArgonovSysInfoLive -Interval $Interval -Log:$Log; return }
        'deep' {
            try {
                $report = Get-ArgonovSysInfoCimData -Days $Days -Deep
                Show-ArgonovSysInfoReport -Report $report -Deep -Days $Days
            } catch {
                Write-Host ('sysinfo не удалось собрать данные Windows: {0}' -f (Get-ArgonovSysInfoErrorText $_)) -ForegroundColor Red
            }
            return
        }
        'export' {
            try {
                $report = Get-ArgonovSysInfoCimData -Days 1
                Export-ArgonovSysInfoReport -Report $report -Path $Path
            } catch {
                Write-Host ('sysinfo export завершился ошибкой: {0}' -f (Get-ArgonovSysInfoErrorText $_)) -ForegroundColor Red
            }
            return
        }
        default {
            try {
                $report = Get-ArgonovSysInfoCimData -Days 1
                Show-ArgonovSysInfoReport -Report $report
            } catch {
                Write-Host ('sysinfo не удалось собрать данные Windows: {0}' -f (Get-ArgonovSysInfoErrorText $_)) -ForegroundColor Red
                Write-Host 'Проверь, что PowerShell CIM/WMI работает, и запусти doctor для проверки оболочки.' -ForegroundColor DarkGray
            }
        }
    }
}
