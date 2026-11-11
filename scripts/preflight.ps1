# preflight.ps1 - read-only look at this PC before (and during) setup. Changes nothing.
# Each line starts with [ok], [!!] (must be fixed for the full routine) or [--] (optional / not there yet).
. "$PSScriptRoot\kit-common.ps1"
$cfg = Get-KitConfig
function Line([string]$mark, [string]$text) { "[$mark] $text" }

# Windows
$os = Get-CimInstance Win32_OperatingSystem
$build = [int]$os.BuildNumber
if ($build -ge 22000) { Line 'ok' "Windows 11 ($($os.Caption), build $build)" }
elseif ($build -ge 19041) { Line 'ok' "Windows 10 build $build (should work; the kit was made on Windows 11)" }
else { Line '!!' "Windows build $build is too old" }
$edition = $os.Caption
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Line '--' "this shell is elevated: $isAdmin (it should NOT be; only the service scripts are run elevated, by the owner)"

# GPU / encoder
$gpus = Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }
$hw = $gpus | Where-Object { $_ -match 'NVIDIA|AMD|Radeon|Intel' }
if ($gpus -match 'NVIDIA') { Line 'ok' "GPU: $($gpus -join '; ') (NVENC, the tested path)" }
elseif ($hw) { Line 'ok' "GPU: $($gpus -join '; ') (Sunshine supports AMD AMF and Intel QuickSync; untested with this kit)" }
else { Line '!!' "GPU: $($gpus -join '; ') - no hardware encoder recognised" }

# Monitors and DDC
$q = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'monitor-power.ps1') -Query
if ($q) { foreach ($l in $q) { if ($l -match 'readable=True') { Line 'ok' "monitor DDC: $l" } else { Line '--' "monitor DDC: $l (no answer: enable DDC/CI in the monitor menu, or the dark-monitors part is skipped)" } } }
else { Line '--' 'monitor DDC: no physical monitor answered' }

# Steam + silent audio device
$steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
if ($steam) { Line 'ok' "Steam: $steam" } else { Line '--' 'Steam not found (it provides the silent "Steam Streaming Speakers" device used to mute the PC)' }
$all = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'audio-default.ps1') -ListAll
$sss = $all | Where-Object { $_ -match "`tSpeakers \(Steam Streaming Speakers\)" } | Sort-Object | Select-Object -First 1
if ($sss -match '^1') { Line 'ok' 'silent audio device: Steam Streaming Speakers is active' }
elseif ($sss -match '^2') { Line '--' 'silent audio device: Steam Streaming Speakers is disabled (discover.ps1 enables it)' }
else { Line '!!' 'silent audio device: Steam Streaming Speakers missing (Steam > Settings > Remote Play > enable; or use another silent device)' }

# WoW Forever
$wow = $cfg.WowRoot
if (-not $wow) { $d = Join-Path ${env:ProgramFiles(x86)} 'World of Warcraft'; if (Test-Path $d) { $wow = $d } }
if ($wow -and (Test-Path (Join-Path $wow '_forever_\Wow.exe'))) { Line 'ok' "WoW Forever: $wow\_forever_" }
elseif ($wow -and (Test-Path (Join-Path $wow '_forever_'))) { Line 'ok' "WoW Forever folder: $wow\_forever_ (no Wow.exe seen there; check the install finished)" }
else { Line '!!' 'WoW Forever not found (install it in the Battle.net app; run discover.ps1 -WowRoot if it is elsewhere)' }

# Network
$lanPublic = $false
Get-NetConnectionProfile -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.InterfaceAlias -match 'Tailscale|ZeroTier|WireGuard|VPN') { Line '--' "network '$($_.Name)' ($($_.InterfaceAlias)): $($_.NetworkCategory)" }
    elseif ($_.NetworkCategory -eq 'Public') { $script:lanPublic = $true; Line '!!' "network '$($_.Name)' ($($_.InterfaceAlias)) is PUBLIC: the Thor will not reach the stream. Owner: Settings > Network & internet > (Ethernet or Wi-Fi) > Private network" }
    else { Line 'ok' "network '$($_.Name)' ($($_.InterfaceAlias)): $($_.NetworkCategory)" }
}
$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2\d|3[01])\.)' -and $_.PrefixOrigin -ne 'WellKnown' } | ForEach-Object { $_.IPAddress }
Line '--' "LAN address(es): $($ips -join ', ')"
$ts = Get-Command tailscale.exe -ErrorAction SilentlyContinue
if (-not $ts -and (Test-Path 'C:\Program Files\Tailscale\tailscale.exe')) { $ts = $true }
if ($ts) { Line '--' 'Tailscale is installed: read "Tailscale" in docs\TROUBLESHOOTING.md (the DS Forever stream must go over the LAN)' } else { Line 'ok' 'no Tailscale on this PC (nothing to work around)' }

# Apollo
$apollo = Get-Service ApolloService -ErrorAction SilentlyContinue
if ($apollo) { Line 'ok' "Apollo service: $($apollo.Status)" } else { Line '--' 'Apollo not installed yet (winget install ClassicOldSong.Apollo)' }
$other = Get-Service SunshineService -ErrorAction SilentlyContinue
if ($other) { Line '--' "LizardByte Sunshine service is also installed ($($other.Status)): it and Apollo fight over ports 47984-47990; keep only one" }
if (Get-Process -Name 'nvstreamer', 'NvStreamService' -ErrorAction SilentlyContinue) { Line '--' 'NVIDIA GameStream service is running: it occupies the same ports as Apollo' }

# DS Forever Desktop
if ($cfg.DesktopDir -and (Test-Path (Join-Path $cfg.DesktopDir 'DsForeverDesktop.exe'))) {
    $ver = (Get-Item (Join-Path $cfg.DesktopDir 'DsForeverDesktop.exe')).VersionInfo.ProductVersion
    Line 'ok' "DS Forever Desktop $ver in $($cfg.DesktopDir)"
} else { Line '--' 'DS Forever Desktop not found yet (run discover.ps1 once it is unpacked and started)' }
if (Get-Process DsForeverDesktop -ErrorAction SilentlyContinue) { Line 'ok' 'DS Forever Desktop is running' } else { Line '--' 'DS Forever Desktop is not running' }
$port = Get-KitSunshinePort $cfg.DataDir
if ($port) { Line 'ok' "DS Forever stream port: $port" } else { Line '--' 'DS Forever has no sunshine.conf yet (pair and stream once)' }

# adb
$adb = Get-KitAdb $cfg.DesktopDir
if ($adb) {
    Line 'ok' "adb: $adb"
    $devs = (& $adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\S' })
    if ($devs) { foreach ($d in $devs) { Line 'ok' "adb device: $d" } } else { Line '--' 'no adb device (Thor: Developer options > USB debugging, plug in, accept the prompt)' }
} else { Line '--' 'adb not found (DS Forever Desktop ships one in platform-tools; or: winget install Google.PlatformTools)' }

# Lock screen needs a way to sign in from the Thor
Line '--' 'lock screen: the owner signs in from the Thor with PIN or password (fingerprint/face do not work over a stream)'
Line '--' "config: $KitConfigPath"
