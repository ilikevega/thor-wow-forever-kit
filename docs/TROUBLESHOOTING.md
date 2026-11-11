# Troubleshooting

Everything here was hit on the first install of this setup (Windows 11, NVIDIA, DS Forever 1.0.16, DS Forever
Desktop 0.2.13 to 0.2.21, Apollo 0.4.6). Start with `scripts\verify.ps1`; its FAIL lines point at most of these.

Where the logs are:

| What | Where |
|---|---|
| The kit's watcher | `%LOCALAPPDATA%\ThorWowKit\session-watch.log` |
| The kit's actions | `%LOCALAPPDATA%\ThorWowKit\kit.log` |
| DS Forever Desktop | `%LOCALAPPDATA%\DSForeverDesktop\desktop.log` |
| DS Forever's Sunshine | `%LOCALAPPDATA%\DSForeverDesktop\sunshine\sunshine.log` |
| Service install | `%LOCALAPPDATA%\DSForeverDesktop\thor-wow-kit-service-install.log` |
| Thor app | `adb logcat` (look for `DSFSTREAM`) |

## The Thor says "The PC isn't answering"

The message names a port. Nothing is reachable on it from the Thor.

- **The home network is Public in Windows.** The firewall rules for Desktop and for the service's Sunshine cover
  Private networks. Fix: Settings > Network & internet > Ethernet (or Wi-Fi) > Network profile type > Private.
  `preflight.ps1` shows the profile.
- **No Sunshine is listening.** `netstat -ano | findstr LISTENING | findstr <port>`. With the service installed:
  `Get-Service ThorWowKitSunshine`. Sunshine needs up to a minute after a start before it listens.
- **Desktop is not running.** The Thor finds the PC through Desktop. Start it.
- **Thor and PC are on different networks** (guest Wi-Fi, a VPN on the Thor).

## Picture freezes, stutters, or the stream never settles

- **Tailscale.** See the next section. This was the cause every time on the first install.
- Weak Wi-Fi: 5 GHz or better for the Thor, Ethernet for the PC.
- Health check while streaming: `adb logcat -d -t 3000 | findstr /c:"Unrecoverable"`. It should print nothing.

## Tailscale (only if the PC or the Thor runs it)

On Android 13 the DS Forever app uses the first address Desktop advertises. With Tailscale up on the PC that can be the
PC's tunnel address. The stream's video packets do not fit the tunnel, so nearly every frame is lost: frozen picture,
jumping mouse.

- Keep Tailscale **off on the Thor** while playing at home.
- Start a session with the PC's Tailscale briefly down: run `scripts\lan-first.ps1` and tap Streaming on the Thor while
  it counts. Once the stream runs over the LAN, Tailscale can be up again.
- Proof that it is right: `desktop.log` says `connected from 192.168...` (or 10.x), and the Thor's logcat has a
  `DSFSTREAM: route:` line with the PC's LAN address.
- The opposite case exists too: at pairing time Desktop may advertise only the tunnel address, and the pairing then
  times out unless the Thor's Tailscale is on. If pairing says the code "didn't arrive in time", check which address
  Desktop's log advertises.
- Artemis and Apollo are not affected. They work over Tailscale, which is the way to play away from home.

## The Sunshine service

**It will not start: "The process cannot access the file because it is being used by another process."**
The service wrapper keeps `<TEMP>\sunshine.log` open, and for a service that is `C:\Windows\Temp\sunshine.log`. Apollo
and LizardByte Sunshine use the same wrapper and the same file, so the second service cannot open it. The installer
gives this service its own TEMP folder through the per-service `Environment` registry value. If you see this error,
that value is missing: re-run the installer.

**After a DS Forever Desktop update, the lock screen no longer streams.**
Desktop updates itself and restores its own `sunshine\sunshine.exe`. Desktop then runs that copy as the user, on a new
port if the service holds the old one, and the Thor streams from it. With `GuardDesktopSunshine` on, the watcher renames
the file again and restarts the service within a few seconds of Desktop starting. `verify.ps1` shows the state. If the
update changed Sunshine itself, verify says the service's copy differs: the owner re-runs
`install-sunshine-service.ps1`. This guard is the least-tested part of the kit; report what `session-watch.log` says
if it misbehaves.

**Pairing a new device, or pairing again.**
Stream pairing goes through Desktop's own Sunshine. Run `uninstall-sunshine-service.ps1`, pair, stream once, then
install the service again.

**Desktop shows the stream state as "unknown", or logs "sunshine not bundled".** Expected with the service.

**Is a service running as LocalSystem a risk?** It is the same arrangement Apollo and Sunshine use by default.
Two things are specific to this kit and worth knowing: the service reads its configuration from Desktop's data folder
in the user profile, and signed-in users may start and stop this one service. Neither gives a second account on the PC
anything it could not already do to the first account's streaming setup, but on a shared PC think about it first.

**Going back.** `uninstall-sunshine-service.ps1` (as administrator), then
`set-config.ps1 -Name GuardDesktopSunshine -Value false` and `-Name LockOnEnd -Value false`.

## The PC did not lock, or WoW stayed open, after a session

The watcher was not running. `verify.ps1` shows it. `enable-autostart.ps1 -StartNow` starts it and makes it start with
Windows. If the kit folder was moved, run that again: the Startup entry holds the full path.

## The PC stayed silent after a session

A session that never ended properly (reboot, crash) can leave the default playback device on the silent one. The
watcher restores it at its next start. By hand: Windows sound settings, pick your normal output.

## Monitors

- **Stayed dark after a session:** `scripts\monitor-power.ps1 -On`, or the monitor's power button. Then turn the part
  off: `set-config.ps1 -Name MonitorsOff -Value false`.
- **Never went dark:** the monitor ignores the DDC power command, or DDC/CI is off in its menu.
  `monitor-power.ps1 -Query` shows which monitors answer. Monitors differ a lot here. One on the first install honoured
  only value 5, another only 4, which is why the script tries both.
- **Went dark, then came back during play:** the watcher re-checks every 20 seconds and switches them off again. If it
  keeps happening, the monitor wakes on signal changes; leave the part off.
- Laptop panels and TVs usually do not support this at all.

## The stream shows the wrong monitor

Desktop's Sunshine picks its capture display. With two monitors it can pick the one WoW is not on, especially after a
display-mode change. The setting is `CaptureDevice` in `%LOCALAPPDATA%\DSForeverDesktop\settings.json`; the display ids
are listed at the top of `sunshine.log`. Check Desktop's own settings window first: newer versions may offer this there.

## Desktop resolution or monitor layout stuck after an Artemis stream

Apollo can be set to change the display layout for a stream and revert it when the app is **quit**. A stream that was
only disconnected stays paused, and the PC keeps the stream's layout. Quit the app from Artemis. If the layout is
already stuck: quit from Artemis, or restore it in Windows display settings.

## Apollo restarts every few seconds; Artemis shows the PC with a spinner

Seen on Apollo 0.4.6 after changing the web UI password or language: `sunshine_state.json` gets booleans saved as text
and Apollo crashes on start (ClassicOldSong/Apollo issue 835). Update Apollo if a newer release has the fix. Otherwise
delete `sunshine_state.json` in Apollo's config folder and pair the clients again. A second cause seen once: the
`credentials` folder in Apollo's config folder had lost SYSTEM's access rights.

## Sign-in shows a captcha, then "disconnected" (BLZ51914400)

This is Blizzard's sign-in protection, not a fault in your setup. It has been reported on DS Forever 1.0.15, 1.0.17 and
1.0.24, and by PC players who start WoW from its exe instead of the Battle.net app. A captcha that is solved and still
ends in "disconnected" will not clear by trying again.

**Stop retrying.** Every failed attempt keeps the protection up. Leave it alone for at least 15 minutes.

Then work down this list, one sign-in attempt per step:

1. **Check the account from the PC.** Open the Battle.net app, press Play on WoW Forever and get to the character
   screen. If that fails too, the problem is the account or Blizzard's servers, and nothing on the Thor will help.
2. **Check the region.** In DS Forever's start-up **Menu > Region**, pick the region your account plays in (US, EU,
   Korea, Taiwan). The Battle.net app has the same choice on its sign-in screen. One player had this exact captcha
   loop with the app on Americas and the account on Europe, and it ended when the two matched.
3. **Forget the login and enter it fresh.** In DS Forever's Menu choose to forget the login, close the app, open it
   and type the login again. Editing the saved login is not the same. This cleared it for the player in DS Forever
   issue 21, who then got the normal authenticator prompt.
4. **Turn off any VPN** on the Thor and the PC for the sign-in, Tailscale exit nodes included.
5. **Have the authenticator ready.** If the account uses the Battle.net Authenticator, approve the prompt on the phone
   straight away.

**Play tonight anyway.** Artemis does not use the saved login. Open Artemis on the Thor, pick the PC, start WoW Forever
from the Battle.net app on the stream and play on the top screen. You lose the bottom-screen companion until the
DS Forever sign-in works again.

If none of it helps, send a report from DS Forever's Menu and wait for the next release.

## DS Forever on the Thor

- **The game download crawls.** Copy the game data from the PC over USB instead (Phase 3 of SKILL.md).
- **"Game art: failed" the first time.** Try again; the first run was still preparing.
- **No keyboard for the login.** Use the Keyboard button on the bottom screen. On older versions of the app the login
  field got no Android keyboard at all; update the app.
- **On the pairing screen, more than one PC is listed.** The entry marked "Sunshine only" is Apollo. Pick the other.
- **The D-pad does nothing in WoW's Game Menu.** The app keeps D-pad presses for itself. Touch the menu on the top screen.

## Sending a report

`scripts\collect-logs.ps1` puts the logs above into one zip on the Desktop. It leaves out DS Forever's settings,
device list, certificates and keys, and masks the Windows user name, the PC name and public IP addresses. Look through
it before sending it.
