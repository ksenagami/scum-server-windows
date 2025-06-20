# 🚀 SCUM Dedicated Server Manager

---

## 🇬🇧 Quick Start (ENGLISH)

A universal PowerShell script for automatic management, updating, monitoring, and backup of your SCUM Dedicated Server on Windows.

---

### ✨ Features
- **Automatic install and update** of SCUM server
- **Update check** before every launch
- **Automatic restart** on crash
- **Scheduled restarts** (06:00, 12:00, 18:00, 00:00)
- **Autostart with Windows**
- **Daily automatic backup at 03:00** (compressed, with rotation)
- **Logging** of all restarts and crashes (`server_restarts.log`)
- **Optional symlinks** to important folders on Desktop (configurable)
- **Flexible config via `config.json`**
- **Discord notifications** for server start, restart, crash, and backups (optional)

---

### 🗄️ Automatic Backups
- By default, a backup is created **every hour** (can be changed in config.json).
- You can control compression (zip) via the BACKUP_COMPRESS parameter.
- Only the **10 most recent backups** are kept; older ones are deleted automatically.
- You can also run a backup manually:
  ```powershell
  powershell -File scum_server_manager.ps1 -Mode backup
  ```
- To restore, simply unzip the desired archive (if compressed) or copy the backup folder contents back to the server folders.

---

### 🔥 Required Ports
Open this port in your firewall/router for proper server operation:

| Purpose         | Port (default) | Protocol |
|-----------------|---------------|----------|
| Game server     | 7777          | UDP      |

> **Note:** When connecting, use IP:PORT+2 (e.g., if port is 7000, connect to 7002). If you change the port in `config.json`, open the corresponding port.

---

### ⚡ Quick Start
1. **Download and extract** all files to a folder.
2. **Open PowerShell as Administrator** (required for symlinks and scheduled tasks).
3. **Navigate to the script folder:**
4. **First launch and install:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scum_server_manager.ps1 -Mode start
   ```
   The script will auto-download SteamCMD, install the server, and create symlinks on your Desktop.

---

### 🛠️ Main Modes
| Mode             | Description                                                        |
|------------------|--------------------------------------------------------------------|
| `start`          | Install (if needed), create symlinks, and start the server         |
| `restart`        | Stop server (if running), then start (or install and start)        |
| `watch`          | Monitor SCUMServer.exe and auto-restart on crash                   |
| `register-tasks` | Register autostart and scheduled restarts via Task Scheduler       |
| `backup`         | Create a backup of server data immediately                         |
| `help`           | Show help message                                                  |

**Examples:**
```powershell
powershell -File scum_server_manager.ps1 -Mode start
powershell -File scum_server_manager.ps1 -Mode restart
powershell -File scum_server_manager.ps1 -Mode watch
powershell -File scum_server_manager.ps1 -Mode register-tasks
powershell -File scum_server_manager.ps1 -Mode backup
```

---

### 🖥️ Autostart with Windows
1. Open PowerShell **as Administrator**
2. Run:
   ```powershell
   powershell -File .\scum_server_manager.ps1 -Mode register-tasks
   ```
3. The server will now start and be monitored automatically on every Windows boot.

---

### 📋 Logging
All events (restarts, crashes, updates, errors) are logged to `server_restarts.log` in the root folder.

---

### 🔔 Discord Notifications
- Set `DISCORD_WEBHOOK_URL` in `config.json` to receive notifications in your Discord channel.
- The script will send messages for:
  - Server start
  - Server restart
  - Server crash (with exit code)
  - Backup creation
- Example notification: `🟢 SCUM Server started. IP: ... Port: ... MaxPlayers: ...`

---

### ⚙️ Server Configuration
Edit `config.json` for main parameters (created automatically on first run):
```json
{
  "APP_ID": "3792580",
  "SERVER_PORT": "7777",
  "MAX_PLAYERS": "128",
  "NOBATTLEYE": false,
  "LINKS_DIR": "%USERPROFILE%\\Desktop",
  "CONFIG_LINK_PATH": "",
  "CONSOLELOG_LINK_PATH": "",
  "LOGS_LINK_PATH": "",
  "RESTART_TIMES": "06:00,12:00,18:00,00:00",
  "BACKUP_INTERVAL_HOURS": 1,
  "BACKUP_COMPRESS": true,
  "CREATE_LINKS": false
}
```
- `BACKUP_INTERVAL_HOURS` — how often to create a backup (in hours, default: 1)
- `BACKUP_COMPRESS` — whether to compress backups as zip (true/false, default: true)
- `CREATE_LINKS` — create symlinks to important folders (true/false, default: false). If true, links are created on Desktop by default (or at custom paths).

---

### ❗ Proper Server Shutdown
To properly shut down the server, use CTRL+C in the console or the provided script commands. **Do not** close the server window with the "X" button, as this may cause data loss or corruption.

---

### 🌐 Useful Links
- [Official SCUM Discord](https://discord.gg/scum)

---

## 👤 Author
- GitHub: [ksenagami](https://github.com/ksenagami)

---

# 🇷🇺 SCUM Dedicated Server Manager (РУССКИЙ)

---

## 🇷🇺 Кратко о возможностях

- **Автоматическая установка и обновление** сервера SCUM
- **Проверка обновлений** перед каждым запуском
- **Автоматический перезапуск** при сбоях
- **Плановые рестарты** (06:00, 12:00, 18:00, 00:00)
- **Автозапуск с Windows**
- **Гибкая система бэкапов**:
  - Если сервер остановлен — полный бэкап игровых данных, логов, конфига и скрипта
  - Если сервер работает — бэкап только config.json и скрипта (с предупреждением)
  - Ротация: хранится только 10 последних бэкапов
- **Восстановление из бэкапа** (restore-backup):
  - По умолчанию — последний бэкап, либо указанный по имени
  - Восстановление невозможно, если сервер запущен
- **Ротация логов**: автоматическое удаление старых логов
- **Discord-уведомления** обо всех ключевых событиях
- **Web-интерфейс**: управление сервером через браузер (localhost:8080)
- **Self-update**: обновление скрипта по ссылке
- **Статистика**: uptime, рестарты, бэкапы, ошибки
- **Пользовательские хуки**: скрипты before/after backup/restart
- **Команда stop**: корректная остановка сервера
- **RCON**: временно отключён (код сохранён для будущего)

---

## 🛠️ Основные режимы
| Mode             | Описание                                                                 |
|------------------|--------------------------------------------------------------------------|
| `start`          | Установка (если нужно), создание symlink'ов, запуск сервера              |
| `stop`           | Остановка сервера                                                        |
| `restart`        | Остановка сервера, бэкап, рестарт                                        |
| `watch`          | Мониторинг SCUMServer.exe, автоперезапуск при сбое                       |
| `register-tasks` | Регистрация автозапуска и плановых рестартов через Task Scheduler        |
| `backup`         | Бэкап данных (если сервер работает — только config и скрипт)             |
| `restore-backup` | Восстановление из последнего или указанного бэкапа (только при остановленном сервере) |
| `send-stats`     | Отправка статистики в Discord                                            |
| `self-update`    | Самообновление скрипта                                                   |
| `web`            | Веб-интерфейс управления                                                 |
| `help`           | Справка                                                                 |
| `rcon-test`      | (Отключено) Тестовое RCON-уведомление                                    |

---

## 🗄️ Бэкапы и восстановление
- **backup**:
  - Если сервер остановлен — полный бэкап папки `server/SCUM/Saved`, config.json и скрипта
  - Если сервер работает — только config.json и скрипт, с предупреждением в лог и Discord
- **restore-backup**:
  - По умолчанию — последний бэкап, либо указанный по имени (через `-BackupName` или позиционный аргумент)
  - Перед восстановлением старая папка Saved удаляется
  - Восстановление невозможно, если сервер работает

---

## 📋 Примеры команд
```powershell
powershell -File scum_server_manager.ps1 -Mode start
powershell -File scum_server_manager.ps1 -Mode stop
powershell -File scum_server_manager.ps1 -Mode restart
powershell -File scum_server_manager.ps1 -Mode backup
powershell -File scum_server_manager.ps1 -Mode restore-backup
powershell -File scum_server_manager.ps1 -Mode restore-backup -BackupName scum_backup_2024-06-20_12-00-00.zip
powershell -File scum_server_manager.ps1 -Mode send-stats
powershell -File scum_server_manager.ps1 -Mode self-update
powershell -File scum_server_manager.ps1 -Mode web
```

---

## ⚠️ Важно
- Для корректного бэкапа игровых данных сервер должен быть остановлен.
- Восстановление из бэкапа возможно только при остановленном сервере.
- RCON-функции временно отключены (код сохранён для будущего, автозагрузка rcon.exe не выполняется).

---

## 🌐 Web-интерфейс
- Запуск: `powershell -File scum_server_manager.ps1 -Mode web`
- Доступ: http://localhost:8080
- Управление сервером, просмотр логов и статуса через браузер

---

## 👤 Автор
- GitHub: [ksenagami](https://github.com/ksenagami)

---

# 📖 Подробная инструкция (RU)

## Основные режимы и команды

| Режим              | Описание |
|--------------------|----------|
| `start`            | Устанавливает сервер (если нужно), проверяет обновления, создает симлинки (если включено), запускает сервер. Используйте для первого запуска или обычного старта. |
| `stop`             | Корректно завершает работу сервера. Рекомендуется перед бэкапом или восстановлением. |
| `restart`          | Останавливает сервер, делает бэкап (если возможно), запускает сервер заново. Перед рестартом отправляет уведомления в Discord и (если включено) игрокам через RCON. |
| `watch`            | Запускает мониторинг процесса SCUMServer.exe. Если сервер падает — автоматически перезапускает. Используйте для стабильной работы 24/7. |
| `register-tasks`   | Регистрирует задачи автозапуска и плановых рестартов через Task Scheduler Windows. Требует запуск от администратора. |
| `backup`           | Создает резервную копию данных сервера. Если сервер работает — архивируются только config.json и скрипт, иначе полный бэкап Saved. |
| `restore-backup`   | Восстанавливает сервер из последнего или указанного бэкапа. Сервер должен быть остановлен. Старые данные удаляются. |
| `send-stats`       | Отправляет статистику (аптайм, рестарты, бэкапы, ошибки) в Discord. |
| `self-update`      | Обновляет скрипт до последней версии с официального репозитория. |
| `web`              | Запускает веб-интерфейс управления сервером на http://localhost:8080. |
| `help`             | Показывает справку по режимам и примерам запуска. |
| `rcon-test`        | (Отключено) Тестовое RCON-уведомление игрокам. |

### Примеры запуска
```powershell
powershell -File scum_server_manager.ps1 -Mode start
powershell -File scum_server_manager.ps1 -Mode stop
powershell -File scum_server_manager.ps1 -Mode restart
powershell -File scum_server_manager.ps1 -Mode backup
powershell -File scum_server_manager.ps1 -Mode restore-backup
powershell -File scum_server_manager.ps1 -Mode restore-backup -BackupName scum_backup_2024-06-20_12-00-00.zip
powershell -File scum_server_manager.ps1 -Mode send-stats
powershell -File scum_server_manager.ps1 -Mode self-update
powershell -File scum_server_manager.ps1 -Mode web
```

## Описание параметров config.json
- **APP_ID** — Steam App ID (обычно 3792580)
- **SERVER_PORT** — порт игрового сервера
- **MAX_PLAYERS** — максимальное число игроков
- **NOBATTLEYE** — отключить Battleye (true/false)
- **LINKS_DIR** — папка для симлинков (по умолчанию Desktop)
- **CONFIG_LINK_PATH, CONSOLELOG_LINK_PATH, LOGS_LINK_PATH** — индивидуальные пути для симлинков
- **RESTART_TIMES** — время плановых рестартов (через запятую)
- **BACKUP_INTERVAL_HOURS** — интервал бэкапа (в часах)
- **BACKUP_COMPRESS** — сжимать ли бэкапы в zip
- **CREATE_LINKS** — создавать ли симлинки
- **DISCORD_WEBHOOK_URL** — ссылка для уведомлений в Discord
- **RCON_ENABLED, RCON_PORT, RCON_PASSWORD** — параметры RCON (временно не используются)
- **HOOKS** — пользовательские скрипты before/after backup/restart
- **SELF_UPDATE_URL** — ссылка для самообновления скрипта

## Бэкапы и восстановление
- Бэкап создается в папке backups. Хранится только 10 последних архивов.
- Если сервер работает — архивируются только config.json и скрипт, игровые данные не трогаются.
- Восстановление возможно только при остановленном сервере. Старые данные удаляются.
- Перед рестартом автоматически создается бэкап с пометкой _restart.
- Проверяется свободное место (не менее 5 ГБ).

## Веб-интерфейс
- Запуск: `powershell -File scum_server_manager.ps1 -Mode web`
- Доступ: http://localhost:8080
- Кнопки: старт, стоп, рестарт, бэкап, отправка статистики, просмотр статуса и логов.

## Discord-уведомления
- Все ключевые события отправляются в Discord через webhook (start, restart, crash, backup, ошибки, self-update, send-stats, web).
- Все сообщения отправляются как embed.

## Хуки
- Можно указать свои скрипты для before/after backup и restart (см. HOOKS в config.json).

## Self-update
- Скрипт может обновлять себя с официального репозитория. По умолчанию SELF_UPDATE_URL уже настроен.
- Для обновления: `powershell -File scum_server_manager.ps1 -Mode self-update`

## Статистика
- Ведется stats.json (аптайм, рестарты, бэкапы, ошибки).
- send-stats отправляет отчет в Discord.

## Ротация логов и бэкапов
- Логи старше 30 дней удаляются автоматически.
- Бэкапы — только 10 последних.

---

# 📖 Detailed Manual (EN)

## Main modes and commands

| Mode               | Description |
|--------------------|-------------|
| `start`            | Installs the server (if needed), checks for updates, creates symlinks (if enabled), starts the server. Use for first launch or normal start. |
| `stop`             | Gracefully stops the server. Recommended before backup or restore. |
| `restart`          | Stops the server, creates a backup (if possible), restarts the server. Sends notifications to Discord and (if enabled) to players via RCON before restart. |
| `watch`            | Starts monitoring SCUMServer.exe. If the server crashes, it will be restarted automatically. Use for 24/7 stability. |
| `register-tasks`   | Registers autostart and scheduled restarts via Windows Task Scheduler. Requires admin rights. |
| `backup`           | Creates a backup of server data. If the server is running, only config.json and script are archived; otherwise, full Saved backup. |
| `restore-backup`   | Restores the server from the latest or specified backup. Server must be stopped. Old data is deleted. |
| `send-stats`       | Sends statistics (uptime, restarts, backups, errors) to Discord. |
| `self-update`      | Updates the script to the latest version from the official repository. |
| `web`              | Starts the web interface at http://localhost:8080 for server management. |
| `help`             | Shows help for modes and usage examples. |
| `rcon-test`        | (Disabled) Test RCON announcement to players. |

### Usage examples
```powershell
powershell -File scum_server_manager.ps1 -Mode start
powershell -File scum_server_manager.ps1 -Mode stop
powershell -File scum_server_manager.ps1 -Mode restart
powershell -File scum_server_manager.ps1 -Mode backup
powershell -File scum_server_manager.ps1 -Mode restore-backup
powershell -File scum_server_manager.ps1 -Mode restore-backup -BackupName scum_backup_2024-06-20_12-00-00.zip
powershell -File scum_server_manager.ps1 -Mode send-stats
powershell -File scum_server_manager.ps1 -Mode self-update
powershell -File scum_server_manager.ps1 -Mode web
```

## config.json parameters
- **APP_ID** — Steam App ID (usually 3792580)
- **SERVER_PORT** — game server port
- **MAX_PLAYERS** — max players
- **NOBATTLEYE** — disable Battleye (true/false)
- **LINKS_DIR** — folder for symlinks (default: Desktop)
- **CONFIG_LINK_PATH, CONSOLELOG_LINK_PATH, LOGS_LINK_PATH** — custom symlink paths
- **RESTART_TIMES** — scheduled restart times (comma-separated)
- **BACKUP_INTERVAL_HOURS** — backup interval (hours)
- **BACKUP_COMPRESS** — compress backups as zip
- **CREATE_LINKS** — create symlinks
- **DISCORD_WEBHOOK_URL** — Discord webhook for notifications
- **RCON_ENABLED, RCON_PORT, RCON_PASSWORD** — RCON params (currently not used)
- **HOOKS** — user scripts for before/after backup/restart
- **SELF_UPDATE_URL** — URL for self-update

## Backups and restore
- Backups are stored in the backups folder. Only the 10 latest are kept.
- If the server is running, only config.json and script are archived; game data is not touched.
- Restore is only possible if the server is stopped. Old data is deleted before restore.
- Before restart, a backup with _restart tag is created automatically.
- Free space is checked (at least 5 GB required).

## Web interface
- Start: `powershell -File scum_server_manager.ps1 -Mode web`
- Access: http://localhost:8080
- Buttons: start, stop, restart, backup, send stats, view status and logs.

## Discord notifications
- All key events are sent to Discord via webhook (start, restart, crash, backup, errors, self-update, send-stats, web).
- All messages are sent as embed.

## Hooks
- You can specify your own scripts for before/after backup and restart (see HOOKS in config.json).

## Self-update
- The script can update itself from the official repository. By default, SELF_UPDATE_URL is already set.
- To update: `powershell -File scum_server_manager.ps1 -Mode self-update`

## Statistics
- stats.json is maintained (uptime, restarts, backups, errors).
- send-stats sends a report to Discord.

## Log and backup rotation
- Logs older than 30 days are deleted automatically.
- Only 10 latest backups are kept.

---
