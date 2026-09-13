# ⚡ ARGONOV SHELL

**A custom PowerShell 7 shell for Windows 11**
**Кастомная оболочка PowerShell 7 для Windows 11**

*Fast commands · Git aliases · AI agent · OSINT toolkit · CAD launcher*
*Быстрые команды · Git-алиасы · AI-агент · OSINT-мультитул · CAD-лончер*

![PowerShell](https://img.shields.io/badge/PowerShell-7.6-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)
![Git](https://img.shields.io/badge/Git-SSH-F05032?style=flat-square&logo=git&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Commands](https://img.shields.io/badge/Commands-96-brightgreen?style=flat-square)

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

**Status / Статус:** Personal project, actively developed. 96 commands across 17 modules. / Персональный проект, активно развивается. 96 команд в 17 модулях.

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
| **Windows** | 10 or 11 | OS / ОС |
| **PowerShell** | 7.6+ | Shell runtime / Среда выполнения |
| **Git** | Any recent | Repo management / Работа с репозиторием |
| **SSH key** / SSH-ключ | ED25519 | GitHub without password / GitHub без пароля |
| **LM Studio** | Latest | AI backend (optional) / Backend для AI (опционально) |
| **Python** | 3.14 | Scripts (optional) / Скрипты (опционально) |

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

**EN:** The installer checks PowerShell 7, Python, Git, SSH key, LM Studio, project structure, profile connection, and all module syntax.
**RU:** Установщик проверяет PowerShell 7, Python, Git, SSH-ключ, LM Studio, структуру проекта, подключение профиля и синтаксис всех модулей.

### Optional / Опционально — Enable script execution / Разрешить скрипты

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

---

## Quick Start / Быстрый старт

**EN:** Open Windows Terminal and try:

**RU:** Открой Windows Terminal и попробуй:

```powershell
sysinfo           # System information panel / Панель железа
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
| `sysinfo` | Hardware info panel | Панель железа |
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
