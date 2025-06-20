# 🚀 SCUM Dedicated Server Manager

---

## 🇬🇧 Quick Start (ENGLISH)

A universal PowerShell script for automatic management, updating, and monitoring of your SCUM Dedicated Server on Windows.

---

### ✨ Features
- **Automatic install and update** of SCUM server
- **Update check** before every launch
- **Automatic restart** on crash
- **Scheduled restarts** (06:00, 12:00, 18:00, 00:00)
- **Autostart with Windows**
- **Logging** of all restarts and crashes (`server_restarts.log`)
- **Symlinks** to important folders on Desktop
- **Flexible config via `SettingServer.ini`**

---

### 🔥 Required Ports
Open these ports in your firewall/router for proper server operation:

| Purpose         | Port (default) | Protocol |
|-----------------|---------------|----------|
| Game server     | 7777          | UDP      |
| Query port      | 27015         | UDP      |

> **Note:** If you change ports in `SettingServer.ini`, open the corresponding ports.

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
| `help`           | Show help message                                                  |

**Examples:**
```powershell
powershell -File scum_server_manager.ps1 -Mode start
powershell -File scum_server_manager.ps1 -Mode restart
powershell -File scum_server_manager.ps1 -Mode watch
powershell -File scum_server_manager.ps1 -Mode register-tasks
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

### ⚙️ Server Configuration
Edit `SettingServer.ini` for main parameters:
```ini
APP_ID=3792580
SERVER_PORT=7777
QUERY_PORT=27015
MAX_PLAYERS=128
LINKS_DIR=%USERPROFILE%\Desktop
CONFIG_LINK_PATH=
CONSOLELOG_LINK_PATH=
LOGS_LINK_PATH=
RESTART_TIMES=06:00,12:00,18:00,00:00
```
You can use environment variables (e.g., `%USERPROFILE%`).

---

### 🌐 Useful Links
- [Official SCUM Discord](https://discord.gg/scum)

---

## 👤 Author
- GitHub: [ksenagami](https://github.com/ksenagami)

---

# 🇷🇺 SCUM Dedicated Server Manager (РУССКИЙ)

---

## ✨ Возможности
- **Автоматическая установка и обновление** сервера SCUM
- **Проверка обновлений** перед каждым запуском
- **Автоматический перезапуск** сервера при сбоях
- **Плановые рестарты** по расписанию (06:00, 12:00, 18:00, 00:00)
- **Автозапуск** вместе с Windows
- **Логирование** всех перезапусков и сбоев (`server_restarts.log`)
- **Создание удобных симлинков** к важным папкам на рабочем столе
- **Гибкая настройка через файл `SettingServer.ini`**

---

## 🔥 Необходимые порты
Откройте эти порты в брандмауэре/роутере для корректной работы сервера:

| Назначение      | Порт (по умолчанию) | Протокол |
|-----------------|---------------------|----------|
| Игровой сервер  | 7777                | UDP      |
| Query порт      | 27015               | UDP      |

> **Важно:** Если вы меняете порты в `SettingServer.ini`, откройте соответствующие порты.

---

## ⚡ Быстрый старт
1. **Скачайте и распакуйте** все файлы в отдельную папку.
2. **Откройте PowerShell от имени администратора** (это важно для создания задач автозапуска и симлинков).
3. **Перейдите в папку со скриптом:**
4. **Первый запуск и установка сервера:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scum_server_manager.ps1 -Mode start
   ```
   Скрипт автоматически скачает SteamCMD, установит сервер и создаст симлинки на рабочем столе.

---

## 🛠️ Основные режимы работы
| Режим         | Описание                                                                 |
|---------------|--------------------------------------------------------------------------|
| `start`       | Установить (если нужно), создать симлинки и запустить сервер             |
| `restart`     | Остановить сервер (если работает), затем запустить (или установить и запустить) |
| `watch`       | Постоянно следить за процессом SCUMServer.exe и перезапускать при сбоях  |
| `register-tasks` | Зарегистрировать автозапуск и плановые рестарты через Планировщик задач |
| `help`        | Показать справку по скрипту                                              |

**Примеры запуска:**
```powershell
powershell -File scum_server_manager.ps1 -Mode start
powershell -File scum_server_manager.ps1 -Mode restart
powershell -File scum_server_manager.ps1 -Mode watch
powershell -File scum_server_manager.ps1 -Mode register-tasks
```

---

## 🖥️ Автоматический запуск вместе с Windows
1. Откройте PowerShell **от имени администратора**
2. Выполните:
   ```powershell
   powershell -File .\scum_server_manager.ps1 -Mode register-tasks
   ```
3. После этого сервер будет автоматически запускаться и мониториться при каждом старте Windows.

---

## 📋 Логирование
Все события (рестарты, сбои, обновления, ошибки) пишутся в файл `server_restarts.log` в корне папки.

---

## ⚙️ Настройка сервера
Все основные параметры задаются в файле `SettingServer.ini`:
```ini
APP_ID=3792580
SERVER_PORT=7777
QUERY_PORT=27015
MAX_PLAYERS=128
LINKS_DIR=%USERPROFILE%\Desktop
CONFIG_LINK_PATH=
CONSOLELOG_LINK_PATH=
LOGS_LINK_PATH=
RESTART_TIMES=06:00,12:00,18:00,00:00
```
Можно использовать переменные окружения (например, `%USERPROFILE%`).

---

## 🌐 Полезные ссылки
- [Официальный Discord SCUM](https://discord.gg/scum)

---

## 👤 Автор
- GitHub: [ksenagami](https://github.com/ksenagami)

---

**Удачной игры и стабильного сервера!** 
