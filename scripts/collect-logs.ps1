# collect-logs.ps1 - bundle what is needed to debug this setup into one zip on the Desktop, to send to whoever maintains
# the kit. It leaves out DS Forever's settings.json, devices.json, certificates and keys, and it masks the Windows user
# name, the PC name, public IP addresses and long hex strings. LAN addresses (192.168.x, 10.x) stay: they are needed.
# Still: open the zip and look before sending it.
. "$PSScriptRoot\kit-common.ps1"
$cfg = Get-KitConfig
$work = Join-Path $env:TEMP ("thor-wow-kit-report-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $work | Out-Null

function Mask([string]$text) {
    $t = $text
    $t = $t -replace [regex]::Escape($env:USERNAME), '<user>'
    $t = $t -replace [regex]::Escape($env:COMPUTERNAME), '<pc>'
    $t = [regex]::Replace($t, '\b(?!(?:10|127)\.|192\.168\.|172\.(?:1[6-9]|2\d|3[01])\.|169\.254\.)(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\b', '<ip>')
    $t = [regex]::Replace($t, '\b[0-9a-fA-F]{24,}\b', '<hex>')
    return $t
}
function Add-Tail([string]$path, [string]$name, [int]$lines) {
    if (Test-Path $path) { Mask ((Get-Content $path -Tail $lines -ErrorAction SilentlyContinue) -join "`r`n") | Out-File (Join-Path $work $name) -Encoding utf8 }
}

Mask ((& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'preflight.ps1') | Out-String)) | Out-File (Join-Path $work 'preflight.txt') -Encoding utf8
Mask ((& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify.ps1') | Out-String)) | Out-File (Join-Path $work 'verify.txt') -Encoding utf8
Mask ((& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'audio-default.ps1') -ListAll | Out-String)) | Out-File (Join-Path $work 'audio-devices.txt') -Encoding utf8
Add-Tail $KitConfigPath 'config.json' 200
Add-Tail $KitLogPath 'kit.log' 400
Add-Tail (Join-Path $KitDir 'session-watch.log') 'session-watch.log' 400
Add-Tail (Join-Path $cfg.DataDir 'desktop.log') 'desktop.log' 600
Add-Tail (Join-Path $cfg.DataDir 'sunshine\sunshine.log') 'sunshine.log' 400
Add-Tail (Join-Path $cfg.DataDir 'sunshine\sunshine.conf') 'sunshine.conf' 100
Add-Tail (Join-Path $cfg.DataDir 'thor-wow-kit-service-install.log') 'service-install.log' 200
Add-Tail (Join-Path $cfg.ServiceDir 'temp\sunshine.log') 'service-wrapper-sunshine.log' 200
$kitRoot = Split-Path -Parent $PSScriptRoot
if (Test-Path (Join-Path $kitRoot '.git')) { (git -C $kitRoot log --oneline -1 2>$null) | Out-File (Join-Path $work 'kit-version.txt') -Encoding utf8 }

$zip = Join-Path ([Environment]::GetFolderPath('Desktop')) ((Split-Path -Leaf $work) + '.zip')
Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip -Force
Remove-Item $work -Recurse -Force
"Report: $zip"
"Open it and look through the files before sending."
