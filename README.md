# ⚡ ARGONOV SHELL

**A custom PowerShell 7 shell for Windows 11**
**Кастомная оболочка PowerShell 7 для Windows 11**

*Fast commands · Git aliases · AI agent · OSINT toolkit · CAD launcher*
*Быстрые команды · Git-алиасы · AI-агент · OSINT-мультитул · CAD-лончер*

![PowerShell](https://img.shields.io/badge/PowerShell-7.6-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)
![Git](https://img.shields.io/badge/Git-SSH-F05032?style=flat-square&logo=git&logoColor=white)
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

**EN:** ARGONOV SHELL is a personal shell environment for Windows 11 built on top of **PowerShell 7**. It transforms the default terminal into a comprehensive toolbox for development, automation, AI assistance, OSINT research, and engineering tasks. The shell loads automatically when you open Windows Terminal.

**RU:** ARGONOV SHELL — персональная оболочка для Windows 11, построенная поверх **PowerShell 7**. Превращает стандартный терминал в полноценный инструментарий для разработки, автоматизации, AI-ассистента, OSINT-исследований и инженерных задач. Оболочка загружается автоматически при открытии Windows Terminal.

**Status / Статус:** Personal project, actively developed. 108 command catalog entries across 22 PowerShell module files in 8 module folders. / Персональный проект, активно развивается. 108 записей в каталоге команд, 22 PowerShell-модуля в 8 папках.

---

## Features / Возможности

| Feature / Возможность | Description / Описание |
|---|---|
| **⚡ Auto-loading** / Автозагрузка | Loads profile on every terminal start / Профиль подхватывается при каждом старте |
| **🎨 Custom prompt** / Кастомный промпт | Two-line prompt with path, git branch, time / Двухстрочный промпт: путь, git-ветка, время |
| **📦 96 commands** / 96 команд | Aliases, functions, utilities / Алиасы, функции, утилиты |
| **🤖 AI agent** / AI-агент | Local LLM (LM Studio) / Локальная LLM (LM Studio) |
| **🕵️ OSINT toolkit** / OSINT-мультитул | IP, DNS, WHOIS, ports, hashes / IP, DNS, WHOIS, порты, хэши |
| **🌐 Proxy manager** / Прокси-менеджер | Fetch ~6000 public proxies / ~6000 публичных прокси |
| **📸 Screenshots** / Скриншоты | Full screen and window capture / Снимок экрана и окна |
| **💾 Backups** / Бэкапы | ZIP archives of the shell / ZIP-архивы оболочки |
| **📐 CAD launcher** / CAD-лончер | SolidWorks, AutoCAD, KOMPAS, Mastercam / SolidWorks, AutoCAD, КОМПАС, Mastercam |
| **🎮 Fun** / Развлечения | Matrix rain, CJK charset / Матрица, CJK-набор |
| **🔒 Sandbox** | AI restricted to safe folders / AI ограничен безопасными папками |
| **🌍 Bilingual** / Двуязычность | All commands documented in EN + RU / Все команды на EN + RU |

---

## Requirements / Требования

| Component / Компонент | Version / Версия | Purpose / Назначение |
|---|---|---|
| **Windows** | Windows 10 build 19041+ / Windows 11 | OS / ОС |
| **Architecture** / Архитектура | x64 | Current Setup.exe build / Текущая сборка установщика |
| **PowerShell** | 7.6.9 (bundled) | Shell runtime / Среда выполнения |
| **.NET Runtime** | 10.x (bundled) | PowerShell runtime / Среда выполнения PowerShell |
| **Git for Windows** | Current stable PortableGit (optional task) | Git aliases and repository commands / Git-алиасы и команды работы с репозиториями |
| **Python** | 3.14 (optional task) | QR generation and Python scripts / Генерация QR и Python-скрипты |
| **Windows Terminal** | Current stable portable or existing package | Terminal host / Терминал |
| **LibreHardwareMonitor** | Current compatible release (optional task) | Hardware sensors in SYSINFO / Датчики в SYSINFO |
| **LM Studio** | Latest (optional, separate install) | Local AI backend / Локальный AI-бэкенд |

> **RU:** PowerShell 7.6.9 и .NET Runtime 10.x входят в установочный пакет. Предварительно устанавливать PowerShell, .NET, Git или Python не требуется. Установщик предлагает недостающие дополнительные компоненты и устанавливает их в пользовательский каталог без прав администратора.
>
> **EN:** PowerShell 7.6.9 and .NET Runtime 10.x are bundled. You do not need to preinstall PowerShell, .NET, Git, or Python. The installer offers missing optional components and deploys them per-user without administrator privileges.

LM Studio and AI models are not bundled. AI commands require a separate LM Studio installation and a model downloaded by the user. SSH keys are never generated automatically; HTTPS Git remotes work without an SSH key.

---

## Installation / Установка

### Recommended / Рекомендуемый способ — Setup.exe

1. Download and run **ARGONOV-SHELL-Setup-x64.exe**.
2. Select the optional components in the installer. Already available components are detected and reused.
3. Keep the default selections to install Git for Windows (PortableGit), Python 3.14 with qrcode and Pillow, Windows Terminal, and the SYSINFO sensor backend.
4. Complete installation. The Start menu shortcut opens ARGONOV SHELL in Windows Terminal when it is available; otherwise it opens the shared PowerShell console.

The installer includes PowerShell and .NET, verifies downloaded installers/archives with SHA-256 or SHA-512, does not change system-wide settings, and does not require administrator privileges.

Shared runtimes and tools are stored separately from the shell in:

    %LOCALAPPDATA%\Programs\ARGONOV-Dependencies

This is intentional: the future ARGONOV uninstaller will be able to remove the shell while leaving PowerShell, .NET, Git, Python, and Windows Terminal installed.

### Repair dependencies / Восстановление зависимостей

Use **Start → ARGONOV SHELL → Repair dependencies** to retry installation or repair Git, Python, Windows Terminal, and LibreHardwareMonitor without reinstalling the shell.

Installer logs and the dependency report are stored in:

    %LOCALAPPDATA%\ARGONOV\installer\

### Architecture note / Примечание об архитектуре

The current Setup.exe supports **Windows x64**. A separate ARM64 build is planned; do not run this x64 package on Windows ARM64 devices.

Windows Terminal portable mode requires Windows 10 build 19041 or later. On older Windows builds the shell can still be launched directly through PowerShell, but the Windows Terminal component cannot be deployed by this installer.

### Developer installation / Ручная установка для разработчиков

For development and manual testing, clone the repository and run the installer script from PowerShell 7.6+:

    git clone https://github.com/Andreyfdfd/argonov-windows.git
    pwsh -NoProfile -File .\argonov-windows\install.ps1

The project installer validates PowerShell syntax, copies the shell to the per-user application directory, backs up an existing installation, and adds a managed block to the selected PowerShell profile. This developer path is separate from the packaged Setup.exe workflow.

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
| `proxy-use N` | Apply proxy #N | Включить прокси #N |
| `proxy-clear` | Disable proxy | Отключить прокси |
| `proxy-status` | Current status | Статус |
| `proxy-count` | Count proxies | Количество |

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

**Write file / Создать или изменить файл** — `write`:
