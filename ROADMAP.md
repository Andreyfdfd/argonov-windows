# ⚡ ARGONOV SHELL

**A custom PowerShell 7 shell for Windows 11**
**Кастомная оболочка PowerShell 7 для Windows 11**

*Fast commands · Git aliases · AI agent · OSINT · Security · CAD launcher*
*Быстрые команды · Git-алиасы · AI-агент · OSINT · Безопасность · CAD-лончер*

![PowerShell](https://img.shields.io/badge/PowerShell-7.6-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)
![Git](https://img.shields.io/badge/Git-SSH-F05032?style=flat-square&logo=git&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Commands](https://img.shields.io/badge/Commands-101-brightgreen?style=flat-square)

---

## 📖 Table of Contents / Содержание

- [Overview / Обзор](#overview--обзор)
- [Features / Возможности](#features--возможности)
- [Requirements / Требования](#requirements--требования)
- [Installation / Установка](#installation--установка)
- [Quick Start / Быстрый старт](#quick-start--быстрый-старт)
- [Command Reference / Справочник команд](#command-reference--справочник-команд)
- [AI Agent / AI-агент](#ai-agent--ai-агент)
- [Security / Безопасность](#security--безопасность)
- [Safety & Sandbox / Безопасность AI](#safety--sandbox--безопасность-ai)
- [Architecture / Архитектура](#architecture--архитектура)
- [Project Structure / Структура проекта](#project-structure--структура-проекта)
- [Configuration / Конфигурация](#configuration--конфигурация)
- [Coding Conventions / Соглашения](#coding-conventions--соглашения)
- [Tech Stack / Технологии](#tech-stack--технологии)
- [Roadmap / План развития](#roadmap--план-развития)
- [License / Лицензия](#license--лицензия)

---

## Overview / Обзор

**EN:** ARGONOV SHELL is a personal PowerShell 7 environment for Windows 11. It combines fast commands, git aliases, a local AI agent, OSINT tools, antivirus integration, and a CAD/CAM launcher. The shell auto-loads on every terminal start and provides 101 commands across 8 categories.

**RU:** ARGONOV SHELL — персональная оболочка PowerShell 7 для Windows 11. Объединяет быстрые команды, git-алиасы, локальный AI-агент, OSINT-инструменты, антивирусную интеграцию и CAD/CAM-лончер. Оболочка автоматически загружается при старте терминала и даёт 101 команду в 8 категориях.

**Status / Статус:** Personal project, actively developed.

---

## Features / Возможности

| Feature | RU |
|---|---|
| ⚡ Auto-loading on terminal start | Автозагрузка при старте терминала |
| 🎨 Two-line prompt with git branch | Двухстрочный промпт с git-веткой |
| 🧠 Local AI agent with tool blocks | AI-агент с tool-блоками |
| 🛡 Antivirus integration (Defender + MinerSearch) | Антивирусная интеграция |
| 🕵️ OSINT toolkit | OSINT-мультитул |
| 🌐 Proxy manager | Менеджер прокси |
| 📸 Screenshots | Скриншоты |
| 💾 ZIP backups | ZIP-бэкапы |
| 📐 CAD/CAM launcher | CAD/CAM-лончер |
| 🔒 Sandbox for AI | Sandbox для AI |
| 🎮 Matrix rain | Матрица |
| 🗂 Categorized modules | Модули по категориям |
| 🌍 Bilingual | Двуязычность |

---

## Requirements / Требования

| Component | Version | Purpose |
|---|---|---|
| **Windows** | 10 / 11 | OS |
| **PowerShell** | 7.6+ | Shell runtime |
| **Git** | Any recent | Repo management |
| **SSH key** | ED25519 | GitHub auth |
| **LM Studio** | Latest | AI backend (optional) |
| **Python** | 3.14 | Scripts (optional) |
| **MinerSearch** | 1.4.x | Antivirus (optional) |

> 💡 **EN:** ARGONOV SHELL works without LM Studio — everything except `ai` commands.
> **RU:** ARGONOV SHELL работает без LM Studio — всё, кроме команд `ai`.

---

## Installation / Установка

### Option 1 / Вариант 1 — Clone from GitHub / Клонирование

```powershell
git clone git@github.com:Andreyfdfd/argonov-windows.git C:\ARGONOV

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
Add-Content -Path $PROFILE -Value '. C:\ARGONOV\profile.ps1' -Encoding UTF8
```

**EN:** Restart Windows Terminal. Done.
**RU:** Перезапустить Windows Terminal. Готово.

### Option 2 / Вариант 2 — Installer / Установщик

```powershell
pwsh -ExecutionPolicy Bypass -File C:\ARGONOV\install.ps1
```

**EN:** The installer checks PowerShell 7, Python, Git, SSH key, LM Studio, project structure, profile connection, module syntax, and automatically reorganizes modules into categories if needed.

**RU:** Установщик проверяет PowerShell 7, Python, Git, SSH-ключ, LM Studio, структуру проекта, подключение профиля, синтаксис модулей и автоматически реорганизует модули по категориям.

### Optional / Опционально — Enable script execution / Разрешить скрипты

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

---

## Quick Start / Быстрый старт

```powershell
sysinfo           # Hardware info / Панель железа
dash              # Full dashboard / Полный дашборд
myip              # External IP / Внешний IP
ai                # Open AI chat / Открыть чат с AI
security-quick    # Quick security check / Быстрая проверка
commands          # Full catalog / Каталог команд
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

### 🗂 Navigation & Files / Навигация и файлы

| Command | EN | RU |
|---|---|---|
| `..` `...` `....` `.....` | Up 1–4 levels | Вверх на 1–4 уровня |
| `~` `home` `root` | Home / drive root | Домашняя / корень |
| `up N` | Up N levels | Вверх на N уровней |
| `mkcd PATH` | mkdir + cd | Создать папку и войти |
| `ll` `la` | List files | Список файлов |
| `touch FILE` | Create / touch | Создать / обновить |
| `sizeof PATH` | Folder size | Размер папки |
| `find-file PATTERN` | Recursive search | Рекурсивный поиск |
| `which CMD` | Locate command | Где команда |
| `grep TEXT FILE` | Search in file | Поиск в файле |

### 💻 System / Система

| Command | EN | RU |
|---|---|---|
| `sysinfo` | Hardware info | Информация о ПК |
| `dash` `d` | Full dashboard | Полный дашборд |
| `autostart` | Startup audit | Аудит автозагрузки |
| `autostart -All` | All startup items | Все записи |
| `autostart-remove NAME` | Remove entry | Удалить из автозагрузки |
| `top` | Top by RAM | Топ процессов |
| `psg NAME` | Processes by name | Процессы по имени |
| `pskill NAME` | Kill process | Убить процесс |
| `bigfiles PATH` | Largest files | Крупные файлы |
| `disks` | All disks | Все диски |
| `env FILTER` | Env vars | Переменные окружения |
| `path` | $PATH entries | Содержимое PATH |
| `svc FILTER` | Windows services | Службы Windows |
| `startup` | Autorun entries | Автозагрузка |
| `cleanup` | Temp size | Размер temp |
| `cleanup -Execute` | Clean temp | Очистить temp |
| `uptime` | Uptime | Аптайм |

### 🛡 Security / Безопасность

| Command | EN | RU |
|---|---|---|
| `security-quick` | Quick scan (processes) | Быстрая проверка |
| `security-all` | Full scan (auto-UAC) | Полная проверка |
| `security-defender` | Windows Defender | Windows Defender |
| `security-miner` | MinerSearch (~11 min) | MinerSearch |
| `security-drweb` | Dr.Web CureIt (GUI) | Dr.Web CureIt |
| `security-eset` | ESET Online Scanner (GUI) | ESET |
| `security-kvrt` | Kaspersky VRT (GUI) | Kaspersky VRT |
| `security-clamav` | ClamAV | ClamAV |
| `security-log` | Scan log | Лог проверок |

### 🌐 Network / Сеть

| Command | EN | RU |
|---|---|---|
| `myip` | External IP | Внешний IP |
| `localip` | Local IPs | Локальные IP |
| `ping-http URL` | HTTP ping | HTTP-пинг |
| `dns NAME` | DNS lookup | DNS-запрос |
| `ports FILTER` | Listening ports | Занятые порты |
| `is-port N` | Check port | Проверить порт |
| `wget URL` | Download | Скачать файл |

### 🔀 Proxy / Прокси

| Command | EN | RU |
|---|---|---|
| `proxy-fetch` | Fetch list | Скачать прокси |
| `proxy-test` | Test all | Проверить все |
| `proxy-test-one PROXY` | Test one | Проверить один |
| `proxy-top` | Top proxies | Лучшие |
| `proxy-use N` | Apply #N | Включить #N |
| `proxy-clear` | Disable | Отключить |
| `proxy-status` | Status | Статус |
| `proxy-count` | Count | Количество |

### 🕵️ OSINT

| Command | EN | RU |
|---|---|---|
| `scan-ip [IP]` | IP geolocation | IP-геолокация |
| `scan-dns DOMAIN` | DNS + SPF/DMARC | DNS + SPF/DMARC |
| `scan-whois DOMAIN` | WHOIS | WHOIS |
| `scan-ports HOST` | Port scan | Скан портов |
| `hash-text TEXT` | Text hashes | Хэши текста |
| `hash-file FILE` | File hashes | Хэши файла |
| `hash-identify HASH` | Identify hash | Тип хэша |
| `hack-pass [N]` | Password gen | Генератор паролей |
| `hack-qr TEXT` | QR code | QR-код |
| `hack-short URL` | Shorten URL | Сократить ссылку |
| `hack` | OSINT help | Справка OSINT |

### 🧠 AI

| Command | EN | RU |
|---|---|---|
| `ai` | Open chat (Esc/q — exit) | Открыть чат |
| `ai <question>` | One-shot + unload | Один вопрос + выгрузка |
| `ai -Model NAME` | Select model | Выбрать модель |
| `ai -Reset` | Clear history | Очистить историю |
| `ai -Unload` | Unload model | Выгрузить модель |
| `ai -Yolo` | No confirmations | Без подтверждений |
| `ai -Dry` | Dry-run mode | Предпросмотр |
| `ai -List` | List models | Список моделей |

### 🎛 LM Studio

| Command | EN | RU |
|---|---|---|
| `lm-up` | Load to VRAM | Загрузить модель |
| `lm-down` | Unload models | Выгрузить модели |
| `lm-status` | Server status | Статус сервера |
| `lm-models` | Models on disk | Список моделей |

### 🌿 Git

| Command | EN | RU |
|---|---|---|
| `gs` | git status | git status |
| `ga .` | git add | git add |
| `gc "MSG"` | git commit | git commit |
| `gp` | git push | git push |
| `gpl` | git pull | git pull |
| `gd` | git diff | git diff |
| `gl` | git log (graph) | Красивая история |
| `gb` | git branch | Список веток |
| `gco BRANCH` | git checkout | Переключить ветку |
| `gcl URL` | git clone | Клонировать |
| `git-branch` | Current branch | Текущая ветка |
| `git-dirty` | Uncommitted changes | Есть ли изменения |

### 📸 Screenshots / Скриншоты

| Command | EN | RU |
|---|---|---|
| `screenshot` | Full screen | Снимок экрана |
| `screenshot-window` | Active window | Активное окно |
| `screenshot-list` | List last 20 | Список |
| `screenshot-folder` | Open folder | Открыть папку |
| `screenshot-clean [N]` | Clean older than N days | Удалить старые |

### 💾 Backup / Бэкапы

| Command | EN | RU |
|---|---|---|
| `backup` | Create ZIP | Резервная копия |
| `backup "label"` | With label | С меткой |
| `backup-list` | List backups | Список архивов |
| `backup-restore` | Restore | Восстановить |
| `backup-delete` | Delete | Удалить |

**EN:** Stored at `C:\Users\<user>\ARGONOV-Backups\`
**RU:** Хранятся в `C:\Users\<user>\ARGONOV-Backups\`

### 📐 CAD/CAM

| Command | EN | RU |
|---|---|---|
| `cad` | Quick help | Краткая подсказка |
| `cad list` | List installed | Что установлено |
| `cad kompas` | Launch KOMPAS | Запустить КОМПАС |
| `cad solidworks` | Launch SolidWorks | Запустить SolidWorks |
| `cad mastercam` | Launch Mastercam | Запустить Mastercam |
| `cad-files [path]` | Find projects | Найти проекты |
| `cad-open FILE` | Open file | Открыть файл |

**Supported CAD:** SolidWorks · AutoCAD · Inventor · Fusion 360 · Siemens NX · CATIA · PTC Creo · KOMPAS-3D · FreeCAD · Rhinoceros · SketchUp · ArchiCAD

**Supported CAM:** Mastercam · SolidCAM · hyperMILL · PowerMill · ESPRIT · CAMWorks · FeatureCAM

### 🎮 Fun / Развлечения

| Command | EN | RU |
|---|---|---|
| `matrix` | Digital rain (30 FPS) | Цифровой дождь |
| `м` | Cyrillic alias | Кириллица |
| `matrix-fast` | 45 FPS | Быстрая |
| `matrix-slow` | 12 FPS | Медленная |
| `matrix-long` | Long tails | Длинные хвосты |
| `matrix-wide` | CJK charset | CJK-набор |

---

## AI Agent / AI-агент

**EN:** AI agent can perform actions via special blocks. When you ask it to create, read, or run something, it responds with a tagged code block, and the shell parses it, shows a preview, and asks for confirmation.

**RU:** AI-агент выполняет действия через специальные блоки. Когда ты просишь создать, прочитать или запустить что-то, модель отвечает блоком, а оболочка парсит его, показывает превью и спрашивает подтверждение.

### Supported blocks / Поддерживаемые блоки

| Block | Purpose / Назначение |
|---|---|
| `write` | Create or overwrite a file / Создать или перезаписать файл |
| `read` | Read file contents / Прочитать содержимое |
| `exec` | Run a shell command / Запустить команду |
| `mkdir` | Create a folder / Создать папку |
| `list` | List directory / Показать содержимое папки |
| `delete` | Delete file or folder / Удалить файл или папку |

### Example / Пример

Ask: **"создай hello.ps1 который печатает привет"**

Model responds:

```
[block: write]
C:\ARGONOV\hello.ps1
Write-Host "привет"
```

Shell executes, shows preview, asks `Write? (y/N)`.

### Modes / Режимы

| Mode | Command | EN Effect | RU Effect |
|---|---|---|---|
| Default | — | Confirm every action | Подтверждать каждое действие |
| Yolo | `ai -Yolo` | No confirmations | Без подтверждений |
| Dry | `ai -Dry` | Show only | Только показать |

**Auto-unload:** model is unloaded from VRAM on chat exit (Esc / q).
**Авто-выгрузка:** модель выгружается из VRAM при выходе из чата (Esc / q).

---

## Security / Безопасность

**EN:** Antivirus integration with multiple tools:

| Tool | Command | Type |
|---|---|---|
| **Windows Defender** | `security-defender` | Built-in |
| **MinerSearch** | `security-miner` | Hidden miners (~11 min) |
| **Dr.Web CureIt** | `security-drweb` | Portable GUI |
| **ESET Online Scanner** | `security-eset` | Cloud-based |
| **Kaspersky VRT** | `security-kvrt` | Portable |
| **ClamAV** | `security-clamav` | Open-source |

**RU:** Антивирусная интеграция с несколькими инструментами:

| Инструмент | Команда | Тип |
|---|---|---|
| **Windows Defender** | `security-defender` | Встроенный |
| **MinerSearch** | `security-miner` | Майнеры (~11 мин) |
| **Dr.Web CureIt** | `security-drweb` | GUI |
| **ESET Online Scanner** | `security-eset` | Облачный |
| **Kaspersky VRT** | `security-kvrt` | Портативный |
| **ClamAV** | `security-clamav` | Open-source |

**Tools location / Расположение:**

```
C:\Users\<user>\Tools\
├── MinerSearch\
├── DrWeb\
├── ESET\
└── KVRT\
```

**Startup check:** `security-quick` runs silently at terminal start and scans running processes for miners. Only critical threats are shown.

**Проверка при старте:** `security-quick` тихо запускается при старте терминала и проверяет активные процессы на майнеры. Показывает только критические угрозы.

---

## Safety & Sandbox / Безопасность AI

**EN:** AI agent is restricted to safe locations:

- `C:\ARGONOV`
- `$HOME`
- `$HOME\Documents`
- `$HOME\Downloads`
- `$HOME\Desktop`

**Blocked patterns:** `rm -rf /` · `format C:` · `del /f /s /q C:\` · `Remove-Item -Recurse -Force C:\` · `shutdown` · `diskpart` · `mkfs` · `dd if=`

**RU:** AI-агент ограничен безопасными папками (`C:\ARGONOV` и папки пользователя). Опасные команды заблокированы.

---

## Architecture / Архитектура

**EN:** One file = one module. Modules are organized into categories.

**RU:** Один файл = один модуль. Модули разложены по категориям.

```
$PROFILE
  └─> C:\ARGONOV\profile.ps1
        └─> modules\<category>\*.ps1  (auto-loaded in order)
```

**Categories loaded in order / Категории загружаются по порядку:**

1. `core` — completion, commands, info, prompt
2. `system` — sysinfo, dashboard, processes, admin, autostart, security, navigation
3. `network` — network, proxy
4. `ai` — ai, lmstudio
5. `tools` — backup, cad, screenshot
6. `dev` — git-aliases
7. `osint` — hacktool
8. `fun` — matrix

**To add a module / Чтобы добавить модуль:** drop a `.ps1` file into `modules\<category>\` — it auto-loads on next terminal start.

**Reorder / Перестановка:** run `pwsh -ExecutionPolicy Bypass -File C:\ARGONOV\reorganize.ps1`

---

## Project Structure / Структура проекта

```
C:\ARGONOV\
├── profile.ps1                Main profile (auto-loaded)
├── README.md                  This file
├── ROADMAP.md                 Development plan
├── install.ps1                Installer with auto-reorganize
├── reorganize.ps1             Module categorization script
└── modules\
    ├── core\
    │   ├── commands.ps1       Command catalog (RU + EN)
    │   ├── completion.ps1     PSReadLine + Tab menu
    │   ├── info.ps1           Help screen
    │   └── prompt.ps1         Two-line prompt
    ├── system\
    │   ├── admin.ps1          uptime, env, path, svc, startup, cleanup
    │   ├── autostart.ps1      Startup audit
    │   ├── dashboard.ps1      Full dashboard
    │   ├── navigation.ps1     .., ~, ll, mkcd, touch
    │   ├── processes.ps1      top, psg, pskill, bigfiles
    │   ├── security.ps1       Antivirus integration
    │   └── sysinfo.ps1        Hardware info
    ├── network\
    │   ├── network.ps1        myip, ports, ping-http, dns
    │   └── proxy.ps1          Proxy manager
    ├── ai\
    │   ├── ai.ps1             AI agent (chat-first, auto-unload)
    │   └── lmstudio.ps1       LM Studio control
    ├── tools\
    │   ├── backup.ps1         ZIP backups
    │   ├── cad.ps1            CAD/CAM launcher
    │   └── screenshot.ps1     Screen capture
    ├── dev\
    │   └── git-aliases.ps1    gs, ga, gc, gp, gl, ...
    ├── osint\
    │   └── hacktool.ps1       OSINT toolkit
    └── fun\
        └── matrix.ps1         Digital rain
```

---

## Configuration / Конфигурация

**EN:** Change default model — edit `modules\ai\ai.ps1`:
**RU:** Сменить модель — `modules\ai\ai.ps1`:

```powershell
$script:AI_MODEL = "deepseek/deepseek-r1-0528-qwen3-8b"
```

**EN:** Add your own module — create `modules\<category>\mymodule.ps1`, restart terminal.
**RU:** Добавить модуль — создай `modules\<категория>\mymodule.ps1`, перезапусти терминал.

**EN:** Disable a module — rename `module.ps1` → `module.ps1.disabled`.
**RU:** Отключить модуль — переименуй `module.ps1` → `module.ps1.disabled`.

---

## Coding Conventions / Соглашения

**EN:** All `.ps1` files must be UTF-8 with BOM (`EF BB BF`). Without BOM, PowerShell 5.1 breaks Cyrillic.

**RU:** Все `.ps1` файлы — UTF-8 с BOM (`EF BB BF`). Без BOM PowerShell 5.1 ломает кириллицу.

**Verify / Проверка:**

```powershell
$b = [System.IO.File]::ReadAllBytes("file.ps1")
"{0:X2} {1:X2} {2:X2}" -f $b[0], $b[1], $b[2]
```

**EN: Compatible with PowerShell 5.1 and 7+:**
- ✅ `if/else`, `foreach`, `try/catch`, standard cmdlets
- ❌ `??`, `?.`, ternary `? :`, `-Parallel`

**RU: Совместимость с 5.1 и 7+:**
- ✅ `if/else`, `foreach`, `try/catch`, стандартные cmdlet
- ❌ `??`, `?.`, тернарный `? :`, `-Parallel`

**Editing rules / Правила:**
1. Full rewrite, never patch / Полная перезапись
2. One file at a time / Один файл за раз
3. Test after each change / Тест после каждого изменения
4. One commit per feature / Один коммит на фичу

---

## Tech Stack / Технологии

| Layer | Technology |
|---|---|
| Shell / Оболочка | PowerShell 7.6 |
| Terminal / Терминал | Windows Terminal |
| AI Backend | LM Studio (OpenAI-compatible) |
| Model | DeepSeek-R1-0528-Qwen3-8B (Q4_K_M) |
| Antivirus | Windows Defender + MinerSearch + Dr.Web |
| Version control | Git + SSH |
| Hosting | GitHub |

---

## Roadmap / План развития

**EN:** See [`ROADMAP.md`](ROADMAP.md). Planned:
**RU:** См. [`ROADMAP.md`](ROADMAP.md). Планируется:

- 🎨 Interface improvements / Улучшение интерфейса
- 🧪 Test suite / Тестовый набор
- 📊 System dashboard customization / Настройка дашборда
- 🌍 More languages / Больше языков

---

## License / Лицензия

MIT — free to use, modify, distribute.
MIT — свободное использование, модификация, распространение.