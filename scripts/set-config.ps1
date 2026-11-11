# set-config.ps1 - change one switch in %LOCALAPPDATA%\ThorWowKit\config.json, or show them all.
#   set-config.ps1                              show the config
#   set-config.ps1 -Name MonitorsOff -Value true
# true/false and whole numbers are stored as such; everything else as text. The watcher re-reads at each session start.
param([string]$Name, [string]$Value)
. "$PSScriptRoot\kit-common.ps1"
$cfg = Get-KitConfig
if ($Name) {
    if (-not $cfg.Contains($Name)) { "Unknown setting '$Name'. Known: $($cfg.Keys -join ', ')"; exit 1 }
    if ($Value -match '^(true|false)$') { $cfg[$Name] = ($Value -eq 'true') }
    elseif ($Value -match '^\d+$') { $cfg[$Name] = [int]$Value }
    else { $cfg[$Name] = $Value }
    Save-KitConfig $cfg
    Write-KitLog "config: $Name = $Value"
}
$cfg.GetEnumerator() | ForEach-Object { "{0,-22} {1}" -f $_.Key, $_.Value }
