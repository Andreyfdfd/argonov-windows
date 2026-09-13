# ARGONOV SHELL

> Кастомная оболочка PowerShell 7 для Windows — быстрые команды, git-алиасы, AI-агент, OSINT-инструменты.
>
> Custom PowerShell 7 shell for Windows — fast commands, git aliases, AI agent, OSINT tools.

Персональная замена стандартного `PowerShell` + `Windows Terminal`. Загружается автоматически при старте терминала.

---

## Что внутри

| Модуль | Команды |
|---|---|
| `profile.ps1` | автозагрузка, версии, время, user |
| `modules/sysinfo.ps1` | `sysinfo` |
| `modules/navigation.ps1` | `..`, `~`, `ll`, `mkcd`, `touch`, `sizeof`, `find-file` |
| `modules/git-aliases.ps1` | `gs`, `ga`, `gc`, `gp`, `gl`, `gpl`, `gb`, `gco`, `gcl` |
| `modules/prompt.ps1` | двухстрочный промпт с git-веткой |
| `modules/info.ps1` | `info` |
| `modules/network.ps1` | `myip`, `localip`, `ports`, `ping-http`, `dns`, `wget` |
| `modules/processes.ps1` | `top`, `psg`, `pskill`, `bigfiles`, `disks` |
| `modules/admin.ps1` | `uptime`, `env`, `path`, `svc`, `startup`, `cleanup` |
| `modules/lmstudio.ps1` | `lm-up`, `lm-down`, `lm-status`, `lm-models` |
| `modules/ai.ps1` | `ai` — AI-агент |
| `modules/backup.ps1` | `backup`, `backup-list`, `backup-restore` |
| `modules/proxy.ps1` | `proxy-fetch`, `proxy-test`, `proxy-use` |
| `modules/screenshot.ps1` | `screenshot`, `screenshot-window`, `screenshot-list` |
| `modules/matrix.ps1` | `matrix`, `м`, `matrix-fast`, `matrix-slow` |
| `modules/hacktool.ps1` | `scan-ip`, `scan-dns`, `scan-ports`, `hash-text`, `hack-pass`, `hack-qr` |
| `modules/cad.ps1` | `cad`, `cad list`, `cad-files`, `cad-open` |
| `modules/commands.ps1` | `commands` — каталог всех команд |
| `install.ps1` | установщик |

---

## Установка

### Требования

- Windows 10/11
- PowerShell 7.6+
- Git
- LM Studio (для AI-команд, опционально)

### Развёртывание

```powershell
git clone git@github.com:Andreyfdfd/argonov-windows.git C:\ARGONOV

if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
Add-Content -Path $PROFILE -Value '. C:\ARGONOV\profile.ps1' -Encoding UTF8