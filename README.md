# ⚡ ARGONOV SHELL

**A custom PowerShell 7 shell for Windows 11**
**Кастомная оболочка PowerShell 7 для Windows 11**

*Fast commands · Git aliases · AI agent · OSINT toolkit · CAD launcher*
*Быстрые команды · Git-алиасы · AI-агент · OSINT-мультитул · CAD-лончер*

![PowerShell](https://img.shields.io/badge/PowerShell-7.6-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)
![Git](https://img.shields.io/badge/Git-optional-F05032?style=flat-square&logo=git&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Commands](https://img.shields.io/badge/Commands-108-brightgreen?style=flat-square)

---

## Table of Contents / Содержание

- [Overview / Обзор](#overview--обзор)
- [Features / Возможности](#features--возможности)
- [Requirements / Требования](#requirements--требования)
- [Installation / Установка](#installation--установка)
- [Quick Start / Быстрый старт](#quick-start--быстрый-старт)
- [Command Reference / Справочник команд](#command-reference--справочник-команд)
- [AI Agent / AI-агент](#ai-agent--ai-агент)
- [Safety / Безопасность](#safety--безопасность)
- [Architecture / Архитектура](#architecture--архитектура)
- [Project Structure / Структура](#project-structure--структура)
- [Configuration / Конфигурация](#configuration--конфигурация)
- [Coding Conventions / Соглашения](#coding-conventions--соглашения)
- [Tech Stack / Технологии](#tech-stack--технологии)
- [Roadmap / План развития](#roadmap--план-развития)
- [License / Лицензия](#license--лицензия)

---

## Overview / Обзор

**EN:** ARGONOV SHELL is a customizable PowerShell environment for Windows 10/11. After installation, its profile is loaded when you start a PowerShell 7 session. It combines command-line helpers, system diagnostics, optional local AI, network utilities, OSINT helpers, backups and CAD/CAM launchers.

**RU:** ARGONOV SHELL — настраиваемая среда PowerShell для Windows 10/11. После установки её профиль загружается при запуске сеанса PowerShell 7. В проект входят команды навигации, диагностика системы, необязательная интеграция с локальным ИИ, сетевые и OSINT-инструменты, резервное копирование и запуск CAD/CAM-программ.

**Status / Статус:** Personal project, actively developed. 108 command catalog entries across 22 PowerShell module files in 8 module folders. / Персональный проект, активно развивается. 108 записей в каталоге команд, 22 PowerShell-модуля в 8 папках.

---

## Features / Возможности

| Feature / Возможность | Description / Описание |
|---|---|
| **⚡ Auto-loading** / Автозагрузка | Loads profile on every terminal start / Профиль подхватывается при каждом старте |
| **🎨 Custom prompt** / Кастомный промпт | Two-line prompt with path, git branch, time / Двухстрочный промпт: путь, git-ветка, время |
| **📦 108 catalog entries** / 108 записей | Aliases, functions, utilities / Алиасы, функции, утилиты |
| **🤖 AI agent** / AI-агент | Local LLM (LM Studio) / Локальная LLM (LM Studio) |
| **🕵️ OSINT toolkit** / OSINT-мультитул | IP, DNS, WHOIS, ports, hashes / IP, DNS, WHOIS, порты, хэши |
| **🌐 Proxy manager** / Прокси-менеджер | Fetch ~6000 public proxies / ~6000 публичных прокси |
| **📸 Screenshots** / Скриншоты | Full screen and window capture / Снимок экрана и окна |
| **💾 Backups** / Бэкапы | ZIP archives of the shell / ZIP-архивы оболочки |
| **📐 CAD launcher** / CAD-лончер | SolidWorks, AutoCAD, KOMPAS, Mastercam / SolidWorks, AutoCAD, КОМПАС, Mastercam |
| **🎮 Fun** / Развлечения | Matrix rain, CJK charset / Матрица, CJK-набор |
| **🔒 AI path allowlist** | Application-level path checks; not OS isolation / Проверка путей на уровне приложения, не изоляция ОС |
| **🌍 Bilingual** / Двуязычность | All commands documented in EN + RU / Все команды на EN + RU |

---

## Requirements / Требования

| Component / Компонент | Requirement / Требование | Notes / Примечание |
|---|---|---|
| **Windows** | Windows 10/11; Windows 11 is the primary target | Some features depend on installed Windows components |
| **PowerShell** | **7.6 or newer** | Required. Windows PowerShell 5.1 is not supported |
| **Git** | Optional | Needed for Git aliases and repository status display |
| **LM Studio** | Optional | Needed for local AI chat and model management |
| **Python** | Optional | Only needed by external or user-added Python-dependent workflows |

The core shell does not require Git, an SSH key, Python or LM Studio. Optional integrations may be unavailable until their dependencies are installed.

Ядро оболочки не требует Git, SSH-ключа, Python или LM Studio. Дополнительные интеграции будут недоступны, пока не установлены соответствующие зависимости.

---

## Installation / Установка

### Option 1 / Вариант 1 — Download ZIP / Скачать ZIP

This is the simplest path and does not require Git or an SSH key.

Это самый простой способ; Git и SSH-ключ не нужны.

1. Open the [GitHub repository](https://github.com/Andreyfdfd/argonov-windows).
2. Click **Code → Download ZIP** and extract the archive to a folder you own, for example §$HOME\Tools\ARGONOV§.
3. Open PowerShell 7.6+ and change to the extracted project folder.
4. Validate the scripts before installation:

§§§powershell
Set-Location "$HOME\Tools\ARGONOV"
pwsh -NoLogo -NoProfile -File .\install.ps1 -ValidateOnly
§§§

5. If validation succeeds, run the installer:

§§§powershell
pwsh -NoLogo -NoProfile -File .\install.ps1
§§§

The installer adds a marked, repeatable entry to the current PowerShell profile and backs up an existing profile before changing it. The optional `-ProfilePath` parameter targets a specific profile file; by default, the installer uses `$PROFILE`. It does not change the system or user ExecutionPolicy. Restart PowerShell 7 to load ARGONOV SHELL.

Установщик добавляет отдельный маркированный блок в профиль текущего PowerShell, поддерживает повторный запуск и создаёт резервную копию существующего профиля перед изменением. Политика выполнения скриптов автоматически не меняется. Перезапусти PowerShell 7, чтобы загрузить оболочку.

### Option 2 / Вариант 2 — Clone with HTTPS / Клонировать по HTTPS

Git is optional. If it is installed, HTTPS cloning does not require an SSH key.

Git необязателен. Если он установлен, можно использовать HTTPS без SSH-ключа.

§§§powershell
git clone https://github.com/Andreyfdfd/argonov-windows.git "$HOME\Tools\ARGONOV"
Set-Location "$HOME\Tools\ARGONOV"
pwsh -NoLogo -NoProfile -File .\install.ps1 -ValidateOnly
pwsh -NoLogo -NoProfile -File .\install.ps1
§§§

### Uninstallation / Удаление

Run this from the project directory in PowerShell 7.6+ to remove ARGONOV's managed entry from the current PowerShell profile:

```powershell
pwsh -NoLogo -NoProfile -File .\uninstall.ps1 -WhatIf
pwsh -NoLogo -NoProfile -File .\uninstall.ps1
```

Use `-WhatIf` first to preview the change. During a normal run, the uninstaller creates a timestamped profile backup before removing the marked ARGONOV block. It preserves the rest of the profile and leaves project files, backups and user data in place. The optional `-ProfilePath` parameter is intended for tests or a specific profile file.

Запускай из каталога проекта в PowerShell 7.6+. Сначала проверь действие через `-WhatIf`. При обычном запуске деинсталлятор сохраняет резервную копию профиля с меткой времени, а затем удаляет только маркированный блок ARGONOV. Остальное содержимое профиля сохраняется; файлы проекта, резервные копии и пользовательские данные не удаляются. Параметр `-ProfilePath` предназначен для тестов или работы с конкретным файлом профиля.

### Troubleshooting / Если запуск скриптов заблокирован

The installer intentionally does not weaken your execution policy. If PowerShell blocks a script, first review your organisation's policy and the downloaded source. Only if you trust the source and control the device, you may choose to allow locally created scripts for your user:

Установщик намеренно не ослабляет политику выполнения. Если PowerShell блокирует скрипт, сначала проверь политику устройства и источник файла. Только если ты доверяешь исходникам и управляешь устройством, можно разрешить локальные скрипты для текущего пользователя:

§§§powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
§§§

Do not use administrator privileges just to install the shell. The installer requires PowerShell 7.6+ and stops before profile changes if script syntax validation fails.

Не запускай установку от администратора без необходимости. Установщик требует PowerShell 7.6+ и прекращает работу до изменения профиля, если обнаруживает ошибки синтаксиса.

---

## Quick Start / Быстрый старт

**EN:** Open Windows Terminal and try:

**RU:** Открой Windows Terminal и попробуй:

```powershell
sysinfo           # Full system health diagnostics / Полная диагностика состояния ПК
myip              # Your external IP / Внешний IP
ai привет         # Chat with local AI / Чат с локальной нейросетью
matrix            # Digital rain / Цифровой дождь
commands          # Full command catalog / Каталог команд
```

---

## Command Reference / Справочник команд

**EN:** Full list: `commands` command.
**RU:** Полный список — команда `commands`.

```powershell
commands          # Full catalog (EN + RU) / Полный каталог
commands -Ru      # Russian only / Только русский
commands -En      # English only / Только английский
info              # Help screen / Справка
```

### Navigation & Files / Навигация и файлы

| Command / Команда | EN | RU |
|---|---|---|
| `..` `...` `....` `.....` | Go up 1–4 levels | Вверх на 1–4 уровня |
| `~` `home` `root` | Home / drive root | Домашняя / корень диска |
| `up N` | Go up N levels | Вверх на N уровней |
| `mkcd PATH` | Create folder and enter | Создать папку и войти |
| `ll` `la` | List files | Список файлов |
| `touch FILE` | Create / update timestamp | Создать / обновить файл |
| `sizeof PATH` | Folder size | Размер папки |
| `find-file PATTERN` | Recursive search | Рекурсивный поиск |
| `which CMD` | Locate command | Где команда |
| `grep TEXT FILE` | Search in file | Поиск в файле |

### System / Система

| Command / Команда | EN | RU |
|---|---|---|
| `sysinfo` | Full system health diagnostics | Полная диагностика состояния ПК |
| `sysinfo live` | Live CPU/RAM/network/sensor monitoring | Мониторинг нагрузки и датчиков |
| `sysinfo live -Log` | Live monitoring plus CSV history | Мониторинг с записью истории CSV |
| `sysinfo deep [-Days N]` | Extended events, device and security analysis | Расширенный анализ событий, устройств и защиты |
| `sysinfo setup` | Install and hash-verify sensor library | Установить библиотеку датчиков и проверить SHA-256 |
| `sysinfo export [-Path BASE]` | Export HTML and JSON report | Экспорт отчёта в HTML и JSON |
| `sysinfo history` | Show recent measurements | Показать последние измерения |
| `sysinfo help` | Show sysinfo mode help | Справка по режимам sysinfo |
| `top` | Top 15 processes by RAM | Топ-15 процессов по RAM |
| `psg NAME` | Processes by name | Процессы по имени |
| `pskill NAME` | Kill process | Убить процесс |
| `bigfiles PATH` | Largest files | Крупнейшие файлы |
| `disks` | All disks | Все диски |
| `env FILTER` | Environment variables | Переменные окружения |
| `path` | Contents of $PATH | Содержимое $PATH |
| `svc FILTER` | Windows services | Службы Windows |
| `startup` | Autorun entries | Автозагрузка |
| `cleanup` | Temp size preview | Размер temp |
| `cleanup -Execute` | Clean temp | Очистка temp |
| `uptime` | System uptime | Аптайм системы |

Detailed diagnostics, data-source limits and privacy notes: [SYSINFO guide](docs/SYSINFO.md).

### Network / Сеть

| Command / Команда | EN | RU |
|---|---|---|
| `myip` | External IP | Внешний IP |
| `localip` | Local IPs | Локальные IP |
| `ping-http URL` | HTTP ping | HTTP-пинг |
| `dns NAME` | DNS lookup | DNS-запрос |
| `ports FILTER` | Listening ports | Занятые порты |
| `is-port N` | Check port | Проверить порт |
| `wget URL` | Download file | Скачать файл |

### Proxy / Прокси

| Command / Команда | EN | RU |
|---|---|---|
| `proxy-fetch` | Fetch proxies | Скачать прокси |
| `proxy-test [-Max N]` | Test proxies | Проверить прокси |
| `proxy-test-one PROXY` | Test one proxy | Проверить один |
| `proxy-top` | Top proxies | ТОП-20 рабочих |
| `proxy-use N` | Apply proxy #N after confirmation; saves original settings | Включить прокси #N после подтверждения; сохраняет прежние настройки |
| `proxy-clear` | Restore the saved Windows user proxy settings | Восстановить сохранённые настройки прокси Windows |
| `proxy-status` | Current status | Статус |
| `proxy-count` | Count proxies | Количество |

**Proxy safety / Безопасность прокси:** `proxy-use` writes to the current user's Windows Internet Settings. Before changing them, it saves the original `ProxyEnable`, `ProxyServer` and `ProxyOverride` values in `$HOME\.argonov-proxy\original-settings.json`. Switching proxy servers keeps the original snapshot; `proxy-clear` restores it and removes the snapshot. If no snapshot exists, `proxy-clear` asks before disabling the current proxy without restoring a baseline. Public proxies are untrusted; do not use them for passwords, banking or sensitive activity. `proxy-use -Force` bypasses the confirmation prompt only, not the warning output.

**Безопасность прокси:** `proxy-use` меняет настройки Internet Settings текущего пользователя Windows. Перед изменением сохраняются исходные значения `ProxyEnable`, `ProxyServer` и `ProxyOverride` в `$HOME\.argonov-proxy\original-settings.json`. При переключении прокси исходный снимок не перезаписывается; `proxy-clear` восстанавливает настройки и удаляет снимок. Если сохранённого снимка нет, команда спрашивает подтверждение перед отключением текущего прокси без восстановления исходных значений. Публичным прокси нельзя доверять: не используй их для паролей, банковских операций и чувствительных действий. `proxy-use -Force` отключает только интерактивный запрос подтверждения, но не предупреждения.

### OSINT

| Command / Команда | EN | RU |
|---|---|---|
| `scan-ip [IP]` | IP geolocation | IP-геолокация |
| `scan-dns DOMAIN` | DNS + SPF/DMARC | DNS + SPF/DMARC |
| `scan-whois DOMAIN` | WHOIS lookup | WHOIS |
| `scan-ports HOST` | Quick port scan | Быстрый скан портов |
| `hash-text TEXT` | MD5/SHA1/SHA256 | MD5/SHA1/SHA256 |
| `hash-file FILE` | File hashes | Хэши файла |
| `hash-identify HASH` | Identify hash | Тип хэша |
| `hack-pass [N]` | Password generator | Генератор паролей |
| `hack-qr TEXT` | QR code | QR-код |
| `hack-short URL` | Shorten URL | Сократить ссылку |
| `hack` | OSINT help | Справка OSINT |

### AI

| Command / Команда | EN | RU |
|---|---|---|
| `ai Q` | Ask model | Задать вопрос |
| `ai -Chat` | Interactive chat | Интерактивный чат |
| `ai -Model NAME` | Select model | Выбрать модель |
| `ai -Reset` | Clear history | Очистить историю |
| `ai -Yolo` | No confirmations | Без подтверждений |
| `ai -Dry` | Show without executing | Показать без выполнения |
| `ai -List` | List models | Список моделей |

### LM Studio

| Command / Команда | EN | RU |
|---|---|---|
| `lm-up` | Load model to VRAM | Загрузить модель |
| `lm-down` | Unload models | Выгрузить модели |
| `lm-status` | Server status | Статус сервера |
| `lm-models` | List models on disk | Модели на диске |

### Git

| Command / Команда | EN | RU |
|---|---|---|
| `gs` | git status | git status |
| `ga .` | git add | git add |
| `gc "MSG"` | git commit | git commit |
| `gp` | git push | git push |
| `gpl` | git pull | git pull |
| `gd` | git diff | git diff |
| `gl` | git log (graph) | git log (граф) |
| `gb` | git branch | git branch |
| `gco BRANCH` | git checkout | git checkout |
| `gcl URL` | git clone | git clone |
| `git-branch` | Current branch | Текущая ветка |
| `git-dirty` | Uncommitted changes | Есть ли изменения |

### Screenshots / Скриншоты

| Command / Команда | EN | RU |
|---|---|---|
| `screenshot` | Full screen shot | Снимок всего экрана |
| `screenshot-window` | Active window shot | Снимок активного окна |
| `screenshot-list` | List last 20 | Список последних 20 |
| `screenshot-folder` | Open folder | Открыть папку |
| `screenshot-clean [N]` | Delete older than N days | Удалить старше N дней |

### Backup / Резервные копии

| Command / Команда | EN | RU |
|---|---|---|
| `backup` | ZIP of entire shell | ZIP всей оболочки |
| `backup "label"` | Backup with label | Бэкап с меткой |
| `backup-list` | List backups | Список архивов |
| `backup-restore` | Restore | Восстановление |
| `backup-delete` | Delete backup | Удалить архив |

**EN:** Stored at `C:\Users\<user>\ARGONOV-Backups\`
**RU:** Хранятся в `C:\Users\<user>\ARGONOV-Backups\`

### CAD/CAM

| Command / Команда | EN | RU |
|---|---|---|
| `cad` | Quick help | Краткая подсказка |
| `cad list` | Detect installed | Найти установленные |
| `cad kompas` | Launch KOMPAS-3D | Запустить КОМПАС-3D |
| `cad solidworks` | Launch SolidWorks | Запустить SolidWorks |
| `cad mastercam` | Launch Mastercam | Запустить Mastercam |
| `cad-files [path]` | Find projects | Найти проекты |
| `cad-open FILE` | Open in app | Открыть в программе |

**CAD:** SolidWorks · AutoCAD · Inventor · Fusion 360 · Siemens NX · CATIA · PTC Creo · KOMPAS-3D / КОМПАС-3D · FreeCAD · Rhinoceros · SketchUp · ArchiCAD

**CAM:** Mastercam · SolidCAM · hyperMILL · PowerMill · ESPRIT · CAMWorks · FeatureCAM

### Fun / Развлечения

| Command / Команда | EN | RU |
|---|---|---|
| `matrix` | Digital rain (30 FPS) | Цифровой дождь (30 FPS) |
| `м` | Same (Cyrillic) | То же (кириллица) |
| `matrix-fast` | Fast (45 FPS) | Быстрая (45 FPS) |
| `matrix-slow` | Slow (12 FPS) | Медленная (12 FPS) |
| `matrix-long` | Long tails | Длинные хвосты |
| `matrix-wide` | CJK charset | CJK-набор |

---

## AI Agent / AI-агент

**EN:** The AI agent can perform actions through special code blocks.

**RU:** AI-агент умеет выполнять действия через специальные блоки.

### Supported action blocks / Поддерживаемые блоки действий

The shell recognises the following action tags:

| Block / Блок | Purpose / Назначение |
|---|---|
| `write` | Create or overwrite a file / Создать или перезаписать файл |
| `read` | Read a file / Прочитать файл |
| `exec` | Run a PowerShell command / Запустить команду PowerShell |
| `mkdir` | Create a directory / Создать каталог |
| `list` | List directory contents / Показать содержимое каталога |
| `delete` | Delete a file or directory / Удалить файл или каталог |

Default mode requests confirmation for file and command actions. `ai -Yolo` skips those confirmations and must be used with care. `ai -Dry` previews supported actions without applying them. The agent uses the locally configured LM Studio endpoint by default.

### AI action example / Пример действия ИИ

```
write
<project-root>\hello.ps1
Write-Host "Привет"
```

The path must be inside an allowed directory configured by the AI module. The allowed-path check is an application-level guard, not a Windows security boundary.

## Safety / Безопасность

- The `ai-exec` path launches a PowerShell process. Treat model-generated commands as untrusted code and read each command before allowing execution.
- `ai -Yolo` removes confirmation prompts; it is not a security mode.
- Dangerous-command filters are heuristic checks and cannot guarantee detection of every harmful command or script.
- Some utilities make network requests to external services (external-IP lookup, IP geolocation, proxy lists and URL-shortening services). Review the relevant module before use in sensitive environments.
- System reports may contain computer names, device details and event-log text. Inspect exported HTML/JSON reports before sharing them publicly.
- Backups can contain source files and configuration. Keep them in a private location.

- В `ai-exec` запускается отдельный процесс PowerShell. Считай команды модели недоверенным кодом и читай их до подтверждения.
- `ai -Yolo` отключает подтверждения, а не повышает безопасность.
- Фильтры опасных команд эвристические и не гарантируют обнаружение всех вредоносных действий.
- Некоторые команды обращаются к внешним сервисам: определение внешнего IP, IP-геолокация, загрузка списков прокси или сокращение ссылок.
- Системные отчёты могут содержать имя компьютера, сведения об устройствах и текст журналов событий. Проверяй HTML/JSON перед публикацией.
- Резервные копии могут включать исходники и конфигурацию; храни их в закрытом каталоге.

## Architecture / Архитектура

The installer adds an entry to the current PowerShell profile. `profile.ps1` resolves the project root from its own location and loads modules from `modules\<category>\*.ps1` in a defined order. No specific installation directory is required.

Установщик добавляет запись в профиль текущего PowerShell. Файл `profile.ps1` определяет корень проекта относительно своего расположения и загружает модули из `modules\<категория>\*.ps1` в заданном порядке. Фиксированный путь установки не требуется.

Load order / Порядок загрузки:

1. `core` — completion, command catalog and prompt
2. `system` — system information, dashboard and utilities
3. `network` — network and proxy tools
4. `ai` — AI agent and LM Studio helpers
5. `tools` — backups, screenshots and CAD/CAM launchers
6. `dev` — Git aliases
7. `osint` — DNS, IP, WHOIS and hashing helpers
8. `fun` — terminal effects

## Project Structure / Структура проекта

```text
argonov-windows/
├── profile.ps1
├── install.ps1
├── reorganize.ps1
├── uninstall.ps1
├── README.md
├── ROADMAP.md
├── CHANGELOG.md
├── LICENSE
├── CONTRIBUTING.md
├── docs/
│   └── SYSINFO.md
├── tests/
│   ├── Test-Sysinfo.ps1
│   ├── Test-AISandbox.ps1
│   ├── Test-Backup.ps1
│   ├── Test-Install.ps1
│   ├── Test-Reorganize.ps1
│   ├── Test-Uninstall.ps1
│   └── Test-ProxySettings.ps1
└── modules/
    ├── ai/
    ├── core/
    ├── dev/
    ├── fun/
    ├── network/
    ├── osint/
    ├── system/
    └── tools/
```

## Configuration / Конфигурация

- To change the default AI model, edit `$script:AI_MODEL` in `modules/ai/ai.ps1`.
- The AI module derives its project root from the profile or its own module path.
- Backups are stored in `$HOME\ARGONOV-Backups` by default. You can set `$global:ARGONOV_BACKUP_DIR` before loading the backup module to choose another folder.
- Optional modules can be disabled by renaming their `.ps1` file so it no longer matches the module loader's `*.ps1` pattern.

- Чтобы сменить модель по умолчанию, измени `$script:AI_MODEL` в `modules/ai/ai.ps1`.
- AI-модуль определяет корень проекта относительно профиля или собственного пути.
- По умолчанию резервные копии хранятся в `$HOME\ARGONOV-Backups`. Для другого каталога до загрузки модуля можно задать `$global:ARGONOV_BACKUP_DIR`.
- Дополнительный модуль можно отключить, переименовав его `.ps1` так, чтобы он не попадал под маску загрузчика.

## Coding Conventions / Соглашения

- Runtime requirement: PowerShell 7.6 or newer. Windows PowerShell 5.1 is not supported.
- Use UTF-8 for source files. Do not convert scripts to ANSI or UTF-16.
- Keep changes focused and test one logical change at a time.
- Validate all PowerShell files and run the relevant smoke tests before opening a pull request.

Порядок проверки:

```powershell
pwsh -NoLogo -NoProfile -File .\install.ps1 -ValidateOnly
pwsh -NoLogo -NoProfile -File .\tests\Test-Sysinfo.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-AISandbox.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-Backup.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-Install.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-Reorganize.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-ProxySettings.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-Uninstall.ps1
```

## Tech Stack / Технологии

| Layer / Слой | Technology / Технология |
|---|---|
| Shell | PowerShell 7.6+ |
| Operating system | Windows 10/11; Windows 11 is the primary target |
| Terminal | Windows Terminal or another terminal host |
| Local AI (optional) | LM Studio with an OpenAI-compatible local API |
| Version control (optional) | Git over HTTPS or SSH |
| Python (optional) | Only for user-added or dependent scripts |

## Roadmap / План развития

See `ROADMAP.md` for planned work. The project is under active development; not every command has been exercised on every Windows configuration.

Планы развития находятся в `ROADMAP.md`. Проект активно развивается; не каждая команда проверена на всех конфигурациях Windows.

## License / Лицензия

ARGONOV SHELL is distributed under the MIT License. See `LICENSE`.

ARGONOV SHELL распространяется по лицензии MIT. Полный текст находится в файле `LICENSE`.
