# DoomToon

Doom on your Toon 2. An app for a rooted Toon 2 running the original software
with the ToonSoftwareCollective `tsc` helper: press **START DOOM** and the Toon
restarts into DoomToon, a small system of its own that runs
[Chocolate Doom](https://www.chocolate-doom.org/) with the shareware episode
of DOOM (1993). When you quit, the Toon restarts and is back in its own
software, just as you left it.

## What you get

- Doom full screen on the Toon's 1024x600 panel, in its original 4:3 shape
  or stretched (a button on the first screen).
- The sound effects of the PC-speaker version on the Toon's own beeper.
- Play with a **Bluetooth game pad** (PlayStation, Xbox, 8BitDo, Nintendo
  Switch Pro...): the first screen pairs it, and it is remembered, so the
  next time one button press on it is enough. A pad on a **USB cable** in the
  Toon's USB port works too. A pad that drops out during the game is picked
  up again when it comes back.
- Doom's settings and saved games are kept.

| Pad | Doom |
|---|---|
| Left stick | move, strafe |
| Right stick | turn |
| Right trigger (R2 / ZR) | fire; in the menu: select |
| Left trigger (L2 / ZL) | run |
| B | use, open doors; in the menu: back |
| LB / RB (L1 / R1, L / R) | previous / next weapon |
| Y (triangle, X on Switch) | automap |
| Start (Options, +) | menu |

To stop: **Quit Game** in Doom's menu, or hold a finger on the screen for
three seconds. The Toon restarts into its own software.

## Good to know

- Toon 2 only.
- The first press of START DOOM downloads DoomToon (25 MB) from the
  [releases](https://github.com/ToonSoftwareCollective/doomtoon/releases) of
  this repository; the Toon needs internet for that. Later starts need no
  download.
- **While Doom runs, the Toon does not control the heating.**
- Nothing of the original software is changed. DoomToon adds its kernel files
  to the recovery partition (`doom2-*`, about 10 MB) and its system to
  `/mnt/data/doom-os` (about 15 MB), and copies this Toon's WiFi settings and
  WiFi/Bluetooth firmware there (the firmware is Broadcom's and is not part of
  DoomToon). Starting DoomToon is one-shot: DoomToon itself removes its start
  script before anything else, so whatever happens, the next restart is the
  Toon's own software (pull the plug if it ever hangs).
- WiFi works in DoomToon too (with the settings of the original software); the
  first screen shows its address. SSH: root / toon.

## Installing by hand

Each release also has `doomtoon-app-<version>.tar.gz`: the app with the image
inside, for a Toon without the store or without internet. Unpack it into
`/qmf/qml/apps/` and restart the GUI (`killall qt-gui`).
