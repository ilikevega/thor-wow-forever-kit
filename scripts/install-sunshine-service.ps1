# install-sunshine-service.ps1 - RUN AS ADMINISTRATOR. Makes DS Forever's Sunshine run as a Windows service (LocalSystem),
# which is what lets the Thor stream and unlock the Windows LOCK SCREEN, the way Apollo does. Without this, DS Forever
# Desktop runs Sunshine as the signed-in user and it cannot show the secure desktop.
#
# What it does (all of it is undone by uninstall-sunshine-service.ps1):
#   1. closes DS Forever Desktop
#   2. copies Desktop's bundled Sunshine to -ServiceDir; its "config" folder there is a junction to Desktop's own Sunshine
#      data, so certificate, pairing and port stay the same and the Thor does not need to pair again
#   3. renames Desktop's own sunshine.exe to sunshine.exe.disabled (Desktop then logs "sunshine not bundled" and keeps
#      doing everything else: bridge, login, starting WoW)
#   4. creates the service (auto start, LocalSystem), gives it its own TEMP folder, lets the signed-in user start/stop it,
#      adds an inbound firewall rule for that sunshine.exe on Private and Domain networks, starts it
#
# Do this only AFTER the Thor is paired with DS Forever Desktop and a normal stream has worked once.
# Re-run it after a DS Forever Desktop update to refresh the service's copy of Sunshine.
#
# Run from an elevated PowerShell, with the two folders discover.ps1 found:
#   powershell -ExecutionPolicy Bypass -File install-sunshine-service.ps1 -DesktopDir "<...>" -DataDir "<...>"
param(
    [Parameter(Mandatory = $true)][string]$DesktopDir,   # folder with DsForeverDesktop.exe
    [Parameter(Mandatory = $true)][string]$DataDir,      # %LOCALAPPDATA%\DSForeverDesktop of the user who plays
    [string]$ServiceName = 'ThorWowKitSunshine',
    [string]$ServiceDir = 'C:\Program Files\ThorWowKit\SunshineSvc'
)
$ErrorActionPreference = 'Continue'
$log = Join-Path $DataDir 'thor-wow-kit-service-install.log'
function Log([string]$m) { $m | Out-File $log -Append -Encoding utf8; Write-Host $m }
"== install-sunshine-service $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $log -Encoding utf8

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Log "NOT ELEVATED. Open PowerShell with 'Run as administrator' and run this again."; exit 1 }

$src = Join-Path $DesktopDir 'sunshine'
$srcExe = Join-Path $src 'sunshine.exe'
$srcDisabled = "$srcExe.disabled"
$conf = Join-Path $DataDir 'sunshine\sunshine.conf'
if (-not (Test-Path (Join-Path $src 'tools\sunshinesvc.exe'))) { Log "No tools\sunshinesvc.exe under $src. Is -DesktopDir right, and does this Desktop version still bundle Sunshine?"; exit 1 }
if (-not (Test-Path $srcExe) -and -not (Test-Path $srcDisabled)) { Log "No sunshine.exe (or sunshine.exe.disabled) in $src."; exit 1 }
if (-not (Test-Path $conf)) { Log "No $conf. Start DS Forever Desktop, pair the Thor and stream once first."; exit 1 }
$port = 0
$portLine = Get-Content $conf | Where-Object { $_ -match '^\s*port\s*=\s*(\d+)' } | Select-Object -First 1
if ($portLine -match '(\d+)') { $port = [int]$Matches[1] }
Log "Desktop: $DesktopDir   data: $DataDir   stream port: $port"

# 1. Desktop must not be running while its Sunshine is swapped
$desk = Get-Process DsForeverDesktop -ErrorAction SilentlyContinue
if ($desk) { Log "closing DS Forever Desktop"; $desk | Stop-Process -Force; Start-Sleep 3 }
Get-CimInstance Win32_Process -Filter "Name='sunshine.exe'" | Where-Object { $_.ExecutablePath -eq $srcExe } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# remove an earlier install of this service
if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
    Log "removing the existing $ServiceName"
    Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
    sc.exe delete $ServiceName | Out-File $log -Append -Encoding utf8
    Start-Sleep 3
}

# 2. copy Sunshine (not its config folder), then point config at Desktop's data
New-Item -ItemType Directory -Force $ServiceDir | Out-Null
New-Item -ItemType Directory -Force (Join-Path $ServiceDir 'temp') | Out-Null
robocopy $src $ServiceDir /E /XD config temp /XF sunshine.exe.disabled /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Log "robocopy failed with $LASTEXITCODE"; exit 1 }
$dstExe = Join-Path $ServiceDir 'sunshine.exe'
if (Test-Path $srcExe) { Copy-Item $srcExe $dstExe -Force } else { Copy-Item $srcDisabled $dstExe -Force }
$junction = Join-Path $ServiceDir 'config'
if (-not (Test-Path $junction)) { cmd.exe /c mklink /J "$junction" "$(Join-Path $DataDir 'sunshine')" | Out-File $log -Append -Encoding utf8 }
if (-not (Test-Path (Join-Path $junction 'sunshine.conf'))) { Log "The config junction does not show sunshine.conf: $junction"; exit 1 }

# 3. disable Desktop's own copy
if (Test-Path $srcExe) { Move-Item $srcExe $srcDisabled -Force; Log "renamed Desktop's sunshine.exe to sunshine.exe.disabled" }

# 4. the service
$bin = Join-Path $ServiceDir 'tools\sunshinesvc.exe'
sc.exe create $ServiceName binPath= "`"$bin`"" start= auto obj= LocalSystem DisplayName= "Thor WoW Kit - DS Forever Sunshine" | Out-File $log -Append -Encoding utf8
sc.exe description $ServiceName "DS Forever's bundled Sunshine as a service, so the Thor can stream the Windows lock screen. Installed by thor-wow-forever-kit." | Out-File $log -Append -Encoding utf8
# The service wrapper writes <TEMP>\sunshine.log and keeps it open without write sharing. Apollo (and LizardByte Sunshine)
# use the same wrapper and the same C:\Windows\Temp\sunshine.log, so a second service fails to start with
# "being used by another process" unless it gets its own TEMP.
$tmp = Join-Path $ServiceDir 'temp'
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName" -Name Environment -PropertyType MultiString -Value @("TMP=$tmp", "TEMP=$tmp") -Force | Out-Null
# let the signed-in (interactive) user start and stop this one service, so the session watcher can restart it after a
# Desktop update without an admin prompt. It grants start/stop/query only, not reconfiguration.
$sd = ((sc.exe sdshow $ServiceName) -join '').Trim()
$ace = '(A;;CCLCSWRPWPDTLOCRRC;;;IU)'
if ($sd -and $sd -notlike "*$ace*") {
    if ($sd -match 'S:\(') { $newSd = $sd -replace 'S:\(', "$ace`S:(" } else { $newSd = $sd + $ace }
    sc.exe sdset $ServiceName $newSd | Out-File $log -Append -Encoding utf8
}
$rule = "Thor WoW Kit - DS Forever Sunshine"
netsh advfirewall firewall delete rule name="$rule" | Out-Null
netsh advfirewall firewall add rule name="$rule" dir=in action=allow program="$dstExe" enable=yes profile=private,domain | Out-File $log -Append -Encoding utf8

try { Start-Service $ServiceName -ErrorAction Stop; Log "service started" } catch { Log "START FAILED: $($_.Exception.Message)" }

# Sunshine needs 20-50 s (encoder probing) before it listens
$listening = $false
for ($i = 0; $i -lt 30 -and -not $listening; $i++) {
    Start-Sleep 3
    if ($port -and (netstat -ano | Select-String -Pattern ":$port\s.*LISTENING")) { $listening = $true }
}
Log ("service: " + (Get-Service $ServiceName).Status + "   listening on ${port}: $listening")
Get-WinEvent -FilterHashtable @{LogName = 'System'; ProviderName = 'Service Control Manager'; StartTime = (Get-Date).AddMinutes(-3) } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'Thor WoW Kit' -and $_.Id -ne 7045 -and $_.Id -ne 7036 } | ForEach-Object { Log ("event $($_.Id): " + ($_.Message -replace '\s+', ' ')) }
Get-NetConnectionProfile | ForEach-Object { Log ("network '$($_.Name)' on $($_.InterfaceAlias): $($_.NetworkCategory)") }
if ($listening) {
    Log "DONE. Start DS Forever Desktop again (not as administrator), then run verify.ps1."
    Log "If a network above says Public, the Thor will get 'The PC isn't answering': set the home network to Private in Windows Settings."
} else {
    Log "NOT LISTENING. Read this log and docs\TROUBLESHOOTING.md; uninstall-sunshine-service.ps1 puts everything back."
}
Log "log: $log"
