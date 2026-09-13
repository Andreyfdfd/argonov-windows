# ARGONOV SHELL

> Кастомная оболочка PowerShell 7 для Windows 11 — быстрые команды, git-алиасы, AI-агент.

Персональная замена стандартного `PowerShell` + `Windows Terminal`. Загружается автоматически при старте терминала.

---

## Что внутри

| Модуль | Что делает |
|---|---|
| `profile.ps1` | автозагрузка, версии Python/PS, время, пользователь |
| `modules/sysinfo.ps1` | `sysinfo` — панель железа |
| `modules/navigation.ps1` | `..`, `~`, `ll`, `mkcd`, `touch`, `sizeof`, `find-file` |
| `modules/git-aliases.ps1` | `gs`, `ga`, `gc`, `gp`, `gl`, `gpl`, `gb`, `gco`, `gcl` |
| `modules/prompt.ps1` | двухстрочный промпт с git-веткой и временем |
| `modules/info.ps1` | `info` — справка по всем командам |
| `modules/network.ps1` | `myip`, `ports`, `ping-http`, `dns`, `wget`, `is-port` |
| `modules/processes.ps1` | `top`, `psg`, `pskill`, `bigfiles`, `disks` |
| `modules/admin.ps1` | `uptime`, `env`, `path`, `svc`, `startup`, `cleanup` |
| `modules/lmstudio.ps1` | `lm-up`, `lm-down`, `lm-status`, `lm-models` |
| `modules/ai.ps1` | `ai` — AI-агент на локальной модели (LM Studio) |

---

## Установка

### Требования

- **Windows 10/11**
- **PowerShell 7.6+**
- **Git**
- **LM Studio** (для AI-команд, опционально)

### Развёртывание

```powershell
git clone git@github.com:Andreyfdfd/argonov-windows.git C:\ARGONOV

# Подключить к профилю PowerShell
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
Add-Content -Path $PROFILE -Value '. C:\ARGONOV\profile.ps1' -Encoding UTF8