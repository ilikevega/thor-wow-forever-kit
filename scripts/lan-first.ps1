# lan-first.ps1 - ONLY for PCs that run Tailscale. Takes the PC's Tailscale down for a short while so the Thor finds
# DS Forever Desktop at the PC's home-LAN address, then brings it back. Start "Streaming" on the Thor while it counts.
# Why: on Android 13 the DS Forever app takes the first address Desktop advertises; with Tailscale up that can be the
# tunnel address, and the stream then freezes (its video packets do not fit the tunnel). Once the stream is running over
# the LAN, Tailscale can be up again. Keep Tailscale OFF on the Thor itself while playing at home.
param([int]$Seconds = 60)
$ts = (Get-Command tailscale.exe -ErrorAction SilentlyContinue).Source
if (-not $ts) { $ts = 'C:\Program Files\Tailscale\tailscale.exe' }
if (-not (Test-Path $ts)) { "Tailscale is not installed on this PC: nothing to do."; exit 0 }
try {
    & $ts down 2>$null
    "Tailscale is DOWN for $Seconds s. On the Thor: DS Forever > Streaming, now."
    Start-Sleep -Seconds $Seconds
} finally {
    & $ts up 2>$null
    "Tailscale is back up."
}
