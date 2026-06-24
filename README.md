# 🎵 Qji 奏在 (Souzai) — Hi-Fi Music Player for Linux

**A high-fidelity terminal music player for Ubuntu / Debian-based Linux**

Qji brings concert-hall acoustic simulation to your desktop through a direct
ffmpeg + ALSA signal path, with no PulseAudio in the chain.
The built-in **Sonia Intelligence** system models nine world-class acoustic
spaces (Musikverein, Concertgebouw, Carnegie Hall, and more) and applies
them in real time using multi-band EQ, multi-stage echo, dynamic compression,
and spatial filtering.

**Supported OS:** Xubuntu 24.04 / 26.04 · Linux Mint · SparkyLinux
(other Ubuntu / Debian-based distros should also work)
**License:** [MIT](./LICENSE)
**Before installing:** please read [Security & Risks](./SECURITY.md)

---

## ✨ Features

- 🎻 **10 audio field presets** — Musikverein, Piano, Chamber, Vocal, Jazz, Calm, Deep, Spatial, Radio, Bypass
- 🎵 **Local library playback** — random shuffle, folder mode, cover-art browser
- 🌐 **Streaming** — Qobuz · SoundCloud · YouTube Music (each with a browser UI)
- 📡 **AirPlay receiver** — play from iPhone / Mac through the Musikverein engine
- 📻 **UPnP / DLNA receiver** — gmediarender + BubbleUPnP Server
- 🤖 **Sonia Intelligence (SI)** — AI-assisted acoustic personalisation with per-album profile saving
- 🎚️ **GUI equalizer** — linked to Qji via FIFO for real-time adjustment
- 🗄 **Music library builder** — tag analysis, mood detection, genre-interleaved shuffle
- 📱 **Now Playing mirror** — displays cover art and track info on your phone browser

---

## 📦 Package contents

```
Qji_installer/
├── install_en.sh                 ← Main installer (English)
├── run_installer_en.sh           ← Installer launch bootstrap
├── uninstall_en.sh               ← Uninstaller
├── Install.desktop               ← Double-click launcher
├── install.sh / run_installer.sh / uninstall.sh
│                                 ← Japanese originals
├── LICENSE
├── SECURITY.md
│
├── qji_en.py                     ← Main player (English)
├── qji_qobuz_en.py               ← Qobuz streaming (English)
├── qji_qobuz_browser_en.py       ← Qobuz browser UI (English)
├── qji_soundcloud_en.py          ← SoundCloud streaming (English)
├── qji_soundcloud_browser_en.py  ← SoundCloud browser UI (English)
├── qji_ytmusic_en.py             ← YouTube Music streaming (English)
├── qji_ytmusic_browser_en.py     ← YouTube Music browser UI (English)
├── audio_equalizer.py            ← GUI equalizer
├── play_auto.sh                  ← Auto-play helper
│
├── sonia_intelligence/
│   ├── acoustic_spaces.py        ← Acoustic space models
│   ├── genre_presets.py          ← Genre presets
│   ├── profile_db.py             ← Per-album profile database
│   └── filter_builder.py         ← ffmpeg filter-chain builder
│
├── scripts/
│   ├── qji_start.sh              ← Qji launch wrapper
│   ├── build_library_db.sh       ← Build music library DB
│   ├── music_library_analyzer.py ← Library analysis engine
│   ├── equalizer_start.sh        ← Equalizer launch wrapper
│   ├── setup_audio_loopback.sh   ← ALSA loopback setup
│   ├── gmediarender_launcher.sh  ← UPnP/DLNA receiver
│   ├── airplay_launcher.sh       ← AirPlay receiver
│   ├── setup_bubbleupnp.sh       ← BubbleUPnP Server setup
│   └── setup_network_ports.sh    ← Open ufw firewall ports
│
├── config_examples/
│   └── qji_lastfm.json.example   ← Last.fm API key template
└── icons/
    ├── qji.png / qji_logo.png
    ├── music_library.png
    ├── equalizer.png
    └── installer.png
```

---

## 🚀 Installation

### Method A: Double-click (recommended)
1. Double-click `Install.desktop`
2. A terminal window opens automatically
3. Follow the on-screen prompts and type `Y` to continue

### Method B: From a terminal
```bash
cd ~/Downloads/Qji_installer
bash install_en.sh
```

The installer takes care of all system packages, Python packages, file
copying, and desktop icon creation automatically.

---

## 🖥️ Desktop icons (created after installation)

| Icon | Function |
|------|----------|
| 🗄 **1-Build Music Library** | Scans music file tags, detects mood/genre, and builds `music_mood_db.json` — **recommended on first run** |
| 🎵 **Qji 奏在** | Main player (terminal interface) |
| 🎚️ **Audio Equalizer** | GUI equalizer linked to Qji via FIFO |
| 🌐 **Network Setup** | Opens AirPlay / DLNA ports via ufw (LAN only) |
| 🔧 **Audio Loopback Setup** | Configures ALSA loopback and detects the output DAC — **required before using AirPlay / DLNA** |
| 📡 **gmediarender Receiver** | Receives UPnP/DLNA casts and plays through the Musikverein engine |
| 🌐 **BubbleUPnP Server** | UPnP bridge for phone-based control of gmediarender |
| 📱 **AirPlay Receiver** | Receives AirPlay audio from iPhone / Mac |

---

## ⚙️ Recommended first-time setup order

1. **Run the installer** — double-click `Install.desktop`
2. **Run 🔧 Audio Loopback Setup**
   - Loads `snd-aloop` and makes it persist across reboots
   - Auto-detects your USB DAC and saves it to `~/qji/.audio_devices`
   - A reboot is recommended after this step
3. **Run 🌐 Network Setup** — only if you plan to use AirPlay or DLNA
4. **Run 🗄 1-Build Music Library** — recommended before first playback
5. **Launch 🎵 Qji 奏在**

`~/qji/.audio_devices` can be edited by hand if needed:
```
OUTPUT_DEVICE=hw:2,0       # DAC output
LOOPBACK_IN=hw:1,1,0       # Input side (used by AirPlay / gmediarender)
LOOPBACK_OUT=hw:1,0,0      # Output side (read by ffmpeg)
```

---

## ⚙️ What gets installed

### System packages (apt)
| Package | Purpose |
|---------|---------|
| `ffmpeg` | Audio processing engine |
| `alsa-utils` | Direct ALSA output (`aplay`) |
| `xterm` | Terminal emulator fallback |
| `feh` | Album art display |
| `python3-tk` | GUI equalizer |
| `fonts-noto-cjk` | CJK font support |
| `gmediarender` | UPnP / DLNA renderer |
| `shairport-sync` | AirPlay receiver |
| `avahi-daemon` | mDNS / Bonjour for AirPlay discovery |

### Python packages (pip)
| Package | Purpose |
|---------|---------|
| `mutagen` | Music file tag reading |
| `requests` | HTTP communication |
| `yt-dlp` | YouTube / SoundCloud audio streaming |
| `ytmusicapi` | YouTube Music search and library access |
| `qobuz-dl` | Qobuz app_secret auto-retrieval |
| `numpy` / `librosa` | Tempo and audio-feature analysis |
| `vosk` + `sounddevice` | Voice recognition *(optional)* |

---

## 🔑 Streaming service setup

### Qobuz
On first launch, Qji will ask for your:
- `X-User-Auth-Token` (Qobuz login token)
- `X-App-Id`

`app_secret` is retrieved automatically via `qobuz-dl` where possible.
All credentials are saved under `~/.config/` — you won't need to re-enter
them on subsequent launches.

### SoundCloud
`client_id` is retrieved automatically — no manual setup required.

### YouTube Music
Search and playback work immediately via `yt-dlp`.
To access your personal library and liked songs, authenticate once:
```bash
python3 -c "from ytmusicapi import YTMusic; YTMusic.setup(filepath='~/.config/qji_ytmusic_auth.json')"
```

---

## 📝 Playback keys (main player)

| Key | Function |
|-----|----------|
| `n` / `b` | Next / previous track |
| `+` / `-` | Output gain up / down |
| `c` | Cycle audio field preset |
| `g` | Cycle gain preset |
| `s` | Save audio profile for this track / album |
| `i` | Show / re-display cover art |
| `f` | Switch to folder playback mode |
| `r` | Restart current track |
| `w` | Toggle Air Particle Layer |
| `z` | Sonia Intelligence feedback |
| `x` | Sonia Intelligence preset |
| `h` | Select acoustic hall |
| `a` | Register album preset |
| `p` | View / apply saved profile |
| `ESC` | Hide cover art |
| `q` | Stop and return to menu |

### Audio field presets (`c` key)
| # | Preset | Character |
|---|--------|-----------|
| 1 | 🎻 Musikverein | Full orchestra — the signature preset |
| 2 | 🎹 Piano | Piano solo |
| 3 | 🏠 Chamber | Chamber music / string quartet |
| 4 | 🎙 Vocal | Vocal / opera |
| 5 | 🎷 Jazz | Jazz |
| 6 | 🌿 Calm | Tranquil / restful |
| 7 | 🌊 Deep | Immersive / introspective |
| 8 | 🌐 Spatial | 3D audio — best with headphones |
| 9 | 📻 Radio | Standard — for radio streams |
| 10 | ⚪ Bypass | No processing / reference |

---

## 📡 BubbleUPnP Server setup

BubbleUPnP Server lets you control `gmediarender` (the UPnP renderer) from
a smartphone app.

Official docs: https://bubblesoftapps.com/bubbleupnpserver2/docs/linux_install.html

### Signal flow
```
Phone (BubbleUPnP app)
    ↓  UPnP control
BubbleUPnP Server (port 58050)
    ↓  playback commands
gmediarender  (shown as "Qji Player")
    ↓  ALSA loopback
ffmpeg  (Musikverein / audio field processing)
    ↓
DAC → Amplifier → Speakers
```

### Steps
1. Start **📡 gmediarender Receiver**
2. Start **🌐 BubbleUPnP Server** (auto-installs the `.deb` package)
3. Open `http://localhost:58050` — "Qji Player" should appear under Devices
4. From the BubbleUPnP phone app, connect to `http://YOUR_PC_IP:58050`
5. Select "Qji Player" as renderer and start playback

---

## 💡 Tested environments

| Item | Details |
|------|---------|
| OS | Xubuntu 24.04 ✅ · Xubuntu 26.04 · Linux Mint (latest) · SparkyLinux |
| Desktop | XFCE |
| Python | 3.10 / 3.11 / 3.12 |
| Terminal | xfce4-terminal · xterm · lxterminal · mate-terminal · gnome-terminal · konsole · qterminal |
| DAC | Amanero Combo384 USB DAC |
| Amp | Mark Levinson |
| Speakers | Vienna Acoustics |

Other Ubuntu / Debian-based distributions should work in principle.
Bug reports and success reports via Issues are welcome.

---

## ⚠️ Notes

- Qji outputs directly to ALSA. If PulseAudio holds the device, run `pulseaudio --kill` first.
- Check sound card numbers with `aplay -l` (`hw:X,0`)
- Vosk voice-recognition models must be downloaded separately from https://alphacephei.com/vosk/models

---

## 🔒 Security & risks

Installation uses `sudo` for sudoers configuration, service management, and
firewall settings. See [SECURITY.md](./SECURITY.md) for full details.

---

## 🤝 Contributing & feedback

Bug reports, environment compatibility reports, and pull requests are all
welcome via GitHub Issues.

---

*Qji 奏在 — powered by the Sonia Intelligence System*
*Musikverein · Concertgebouw · Carnegie Hall · and more*
