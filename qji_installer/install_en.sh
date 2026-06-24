#!/bin/bash
# ============================================================
# Qji 奏在 (Kanzai) — Installer (English)
# Double-click (or run from any terminal) for fully automatic setup
# ============================================================

# --- If not already running in a terminal, relaunch in an available one ---
if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for term in xfce4-terminal lxterminal mate-terminal xterm gnome-terminal konsole qterminal; do
        if command -v "$term" &>/dev/null; then
            case "$term" in
                xfce4-terminal) exec "$term" --disable-server -T "Qji Installer" -e "bash $0" ;;
                lxterminal)     exec "$term" --title "Qji Installer" -e "bash $0" ;;
                mate-terminal)  exec "$term" --title "Qji Installer" -e "bash $0" ;;
                gnome-terminal) exec "$term" --title "Qji Installer" -- bash "$0" ;;
                konsole)        exec "$term" --title "Qji Installer" -e "bash $0" ;;
                qterminal)      exec "$term" -e "bash $0" ;;
                xterm)          exec "$term" -fa "Monospace" -fs 12 -title "Qji Installer" -geometry 90x40 -e bash "$0" ;;
            esac
        fi
    done
fi

# Keep the window open and show a message if something fails
trap 'ec=$?; echo ""; echo "----------------------------------------"; echo "An error occurred (exit code: $ec)."; echo "Please check the log above."; echo "----------------------------------------"; read -rp "Press Enter to close..." _; exit 1' ERR

QJI_DIR="$HOME/qji"
LOG_FILE="$HOME/qji_install_debug.log"
mkdir -p "$QJI_DIR"
exec > >(tee "$LOG_FILE") 2>&1
echo "(A full log of this install is saved to $LOG_FILE)"
echo ""
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null)"
[ -z "$DESKTOP_DIR" ] && DESKTOP_DIR="$HOME/Desktop"
INSTALLER_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║            🎵 Qji 奏在 Installer          ║"
    echo "  ║   High-Fidelity Music Player for Linux   ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${RESET}"
}

step() {
    echo -e "\n${CYAN}▶ $1${RESET}"
}

ok() {
    echo -e "  ${GREEN}✓ $1${RESET}"
}

warn() {
    echo -e "  ${YELLOW}⚠  $1${RESET}"
}

err() {
    echo -e "  ${RED}✗ $1${RESET}"
}

banner

echo -e "${BOLD}Install location: ${QJI_DIR}${RESET}"
echo -e "This script will:"
echo "  1. Install the required system packages"
echo "  2. Install the required Python packages"
echo "  3. Copy files into ~/qji/"
echo "  4. Create desktop icons (8 total)"
echo ""
read -rp "Continue? [Y/n] " answer
case "$answer" in
    [nN]*) echo "Installation cancelled."; exit 0 ;;
esac

# ============================================================
# Step 1: System packages
# ============================================================
step "Checking / installing system packages"

APT_PACKAGES=(
    python3-pip python3-tk
    ffmpeg alsa-utils
    xterm
    feh
    python3-mutagen
    fonts-noto-cjk
    gmediarender
    gstreamer1.0-plugins-good
    gstreamer1.0-plugins-base
    shairport-sync
    avahi-daemon
    ufw
    libsndfile1
    sox
)

MISSING_APT=()
for pkg in "${APT_PACKAGES[@]}"; do
    if ! dpkg -l "$pkg" &>/dev/null; then
        MISSING_APT+=("$pkg")
    fi
done

if [ ${#MISSING_APT[@]} -gt 0 ]; then
    echo "  Packages to install: ${MISSING_APT[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${MISSING_APT[@]}"
    ok "System packages installed"
else
    ok "All required system packages are already installed"
fi

# shairport-sync is often auto-started/auto-enabled when the package is
# installed, which can hold onto the output device and break Qji playback,
# so it is disabled here (Qji's own AirPlay receiver icon starts it on demand).
if systemctl list-unit-files 2>/dev/null | grep -q "^shairport-sync.service"; then
    sudo systemctl stop shairport-sync 2>/dev/null
    sudo systemctl disable shairport-sync 2>/dev/null
    ok "Disabled shairport-sync auto-start (Qji starts it only when needed)"
fi
if systemctl list-unit-files 2>/dev/null | grep -q "^gmediarender.service"; then
    sudo systemctl stop gmediarender 2>/dev/null
    sudo systemctl disable gmediarender 2>/dev/null
    ok "Disabled gmediarender auto-start (Qji starts it only when needed)"
fi

# sudo privilege setup (equivalent of editing via visudo)
SUDOERS_FILE="/etc/sudoers.d/qji"
if [ ! -f "$SUDOERS_FILE" ]; then
    {
        echo "# Qji 奏在 — auto-generated sudo privileges"
        echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/bluealsa-aplay"
        echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/bluealsad"
        echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/python3 $HOME/qji/qji.py"
        echo "$USER ALL=(ALL) NOPASSWD: /usr/sbin/modprobe"
    } | sudo tee "$SUDOERS_FILE" >/dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    ok "Configured sudo privileges ($SUDOERS_FILE)"
else
    ok "sudo privileges already configured"
fi

# ============================================================
# Step 2: Python packages
# ============================================================
step "Checking / installing Python packages"

PIP_PACKAGES=(
    mutagen
    requests
    yt-dlp
    ytmusicapi
    numpy
    librosa
    qobuz-dl
)

# Optional (speech recognition — installer continues even if this fails)
OPTIONAL_PIP=(
    vosk
    sounddevice
)

pip3 install --quiet --break-system-packages "${PIP_PACKAGES[@]}" 2>/dev/null || \
    pip3 install --quiet "${PIP_PACKAGES[@]}"
ok "Installed required Python packages"

for pkg in "${OPTIONAL_PIP[@]}"; do
    if pip3 install --quiet --break-system-packages "$pkg" 2>/dev/null || \
       pip3 install --quiet "$pkg" 2>/dev/null; then
        ok "Optional: $pkg"
    else
        warn "Optional package $pkg could not be installed (voice recognition will be disabled)"
    fi
done

# ============================================================
# Step 3: Copy files
# ============================================================
step "Copying files to ~/qji/"

mkdir -p "$QJI_DIR/sonia_intelligence"
mkdir -p "$QJI_DIR/scripts"

# Main scripts
MAIN_FILES=(
    qji.py
    qji_qobuz.py
    qji_qobuz_browser.py
    qji_soundcloud.py
    qji_soundcloud_browser.py
    qji_ytmusic.py
    qji_ytmusic_browser.py
    audio_equalizer.py
    play_auto.sh
)

for f in "${MAIN_FILES[@]}"; do
    if [ -f "$INSTALLER_DIR/$f" ]; then
        cp "$INSTALLER_DIR/$f" "$QJI_DIR/"
        chmod +x "$QJI_DIR/$f"
        ok "$f"
    else
        warn "$f not found (skipped)"
    fi
done

# Sonia Intelligence modules
SI_FILES=(
    acoustic_spaces.py
    genre_presets.py
    profile_db.py
    filter_builder.py
    audio_equalizer.py
)

for f in "${SI_FILES[@]}"; do
    if [ -f "$INSTALLER_DIR/sonia_intelligence/$f" ]; then
        cp "$INSTALLER_DIR/sonia_intelligence/$f" "$QJI_DIR/sonia_intelligence/"
        ok "sonia_intelligence/$f"
    elif [ -f "$INSTALLER_DIR/$f" ]; then
        cp "$INSTALLER_DIR/$f" "$QJI_DIR/sonia_intelligence/"
        ok "sonia_intelligence/$f (copied from root)"
    else
        warn "sonia_intelligence/$f not found (skipped)"
    fi
done

# Copy icon images
if [ -d "$INSTALLER_DIR/icons" ]; then
    cp -r "$INSTALLER_DIR/icons" "$QJI_DIR/"
    ok "Icon images"
fi

# Copy the library analyzer script (if present)
if [ -f "$INSTALLER_DIR/scripts/music_library_analyzer.py" ]; then
    cp "$INSTALLER_DIR/scripts/music_library_analyzer.py" "$QJI_DIR/scripts/"
    chmod +x "$QJI_DIR/scripts/music_library_analyzer.py"
    ok "music_library_analyzer.py"
else
    # Generate a minimal fallback version if it isn't bundled
    cat > "$QJI_DIR/scripts/music_library_analyzer.py" << 'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
music_library_analyzer.py
Music library analysis tool (bundled with Qji 奏在)
"""
import os, sys, json
from pathlib import Path

try:
    from mutagen import File as MutagenFile
    from mutagen.id3 import ID3NoHeaderError
    MUTAGEN_OK = True
except ImportError:
    MUTAGEN_OK = False

AUDIO_EXTS = {".flac", ".mp3", ".wav", ".aac", ".m4a", ".ogg", ".opus", ".dsf", ".dff"}

def scan_library(root: str):
    root_path = Path(root).expanduser()
    if not root_path.exists():
        print(f"Error: directory not found: {root_path}")
        return

    stats = {"total": 0, "genres": {}, "formats": {}, "errors": 0}
    print(f"\n🔍 Scanning: {root_path}\n")

    for dirpath, dirnames, filenames in os.walk(root_path, onerror=lambda e: None):
        for name in filenames:
            path = Path(dirpath) / name
            if path.suffix.lower() not in AUDIO_EXTS:
                continue
            stats["total"] += 1
            fmt = path.suffix.lower()
            stats["formats"][fmt] = stats["formats"].get(fmt, 0) + 1

            if MUTAGEN_OK:
                try:
                    audio = MutagenFile(path, easy=True)
                    if audio:
                        genre = (audio.get("genre") or ["Unknown"])[0]
                        stats["genres"][genre] = stats["genres"].get(genre, 0) + 1
                except Exception:
                    stats["errors"] += 1

    print(f"📂 Total files: {stats['total']}")
    print(f"\n🎵 By format:")
    for fmt, cnt in sorted(stats["formats"].items(), key=lambda x: -x[1]):
        print(f"   {fmt:8s} {cnt:5d} files")
    if stats["genres"]:
        print(f"\n🎭 By genre (top 20):")
        for genre, cnt in sorted(stats["genres"].items(), key=lambda x: -x[1])[:20]:
            bar = "█" * min(40, cnt // max(1, stats["total"] // 100))
            print(f"   {genre[:30]:30s} {cnt:5d}  {bar}")
    print(f"\n⚠  Errors: {stats['errors']} files")

if __name__ == "__main__":
    library_path = sys.argv[1] if len(sys.argv) > 1 else "~/Music"
    scan_library(library_path)
    print("\nScan complete. Press Enter to close...")
    input()
PYEOF
    chmod +x "$QJI_DIR/scripts/music_library_analyzer.py"
    ok "music_library_analyzer.py (generated minimal version)"
fi

if [ -f "$INSTALLER_DIR/scripts/setup_network_ports.sh" ]; then
    cp "$INSTALLER_DIR/scripts/setup_network_ports.sh" "$QJI_DIR/scripts/"
    chmod +x "$QJI_DIR/scripts/setup_network_ports.sh"
    ok "setup_network_ports.sh"
fi

for f in setup_audio_loopback.sh gmediarender_launcher.sh airplay_launcher.sh qji_start.sh build_library_db.sh setup_bubbleupnp.sh equalizer_start.sh; do
    if [ -f "$INSTALLER_DIR/scripts/$f" ]; then
        cp "$INSTALLER_DIR/scripts/$f" "$QJI_DIR/scripts/"
        chmod +x "$QJI_DIR/scripts/$f"
        ok "$f"
    fi
done

# ============================================================
# Step 4: Create desktop icons
# ============================================================
step "Creating desktop icons"

mkdir -p "$DESKTOP_DIR"

# --- Auto-detect an available terminal emulator ---
TERM_CMD=""
TERM_EXEC_OPT="-e"
for term in xfce4-terminal lxterminal mate-terminal xterm gnome-terminal konsole qterminal; do
    if command -v "$term" &>/dev/null; then
        TERM_BIN="$term"
        case "$term" in
            xfce4-terminal) TERM_CMD="$term --disable-server -T" ; TERM_EXEC_OPT="-x" ;;
            lxterminal)     TERM_CMD="$term --title" ; TERM_EXEC_OPT="-e" ;;
            mate-terminal)  TERM_CMD="$term --title" ; TERM_EXEC_OPT="-e" ;;
            gnome-terminal) TERM_CMD="$term --title" ; TERM_EXEC_OPT="--" ;;
            konsole)        TERM_CMD="$term --title" ; TERM_EXEC_OPT="-e" ;;
            qterminal)      TERM_CMD="$term" ; TERM_EXEC_OPT="-e" ;;
            xterm)          TERM_CMD="$term -fa Monospace -fs 12 -title" ; TERM_EXEC_OPT="-e" ;;
        esac
        break
    fi
done
[ -z "$TERM_CMD" ] && TERM_CMD="xterm -fa Monospace -fs 12 -title" && TERM_EXEC_OPT="-e"
ok "Terminal: $TERM_BIN"

# --- Resolve icon image paths ---
ICON_QJI="$QJI_DIR/icons/qji.png"
ICON_LIBRARY="$QJI_DIR/icons/music_library.png"
ICON_EQ="$QJI_DIR/icons/equalizer.png"
ICON_NET="$QJI_DIR/icons/installer.png"

# Fallback to system icons
[ -f "$ICON_QJI" ]     || ICON_QJI="audio-x-generic"
[ -f "$ICON_LIBRARY" ] || ICON_LIBRARY="folder-music"
[ -f "$ICON_EQ" ]      || ICON_EQ="multimedia-volume-control"
[ -f "$ICON_NET" ]     || ICON_NET="network-wired"

# --- 0. Build music library DB (recommended to run first) ---
cat > "$DESKTOP_DIR/Build-Music-Library.desktop" << DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Build Music Library
GenericName=Build Music Library DB
Comment=Builds music_mood_db.json (recommended before first Qji launch)
Exec=$TERM_CMD "🗄 Build Music Library" $TERM_EXEC_OPT bash "$QJI_DIR/scripts/build_library_db.sh"
Icon=${ICON_LIBRARY}
Terminal=false
StartupNotify=false
Categories=Audio;Music;Utility;
Keywords=library;database;mood;genre;Qji;
DESKTOP_EOF
chmod +x "$DESKTOP_DIR/Build-Music-Library.desktop"
ok "Build-Music-Library.desktop"

# --- 1. Qji 奏在 (main player) ---
cat > "$DESKTOP_DIR/Qji-Player.desktop" << DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Qji 奏在
GenericName=High-Fidelity Music Player
Comment=Hi-fi music player (terminal interface)
Exec=$TERM_CMD "🎵 Qji 奏在" $TERM_EXEC_OPT bash "$QJI_DIR/scripts/qji_start.sh"
Icon=${ICON_QJI}
Terminal=false
StartupNotify=false
Categories=Audio;Player;Music;
Keywords=music;player;hifi;jazz;classical;Qji;
DESKTOP_EOF
chmod +x "$DESKTOP_DIR/Qji-Player.desktop"
ok "Qji-Player.desktop"

# --- 2. Audio Equalizer ---
cat > "$DESKTOP_DIR/Audio-Equalizer.desktop" << DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Audio Equalizer
GenericName=Audio Equalizer Pro
Comment=Equalizer GUI linked to Qji 奏在 via FIFO
Exec=bash "$QJI_DIR/scripts/equalizer_start.sh"
Icon=${ICON_EQ}
Terminal=false
StartupNotify=false
Categories=Audio;Mixer;Utility;
Keywords=equalizer;EQ;audio;Qji;
DESKTOP_EOF
chmod +x "$DESKTOP_DIR/Audio-Equalizer.desktop"
ok "Audio-Equalizer.desktop"

# --- 4. Network setup (AirPlay/DLNA) ---
cat > "$DESKTOP_DIR/Network-Setup-AirPlay-DLNA.desktop" << DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Network Setup (AirPlay/DLNA)
GenericName=Network Port Setup
Comment=Opens AirPlay/gmediarender ports via ufw
Exec=bash $QJI_DIR/scripts/setup_network_ports.sh
Icon=${ICON_NET}
Terminal=false
StartupNotify=false
Categories=System;Network;
Keywords=AirPlay;DLNA;UPnP;ufw;firewall;Qji;
DESKTOP_EOF
chmod +x "$DESKTOP_DIR/Network-Setup-AirPlay-DLNA.desktop"
ok "Network-Setup-AirPlay-DLNA.desktop"

# --- 5. Audio loopback setup ---
cat > "$DESKTOP_DIR/Audio-Loopback-Setup.desktop" << DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Audio Loopback Setup
GenericName=Audio Loopback Setup
Comment=Configures ALSA loopback and detects the output DAC (required on first run)
Exec=bash $QJI_DIR/scripts/setup_audio_loopback.sh
Icon=${ICON_NET}
Terminal=false
StartupNotify=false
Categories=System;Audio;
Keywords=ALSA;loopback;DAC;Qji;
DESKTOP_EOF
chmod +x "$DESKTOP_DIR/Audio-Loopback-Setup.desktop"
ok "Audio-Loopback-Setup.desktop"

# --- 6. gmediarender receiver ---
cat > "$DESKTOP_DIR/gmediarender-Receiver.desktop" << DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=gmediarender Receiver
GenericName=UPnP-DLNA Receiver
Comment=Receives UPnP/DLNA casts from phones etc. and plays them through the Musikverein engine
Exec=bash $QJI_DIR/scripts/gmediarender_launcher.sh
Icon=${ICON_LIBRARY}
Terminal=false
StartupNotify=false
Categories=Audio;Network;
Keywords=UPnP;DLNA;gmediarender;Qji;
DESKTOP_EOF
chmod +x "$DESKTOP_DIR/gmediarender-Receiver.desktop"
ok "gmediarender-Receiver.desktop"

# --- BubbleUPnP Server ---
cat > "$DESKTOP_DIR/BubbleUPnP-Server.desktop" << DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=BubbleUPnP Server
GenericName=UPnP Bridge Server
Comment=UPnP bridge that lets you control gmediarender from a phone
Exec=$TERM_CMD "📡 BubbleUPnP Server" $TERM_EXEC_OPT bash "$QJI_DIR/scripts/setup_bubbleupnp.sh"
Icon=${ICON_NET}
Terminal=false
StartupNotify=false
Categories=Audio;Network;
Keywords=BubbleUPnP;UPnP;DLNA;gmediarender;Qji;
DESKTOP_EOF
chmod +x "$DESKTOP_DIR/BubbleUPnP-Server.desktop"
ok "BubbleUPnP-Server.desktop"

# --- 7. AirPlay receiver ---
cat > "$DESKTOP_DIR/AirPlay-Receiver.desktop" << DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=AirPlay Receiver
GenericName=AirPlay Receiver
Comment=Receives AirPlay audio from iPhone/Mac and plays it through the Musikverein engine
Exec=bash $QJI_DIR/scripts/airplay_launcher.sh
Icon=${ICON_QJI}
Terminal=false
StartupNotify=false
Categories=Audio;Network;
Keywords=AirPlay;shairport;Qji;
DESKTOP_EOF
chmod +x "$DESKTOP_DIR/AirPlay-Receiver.desktop"
ok "AirPlay-Receiver.desktop"

# Mark icons as "trusted" and executable for Xubuntu/XFCE
for desktop_file in "Build-Music-Library" "Qji-Player" "Audio-Equalizer" "Network-Setup-AirPlay-DLNA" "Audio-Loopback-Setup" "gmediarender-Receiver" "BubbleUPnP-Server" "AirPlay-Receiver"; do
    f="$DESKTOP_DIR/${desktop_file}.desktop"
    chmod +x "$f"
    gio set "$f" metadata::trusted true 2>/dev/null || true
    # Some XFCE versions need this attribute too
    gio set "$f" "metadata::xfce-exe-checksum" "$(sha256sum "$f" | cut -d' ' -f1)" 2>/dev/null || true
done

# Refresh the desktop
xfdesktop --reload 2>/dev/null || true

# ============================================================
# Done
# ============================================================
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}  ✅ Qji 奏在 installed successfully!${RESET}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "  Install location: $QJI_DIR"
echo ""
echo "  Desktop icons created:"
echo "    🗄 Build Music Library — recommended first run (music_mood_db.json)"
echo "    🎵 Qji 奏在               — launch the main player"
echo "    🎚️ Audio Equalizer        — launch the EQ GUI"
echo "    🌐 Network Setup          — open AirPlay/DLNA ports (ufw)"
echo "    🔧 Audio Loopback Setup   — configure ALSA loopback (required on first run)"
echo "    📡 gmediarender Receiver  — receive UPnP/DLNA casts"
echo "    🌐 BubbleUPnP Server      — control via UPnP from a phone"
echo "    📱 AirPlay Receiver       — receive AirPlay audio"
echo ""
echo -e "  ${YELLOW}★ On first use, please run \"🔧 Audio Loopback Setup\""
echo -e "    once before using AirPlay/gmediarender.${RESET}"
echo ""
echo -e "  ${YELLOW}Tip: the music folder path can be changed via the"
echo -e "  MUSIC_DIRS variable inside qji.py.${RESET}"
echo ""
read -rp "Press Enter to close this window..." _
