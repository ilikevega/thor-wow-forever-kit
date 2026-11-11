# kit-common.ps1 - shared helpers. Dot-source it:  . "$PSScriptRoot\kit-common.ps1"
# State lives in %LOCALAPPDATA%\ThorWowKit: config.json (what this PC needs), kit.log (what the scripts did).

$KitDir = Join-Path $env:LOCALAPPDATA 'ThorWowKit'
if (-not (Test-Path $KitDir)) { New-Item -ItemType Directory -Force $KitDir | Out-Null }
$KitConfigPath = Join-Path $KitDir 'config.json'
$KitLogPath = Join-Path $KitDir 'kit.log'

function Write-KitLog([string]$Message) {
    ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) | Out-File $KitLogPath -Append -Encoding utf8
    Write-Host $Message
}

function Get-KitDefaults {
    return [ordered]@{
        SilentAudioId        = ''      # playback endpoint that makes no sound (Steam Streaming Speakers); set by discover.ps1
        MuteDuringSession    = $true   # switch the PC's default output to SilentAudioId while the Thor is connected
        MonitorsOff          = $false  # DDC/CI monitor power-off during a session; turn on only after monitor-power.ps1 -Test passed
        MonitorDelaySeconds  = 25      # WoW going fullscreen wakes the panels, so they are switched off a little later
        CloseWowOnLeave      = $true   # close WoW on the PC when the Thor leaves
        GraceSeconds         = 20      # how long the Thor may be gone before the session counts as over
        LockOnEnd            = $false  # lock the PC when the session ends; turn on only after the Sunshine service works
        GuardDesktopSunshine = $false  # keep DS Forever Desktop's own Sunshine disabled; turn on after the service is installed
        DesktopDir           = ''      # folder with DsForeverDesktop.exe
        DataDir              = (Join-Path $env:LOCALAPPDATA 'DSForeverDesktop')
        WowRoot              = ''      # World of Warcraft folder (the one that contains _forever_)
        ServiceName          = 'ThorWowKitSunshine'
        ServiceDir           = 'C:\Program Files\ThorWowKit\SunshineSvc'
    }
}

function Get-KitConfig {
    $cfg = Get-KitDefaults
    if (Test-Path $KitConfigPath) {
        try {
            $saved = Get-Content $KitConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $saved.PSObject.Properties) { $cfg[$p.Name] = $p.Value }
        } catch { Write-Host "config.json is unreadable, using defaults: $($_.Exception.Message)" }
    }
    return $cfg
}

function Save-KitConfig($Config) {
    $Config | ConvertTo-Json -Depth 5 | Out-File $KitConfigPath -Encoding utf8
}

# adb: PATH first, then the copy DS Forever Desktop ships, then the usual SDK location.
function Get-KitAdb([string]$DesktopDir) {
    $cmd = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @()
    if ($DesktopDir) { $candidates += (Join-Path $DesktopDir 'platform-tools\adb.exe') }
    $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

# The port DS Forever's Sunshine is configured for (Desktop writes sunshine.conf).
function Get-KitSunshinePort([string]$DataDir) {
    $conf = Join-Path $DataDir 'sunshine\sunshine.conf'
    if (-not (Test-Path $conf)) { return $null }
    $line = Get-Content $conf | Where-Object { $_ -match '^\s*port\s*=\s*(\d+)' } | Select-Object -First 1
    if ($line -match '(\d+)') { return [int]$Matches[1] }
    return $null
}
