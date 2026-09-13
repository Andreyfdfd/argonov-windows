# ARGONOV SHELL · Roadmap

Кастомная оболочка PowerShell 7 для Windows 11.
Обновлено: 2026-09-13.

---

## Что уже работает

| Модуль | Команды |
|---|---|
| `profile.ps1` | автозагрузка, версии, время, пользователь |
| `modules/sysinfo.ps1` | `sysinfo` |
| `modules/navigation.ps1` | `..`, `~`, `ll`, `mkcd`, `touch`, `sizeof`, `find-file` |
| `modules/git-aliases.ps1` | `gs`, `ga`, `gc`, `gp`, `gl`, `gpl`, `gb`, `gco`, `gcl` |
| `modules/prompt.ps1` | двухстрочный промпт |
| `modules/info.ps1` | `info` |
| `modules/network.ps1` | `myip`, `localip`, `ports`, `ping-http`, `dns`, `wget`, `is-port` |
| `modules/processes.ps1` | `top`, `psg`, `pskill`, `bigfiles`, `disks` |
| `modules/admin.ps1` | `uptime`, `env`, `path`, `svc`, `startup`, `cleanup` |
| `modules/lmstudio.ps1` | `lm-up`, `lm-down`, `lm-status`, `lm-models` |
| `modules/ai.ps1` | `ai` — агент с write/read/exec |

---

## План на будущее

### B — Резервное копирование (следующий шаг)

- `modules/backup.ps1`
  - `backup` — архив всей оболочки в zip с датой
  - `backup-list` — список архивов
  - `restore` — восстановление (интерактивный выбор)

### A — Установщик

- `install.ps1` — разворачивает оболочку на новой машине
  - Проверка PowerShell 7, Python, Git, LM Studio
  - Подключение профиля
  - Клонирование модулей

### C — Расширение AI-агента

Дополнительные tool-блоки:
- `delete` — безопасное удаление файлов
- `mkdir` — создание папок
- `list` — листинг директорий
- Улучшение system prompt (больше примеров)

### D — Полезные фичи

**D1. VPN-модуль**
- `vpn-list` — список VPN-подключений
- `vpn-up <имя>` — подключиться
- `vpn-down` — отключиться
- `vpn-status` — текущий статус

**D2. Скриншот в терминале**
- `screenshot` — снимок экрана в файл
- `screenshot-full` — все экраны
- `screenshot-window` — активное окно

**D3. CAD-модуль (KOMPAS, AutoCAD)**
- `cad` — быстрый доступ к папкам проектов
- `cad-open <файл>` — открыть в приложении
- `cad-list` — список проектов

**D4. Матрица в терминале**
- `matrix` — цифровой дождь (как в Termux)
- При вводе `м` — алиас на запуск

**D5. Hacktool (как в Termux)**
- `hack` — OSINT мультитул
- `scan <домен>` — WHOIS + DNS
- `ip` — внешний IP + геолокация
- `qr <текст>` — генерация QR-кода в терминале
- `ports <host>` — скан портов
- `ping <host>` — пинг
- `hash <текст>` — MD5/SHA256
- `pass <длина>` — криптостойкий пароль

---

## Технологии

- PowerShell 7.6
- Windows Terminal
- LM Studio (localhost:1234)
- DeepSeek-R1-0528-Qwen3-8B
- Git + SSH к `Andreyfdfd/argonov-windows`

---

## Правила проекта

1. Файл правим целиком: **снос + пересоздание**
2. Один файл за раз
3. После каждого изменения — проверка
4. Каждый рабочий шаг — отдельный коммит