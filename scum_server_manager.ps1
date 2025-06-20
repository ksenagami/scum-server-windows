param(
    [ValidateSet("start", "stop", "restart", "watch", "register-tasks", "help", "backup", "restore-backup", "send-stats", "self-update", "web", "rcon-test")]
    [string]$Mode = "help",
    [string]$BackupName
)

# ========== CONFIG & UTILS ==========
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$steamcmdDir = Join-Path $baseDir "steamcmd"
$gameServerDir = Join-Path $baseDir "server"
$configFile = Join-Path $baseDir "config.json"
$serverExe = Join-Path $gameServerDir "SCUM\Binaries\Win64\SCUMServer.exe"
$restartLogFile = Join-Path $baseDir "server_restarts.log"
$manifestFile = Join-Path $gameServerDir "steamapps\appmanifest_3792580.acf"
$statsFile = Join-Path $baseDir "stats.json"
$WEB_PORT = 8080

function Write-Status($msg, $color) {
    Write-Host $msg -ForegroundColor $color
}

function Write-ServerLog($msg, [switch]$error) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $msg"
    Add-Content -Path $restartLogFile -Value $logEntry -Encoding UTF8
    if ($error) {
        Update-Stats "error"
        Write-Status $msg Red
    } else {
        Write-Status $msg Cyan
    }
}

# Create config.json with default values if it does not exist
if (-not (Test-Path $configFile)) {
    $defaultConfig = @{
        APP_ID = "3792580"
        SERVER_PORT = "7777"
        MAX_PLAYERS = "128"
        NOBATTLEYE = $false
        LINKS_DIR = [Environment]::GetFolderPath('Desktop')
        CONFIG_LINK_PATH = ""
        CONSOLELOG_LINK_PATH = ""
        LOGS_LINK_PATH = ""
        RESTART_TIMES = "06:00,12:00,18:00,00:00"
        BACKUP_INTERVAL_HOURS = 1
        BACKUP_COMPRESS = $true
        CREATE_LINKS = $false
        DISCORD_WEBHOOK_URL = ""
        RCON_ENABLED = $false
        RCON_PORT = 27015
        RCON_PASSWORD = ""
        HOOKS = @{
            before_restart = ""
            after_restart = ""
            before_backup = ""
            after_backup = ""
        }
        SELF_UPDATE_URL = ""
    }
    $defaultConfig | ConvertTo-Json -Depth 3 | Set-Content $configFile -Encoding UTF8
    Write-Status "[INFO] Created default config.json" Cyan
}

# Read config.json
$config = Get-Content $configFile -Raw | ConvertFrom-Json

# Assign config variables
$APP_ID = $config.APP_ID
$SERVER_PORT = $config.SERVER_PORT
$MAX_PLAYERS = $config.MAX_PLAYERS
$NOBATTLEYE = $config.NOBATTLEYE
$LINKS_DIR = $config.LINKS_DIR
$CONFIG_LINK_PATH = $config.CONFIG_LINK_PATH
$CONSOLELOG_LINK_PATH = $config.CONSOLELOG_LINK_PATH
$LOGS_LINK_PATH = $config.LOGS_LINK_PATH
$RESTART_TIMES = $config.RESTART_TIMES
$BACKUP_INTERVAL_HOURS = if ($config.PSObject.Properties.Name -contains 'BACKUP_INTERVAL_HOURS') { $config.BACKUP_INTERVAL_HOURS } else { 1 }
$BACKUP_COMPRESS = if ($config.PSObject.Properties.Name -contains 'BACKUP_COMPRESS') { $config.BACKUP_COMPRESS } else { $true }
$CREATE_LINKS = if ($config.PSObject.Properties.Name -contains 'CREATE_LINKS') { $config.CREATE_LINKS } else { $false }
$DISCORD_WEBHOOK_URL = if ($config.PSObject.Properties.Name -contains 'DISCORD_WEBHOOK_URL') { $config.DISCORD_WEBHOOK_URL } else { "" }
$RCON_ENABLED = if ($config.PSObject.Properties.Name -contains 'RCON_ENABLED') { $config.RCON_ENABLED } else { $false }
$RCON_PORT = if ($config.PSObject.Properties.Name -contains 'RCON_PORT') { $config.RCON_PORT } else { 27015 }
$RCON_PASSWORD = if ($config.PSObject.Properties.Name -contains 'RCON_PASSWORD') { $config.RCON_PASSWORD } else { "" }
$HOOKS = if ($config.PSObject.Properties.Name -contains 'HOOKS') { $config.HOOKS } else { @{ before_restart=""; after_restart=""; before_backup=""; after_backup="" } }
$SELF_UPDATE_URL = if ($config.PSObject.Properties.Name -contains 'SELF_UPDATE_URL') { $config.SELF_UPDATE_URL } else { "" }

foreach ($var in @('LINKS_DIR','CONFIG_LINK_PATH','CONSOLELOG_LINK_PATH','LOGS_LINK_PATH')) {
    $val = Get-Variable $var -ValueOnly
    if ($val -and $val -match "%(.+?)%") {
        Set-Variable -Name $var -Value ([Environment]::ExpandEnvironmentVariables($val))
    }
}

# ========== LINK PATHS =============
$linkTargets = @{
    'Config'     = Join-Path $gameServerDir 'SCUM\Saved\Config\WindowsServer'
    'ConsoleLog' = Join-Path $gameServerDir 'SCUM\Saved\Logs'
    'Logs'       = Join-Path $gameServerDir 'SCUM\Saved\SaveFiles\Logs'
}
$linkPaths = @{
    'Config'     = if ($CONFIG_LINK_PATH)     { $CONFIG_LINK_PATH }     else { Join-Path $LINKS_DIR 'Config' }
    'ConsoleLog' = if ($CONSOLELOG_LINK_PATH) { $CONSOLELOG_LINK_PATH } else { Join-Path $LINKS_DIR 'ConsoleLog' }
    'Logs'       = if ($LOGS_LINK_PATH)       { $LOGS_LINK_PATH }       else { Join-Path $LINKS_DIR 'Logs' }
}

function Create-Links {
    if (-not $CREATE_LINKS) {
        Write-ServerLog "Symlink creation is disabled (CREATE_LINKS=false)."
        return
    }
    foreach ($linkName in $linkTargets.Keys) {
        $targetPath = $linkTargets[$linkName]
        $linkPath = $linkPaths[$linkName]
        $linkDir = Split-Path $linkPath -Parent
        if (-not (Test-Path $linkDir)) {
            Write-Status "[INFO] Creating link parent directory: $linkDir" Cyan
            New-Item -ItemType Directory -Path $linkDir | Out-Null
        }
        if (Test-Path $linkPath) {
            if ((Get-Item $linkPath).LinkType -eq 'SymbolicLink') {
                Write-Status "[INFO] Link '$linkName' already exists." Cyan
            } else {
                Write-Status "[WARNING] '$linkName' exists and is not a symlink. Skipping link creation." Yellow
            }
        } elseif (-not (Test-Path $targetPath)) {
            Write-Status "[WARNING] Target for link '$linkName' does not exist: $targetPath" Yellow
        } else {
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath | Out-Null
            Write-Status "[OK] Created link '$linkName' -> $targetPath" Green
        }
    }
}

function Check-ServerUpdates {
    Write-ServerLog "Checking for server updates..."
    
    $currentBuildId = $null
    if (Test-Path $manifestFile) {
        $manifest = Get-Content $manifestFile -Raw
        if ($manifest -match '"buildid"\s+"(\d+)"') {
            $currentBuildId = $Matches[1]
        }
    }

    $updateCheckFile = Join-Path $steamcmdDir "update_check.txt"
    $steamCmdArgs = @(
        "+login anonymous",
        "+app_info_update 1",
        "+app_info_print 3792580",
        "+quit"
    )
    
    Push-Location $steamcmdDir
    $steamCmdOutput = & ".\steamcmd.exe" $steamCmdArgs | Out-String
    Pop-Location

    $latestBuildId = $null
    if ($steamCmdOutput -match '"buildid"\s+"(\d+)"') {
        $latestBuildId = $Matches[1]
    }

    if (-not $currentBuildId -or -not $latestBuildId) {
        Write-ServerLog "Could not determine build versions. Forcing update check." -error
        return $true
    }

    if ($currentBuildId -ne $latestBuildId) {
        Write-ServerLog "Update available! Current build: $currentBuildId, Latest build: $latestBuildId"
        return $true
    } else {
        Write-ServerLog "Server is up to date (Build: $currentBuildId)"
        return $false
    }
}

function Send-DiscordWebhook {
    param(
        [string]$Message,
        $Embed = $null
    )
    if (-not $DISCORD_WEBHOOK_URL) { return }
    $payload = @{}
    if ($Message) { $payload.content = $Message }
    if ($Embed) {
        if ($Embed -is [System.Collections.IEnumerable] -and -not ($Embed -is [string])) {
            $payload.embeds = @($Embed)
        } else {
            $payload.embeds = @($Embed)
        }
    }
    $json = $payload | ConvertTo-Json -Depth 6
    try {
        Invoke-RestMethod -Uri $DISCORD_WEBHOOK_URL -Method Post -ContentType 'application/json' -Body $json | Out-Null
    } catch {
        Write-ServerLog "Failed to send Discord webhook: $_" -error
    }
}

function Test-ServerAvailability {
    $testPort = [int]$SERVER_PORT + 2
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike '*Loopback*' -and $_.IPAddress -notlike '169.*' } | Select-Object -First 1 -ExpandProperty IPAddress)
    $externalIP = Get-ExternalIP
    foreach ($checkIP in @($ip, $externalIP)) {
        if ($checkIP -and $checkIP -ne "Unavailable") {
            $udpClient = $null
            try {
                $udpClient = New-Object System.Net.Sockets.UdpClient
                $remoteEP = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Parse($checkIP), $testPort)
                $data = [System.Text.Encoding]::ASCII.GetBytes("SCUMPING")
                $udpClient.Client.ReceiveTimeout = 5000
                $udpClient.Send($data, $data.Length, $remoteEP) | Out-Null
                $received = $udpClient.Receive([ref]$remoteEP)
                if ($received) {
                    Write-ServerLog "Server is available on $($checkIP):$testPort (UDP)."
                    Send-DiscordWebhook -Embed @{ description = "[OK] SCUM Server is available on $($checkIP):$testPort (UDP)."; color = 65280 }
                }
            } catch {
                Write-ServerLog "Server is NOT available on $($checkIP):$testPort (UDP)!" -error
                Send-DiscordWebhook -Embed @{ description = "[ERROR] SCUM Server is NOT available on $($checkIP):$testPort (UDP)! Check firewall, ports, or server health."; color = 16711680 }
            } finally {
                if ($udpClient) { $udpClient.Close() }
            }
        }
    }
}

function Get-ExternalIP {
    try {
        return (Invoke-RestMethod -Uri 'https://api.ipify.org')
    } catch {
        return "Unavailable"
    }
}

function Start-Server {
    if (Check-ServerUpdates) {
        Write-ServerLog "Updates found. Installing..."
        Install-Or-Update-Server
    }
    Create-Links
    $serverParams = "-log -port=$SERVER_PORT -MaxPlayers=$MAX_PLAYERS"
    if ($NOBATTLEYE -eq "1" -or $NOBATTLEYE -eq $true) {
        $serverParams += " -nobattleye"
    }
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike '*Loopback*' -and $_.IPAddress -notlike '169.*' } | Select-Object -First 1 -ExpandProperty IPAddress)
    $externalIP = Get-ExternalIP
    Write-ServerLog "Starting SCUM server..."
    Start-Process -WorkingDirectory (Split-Path $serverExe) $serverExe -ArgumentList $serverParams
    Write-ServerLog "SCUM server started. Internal IP: $ip  External IP: $externalIP  Port: $SERVER_PORT  MaxPlayers: $MAX_PLAYERS"
    Write-ServerLog "IMPORTANT: Players must connect to IP:PORT+2 (e.g., if port is 7000, connect to 7002)"
    Send-DiscordWebhook -Embed @{ title = "SCUM Server Started"; description = "SCUM Server started.\nInternal IP: $ip\nExternal IP: $externalIP\nPort: $SERVER_PORT\nMaxPlayers: $MAX_PLAYERS"; color = 65280 }
    Test-ServerAvailability
    # ======== NEXT RESTART INFO ========
    $restartList = $RESTART_TIMES -split "," | ForEach-Object { $_.Trim() }
    $now = Get-Date
    $nextRestart = $null
    foreach ($t in $restartList) {
        try {
            $todayRestart = [datetime]::ParseExact($t, "HH:mm", $null)
            $candidate = $now.Date.AddHours($todayRestart.Hour).AddMinutes($todayRestart.Minute)
            if ($candidate -le $now) { $candidate = $candidate.AddDays(1) }
            if (-not $nextRestart -or $candidate -lt $nextRestart) { $nextRestart = $candidate }
        } catch {}
    }
    if ($nextRestart) {
        $delta = $nextRestart - $now
        Write-ServerLog "Next scheduled restart: $($nextRestart.ToString('yyyy-MM-dd HH:mm')) (in $([math]::Floor($delta.TotalHours))h $($delta.Minutes)m)"
    }
    Update-Stats "start"
}

function Stop-Server {
    $procs = Get-Process -Name SCUMServer -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Status "[INFO] Stopping all SCUMServer.exe processes..." Cyan
        foreach ($proc in $procs) {
            try {
                Stop-Process -Id $proc.Id -Force
                Write-Status "[OK] Stopped process ID $($proc.Id)" Green
            } catch {
                Write-Status "[ERROR] Failed to stop process ID $($proc.Id): $_" Red
            }
        }
        Start-Sleep -Seconds 5
    }
}

function Check-FreeSpace {
    param(
        [int]$MinGB = 5
    )
    $drive = (Get-Item $gameServerDir).PSDrive.Root
    $freeGB = [math]::Round((Get-PSDrive -Name ($drive.Substring(0,1))).Free/1GB,2)
    if ($freeGB -lt $MinGB) {
        $msg = "⚠️ Low disk space: only $freeGB GB free on $drive. Minimum required: $MinGB GB."
        Write-ServerLog $msg -error
        Send-DiscordWebhook -Embed @{ title = "Low Disk Space"; description = $msg; color = 16776960 }
        return $false
    }
    return $true
}

function Rotate-Logs {
    $logDirs = @(
        (Join-Path $gameServerDir 'SCUM\Saved\Logs'),
        (Join-Path $gameServerDir 'SCUM\Saved\SaveFiles\Logs')
    )
    $days = 30
    foreach ($dir in $logDirs) {
        if (Test-Path $dir) {
            $oldLogs = Get-ChildItem $dir -File -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$days) }
            foreach ($log in $oldLogs) {
                try {
                    Remove-Item $log.FullName -Force
                    Write-ServerLog "Old log deleted: $($log.FullName)"
                } catch {
                    Write-ServerLog "Failed to delete old log: $($log.FullName) - $_" -error
                }
            }
        }
    }
}

function Backup-ServerData {
    param(
        [string]$Reason = ""
    )
    Run-Hook "before_backup"
    Rotate-Logs
    if (-not (Check-FreeSpace)) { return }
    Update-Stats "backup"
    $backupDir = Join-Path $baseDir "backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reasonSuffix = if ($Reason) { "_" + $Reason } else { "" }
    $savedPath = Join-Path $gameServerDir "SCUM\Saved"
    $filesToBackup = @()
    $proc = Get-Process -Name SCUMServer -ErrorAction SilentlyContinue
    $onlyConfig = $false
    if ($proc) {
        # Сервер работает — только конфиг и скрипт
        $filesToBackup = @($configFile, $PSCommandPath)
        $onlyConfig = $true
    } else {
        $filesToBackup = @($savedPath, $configFile, $PSCommandPath)
    }
    if (-not (Test-Path $savedPath) -and -not $onlyConfig) {
        Write-ServerLog "No data found to backup (SCUM\\Saved not found)." -error
        return
    }
    if ($BACKUP_COMPRESS) {
        $backupName = "scum_backup_${timestamp}${reasonSuffix}.zip"
        $backupPath = Join-Path $backupDir $backupName
        try {
            Compress-Archive -Path $filesToBackup -DestinationPath $backupPath -Force
        } catch {
            Write-ServerLog "Warning: Some files could not be archived (may be in use): $_"
        }
        Write-ServerLog "Backup created: $backupPath"
        Send-DiscordWebhook -Embed @{ title = "Backup Created"; description = "SCUM Server backup created: $backupName"; color = 3447003 }
        if ($onlyConfig) {
            $msg = "SCUMServer.exe is running, backup contains only config and script (no game data)."
            Write-ServerLog $msg -error
            Send-DiscordWebhook -Embed @{ title = "Backup Warning"; description = $msg; color = 16776960 }
        }
        $backups = Get-ChildItem $backupDir -Filter "scum_backup_*.zip" | Sort-Object LastWriteTime -Descending
        if ($backups.Count -gt 10) {
            $toDelete = $backups | Select-Object -Skip 10
            foreach ($old in $toDelete) {
                Remove-Item $old.FullName -Force
                Write-ServerLog "Old backup deleted: $($old.FullName)"
            }
        }
    } else {
        $backupName = "scum_backup_${timestamp}${reasonSuffix}"
        $backupPath = Join-Path $backupDir $backupName
        New-Item -ItemType Directory -Path $backupPath | Out-Null
        if ($onlyConfig) {
            Copy-Item $configFile -Destination $backupPath -Force
            Copy-Item $PSCommandPath -Destination $backupPath -Force
            $msg = "SCUMServer.exe is running, backup contains only config and script (no game data)."
            Write-ServerLog $msg -error
            Send-DiscordWebhook -Embed @{ title = "Backup Warning"; description = $msg; color = 16776960 }
        } else {
            Copy-Item $savedPath -Destination $backupPath -Recurse -Force
            Copy-Item $configFile -Destination $backupPath -Force
            Copy-Item $PSCommandPath -Destination $backupPath -Force
        }
        Write-ServerLog "Backup created (uncompressed): $backupPath"
        Send-DiscordWebhook -Embed @{ title = "Backup Created"; description = "SCUM Server backup created: $backupName"; color = 3447003 }
        $backups = Get-ChildItem $backupDir -Directory | Where-Object { $_.Name -like "scum_backup_*" } | Sort-Object LastWriteTime -Descending
        if ($backups.Count -gt 10) {
            $toDelete = $backups | Select-Object -Skip 10
            foreach ($old in $toDelete) {
                Remove-Item $old.FullName -Recurse -Force
                Write-ServerLog "Old backup deleted: $($old.FullName)"
            }
        }
    }
    Run-Hook "after_backup"
}

function Register-Tasks {
    $thisScript = $PSCommandPath
    $action1 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$thisScript`" -Mode watch"
    $trigger1 = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName "SCUMServer_AutoStart_And_Watch" -Action $action1 -Trigger $trigger1 -RunLevel Highest -Force
    $times = @("06:00","12:00","18:00","00:00")
    foreach ($t in $times) {
        $action2 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$thisScript`" -Mode restart"
        $trigger2 = New-ScheduledTaskTrigger -Daily -At $t
        Register-ScheduledTask -TaskName "SCUMServer_Restart_$($t.Replace(':','_'))" -Action $action2 -Trigger $trigger2 -RunLevel Highest -Force
    }
    # Backup task with custom interval
    $actionBackup = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$thisScript`" -Mode backup"
    $triggerBackup = New-ScheduledTaskTrigger -Once -At 3:00am -RepetitionInterval ([TimeSpan]::FromHours($BACKUP_INTERVAL_HOURS)) -RepetitionDuration ([TimeSpan]::FromDays(365))
    Register-ScheduledTask -TaskName "SCUMServer_DailyBackup" -Action $actionBackup -Trigger $triggerBackup -RunLevel Highest -Force
    Write-ServerLog "[OK] Scheduled tasks registered."
}

function Show-Help {
    Write-Host "SCUM Server Manager - Help" -ForegroundColor Cyan
    Write-Host "-----------------------------------"
    Write-Host "Usage: powershell -File scum_server_manager.ps1 -Mode <mode> [-BackupName <name>]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available modes:" -ForegroundColor Green
    Write-Host "  start           Install (if needed), create links, and start the server"
    Write-Host "  stop            Stop the server (if running)"
    Write-Host "  restart         Stop the server (if running), then start (or install and start)"
    Write-Host "  watch           Monitor SCUMServer.exe and auto-restart if it stops"
    Write-Host "  register-tasks  Register scheduled tasks for autostart and scheduled restarts"
    Write-Host "  backup          Perform server data backup (if server is running, only config/script are saved)"
    Write-Host "  restore-backup  Restore server data from the latest or specified backup"
    Write-Host "  send-stats      Send server statistics to Discord"
    Write-Host "  help            Show this help message"
    Write-Host "  self-update     Update this script from SELF_UPDATE_URL in config.json"
    Write-Host "  web             Start web interface on http://localhost:8080"
    Write-Host "  rcon-test       (disabled) Test RCON announcement (currently not available)"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode start"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode stop"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode restart"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode watch"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode register-tasks"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode backup"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode restore-backup"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode restore-backup -BackupName scum_backup_2024-06-20_12-00-00.zip"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode send-stats"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode help"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode self-update"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode web"
    Write-Host ""
    Write-Host "See README.md for full documentation."
}

function Install-Or-Update-Server {
    if (-not (Check-FreeSpace)) { return }
    # Create directories
    foreach ($dir in @($steamcmdDir, $gameServerDir)) {
        if (-not (Test-Path $dir)) {
            Write-Status "[INFO] Creating directory: $dir" Cyan
            New-Item -ItemType Directory -Path $dir | Out-Null
        }
    }
    # Download SteamCMD if needed
    $steamcmdExe = Join-Path $steamcmdDir "steamcmd.exe"
    if (-not (Test-Path $steamcmdExe)) {
        Write-Status "[INFO] SteamCMD not found. Downloading..." Cyan
        Invoke-WebRequest 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile (Join-Path $steamcmdDir "steamcmd.zip")
        Write-Status "[INFO] Extracting SteamCMD..." Cyan
        Expand-Archive -Path (Join-Path $steamcmdDir "steamcmd.zip") -DestinationPath $steamcmdDir -Force
        Remove-Item (Join-Path $steamcmdDir "steamcmd.zip")
        Write-Status "[OK] SteamCMD downloaded and extracted successfully." Green
    } else {
        Write-Status "[INFO] SteamCMD already installed." Cyan
    }
    # Install/update server
    Write-Status "[INFO] Installing or updating SCUM Dedicated Server (AppID: $APP_ID)..." Cyan
    Push-Location $steamcmdDir
    & $steamcmdExe +force_install_dir "$gameServerDir" +login anonymous +app_update $APP_ID validate +quit
    Pop-Location
    # Try to get server version
    $versionFile = Join-Path $gameServerDir "SCUM\Binaries\Win64\version.txt"
    if (Test-Path $versionFile) {
        $serverVersion = Get-Content $versionFile | Select-Object -First 1
        Write-Status "[OK] SCUM Dedicated Server installed or updated. Version: $serverVersion" Green
    } else {
        Write-Status "[OK] SCUM Dedicated Server installed or updated. (Version info not found)" Green
    }
}

function Watch-Server {
    Write-ServerLog "Server watcher started"
    $lastExitCode = 0
    while ($true) {
        $proc = Get-Process -Name SCUMServer -ErrorAction SilentlyContinue
        if (-not $proc) {
            if ($lastExitCode -ne 0) {
                Write-ServerLog "Server crashed or was terminated unexpectedly (Exit Code: $lastExitCode)" -error
                Send-DiscordWebhook -Embed @{ title = "Server Crash"; description = "SCUM Server crashed or was terminated unexpectedly (Exit Code: $lastExitCode). Restarting..."; color = 16711680 }
            } else {
                Write-ServerLog "Server process not found, restarting..."
                Send-DiscordWebhook -Embed @{ title = "Server Not Found"; description = "SCUM Server process not found, restarting..."; color = 16753920 }
            }
            try {
                Start-Server
                $lastExitCode = 0
                Write-ServerLog "Server restarted successfully"
                Send-DiscordWebhook -Embed @{ title = "Server Restarted"; description = "SCUM Server restarted successfully."; color = 16776960 }
            } catch {
                $lastExitCode = $LASTEXITCODE
                Write-ServerLog "Failed to restart server: $_" -error
                Send-DiscordWebhook -Embed @{ title = "Restart Failed"; description = "Failed to restart SCUM Server: $_"; color = 16711680 }
            }
            Start-Sleep -Seconds 30
        } else {
            $lastProcId = $proc.Id
            Start-Sleep -Seconds 10
            try {
                $exitedProc = Get-Process -Id $lastProcId -ErrorAction SilentlyContinue
                if (-not $exitedProc) {
                    $procInfo = Get-WmiObject Win32_Process -Filter "ProcessId = $lastProcId"
                    if ($procInfo) {
                        $lastExitCode = $procInfo.ExitCode
                    }
                }
            } catch {
                Write-ServerLog "Error checking process status: $_" -error
            }
        }
    }
}

function Restore-Backup {
    param(
        [string]$BackupName = $null
    )
    $backupDir = Join-Path $baseDir "backups"
    if (-not (Test-Path $backupDir)) {
        Write-ServerLog "No backups directory found." -error
        return
    }
    $backups = Get-ChildItem $backupDir -Filter "scum_backup_*" | Sort-Object LastWriteTime -Descending
    if (-not $backups) {
        Write-ServerLog "No backups found to restore." -error
        return
    }
    $backup = $null
    if (-not $BackupName -and $args.Count -ge 1) { $BackupName = $args[0] }
    if ($BackupName) {
        $backup = $backups | Where-Object { $_.Name -eq $BackupName } | Select-Object -First 1
        if (-not $backup) {
            Write-ServerLog "Backup $BackupName not found." -error
            return
        }
    } else {
        $backup = $backups | Select-Object -First 1
    }
    $savedPath = Join-Path $gameServerDir "SCUM\Saved"
    if (Test-Path $savedPath) {
        try {
            Remove-Item $savedPath -Recurse -Force
            Write-ServerLog "Old SCUM\Saved removed before restore."
        } catch {
            Write-ServerLog "Failed to remove old SCUM\Saved: $_" -error
            return
        }
    }
    if ($backup.Extension -eq ".zip") {
        Expand-Archive -Path $backup.FullName -DestinationPath $gameServerDir -Force
        Write-ServerLog "Restored from backup: $($backup.Name)"
        Send-DiscordWebhook -Embed @{ title = "Restore Backup"; description = "SCUM Server restored from backup: $($backup.Name)"; color = 3066993 }
    } else {
        Copy-Item $backup.FullName -Destination $savedPath -Recurse -Force
        Write-ServerLog "Restored from backup: $($backup.Name)"
        Send-DiscordWebhook -Embed @{ title = "Restore Backup"; description = "SCUM Server restored from backup: $($backup.Name)"; color = 3066993 }
    }
}

function Send-RCONMessage {
    param([string]$Message)
    return  # RCON temporarily disabled (code preserved for future use)
}

function Run-Hook {
    param(
        [string]$HookName
    )
    $hookPath = $HOOKS.$HookName
    if ($hookPath -and (Test-Path $hookPath)) {
        try {
            Write-ServerLog "Running user hook: $HookName ($hookPath)"
            & $hookPath | Out-Null
            Write-ServerLog "User hook finished: $HookName"
        } catch {
            Write-ServerLog "User hook failed: $HookName - $_" -error
        }
    }
}

function Load-Stats {
    if (Test-Path $statsFile) {
        return Get-Content $statsFile -Raw | ConvertFrom-Json
    } else {
        return @{ UptimeSeconds = 0; Restarts = 0; Backups = 0; Errors = 0; LastStart = $null }
    }
}

function Save-Stats($stats) {
    $stats | ConvertTo-Json | Set-Content $statsFile -Encoding UTF8
}

function Update-Stats {
    param(
        [string]$Event
    )
    $stats = Load-Stats
    switch ($Event) {
        "start" {
            $stats.LastStart = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        "restart" {
            $stats.Restarts++
        }
        "backup" {
            $stats.Backups++
        }
        "error" {
            $stats.Errors++
        }
        "uptime" {
            if ($stats.LastStart) {
                $last = [datetime]::Parse($stats.LastStart)
                $stats.UptimeSeconds += [int]((Get-Date) - $last).TotalSeconds
                $stats.LastStart = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    }
    Save-Stats $stats
}

function Send-Stats {
    $stats = Load-Stats
    $uptime = [TimeSpan]::FromSeconds($stats.UptimeSeconds)
    $msg = @(
        "[STATS] SCUM Server:",
        "Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m",
        "Restarts: $($stats.Restarts)",
        "Backups: $($stats.Backups)",
        "Errors: $($stats.Errors)"
    ) -join "`n"
    Send-DiscordWebhook -Embed @{ title = "Server Stats"; description = $msg; color = 3447003 }
    Write-ServerLog "Stats sent to Discord."
}

function Self-Update {
    if (-not $SELF_UPDATE_URL) {
        Write-ServerLog "SELF_UPDATE_URL not set in config.json. Cannot self-update." -error
        return
    }
    $tmpFile = "$PSCommandPath.tmp"
    try {
        Invoke-WebRequest -Uri $SELF_UPDATE_URL -OutFile $tmpFile -UseBasicParsing
        Move-Item -Path $tmpFile -Destination $PSCommandPath -Force
        Write-ServerLog "Self-update successful from $SELF_UPDATE_URL"
        Send-DiscordWebhook -Embed @{ title = "Self-Update"; description = "SCUM Server Manager self-updated from $SELF_UPDATE_URL"; color = 3447003 }
    } catch {
        Write-ServerLog "Self-update failed: $_" -error
        Send-DiscordWebhook -Embed @{ title = "Self-Update Failed"; description = "Self-update failed: $_"; color = 16711680 }
    }
}

function Start-WebInterface {
    $listener = New-Object System.Net.HttpListener
    $prefix = "http://localhost:$WEB_PORT/"
    $listener.Prefixes.Add($prefix)
    try {
        $listener.Start()
        Write-ServerLog "Web interface started at $prefix"
        Send-DiscordWebhook -Embed @{ title = "Web Interface"; description = "SCUM Server Web Interface started at $prefix"; color = 3447003 }
    } catch {
        Write-ServerLog "Failed to start web interface: $_" -error
        return
    }
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $writer = New-Object System.IO.StreamWriter($response.OutputStream)
        $action = $request.Url.AbsolutePath.Trim('/').ToLower()
        $result = ""
        switch ($action) {
            "start" {
                Start-Server
                $result = "Server started."
            }
            "stop" {
                Stop-Server
                $result = "Server stopped."
            }
            "restart" {
                if ($RCON_ENABLED -and $RCON_PASSWORD) {
                    Send-RCONMessage "[SERVER] Server will restart in 1 minute! Please disconnect."
                    Start-Sleep -Seconds 60
                }
                Stop-Server
                if (Wait-For-ServerStop -TimeoutSec 60) {
                    Backup-ServerData -Reason "restart"
                } else {
                    Write-ServerLog "Timeout waiting for SCUMServer.exe to stop. Backup may be incomplete." -error
                    Send-DiscordWebhook -Embed @{ title = "Backup Warning"; description = "Timeout waiting for SCUMServer.exe to stop. Backup may be incomplete."; color = 16776960 }
                    Backup-ServerData -Reason "restart"
                }
                Rotate-Logs
                Update-Stats "restart"
                if (Test-Path $serverExe) {
                    Start-Server
                    Send-DiscordWebhook -Embed @{ title = "Server Restarted"; description = "SCUM Server restarted by web interface."; color = 3447003 }
                } else {
                    Install-Or-Update-Server
                    Start-Server
                    Send-DiscordWebhook -Embed @{ title = "Server Restarted"; description = "SCUM Server installed and started after restart (web)."; color = 3447003 }
                }
                $result = "Server restarted."
            }
            "backup" {
                Backup-ServerData -Reason "web"
                $result = "Backup created."
            }
            "send-stats" {
                Send-Stats
                $result = "Stats sent to Discord."
            }
            "status" {
                $stats = Load-Stats
                $uptime = [TimeSpan]::FromSeconds($stats.UptimeSeconds)
                $logTail = (Get-Content $restartLogFile -Tail 20 -ErrorAction SilentlyContinue) -join "<br>"
                $result = @"
<b>SCUM Server Status</b><br>
Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m<br>
Restarts: $($stats.Restarts)<br>
Backups: $($stats.Backups)<br>
Errors: $($stats.Errors)<br>
<br><b>Last log lines:</b><br>$logTail
"@
            }
            "rcon-test" {
                $testMsg = "[TEST] This is a test announcement via RCON."
                Send-RCONMessage "anounce $testMsg"
                Write-ServerLog "Test RCON announcement sent: $testMsg"
                Send-DiscordWebhook -Embed @{ title = "RCON Test"; description = "Test RCON announcement sent: $testMsg"; color = 3447003 }
            }
            default {
                $result = @"
<html><head><title>SCUM Server Manager</title></head><body>
<h2>SCUM Server Manager Web Interface</h2>
<form method='post' action='/start'><button>Start Server</button></form>
<form method='post' action='/stop'><button>Stop Server</button></form>
<form method='post' action='/restart'><button>Restart Server</button></form>
<form method='post' action='/backup'><button>Backup Now</button></form>
<form method='post' action='/send-stats'><button>Send Stats to Discord</button></form>
<form method='get' action='/status'><button>Show Status</button></form>
</body></html>
"@
            }
        }
        $response.ContentType = 'text/html; charset=utf-8'
        $writer.Write($result)
        $writer.Flush()
        $response.Close()
    }
    $listener.Stop()
}

function Wait-For-ServerStop {
    param(
        [int]$TimeoutSec = 60
    )
    $elapsed = 0
    while ($elapsed -lt $TimeoutSec) {
        $proc = Get-Process -Name SCUMServer -ErrorAction SilentlyContinue
        if (-not $proc) { return $true }
        Start-Sleep -Seconds 5
        $elapsed += 5
    }
    return $false
}

# ========== MAIN SWITCH ==========
switch ($Mode) {
    "start" {
        if (Test-Path $serverExe) {
            Write-Status "[INFO] SCUM server files found. Skipping download and update." Cyan
            Start-Server
        } else {
            Install-Or-Update-Server
            Start-Server
        }
        Pause
    }
    "stop" {
        Stop-Server
        Write-ServerLog "SCUM server stopped by user command."
        Send-DiscordWebhook -Embed @{ title = "Server Stopped"; description = "SCUM Server stopped by user command."; color = 16776960 }
    }
    "restart" {
        Run-Hook "before_restart"
        if ($RCON_ENABLED -and $RCON_PASSWORD) {
            Send-RCONMessage "[SERVER] Server will restart in 1 minute! Please disconnect."
            Start-Sleep -Seconds 60
        }
        Stop-Server
        if (Wait-For-ServerStop -TimeoutSec 60) {
            Backup-ServerData -Reason "restart"
        } else {
            Write-ServerLog "Timeout waiting for SCUMServer.exe to stop. Backup may be incomplete." -error
            Send-DiscordWebhook -Embed @{ title = "Backup Warning"; description = "Timeout waiting for SCUMServer.exe to stop. Backup may be incomplete."; color = 16776960 }
            Backup-ServerData -Reason "restart"
        }
        Rotate-Logs
        Update-Stats "restart"
        if (Test-Path $serverExe) {
            Start-Server
            Send-DiscordWebhook -Embed @{ title = "Server Restarted"; description = "SCUM Server restarted by scheduled/manual action."; color = 3447003 }
        } else {
            Install-Or-Update-Server
            Start-Server
            Send-DiscordWebhook -Embed @{ title = "Server Restarted"; description = "SCUM Server installed and started after restart."; color = 3447003 }
        }
        Run-Hook "after_restart"
        Pause
    }
    "watch" {
        Watch-Server
    }
    "register-tasks" {
        Register-Tasks
    }
    "backup" {
        Backup-ServerData
    }
    "restore-backup" {
        $proc = Get-Process -Name SCUMServer -ErrorAction SilentlyContinue
        if ($proc) {
            $msg = "Cannot restore backup while SCUMServer.exe is running. Please stop the server first."
            Write-ServerLog $msg -error
            Send-DiscordWebhook -Embed @{ title = "Restore Error"; description = $msg; color = 16711680 }
            Write-Host $msg -ForegroundColor Red
            return
        }
        Restore-Backup $BackupName
    }
    "send-stats" {
        Send-Stats
    }
    "self-update" {
        Self-Update
    }
    "web" {
        Start-WebInterface
    }
    "rcon-test" {
        $testMsg = "[TEST] This is a test announcement via RCON."
        Send-RCONMessage "anounce $testMsg"
        Write-ServerLog "Test RCON announcement sent: $testMsg"
        Send-DiscordWebhook -Embed @{ title = "RCON Test"; description = "Test RCON announcement sent: $testMsg"; color = 3447003 }
    }
    default {
        Show-Help
    }
} 