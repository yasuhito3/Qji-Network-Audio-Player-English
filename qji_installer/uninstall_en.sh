#!/bin/bash
# Qji 奏在 Uninstaller (English)

if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    xterm -fa "Monospace" -fs 12 -title "Qji Uninstaller" \
          -geometry 70x25 -e bash "$0" "$@"
    exit $?
fi

QJI_DIR="$HOME/qji"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null)"
[ -z "$DESKTOP_DIR" ] && DESKTOP_DIR="$HOME/Desktop"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Qji 奏在 Uninstaller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This will remove:"
echo "  • the entire ~/qji/ directory"
echo "  • the Qji desktop icons (8 total)"
echo ""
read -rp "Are you sure you want to uninstall? [y/N] " answer
case "$answer" in
    [yY]*)
        rm -rf "$QJI_DIR"
        for f in "1-Build-Music-Library" "Qji-Player" "Audio-Equalizer" \
                 "Network-Setup-AirPlay-DLNA" "Audio-Loopback-Setup" \
                 "gmediarender-Receiver" "BubbleUPnP-Server" "AirPlay-Receiver"; do
            rm -f "$DESKTOP_DIR/${f}.desktop"
        done
        echo ""
        echo "✓ Qji 奏在 has been removed."
        echo "  Config files (e.g. ~/.music_player_presets.json) were kept."
        ;;
    *)
        echo "Cancelled."
        ;;
esac
echo ""
read -rp "Press Enter to close..." _
