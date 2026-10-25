# ARGONOV SYSINFO — diagnostic center

`sysinfo` is a read-only diagnostic layer for the existing ARGONOV Windows PowerShell shell. It complements `dash`: the dashboard is a quick system overview; sysinfo focuses on health indicators, errors, sensors, storage reliability and supporting evidence.

## Commands

| Command | Action |
|---|---|
| `sysinfo` | Current snapshot: Windows, CPU, GPUs, RAM, motherboard/BIOS, all local volumes, physical disk status, available sensors, device problems and recent relevant events. |
| `sysinfo live` | Repeated monitoring of CPU, RAM, network throughput and available sensors. Stop with `Ctrl+C`. |
| `sysinfo live -Log` | Same monitoring, while recording a CSV history under `$HOME\.argonov\sysinfo\history.csv`. |
| `sysinfo deep` | Extended event analysis, device error codes, storage counters and additional Windows security status. Read-only. |
| `sysinfo deep -Days 14` | Extended event lookback for 14 days. Allowed range is 1–90 days. |
| `sysinfo setup` | Downloads the official LibreHardwareMonitor .NET 10 release, verifies the asset SHA-256 against GitHub release metadata, and installs its library locally. It does not launch the graphical application. |
| `sysinfo export` | Saves a JSON and HTML report under `$HOME\.argonov\sysinfo\reports`. |
| `sysinfo export -Path C:\Reports\pc` | Saves `pc.json` and `pc.html` at the specified base path. |
| `sysinfo history` | Displays recent CSV measurements, if live logging was enabled. |
| `sysinfo help` | Shows built-in help. |

## Data sources

- Windows CIM/WMI for OS, processor inventory, graphics adapters, memory modules, BIOS and motherboard data.
- Windows Storage cmdlets (`Get-PhysicalDisk`, `Get-StorageReliabilityCounter`) for physical disk health, wear, temperatures and reliability counters, where the controller/driver reports them.
- Windows event logs for recent critical/error/warning events, including WHEA, storage, display and unexpected-shutdown records. Entries are grouped by provider and Event ID; correlated EventLog 6008 entries are not counted as duplicate root-cause findings when a nearby Kernel-Power 41 exists.
- Plug-and-Play device status for devices reporting a non-OK state.
- LibreHardwareMonitor's library, loaded inside the existing PowerShell process, for supported thermal, fan, voltage, load, clock and power sensors.

## Hardware sensors and installation

Windows does not expose all hardware telemetry through one universally supported interface. `sysinfo setup` is an explicit optional step: the official release asset is selected from the GitHub API and its SHA-256 is checked before extraction. The library is loaded into the current PowerShell process; the GUI app is not started. Some sensors can remain unavailable, may require an elevated shell, or may not be exposed by a given BIOS, controller or driver. A missing reading is reported as missing data, not as a temperature of zero.

Project: <https://github.com/LibreHardwareMonitor/LibreHardwareMonitor>
The upstream project is licensed under MPL-2.0 and includes third-party notices. Keep any upstream license and notice files with the local library installation.

## Diagnostic codes and Internet search

Each finding includes a stable diagnostic code, a ready-to-copy search query, a Google search URL, and an official Microsoft reference where a reliable one exists. The JSON and HTML exports contain the same fields (`Scope`, `DiagnosticCode`, `SearchQuery`, `SearchUrl`, `ReferenceUrl`).

- **Windows identifiers** such as `WIN-EVENT-KERNEL-POWER-41`, `WIN-EVENT-WHEA-LOGGER-1`, `WIN-DEVICE-MANAGER-CODE-10` and `WIN-BUGCHECK-0x00000124` refer to a source event, Device Manager problem code, or stop code.
- **ARGONOV rule codes** (`ARGONOV-...`) identify a heuristic raised by this project, for example low disk space or high RAM usage. They are not Microsoft error numbers. Use their generated search query to find troubleshooting information.
- A Windows Event ID is not necessarily a root-cause code. For example, Event ID 41 says Windows did not shut down cleanly; when `BugcheckCode=0`, Windows did not record a stop code in that event. The cause requires surrounding evidence.
- WHEA hardware error records use CPER data. `WIN-EVENT-WHEA-LOGGER-1` identifies the event family; it does not independently name a defective part.

## How to read the status

- `CRITICAL`: a currently measured indicator crosses a high-risk threshold or an active device/storage check reports a serious issue.
- `ATTENTION`: current measurements or device state contain warnings requiring review.
- `HISTORICAL_EVENTS`: recent Windows logs contain critical/error events, but they are classified as historical evidence rather than proof of a current fault.
- `PARTIAL_DATA`: some telemetry or event-log queries were unavailable, so the result is incomplete.
- `NO_KNOWN_ISSUES`: the checks available to ARGONOV did not detect an issue covered by its rules. This does not prove that the machine is fault-free.

Temperature limits in this first release are conservative heuristics for raising a review flag. Component specifications and manufacturer diagnostics take precedence, especially for GPU hotspot/junction readings.

## Safety and privacy

- All default diagnostics are read-only. They do not modify BIOS/UEFI, edit the registry, kill processes, install drivers, repair Windows or launch stress tests.
- `sysinfo setup` is the only mode that downloads the optional sensor library. It uses the official GitHub release URL and verifies the archive hash before extraction.
- Live logging is opt-in (`sysinfo live -Log`). JSON/HTML exports stay local and can include the computer name, device models, event text and diagnostic details. Review an exported report before sharing it publicly.
- No telemetry is sent to ARGONOV or another service by the diagnostics. The explicit setup mode contacts GitHub to fetch the official release.

## Test

Run the syntax/integration smoke test from the repository root:

```powershell
pwsh -NoProfile -File .\tests\Test-Sysinfo.ps1
```

The smoke test parses the changed PowerShell scripts, checks the command catalog and unit-tests Kernel-Power/WHEA/bugcheck mappings, DCOM 10016 policy, TPM-WMI 1801/1808 current-state policy, Windows 10 ESU status signaling, PlanetVPN service residue classification, Secure Boot access-denied handling, and separate memory-speed fields. Actual hardware sensors, Windows event logs, Secure Boot state and storage reliability counters must still be tested on the target PC because their availability depends on hardware, drivers and permissions.


## Диагностические правила 2.2.0 — сохранённая база

- `DistributedCOM 10016` по умолчанию трактуется как информационное историческое событие: Microsoft описывает типовые записи как ожидаемые и рекомендует не менять разрешения DCOM только ради их подавления.
- `Service Control Manager 7000` группируется по имени службы. Для `PlanetVPNService` ARGONOV проверяет регистрацию службы и путь к исполняемому файлу только для чтения. Никакая служба автоматически не удаляется; HAP не затрагивается.
- Скорости `ConfiguredClockSpeed` и `Speed` показываются отдельно как данные Win32_PhysicalMemory/SMBIOS, не как значения независимого live-датчика.
- Если проверка Secure Boot возвращает «доступ запрещён», отчёт предлагает повторить deep-диагностику в повышенной PowerShell-сессии, а не трактует это как отключённый Secure Boot.
- Для Windows 10 22H2 (build 19045) отчёт напоминает проверить ESU: обычная поддержка закончилась 14 октября 2025 года, но по номеру сборки нельзя определить регистрацию в ESU. Исключены LTSC/IoT-редакции.

### Диагностические правила 2.3.0

- `TPM-WMI 1801` больше не классифицируется как подтверждённая текущая неисправность только из-за недавнего времени события. Отчёт читает `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\UEFICA2023Status` и ищет более позднее успешное событие `TPM-WMI 1808`. Если подтверждения нет, выводится scope `Verification` («требует проверки»); если статус `Updated` или более позднее событие 1808 подтверждает успех, запись 1801 остаётся информационной историей.
- Сводка отдельно считает проверки, требующие подтверждения, а не смешивает их с доказанными текущими отклонениями.
- События с `Event ID 0` и пустым сообщением остаются видимыми в сыром списке без выдуманного кода диагностики и не создают неинформативное finding.
- Эти проверки выполняют только чтение реестра и журналов. ARGONOV не изменяет сертификаты/ключи Secure Boot и не удаляет службы.
