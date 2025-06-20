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

**Удачной игры и стабильного сервера!** 
