# install-addon.ps1 - copy the tiny NoAddonBlockedPopup add-on into WoW Forever.
# DS Forever's companion add-on keeps tripping WoW's "... has been blocked from an action only available to the Blizzard UI"
# dialog (Disable / Ignore). This add-on removes the dialog only; the blocked actions stay blocked.
# Takes effect at the next WoW start.   -Remove takes it out again.
param([string]$WowRoot, [switch]$Remove)
. "$PSScriptRoot\kit-common.ps1"
if (-not $WowRoot) { $WowRoot = (Get-KitConfig).WowRoot }
$addons = Join-Path $WowRoot '_forever_\Interface\AddOns'
if (-not $WowRoot -or -not (Test-Path $addons)) { "No AddOns folder at '$addons'. Run discover.ps1, or pass -WowRoot (the folder that contains _forever_)."; exit 1 }
$dst = Join-Path $addons 'NoAddonBlockedPopup'
if ($Remove) { Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue; "removed $dst"; exit 0 }

$src = Join-Path (Split-Path -Parent $PSScriptRoot) 'addon\NoAddonBlockedPopup'
try {
    New-Item -ItemType Directory -Force $dst -ErrorAction Stop | Out-Null
    Copy-Item (Join-Path $src '*') $dst -Force -ErrorAction Stop
} catch { "Could not write to $dst ($($_.Exception.Message)). The owner can copy the folder '$src' there by hand."; exit 1 }

# WoW ignores add-ons whose "## Interface:" number is older than the client. Take the number from an add-on that is
# already there and loads (DS Forever's own, else any other).
$toc = Join-Path $dst 'NoAddonBlockedPopup.toc'
$donor = Get-ChildItem $addons -Filter '*.toc' -Recurse -Depth 1 -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notlike "$dst*" } | Sort-Object { $_.Name -notmatch 'WowCompanion' }, LastWriteTime -Descending | Select-Object -First 1
if ($donor) {
    $line = Get-Content $donor.FullName | Where-Object { $_ -match '^##\s*Interface:\s*(\d+)' } | Select-Object -First 1
    if ($line -match '(\d+)') {
        $n = $Matches[1]
        (Get-Content $toc) -replace '^##\s*Interface:.*$', "## Interface: $n" | Set-Content $toc -Encoding ascii
        "Interface number $n taken from $($donor.Name)"
    }
}
Write-KitLog "add-on installed: $dst"
"Restart WoW for it to load."
