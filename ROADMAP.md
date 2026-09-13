# ARGONOV SHELL · Roadmap

Кастомная оболочка PowerShell 7 для Windows 11.
Версия на 2026-09-13.

---

## Что уже работает

| Модуль | Команды |
|---|---|
| `profile.ps1` | автозагрузка, версии Python/PS, время, пользователь |
| `modules/sysinfo.ps1` | `sysinfo` — панель железа |
| `modules/navigation.ps1` | `..`, `~`, `ll`, `mkcd`, `touch`, `sizeof`, `find-file`, `which`, `grep` |
| `modules/git-aliases.ps1` | `gs`, `ga`, `gc`, `gp`, `gpl`, `gd`, `gl`, `gb`, `gco`, `gcl`, `git-branch`, `git-dirty` |
| `modules/prompt.ps1` | двухстрочный промпт с git-веткой и временем |
| `modules/info.ps1` | `info` — справка |
| `modules/network.ps1` | `myip`, `localip`, `ping-http`, `ports`, `is-port`, `wget`, `dns` |
| `modules/ai.ps1` | `ai <вопрос>`, `ai -List`, `ai -Chat`, `ai -Model`, `ai -Reset` |

---

## Ближайшие шаги

### Шаг 10 — ROADMAP.md (этот файл)

### Шаг 11 — Модуль processes.ps1
- `psg <имя>` — найти процессы по имени
- `pskill <имя>` — убить процесс
- `top` — топ-15 процессов по памяти
- `bigfiles [путь]` — самые большие файлы
- `disks` — свободное место на всех дисках

### Шаг 12 — Модуль lmstudio.ps1 (автозагрузка)
- Проверка, запущен ли `lms.exe` (LM Studio CLI)
- Автоматический `lms server start`
- Автоматический `lms load <model>` — загрузка модели в VRAM
- Команды: `lm-up`, `lm-down`, `lm-status`, `lm-models`

### Шаг 13 — AI-агент (переделка ai.ps1)
Модель может сама:
- **write** — создавать и редактировать файлы
- **read** — читать файлы
- **exec** — запускать команды в терминале

Логика:
1. Модель отвечает структурированными блоками ` ```write `, ` ```read `, ` ```exec `
2. Скрипт ловит их в ответе
3. Показывает что собирается сделать
4. Спрашивает `Выполнить? (y/N)`
5. Если `y` — выполняет
6. Результат отправляет обратно модели

Sandbox (что можно менять):
- `C:\ARGONOV`
- `C:\Users\Andrey` (документы, загрузки, рабочий стол, проекты)
- Ничего из `C:\Windows`, `C:\Program Files` — защищено

Danger-фильтр (блокируется жёстко):
- `rm -rf /`, `format`, `del /f /s /q C:\`, `shutdown`, `diskpart`, `Remove-Item -Recurse -Force C:\`

Режимы:
- По умолчанию — подтверждение на каждое действие
- `ai -Yolo` — без подтверждений
- `ai -Dry` — только показать, не выполнять

### Шаг 14 — Полезное для админа
- `env` — переменные окружения
- `path` — что в PATH
- `clean` — очистка временных файлов
- `svc` — службы Windows
- `startup` — автозагрузка

### Шаг 15 — Первый push на GitHub
Когда всё стабильно — `git push -u origin main`

---

## Технический стек

- **Оболочка:** PowerShell 7.6.6
- **Терминал:** Windows Terminal
- **AI backend:** LM Studio, сервер на `localhost:1234`
- **Модель:** `deepseek-r1-0528-qwen3-8b` (5 ГБ, Q4_K_M)
- **GitHub:** `Andreyfdfd/argonov-windows`

---

## Правила проекта

1. Файл правим целиком: **снос + пересоздание**, не точечно
2. Один файл за раз
3. После каждого изменения — проверка в терминале
4. Каждый рабочий шаг — отдельный git-коммит
5. Пуш — только когда всё стабильно