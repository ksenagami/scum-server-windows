param(
    [ValidateSet("start", "restart", "watch", "register-tasks", "help")]
    [string]$Mode = "help"
)

# ========== CONFIG & UTILS ==========
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$steamcmdDir = Join-Path $baseDir "steamcmd"
$gameServerDir = Join-Path $baseDir "server"
$configFile = Join-Path $baseDir "SettingServer.ini"
$serverExe = Join-Path $gameServerDir "SCUM\Binaries\Win64\SCUMServer.exe"
$restartLogFile = Join-Path $baseDir "server_restarts.log"
$manifestFile = Join-Path $gameServerDir "steamapps\appmanifest_3792580.acf"

function Write-Status($msg, $color) {
    Write-Host $msg -ForegroundColor $color
}

function Write-ServerLog($msg, [switch]$error) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $msg"
    Add-Content -Path $restartLogFile -Value $logEntry -Encoding UTF8
    if ($error) {
        Write-Status $msg Red
    } else {
        Write-Status $msg Cyan
    }
}

# Create SettingServer.ini with default values if it does not exist
if (-not (Test-Path $configFile)) {
    @"
APP_ID=3792580
SERVER_PORT=7777
QUERY_PORT=7778
STEAM_SERVER_PORT=7779
MAX_PLAYERS=128
"@ | Set-Content $configFile -Encoding UTF8
    Write-Status "[INFO] Created default SettingServer.ini" Cyan
}

# ========== CONFIG READ ==========
$APP_ID = "3792580"
$SERVER_PORT = "7787"
$QUERY_PORT = "7788"
$STEAM_SERVER_PORT = "7789"
$MAX_PLAYERS = "128"
$LINKS_DIR = [Environment]::GetFolderPath('Desktop')
$CONFIG_LINK_PATH = $null
$CONSOLELOG_LINK_PATH = $null
$LOGS_LINK_PATH = $null

if (Test-Path $configFile) {
    Get-Content $configFile | ForEach-Object {
        if ($_ -match "^APP_ID=(.+)$") { $APP_ID = $Matches[1] }
        elseif ($_ -match "^SERVER_PORT=(.+)$") { $SERVER_PORT = $Matches[1] }
        elseif ($_ -match "^QUERY_PORT=(.+)$") { $QUERY_PORT = $Matches[1] }
        elseif ($_ -match "^STEAM_SERVER_PORT=(.+)$") { $STEAM_SERVER_PORT = $Matches[1] }
        elseif ($_ -match "^MAX_PLAYERS=(.+)$") { $MAX_PLAYERS = $Matches[1] }
        elseif ($_ -match "^LINKS_DIR=(.+)$") { $LINKS_DIR = $Matches[1] }
        elseif ($_ -match "^CONFIG_LINK_PATH=(.+)$") { $CONFIG_LINK_PATH = $Matches[1] }
        elseif ($_ -match "^CONSOLELOG_LINK_PATH=(.+)$") { $CONSOLELOG_LINK_PATH = $Matches[1] }
        elseif ($_ -match "^LOGS_LINK_PATH=(.+)$") { $LOGS_LINK_PATH = $Matches[1] }
    }
    Write-Status "[INFO] Loaded config from SettingServer.ini" Cyan
} else {
    Write-Status "[WARNING] SettingServer.ini not found. Using default values." Yellow
}

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

function Start-Server {
    # Проверяем обновления перед запуском
    if (Check-ServerUpdates) {
        Write-ServerLog "Updates found. Installing..."
        Install-Or-Update-Server
    }

    Create-Links
    $serverParams = "-log -port=$SERVER_PORT -QueryPort=$QUERY_PORT -SteamServerPort=$STEAM_SERVER_PORT -MaxPlayers=$MAX_PLAYERS"
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike '*Loopback*' -and $_.IPAddress -notlike '169.*' } | Select-Object -First 1 -ExpandProperty IPAddress)
    Write-ServerLog "Starting SCUM server..."
    Start-Process -WorkingDirectory (Split-Path $serverExe) $serverExe -ArgumentList $serverParams
    Write-ServerLog "SCUM server started. IP: $ip  Port: $SERVER_PORT  MaxPlayers: $MAX_PLAYERS"

    # ======== NEXT RESTART INFO ========
    $RESTART_TIMES = "06:00,12:00,18:00,00:00"
    if (Test-Path $configFile) {
        $restartLine = (Get-Content $configFile | Where-Object { $_ -match "^RESTART_TIMES=" })
        if ($restartLine) {
            $RESTART_TIMES = $restartLine -replace "^RESTART_TIMES=", ""
        }
    }
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
}

function Stop-Server {
    $proc = Get-Process -Name SCUMServer -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Status "[INFO] Stopping SCUMServer.exe..." Cyan
        Stop-Process -Id $proc.Id -Force
        Start-Sleep -Seconds 5
    }
}

function Install-Or-Update-Server {
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
            } else {
                Write-ServerLog "Server process not found, restarting..."
            }
            
            try {
                Start-Server
                $lastExitCode = 0
                Write-ServerLog "Server restarted successfully"
            } catch {
                $lastExitCode = $LASTEXITCODE
                Write-ServerLog "Failed to restart server: $_" -error
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
    Write-ServerLog "[OK] Scheduled tasks registered."
}

function Show-Help {
    Write-Host "SCUM Server Manager - Help" -ForegroundColor Cyan
    Write-Host "-----------------------------------"
    Write-Host "Usage: powershell -File scum_server_manager.ps1 -Mode <mode>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available modes:" -ForegroundColor Green
    Write-Host "  start           Install (if needed), create links, and start the server"
    Write-Host "  restart         Stop the server (if running), then start (or install and start)"
    Write-Host "  watch           Monitor SCUMServer.exe and auto-restart if it stops"
    Write-Host "  register-tasks  Register scheduled tasks for autostart and scheduled restarts"
    Write-Host "  help            Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode start"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode restart"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode watch"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode register-tasks"
    Write-Host "  powershell -File scum_server_manager.ps1 -Mode help"
    Write-Host ""
    Write-Host "SettingServer.ini parameters:" -ForegroundColor Cyan
    Write-Host "  APP_ID              Steam App ID for SCUM Dedicated Server (default: 3792580)"
    Write-Host "  SERVER_PORT         Game server port (default: 7777)"
    Write-Host "  QUERY_PORT          Query port for server browser (default: 7778)"
    Write-Host "  STEAM_SERVER_PORT   Steam server port (default: 7779)"
    Write-Host "  MAX_PLAYERS         Maximum number of players (default: 128)"
    Write-Host "  LINKS_DIR           Directory for all symlinks (default: Desktop)"
    Write-Host "  CONFIG_LINK_PATH    Custom path for Config link (overrides LINKS_DIR for Config)"
    Write-Host "  CONSOLELOG_LINK_PATH Custom path for ConsoleLog link (overrides LINKS_DIR for ConsoleLog)"
    Write-Host "  LOGS_LINK_PATH      Custom path for Logs link (overrides LINKS_DIR for Logs)"
    Write-Host ""
    Write-Host "You can use environment variables in paths, e.g. %USERPROFILE%\Desktop" -ForegroundColor Yellow
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
    "restart" {
        Stop-Server
        if (Test-Path $serverExe) {
            Start-Server
        } else {
            Install-Or-Update-Server
            Start-Server
        }
        Pause
    }
    "watch" {
        Watch-Server
    }
    "register-tasks" {
        Register-Tasks
    }
    default {
        Show-Help
    }
} 