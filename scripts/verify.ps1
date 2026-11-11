# verify.ps1 - read-only check of the finished setup. PASS / FAIL / SKIP per part, and what to do about a FAIL.
. "$PSScriptRoot\kit-common.ps1"
$cfg = Get-KitConfig
$fail = 0
function Pass([string]$t) { "PASS  $t" }
function Skip([string]$t) { "SKIP  $t" }
function Fail([string]$t) { $script:fail++; "FAIL  $t" }

# config facts
if ($cfg.DesktopDir -and (Test-Path (Join-Path $cfg.DesktopDir 'DsForeverDesktop.exe'))) { Pass "Desktop folder: $($cfg.DesktopDir)" } else { Fail 'Desktop folder unknown -> run discover.ps1' }
if ($cfg.WowRoot -and (Test-Path (Join-Path $cfg.WowRoot '_forever_'))) { Pass "WoW Forever: $($cfg.WowRoot)" } else { Fail 'WoW folder unknown -> run discover.ps1' }

# sound
if (-not $cfg.MuteDuringSession) { Skip 'muting the PC during a session is switched off' }
elseif ($cfg.SilentAudioId) {
    $active = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'audio-default.ps1') -List
    if ($active | Where-Object { $_.StartsWith($cfg.SilentAudioId) }) { Pass 'silent audio device is active' } else { Fail 'the saved silent audio device is not active -> run discover.ps1' }
} else { Fail 'no silent audio device saved -> run discover.ps1 (or set MuteDuringSession false)' }

# monitors
if ($cfg.MonitorsOff) {
    $q = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'monitor-power.ps1') -Query
    if ($q -match 'readable=True') { Pass "monitors off during a session: enabled ($(@($q).Count) monitor(s) answer DDC)" } else { Fail 'MonitorsOff is on but no monitor answers DDC right now' }
} else { Skip 'monitors off during a session is switched off (enable only after monitor-power.ps1 -Test passed)' }

# the Sunshine service
$svc = Get-Service $cfg.ServiceName -ErrorAction SilentlyContinue
$port = Get-KitSunshinePort $cfg.DataDir
if (-not $svc) {
    Skip "Sunshine service not installed: streaming works only while the PC is UNLOCKED"
    if ($cfg.LockOnEnd) { Fail 'LockOnEnd is on without the service: the next session could not start from the lock screen -> install the service or set LockOnEnd false' }
} else {
    if ($svc.Status -eq 'Running') { Pass "service $($cfg.ServiceName) is running" } else { Fail "service $($cfg.ServiceName) is $($svc.Status) -> Start-Service $($cfg.ServiceName); see TROUBLESHOOTING" }
    $own = Join-Path $cfg.DesktopDir 'sunshine\sunshine.exe'
    if (Test-Path $own) { Fail "Desktop's own sunshine.exe is back (a Desktop update?) -> the watcher's guard fixes it when GuardDesktopSunshine is true; or re-run install-sunshine-service.ps1" } else { Pass "Desktop's own Sunshine is disabled" }
    $svcExe = Join-Path $cfg.ServiceDir 'sunshine.exe'
    $procs = @(Get-CimInstance Win32_Process -Filter "Name='sunshine.exe'")
    $userOwned = @($procs | Where-Object { $_.ExecutablePath -and $_.ExecutablePath -ne $svcExe -and $_.ExecutablePath -like "$($cfg.DesktopDir)*" })
    if ($userOwned.Count) { Fail 'a user-mode Sunshine from the Desktop folder is running next to the service' }
    if ($port) {
        $l = netstat -ano | Select-String -Pattern ":$port\s.*LISTENING" | Select-Object -First 1
        if ($l) {
            $listenPid = [int](($l.Line -split '\s+')[-1])
            $owner = (Get-CimInstance Win32_Process -Filter "ProcessId=$listenPid" | Invoke-CimMethod -MethodName GetOwner -ErrorAction SilentlyContinue).User
            if ($owner -eq 'SYSTEM' -or -not $owner) { Pass "stream port $port is served by the service's Sunshine (pid $listenPid)" } else { Fail "stream port $port is served by a Sunshine running as $owner, not the service" }
        } else { Fail "nothing listens on stream port $port (Sunshine needs up to a minute after a service start)" }
    } else { Fail 'no stream port in sunshine.conf' }
    $a = Join-Path $cfg.ServiceDir 'sunshine.exe'; $b = Join-Path $cfg.DesktopDir 'sunshine\sunshine.exe.disabled'
    if ((Test-Path $a) -and (Test-Path $b) -and ((Get-Item $a).Length -ne (Get-Item $b).Length)) { Fail "the service's Sunshine differs from the one Desktop ships now (Desktop updated) -> owner re-runs install-sunshine-service.ps1" }
    if ($cfg.GuardDesktopSunshine) { Pass 'guard against Desktop re-enabling its Sunshine: on' } else { Fail 'GuardDesktopSunshine is off -> set-config.ps1 -Name GuardDesktopSunshine -Value true' }
    $rule = netsh advfirewall firewall show rule name="Thor WoW Kit - DS Forever Sunshine" 2>$null
    if ($rule -match 'Enabled:\s+Yes') { Pass 'firewall rule for the service Sunshine exists' } else { Fail 'firewall rule missing -> owner re-runs install-sunshine-service.ps1' }
}
Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.NetworkCategory -eq 'Public' -and $_.InterfaceAlias -notmatch 'Tailscale|ZeroTier|WireGuard|VPN' } |
    ForEach-Object { Fail "network '$($_.Name)' is Public -> owner sets it to Private in Windows Settings" }

# lock at the end
if ($cfg.LockOnEnd) { if ($svc) { Pass 'lock the PC at session end: on' } } else { Skip 'lock the PC at session end is switched off' }

# watcher + autostart
$w = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'session-watch\.ps1' }
if ($w) { Pass "session watcher is running (pid $(@($w)[0].ProcessId))" } else { Fail 'session watcher is not running -> enable-autostart.ps1 -StartNow' }
$startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'Thor WoW Kit session watcher.vbs'
if (Test-Path $startup) {
    if ((Get-Content $startup -Raw) -match [regex]::Escape((Join-Path $PSScriptRoot 'session-watch.ps1'))) { Pass 'watcher starts with Windows' } else { Fail 'the Startup entry points at another folder (kit moved?) -> enable-autostart.ps1' }
} else { Fail 'watcher does not start with Windows -> enable-autostart.ps1' }

# add-on
$addon = Join-Path $cfg.WowRoot '_forever_\Interface\AddOns\NoAddonBlockedPopup\NoAddonBlockedPopup.toc'
if ($cfg.WowRoot -and (Test-Path $addon)) { Pass 'NoAddonBlockedPopup add-on is installed' } else { Skip 'NoAddonBlockedPopup add-on not installed (install-addon.ps1)' }

""
if ($fail) { "$fail FAIL line(s). Fix them top to bottom, then run verify.ps1 again."; exit 1 } else { "All enabled parts check out. The real test is one full session from the couch (docs\COUCH-ROUTINE.md)." }
