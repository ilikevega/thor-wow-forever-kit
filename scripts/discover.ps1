# discover.ps1 - find what THIS PC needs and write it to %LOCALAPPDATA%\ThorWowKit\config.json.
# Safe to run again at any time: it only fills in facts (folders, the silent audio device), never the on/off switches.
#   -DesktopDir "<folder>"   folder with DsForeverDesktop.exe, if it is not running and not in a usual place
#   -WowRoot "<folder>"      World of Warcraft folder, if it is not found
param([string]$DesktopDir, [string]$WowRoot)
. "$PSScriptRoot\kit-common.ps1"
$cfg = Get-KitConfig

# --- DS Forever Desktop folder: the running process, else what was saved, else common places
if (-not $DesktopDir) {
    $p = Get-Process DsForeverDesktop -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p -and $p.Path) { $DesktopDir = Split-Path -Parent $p.Path }
}
if (-not $DesktopDir -and $cfg.DesktopDir -and (Test-Path (Join-Path $cfg.DesktopDir 'DsForeverDesktop.exe'))) { $DesktopDir = $cfg.DesktopDir }
if (-not $DesktopDir) {
    # one and two folders deep under the usual places and every fixed drive
    $roots = @($env:LOCALAPPDATA, "$env:LOCALAPPDATA\Programs", $env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents")
    $roots += (Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { $_.DeviceID + '\' })
    foreach ($r in $roots) {
        if (-not $r -or -not (Test-Path $r)) { continue }
        $hit = Resolve-Path (Join-Path $r '*\DsForeverDesktop.exe'), (Join-Path $r '*\*\DsForeverDesktop.exe') -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { $DesktopDir = Split-Path -Parent $hit.Path; break }
    }
}
if ($DesktopDir) { $cfg.DesktopDir = $DesktopDir; "DS Forever Desktop: $DesktopDir" } else { "DS Forever Desktop: NOT FOUND (start it once, or pass -DesktopDir)" }
if (Test-Path (Join-Path $cfg.DataDir 'desktop.log')) { "Desktop data: $($cfg.DataDir)" } else { "Desktop data: no desktop.log yet in $($cfg.DataDir) (Desktop has never run for this user)" }

# --- World of Warcraft folder: Desktop's own log, else the registry, else the default path
if (-not $WowRoot) {
    $dlog = Join-Path $cfg.DataDir 'desktop.log'
    if (Test-Path $dlog) {
        $line = Get-Content $dlog -ErrorAction SilentlyContinue | Where-Object { $_ -match 'WoW at (.+?) \(_forever_\)' } | Select-Object -Last 1
        if ($line -match 'WoW at (.+?) \(_forever_\)') { $WowRoot = $Matches[1] }
    }
}
if (-not $WowRoot) {
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft', 'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft') {
        $v = (Get-ItemProperty $k -ErrorAction SilentlyContinue).InstallPath
        if ($v) { $WowRoot = $v.TrimEnd('\'); if ((Split-Path -Leaf $WowRoot) -match '^_.+_$') { $WowRoot = Split-Path -Parent $WowRoot }; break }
    }
}
if (-not $WowRoot) { $d = Join-Path ${env:ProgramFiles(x86)} 'World of Warcraft'; if (Test-Path $d) { $WowRoot = $d } }
if ($WowRoot -and (Test-Path (Join-Path $WowRoot '_forever_'))) { $cfg.WowRoot = $WowRoot; "WoW Forever: $WowRoot\_forever_" }
else { "WoW Forever: NOT FOUND (install WoW Forever in the Battle.net app, or pass -WowRoot)" }

# --- the silent playback device: Steam Streaming Speakers (installed by Steam's Remote Play audio driver)
$audio = Join-Path $PSScriptRoot 'audio-default.ps1'
$all = & powershell -NoProfile -ExecutionPolicy Bypass -File $audio -ListAll
$steam = $all | Where-Object { $_ -match "^(\d+)`t(\S+)`tSpeakers \(Steam Streaming Speakers\)" } | Sort-Object | Select-Object -First 1
if ($steam -and $steam -match "^(\d+)`t(\S+)`t") {
    $state = [int]$Matches[1]; $id = $Matches[2]
    if ($state -eq 2) { "Steam Streaming Speakers is disabled; enabling it"; & powershell -NoProfile -ExecutionPolicy Bypass -File $audio -Enable $id }
    if ($state -eq 1 -or $state -eq 2) { $cfg.SilentAudioId = $id; "Silent audio device: Steam Streaming Speakers ($id)" }
    else { "Silent audio device: Steam Streaming Speakers exists but is not present (state $state). In Steam: Settings > Remote Play > enable it and let it install the audio driver." }
} else {
    "Silent audio device: NOT FOUND. In Steam: Settings > Remote Play > turn Remote Play on (installs 'Steam Streaming Speakers'), then run this again."
    "  Any other always-silent playback device works too (for example VB-Cable): put its id from 'audio-default.ps1 -List' into SilentAudioId."
}
"Current default playback device: " + ((& powershell -NoProfile -ExecutionPolicy Bypass -File $audio -Get) | Out-String).Trim()

Save-KitConfig $cfg
"Saved: $KitConfigPath"
