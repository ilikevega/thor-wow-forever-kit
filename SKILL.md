---
name: thor-wow-kit
description: Set up an AYN Thor and a Windows gaming PC for couch play. Apollo + Artemis for general PC streaming, DS Forever for WoW Forever with the bottom-screen companion, and a Moonlight-style routine around it (PC sound only on the Thor, monitors dark, WoW closes when the Thor leaves, PC starts and ends locked). Use when the user says "set up my Thor", "thor wow kit", or asks to fix or verify this setup.
---

# Thor WoW Forever kit

You are setting up someone's own PC and their own AYN Thor, with them sitting next to you. You drive, they click.
Expect about an hour, most of it waiting on downloads and one large file copy.

The finished routine looks like this:

1. The PC sits locked with its monitors off.
2. On the Thor: open DS Forever, choose Streaming. The top screen shows the Windows lock screen. They sign in with their PIN.
3. WoW Forever is already starting on the PC. They play. The PC's monitors go dark, the sound comes out of the Thor.
4. They leave the stream on the Thor. Within about half a minute WoW closes, monitors and sound come back, and the PC locks.

Apollo + Artemis is the second, independent path: the whole desktop or any other game on the Thor.

## How to run this session

- **Work in phases, in order.** Each phase ends with a check. Do not start the next phase on a failed check.
- **The base comes first.** Phases 1 to 3 give a working stream. Phases 4 to 8 are the routine; each part is optional and
  has its own switch. If one part cannot work on this PC (a monitor without DDC, no silent audio device), leave its
  switch off, say so plainly, and carry on. A working stream with three of five extras is a good result.
- **Scripts are in `scripts\` next to this file.** Run them with their full path:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<this folder>\scripts\<name>.ps1"`.
  State is in `%LOCALAPPDATA%\ThorWowKit\` (`config.json`, `kit.log`, `session-watch.log`).
- **Things only the owner does.** Say exactly what to click or paste, then wait for "done":
  - anything with a UAC prompt, and every command marked OWNER below (services, firewall, Startup entry)
  - PINs, pairing codes, the Battle.net login, the Windows sign-in, any password: never type, read back or store these
  - installing apps on the Thor from a store, and accepting prompts on the Thor
  - switching the home network to Private in Windows Settings
- **If your permission system refuses a step** (creating a service, a firewall rule, a Startup entry, launching an
  installer), do not look for another way to do the same thing. That step is the owner's: give them the one command,
  ready to paste, and continue with whatever does not depend on it.
- **Upstream is the authority on installing the apps.** DS Forever, Apollo and Artemis change quickly. Read each
  project's current README and release notes before installing, and prefer what they say over this file where the two
  disagree. This kit was made with DS Forever 1.0.16 (Thor) and DS Forever Desktop 0.2.13 to 0.2.21, Apollo 0.4.6,
  on Windows 11 with an NVIDIA card. Tell the owner when you meet a difference.
- **Check after every change, with evidence** (a log line, a listening port, what the owner sees on the Thor). Do not
  report a part as working because the command returned without an error.
- **When stuck**, read `docs\TROUBLESHOOTING.md` first: most of what went wrong on the first install is in there.
  If it is not, run `collect-logs.ps1` and tell the owner to send the zip to whoever gave them this kit.

## Phase 0: what the owner needs ready

Ask once, up front:

- WoW Forever installed on the PC through the Battle.net app, and their Battle.net login to hand
- Steam installed (it provides the silent audio device)
- the Thor charged, on the same home Wi-Fi as the PC (5 GHz or better; PC on Ethernet if possible), with about 60 GB free
- a USB-C cable from the Thor to the PC
- a Windows PIN or password they can type (fingerprint and face sign-in do not work through a stream)

## Phase 1: preflight

Run `preflight.ps1` and read every line with the owner.

- `[!!]` lines must be fixed before the part they belong to. A PUBLIC home network is the common one: the owner sets it
  to Private (Settings > Network & internet > Ethernet or Wi-Fi > Network profile type). Only do this for their own
  home network.
- No NVIDIA card: Sunshine also supports AMD and Intel encoders, but this kit has not been tried on them. Say so and continue.
- Tailscale present: read the Tailscale section of the troubleshooting doc now; it changes Phase 3.

## Phase 2: Apollo on the PC, Artemis on the Thor

Apollo is a Sunshine fork (github.com/ClassicOldSong/Apollo). Artemis is its Android client
(github.com/ClassicOldSong/moonlight-android, also on the Play Store as "Artemis").

1. If LizardByte Sunshine or NVIDIA GameStream is already installed, they use the same ports. Agree with the owner which
   one stays before installing Apollo.
2. OWNER installs Apollo: `winget install ClassicOldSong.Apollo` (or the installer from the project's Releases page).
3. OWNER opens `https://localhost:47990`, accepts the self-signed certificate warning, and creates the web UI login.
   They keep that login themselves.
4. OWNER installs Artemis on the Thor, opens it, taps the PC, and enters the PIN it shows into Apollo's web UI (PIN page).
5. In Apollo's web UI, Audio/Video settings: set the virtual sink to **Steam Streaming Speakers** so the PC stays silent
   during an Artemis stream. Leave the display settings at their defaults for now.
6. Check: the owner starts "Desktop" in Artemis, sees the PC desktop on the Thor with sound on the Thor, and ends it
   with Artemis' **quit** (not just closing the app). `netstat -ano | findstr 4798` shows Apollo listening on
   47984, 47989 and 47990.

Tell the owner the difference between disconnecting and quitting (see the couch routine doc). It matters when Apollo
is set to change the display layout for a stream.

## Phase 3: DS Forever (WoW Forever with the bottom-screen companion)

Project: github.com/Jreese702/DS-Forever. Read its README and latest release notes first.

1. **Thor app.** Get the current APK from the project's Releases page and install it on the Thor (with adb over USB:
   `adb install <apk>`; or the owner downloads and opens it on the Thor). Developer options > USB debugging must be on
   for adb; the owner accepts the prompt on the Thor.
2. **DS Forever Desktop.** Unpack the current Desktop release to a folder that will stay put, for example
   `C:\DSForeverDesktop`. OWNER starts `DsForeverDesktop.exe` (allow it through the firewall on Private networks when
   Windows asks). Then run `discover.ps1`: it must print the Desktop folder and the WoW Forever folder.
3. **Game data on the Thor.** DS Forever needs the game files on the Thor even in Streaming mode (it builds its map
   art from them). Its own "install directly" download was very slow when this kit was written (hours). If it is
   still slow, copy the files from the PC instead, over USB:
   - `adb push "<WowRoot>\Data" "/storage/emulated/0/WoW Forever/"` and push `<WowRoot>\.build.info` to the same folder.
     This is tens of GB; expect 20 to 30 minutes over USB 3.
   - If the app left a `.ds-streamed` marker file in that folder, rename it (`.ds-streamed.off`) so it uses the local
     files, then relaunch the app. A first "Game art: failed" usually passes on "Try again".
   Check what the current README says about this before copying: the app may have changed.
4. **Pairing.** In the Thor app choose Streaming. Desktop shows a code on the PC; the OWNER types it on the Thor.
   Then the Battle.net login, typed by the OWNER on the Thor (bottom-screen Keyboard button).
5. **Tailscale.** If the PC runs Tailscale, the Thor must find the PC by its LAN address: turn Tailscale OFF on the Thor,
   and run `lan-first.ps1` on the PC while the owner taps Streaming. See the troubleshooting doc.
6. Check, with the PC unlocked: the owner picks Streaming, WoW starts on the PC, the game appears on the Thor's top screen
   and the companion on the bottom, picture is smooth. `desktop.log` in the Desktop data folder shows
   `bridge: <device> connected from <a LAN address>`.

In the Thor app's settings, set **Controller > Pause menu: open = Hold**. A tap of Start then reaches WoW's own Game
Menu, which is how a session is ended from the couch (see the couch routine doc).

Stop here and let the owner play for a few minutes. Everything after this is the routine on top of a working stream.

## Phase 4: PC sound only on the Thor

1. Run `discover.ps1` again. It finds Steam's silent playback device, "Steam Streaming Speakers", enables it if it was
   disabled, and saves its id. If it is missing: Steam > Settings > Remote Play > turn Remote Play on, then run it again.
2. Prove it by hand, with the owner listening and something playing on the PC:
   `audio-default.ps1 -Get` (note the id), then `audio-default.ps1 -Set "<SilentAudioId from config>"` (PC goes
   quiet), then `audio-default.ps1 -Set "<the id noted first>"` (sound is back).
3. If no silent device can be had, `set-config.ps1 -Name MuteDuringSession -Value false` and tell the owner the PC
   speakers will play during a session.

## Phase 5: the session watcher

1. `enable-autostart.ps1 -StartNow` writes a small Startup entry and starts the watcher hidden. If you are refused,
   it is an OWNER command.
2. Check: the owner starts a stream on the Thor. `%LOCALAPPDATA%\ThorWowKit\session-watch.log` says `session start`,
   the PC goes quiet. The owner leaves the stream (bottom screen Menu > Exit game, or just back out of the app). After
   the grace period the log says `session end`, `sound restored`, `closing WoW`, `WoW closed`.

WoW closing when the Thor leaves is `CloseWowOnLeave`. Without the watcher, Desktop closes WoW only after about five
minutes without a stream and without input at the PC.

## Phase 6: monitors dark during a session

This part depends on the monitors. It is skipped more often than any other.

1. `monitor-power.ps1 -Query`. Monitors that print `readable=True` answer DDC/CI. For one that does not, the owner can
   enable DDC/CI in the monitor's own on-screen menu and you query again.
2. Warn the owner first, then run `monitor-power.ps1 -Test`: every monitor should go dark for 8 seconds and come back
   by itself. Ask the owner what each monitor did.
3. Enable it only if **every** monitor went dark and came back on its own:
   `set-config.ps1 -Name MonitorsOff -Value true`. A monitor that stayed dark needs its power button, and then this
   part stays off on this PC. A monitor that ignored the command just stays lit; the owner decides if that is acceptable.
4. Check in a real session: about 25 seconds after the stream starts the monitors go dark and stay dark while playing,
   the picture on the Thor is unaffected, and they come back when the session ends.

If a session ever ends with the monitors still dark: `monitor-power.ps1 -On`, or the monitor's power button.

## Phase 7: start locked, end locked (the Sunshine service)

DS Forever Desktop runs its bundled Sunshine as the signed-in user, and a user process cannot show the lock screen.
Apollo can, because it runs as a Windows service. `install-sunshine-service.ps1` makes DS Forever's Sunshine a service
too. Read the comment block at the top of that script to the owner before they run it, so they know what it changes.
`uninstall-sunshine-service.ps1` undoes all of it.

Only do this after Phase 3 has worked. New pairings need Desktop's own Sunshine, which this disables.

1. OWNER, in PowerShell opened with "Run as administrator" (fill in the two folders from `set-config.ps1`):
   `powershell -ExecutionPolicy Bypass -File "<kit>\scripts\install-sunshine-service.ps1" -DesktopDir "<DesktopDir>" -DataDir "<DataDir>"`
   It prints `DONE` when the service's Sunshine listens on the stream port (this takes up to a minute).
2. OWNER starts DS Forever Desktop again, normally, not as administrator. Its log now says "sunshine not bundled".
   That is expected.
3. `set-config.ps1 -Name GuardDesktopSunshine -Value true`. DS Forever Desktop updates itself and puts its own
   Sunshine back; the watcher's guard disables it again and restarts the service. Then restart the watcher:
   `enable-autostart.ps1 -Remove`, then `enable-autostart.ps1 -StartNow`.
4. Check, PC unlocked: a stream still starts with no new pairing. `verify.ps1` passes the service lines.
5. Check, PC locked (the owner presses Win+L): the owner starts Streaming on the Thor, sees the Windows lock screen
   on the top screen, taps it, and signs in with the bottom-screen Keyboard button. The game appears.
6. Only when step 5 worked: `set-config.ps1 -Name LockOnEnd -Value true`.

If step 5 fails, leave `LockOnEnd` off (a PC that locks itself but cannot be unlocked from the couch is worse than
before) and read the service section of the troubleshooting doc.

## Phase 8: small things that make it pleasant

- `install-addon.ps1` adds a two-line WoW add-on that removes the recurring "... has been blocked from an action only
  available to the Blizzard UI" dialog that the companion add-on trips. Explain it to the owner; it is optional.
- Game text is small on the Thor's screen. A lower PC resolution does not help. WoW Options > UI Scale, and the Thor
  app's Settings > Top screen (moves minimap, chat and trackers to the bottom screen) do.
- While a session runs, the PC's mouse pointer jumps to the top edge about once a second. That is how the companion
  drives the game through the stream. It is not a fault, and the PC should not be used during a session.

## Phase 9: the full run, and handing over

1. Run `verify.ps1`. Every enabled part should say PASS.
2. One complete session by the owner, hands off the PC, exactly as in `docs\COUCH-ROUTINE.md`: lock the PC, start from
   the Thor, sign in, play two minutes, leave, and watch the PC close WoW and lock.
3. Tell the owner, in a short list: which parts are on, which were skipped and why, how to end a session, the one
   command that undoes the service, and that `verify.ps1` is the first thing to run when something stops working
   (a DS Forever Desktop update is the usual cause).

## Later: "it stopped working"

Run `verify.ps1`, then follow its FAIL lines from the top. Then `docs\TROUBLESHOOTING.md`. To get help, run
`collect-logs.ps1`; it makes a zip on the Desktop with names, public addresses and keys left out, which the owner
should look through and send to whoever maintains the kit.
