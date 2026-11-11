# session-watch.ps1 - the PC side of a couch session, in the style of Moonlight + Apollo.
# Runs hidden in the background (Startup entry made by enable-autostart.ps1) and watches DS Forever Desktop's desktop.log.
#   Thor connects -> PC sound to the silent device (it plays on the Thor only), monitors off over DDC/CI.
#   Thor leaves   -> after GraceSeconds without coming back: monitors on, sound restored, WoW closed, PC locked.
# Every part is a switch in %LOCALAPPDATA%\ThorWowKit\config.json and is re-read at each session start.
# Log: %LOCALAPPDATA%\ThorWowKit\session-watch.log
. "$PSScriptRoot\kit-common.ps1"
$audio = Join-Path $PSScriptRoot 'audio-default.ps1'
$mon = Join-Path $PSScriptRoot 'monitor-power.ps1'
$out = Join-Path $KitDir 'session-watch.log'

function Say([string]$m) { ("{0}  {1}" -f (Get-Date -Format 'MM-dd HH:mm:ss'), $m) | Out-File $out -Append -Encoding utf8 }
# never name a function "Ps": it is an alias of Get-Process
function RunPs($file, $argsList) { & powershell -NoProfile -ExecutionPolicy Bypass -File $file @argsList 2>&1 | Out-String }

# one instance only (Startup and a manual start may both run it)
$mutex = New-Object System.Threading.Mutex($false, 'Local\ThorWowKitSessionWatch')
if (-not $mutex.WaitOne(0)) { exit }

$cfg = Get-KitConfig
$previousAudio = $null
$monitorDueAt = $null
# crash recovery: a session that never ended (reboot, killed watcher) left the PC on the silent device
$prevFile = Join-Path $KitDir 'previous-audio.txt'
if (Test-Path $prevFile) {
    $saved = (Get-Content $prevFile -TotalCount 1).Trim()
    if ($saved -and ((RunPs $audio @('-Get')).Trim() -eq $cfg.SilentAudioId)) { RunPs $audio @('-Set', $saved) | Out-Null; Say "restored the sound left muted by an unfinished session" }
    Remove-Item $prevFile -ErrorAction SilentlyContinue
}

function SessionStart {
    $script:cfg = Get-KitConfig
    if ($cfg.MuteDuringSession -and $cfg.SilentAudioId) {
        $current = (RunPs $audio @('-Get')).Trim()
        if ($current -and $current -ne $cfg.SilentAudioId) { $script:previousAudio = $current; $current | Out-File $prevFile -Encoding ascii }
        RunPs $audio @('-Set', $cfg.SilentAudioId) | Out-Null
        Say "session start: PC sound -> silent device"
    } else { Say "session start (sound left alone)" }
    if ($cfg.MonitorsOff) { $script:monitorDueAt = (Get-Date).AddSeconds([int]$cfg.MonitorDelaySeconds) }
}

function MonitorsDown {
    $q = RunPs $mon @('-Query')
    if ($q -match 'current=1') { RunPs $mon @('-Off') | Out-Null; Say "monitors -> off" }
}

function SessionEnd {
    Say "session end"
    if ($cfg.MonitorsOff) { RunPs $mon @('-On') | Out-Null; Say "monitors on" }
    if ($script:previousAudio) { RunPs $audio @('-Set', $script:previousAudio) | Out-Null; $script:previousAudio = $null; Say "sound restored" }
    Remove-Item $prevFile -ErrorAction SilentlyContinue
    if ($cfg.CloseWowOnLeave) {
        $w = Get-Process Wow -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($w) {
            Say "closing WoW (pid $($w.Id))"
            $w.CloseMainWindow() | Out-Null
            Start-Sleep 20
            if (-not $w.HasExited) { Say "WoW still up, forcing"; Stop-Process -Id $w.Id -Force -ErrorAction SilentlyContinue }
            Say "WoW closed"
        } else { Say "WoW already closed" }
    }
    if ($cfg.LockOnEnd) { Say "locking the PC"; & rundll32.exe user32.dll,LockWorkStation }
}

# DS Forever Desktop updates itself and puts its own sunshine.exe back. If that copy runs, the stream comes from a
# user-mode Sunshine again and the lock screen can no longer be streamed. Disable it again and restart the service.
function GuardDesktopSunshine {
    if (-not $cfg.GuardDesktopSunshine -or -not $cfg.DesktopDir) { return }
    $exe = Join-Path $cfg.DesktopDir 'sunshine\sunshine.exe'
    if (-not (Test-Path $exe)) { return }
    if (-not (Get-Service $cfg.ServiceName -ErrorAction SilentlyContinue)) { return }
    try {
        Move-Item $exe "$exe.disabled" -Force -ErrorAction Stop
        Get-CimInstance Win32_Process -Filter "Name='sunshine.exe'" | Where-Object { $_.ExecutablePath -eq $exe } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep 2
        Restart-Service $cfg.ServiceName -ErrorAction Stop
        Say "guard: Desktop's own Sunshine came back (update?); disabled it again and restarted $($cfg.ServiceName)"
    } catch { Say "guard: could not finish ($($_.Exception.Message)); run verify.ps1" }
}

Say "watch started (grace $($cfg.GraceSeconds)s, mute=$($cfg.MuteDuringSession), monitorsOff=$($cfg.MonitorsOff), lockOnEnd=$($cfg.LockOnEnd))"
$log = Join-Path $cfg.DataDir 'desktop.log'
$pos = (Get-Item $log -ErrorAction SilentlyContinue).Length
$pending = $null; $inSession = $false; $waiting = $false; $lastGuard = Get-Date
while ($true) {
    Start-Sleep 2
    # Desktop not running: finish any open session, then keep waiting for it. The watch must never end by itself,
    # or a session started later runs without it and the PC is never locked.
    if (-not (Get-Process DsForeverDesktop -ErrorAction SilentlyContinue)) {
        if ($inSession) { $inSession = $false; $monitorDueAt = $null; SessionEnd }
        $pending = $null
        if (-not $waiting) { Say "Desktop not running; waiting for it"; $waiting = $true }
        Start-Sleep 8; continue
    }
    if ($waiting) {
        $waiting = $false; $cfg = Get-KitConfig; $log = Join-Path $cfg.DataDir 'desktop.log'
        $pos = (Get-Item $log -ErrorAction SilentlyContinue).Length; Say "Desktop is up, watching"
    }
    if (-not $inSession -and ((Get-Date) - $lastGuard).TotalSeconds -ge 15) { $lastGuard = Get-Date; GuardDesktopSunshine }
    $len = (Get-Item $log -ErrorAction SilentlyContinue).Length
    if ($len -lt $pos) { $pos = 0 }   # Desktop rotated its log
    if ($len -gt $pos) {
        $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite'); $fs.Seek($pos, 'Begin') | Out-Null
        $sr = New-Object System.IO.StreamReader($fs); $new = $sr.ReadToEnd(); $sr.Close(); $fs.Close(); $pos = $len
        foreach ($line in ($new -split "`n")) {
            # Desktop logs "bridge: <device name> connected from <ip>" and "bridge: <device name> disconnected"
            if ($line -match 'bridge: .+ connected from') {
                if ($pending) { Say "Thor is back" }
                $pending = $null
                if (-not $inSession) { $inSession = $true; SessionStart }
            } elseif ($line -match 'bridge: .+ disconnected') {
                $pending = Get-Date; Say "Thor left; ending the session in $($cfg.GraceSeconds)s unless it returns"
            }
        }
    }
    if ($inSession -and $monitorDueAt -and (Get-Date) -ge $monitorDueAt) { MonitorsDown; $monitorDueAt = (Get-Date).AddSeconds(20) }
    if ($pending -and ((Get-Date) - $pending).TotalSeconds -ge [int]$cfg.GraceSeconds) {
        $pending = $null
        if ($inSession) { $inSession = $false; $monitorDueAt = $null; SessionEnd }
    }
}
