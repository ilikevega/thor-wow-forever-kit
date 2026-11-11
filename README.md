# Thor WoW Forever kit

A Claude Code skill that sets up an AYN Thor and a Windows gaming PC for playing WoW Forever from the couch, the way
Moonlight feels: the PC stays locked with its monitors off, you start from the Thor, and when you stop, the PC closes
the game and locks itself again.

You sit with it for about an hour. Claude Code drives; you click the things only you should click.

## What you end up with

- **WoW Forever on the Thor's top screen, the companion on the bottom screen**, through
  [DS Forever](https://github.com/Jreese702/DS-Forever), streamed from your PC.
- **The whole PC desktop or any other game on the Thor**, through
  [Apollo](https://github.com/ClassicOldSong/Apollo) on the PC and
  [Artemis](https://github.com/ClassicOldSong/moonlight-android) on the Thor.
- **A routine around a WoW session**, each part optional:
  - the PC's sound plays only on the Thor
  - the PC's monitors go dark while you play
  - WoW closes on the PC when you leave the stream
  - the PC can be locked the whole time: you sign in from the Thor, and it locks again when you stop

How a session goes, start to finish: [docs/COUCH-ROUTINE.md](docs/COUCH-ROUTINE.md).

## What you need

- A Windows 11 PC with an NVIDIA card (AMD and Intel may work; nobody has tried them with this kit)
- WoW Forever installed through the Battle.net app, and your Battle.net login
- Steam installed (it supplies the silent audio device used to mute the PC)
- An AYN Thor on the same home network, about 60 GB free on it, and a USB-C cable
- Claude Code on the PC
- A Windows PIN or password you can type on the Thor

## Install and run

In PowerShell:

```
git clone https://github.com/ilikevega/thor-wow-forever-kit "$env:USERPROFILE\.claude\skills\thor-wow-kit"
```

Then start Claude Code and type:

```
/thor-wow-kit
```

If the command is not offered, restart Claude Code once, or say "set up my Thor with the thor-wow-kit skill".

## What it will ask you to do yourself

- Type every PIN, pairing code and password. Claude never types or sees them.
- Approve Windows administrator prompts, and paste two or three commands into an administrator PowerShell
  (a Windows service, a firewall rule). Claude Code is not allowed to do those for you, and should not be.
- Install the apps on the Thor and accept its prompts.
- Watch your monitors during a ten-second test and say what they did.

## What it changes on the PC

Nothing is hidden, and the larger steps can be undone.

| Change | Undo |
|---|---|
| Installs Apollo and DS Forever Desktop | Uninstall them normally |
| A small background watcher that starts with Windows | `scripts\enable-autostart.ps1 -Remove` |
| Settings in `%LOCALAPPDATA%\ThorWowKit\config.json` | Delete the folder |
| A Windows service that runs DS Forever's own Sunshine, so the lock screen can be streamed; a firewall rule for it on Private networks | `scripts\uninstall-sunshine-service.ps1` |
| A two-line WoW add-on that hides one recurring dialog | `scripts\install-addon.ps1 -Remove` |

The service step is the one to understand before you agree to it. The comment at the top of
`scripts\install-sunshine-service.ps1` says exactly what it does, and the troubleshooting page has a short note on what
it means for a shared PC.

## When something stops working

```
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\thor-wow-kit\scripts\verify.ps1"
```

It prints PASS, FAIL or SKIP for each part and what to do about a FAIL. A DS Forever Desktop update is the usual cause.
Then [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md), or ask Claude Code to "verify my Thor setup".

To get help from whoever gave you this kit, run `scripts\collect-logs.ps1`, look through the zip it puts on your
Desktop, and send it.

Update the kit with `git pull` in its folder.

## Status

This was built from one working setup and has not yet been run start to finish on a second PC. If you are reading this
early, you are the test. The monitor, audio and service parts depend on your hardware, which is why each can be left off. Versions it was made with: DS Forever 1.0.16, DS Forever Desktop 0.2.13 to
0.2.21, Apollo 0.4.6. Those projects move fast, and their own instructions win where they disagree with this kit.

This kit contains none of their code. It downloads nothing by itself; it points you at each project's own releases.
DS Forever, Apollo, Artemis, Sunshine, Steam and World of Warcraft belong to their owners. This is an unofficial hobby
project with no connection to any of them.

License: MIT, see [LICENSE](LICENSE).
