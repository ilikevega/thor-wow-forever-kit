# WoW Forever on your Thor, from the couch

You pick up the Thor, tap one thing, and you are in Azeroth. Your PC does the heavy lifting in the other room with its
monitors off. When you put the Thor down, the PC closes the game and locks itself.

This kit gets you there. You do not have to understand any of it. Claude Code does the setup on your PC, and you sit
next to it and click when it asks.

**Set aside about an hour.** Most of it is waiting on downloads, so have a drink nearby.

---

## What it feels like when it's done

| You do this | This happens |
|---|---|
| Open **DS Forever** on the Thor and tap **Streaming** | Your PC wakes the game up. If the PC is locked, you see its lock screen on the Thor. |
| Type your Windows PIN on the Thor | WoW appears on the top screen. Map, bags and chat sit on the bottom screen. |
| Play | Sound comes out of the Thor. The PC's monitors go dark and its speakers stay quiet. |
| Log out and put the Thor down | About half a minute later the PC closes WoW, turns its monitors back on and locks. |

You also get **Artemis**, a second app on the Thor that shows your whole PC. Use it for any other game, or to poke at
your desktop from the sofa.

The full play-by-play, including how to quit cleanly, is in [the couch routine](docs/COUCH-ROUTINE.md). It is one page.

---

## Before you start, have these ready

- [ ] **WoW Forever installed on the PC** through the Battle.net app
- [ ] **Your Battle.net login** (you will type it on the Thor once)
- [ ] **Steam installed on the PC** (the kit borrows a silent speaker from it to keep the PC quiet)
- [ ] **Your Thor**, charged, on your home Wi-Fi, with about **60 GB free**
- [ ] **A USB-C cable** from the Thor to the PC
- [ ] **A Windows PIN or password you can type.** Fingerprint and face unlock do not work through a stream.
- [ ] **Claude Code** on the PC

A Windows 11 PC with an NVIDIA graphics card is what this was built on. AMD and Intel cards might work. Nobody has
tried yet.

---

## Three steps to get going

**1. Open PowerShell and paste this.** It downloads the kit into the place Claude Code looks for skills.

```
git clone https://github.com/ilikevega/thor-wow-forever-kit "$env:USERPROFILE\.claude\skills\thor-wow-kit"
```

**2. Start Claude Code and type:**

```
/thor-wow-kit
```

**3. Follow along.** Claude tells you what it is doing, checks that each piece works before moving on, and stops to ask
whenever it needs your hands.

> If `/thor-wow-kit` does not show up, close Claude Code and open it again. Or just say:
> *"Set up my Thor with the thor-wow-kit skill."*

---

## What Claude will ask you to do

Some things are yours to do, on purpose. Claude will tell you exactly what to click or paste each time.

- **Type every PIN, code and password yourself.** Claude never types them and never sees them.
- **Say yes to the Windows "allow this app to make changes" prompts**, and paste two or three commands into an
  administrator PowerShell. Claude Code is not allowed to do those for you, and that is a good thing.
- **Tap through the prompts on the Thor** and install the two apps on it.
- **Watch your monitors for ten seconds** and say whether they went dark and came back. Not every monitor can do this
  trick. If yours cannot, that one feature gets skipped and everything else still works.

---

## Will this mess up my PC?

No, and nothing is hidden. Here is every change it makes and how to take it back.

| What it adds | How to remove it |
|---|---|
| Two apps: Apollo and DS Forever Desktop | Uninstall them like any other app |
| A tiny background helper that starts with Windows. It is the thing that closes WoW and locks the PC when you stop. | `scripts\enable-autostart.ps1 -Remove` |
| A small settings file in `%LOCALAPPDATA%\ThorWowKit` | Delete the folder |
| A Windows service, so your Thor can show the lock screen and let you sign in. It comes with a firewall rule for your home network only. | `scripts\uninstall-sunshine-service.ps1` |
| A two-line WoW add-on that hides one nagging popup | `scripts\install-addon.ps1 -Remove` |

The Windows service is the only big one. Claude will read you what it does before you run it, and you can say no.
Without it everything still works, except that the PC has to be unlocked before you start playing.

---

## It was working and now it isn't

This will happen at some point. DS Forever updates itself often, and an update is nearly always the cause.

**Easiest:** open Claude Code and say *"verify my Thor setup."*

**Or run the checker yourself:**

```
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\thor-wow-kit\scripts\verify.ps1"
```

It prints PASS, FAIL or SKIP for each piece, and next to every FAIL it says what to do.

Still stuck? The [troubleshooting page](docs/TROUBLESHOOTING.md) lists every problem we hit building this, with the fix.

**Want me to look at it?** Run `scripts\collect-logs.ps1`. It puts a zip on your Desktop with your name, your PC's
name, your passwords and your keys left out. Have a look inside, then send it over.

To get the latest fixes, run `git pull` inside the kit folder.

---

## Fair warning

You are early. This was built from one working setup and has not yet been run start to finish on a second PC, so you
may be the first. If something goes sideways, it is the kit and not you. Send the zip and it gets fixed for the next
person.

It was made with DS Forever 1.0.16, DS Forever Desktop 0.2.13 to 0.2.21 and Apollo 0.4.6. Those projects move fast.
Where their own instructions disagree with this kit, theirs win, and Claude knows to check.

---

## Credit where it's due

The real work is other people's. This kit only ties their projects together.

- [DS Forever](https://github.com/Jreese702/DS-Forever), the two-screen WoW Forever companion and its PC app
- [Apollo](https://github.com/ClassicOldSong/Apollo), the streaming host on the PC
- [Artemis](https://github.com/ClassicOldSong/moonlight-android), the streaming app on the Thor

The kit contains none of their code and downloads nothing by itself. It points you at each project's own releases.
It is an unofficial hobby project with no connection to them, to Valve or to Blizzard.

License: MIT, see [LICENSE](LICENSE).
