# uninstall-sunshine-service.ps1 - RUN AS ADMINISTRATOR. Undoes install-sunshine-service.ps1: DS Forever Desktop runs its
# own Sunshine again (streaming works as before, but not from the lock screen).
#   powershell -ExecutionPolicy Bypass -File uninstall-sunshine-service.ps1 -DesktopDir "<folder with DsForeverDesktop.exe>"
# Afterwards: set-config.ps1 -Name GuardDesktopSunshine -Value false   and   -Name LockOnEnd -Value false
param(
    [Parameter(Mandatory = $true)][string]$DesktopDir,
    [string]$ServiceName = 'ThorWowKitSunshine',
    [string]$ServiceDir = 'C:\Program Files\ThorWowKit\SunshineSvc'
)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { "NOT ELEVATED. Open PowerShell with 'Run as administrator' and run this again."; exit 1 }

Get-Process DsForeverDesktop -ErrorAction SilentlyContinue | Stop-Process -Force
if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
    Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
    sc.exe delete $ServiceName
    Start-Sleep 3
}
netsh advfirewall firewall delete rule name="Thor WoW Kit - DS Forever Sunshine" | Out-Null

$exe = Join-Path $DesktopDir 'sunshine\sunshine.exe'
if (-not (Test-Path $exe) -and (Test-Path "$exe.disabled")) { Move-Item "$exe.disabled" $exe; "restored Desktop's sunshine.exe" }

if (Test-Path $ServiceDir) {
    # remove the junction itself first so nothing follows it into Desktop's data
    $junction = Join-Path $ServiceDir 'config'
    if (Test-Path $junction) { cmd.exe /c rmdir "$junction" }
    Remove-Item $ServiceDir -Recurse -Force -ErrorAction SilentlyContinue
    $parent = Split-Path -Parent $ServiceDir
    if ((Split-Path -Leaf $parent) -eq 'ThorWowKit' -and -not (Get-ChildItem $parent -ErrorAction SilentlyContinue)) { Remove-Item $parent -Force }
}
"Removed. Start DS Forever Desktop again; it runs its own Sunshine now."
