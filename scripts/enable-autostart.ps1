# enable-autostart.ps1 - make the session watcher start hidden with Windows (a small .vbs in the user's Startup folder;
# no registry, no scheduled task, no admin).   -StartNow also starts it right away.   -Remove takes the entry out.
# Claude Code's auto mode may refuse to create Startup entries. That is expected: the owner then runs this line himself.
# Run it again if the kit folder is ever moved (the entry holds the full path).
param([switch]$StartNow, [switch]$Remove)
$startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'Thor WoW Kit session watcher.vbs'
$watch = Join-Path $PSScriptRoot 'session-watch.ps1'
if ($Remove) {
    Remove-Item $startup -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'session-watch\.ps1' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    "Startup entry removed and watcher stopped."; exit 0
}
$q = '"'
$vbs = 'CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ' + $q + $q + $watch + $q + $q + '", 0, False'
$vbs | Out-File $startup -Encoding ascii
"Startup entry written: $startup"
if ($StartNow) {
    Start-Process wscript.exe -ArgumentList "`"$startup`""
    Start-Sleep 4
    $w = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'session-watch\.ps1' }
    if ($w) { "Watcher is running (pid $(@($w)[0].ProcessId)). Log: $env:LOCALAPPDATA\ThorWowKit\session-watch.log" } else { "Watcher did not start; run session-watch.ps1 in a console to see why." }
}
