<p align="center">
  <img src="docs/prism-banner.jpg" alt="Prism — a shell for mpv" width="100%">
</p>

<p align="center">
  <b>One shell — many facets.</b><br>
  An on-screen controller for <a href="https://mpv.io">mpv</a> that you rebuild with the mouse, right in the player.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/mpv-0.40%2B-8C6CFF?style=flat-square" alt="mpv 0.40+">
  <img src="https://img.shields.io/badge/Windows-ready-4FE0FF?style=flat-square" alt="Windows">
  <img src="https://img.shields.io/badge/license-LGPL--2.1-4FE0FF?style=flat-square" alt="LGPL-2.1">
  <br><a href="README.md">Русский</a>
</p>

<p align="center">
  <img src="docs/launch.webp" alt="Start screen, click a card, the video goes on from where you stopped" width="800">
</p>

## Player

<p align="center"><img src="docs/panel.jpg" alt="Prism bar" width="800"></p>

## Editor

<p align="center"><img src="docs/editor.webp" alt="Editor: Ctrl+E, drag a button, change its color, save" width="800"></p>

## Install

1. **Download** [the ZIP](https://github.com/VasiliskBRO/mpv-prism/archive/refs/heads/master.zip) and unpack it.
2. **Copy everything** into your mpv config folder: `portable_config` next to `mpv.exe` or `%APPDATA%\mpv\`
   on Windows, `~/.config/mpv/` on Linux / macOS.
3. **Remove other OSC scripts** (uosc, ModernZ…) from `scripts`, otherwise you get two bars.

Needs **mpv 0.40+**. Optional: **Python** (SponsorBlock), **streamlink** (Twitch/Kick/GoodGame live), **yt-dlp** (links).

Want to send videos from websites to Prism with one click? See **[mpv browser button](https://github.com/VasiliskBRO/mpv-browser-button)** (Windows, Linux beta).

## Cheat sheet

| I want | Do |
|---|---|
| the menu | right click on the video (type to search) |
| open a link | copy it and press `Ctrl+V` |
| move a button, recolor it | `Ctrl+E` → drag, right click for properties → «Сохранить» (Save) |
| my own menu | `Ctrl+Shift+E` |
| another look | right click → «Скины» (Skins) |
| undo everything | `Ctrl+E` → «Как по умолчанию» (Defaults) → «Сохранить» |

The interface is in Russian. The full guide (in Russian) is in [docs/GUIDE.md](docs/GUIDE.md):
start screen with recent videos, prism pause, skin export / import, menu builder, chameleon accent,
the pet, own icons.

## Credits and licenses

Based on [ModernZ](https://github.com/Samillion/ModernZ) (LGPL-2.1), volume, speed ruler and menus after
[uosc](https://github.com/tomasklaen/uosc) (LGPL-2.1); [thumbfast](https://github.com/po5/thumbfast) (MPL-2.0),
[mpv_sponsorblock](https://github.com/po5/mpv_sponsorblock) (GPL-3.0). Project license: **LGPL-2.1**.
