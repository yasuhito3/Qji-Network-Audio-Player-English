#!/bin/bash
# ============================================================
# Qji 奏在 — Installer launch bootstrap (English)
#  Locates and runs install_en.sh without relying on desktop
#  variables such as %k.
# ============================================================

if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    for _t in xfce4-terminal lxterminal mate-terminal xterm gnome-terminal konsole qterminal; do
        command -v "$_t" &>/dev/null && break
    done
    case "$_t" in
        xfce4-terminal) exec "$_t" --disable-server -T "Qji Installer" -x bash "$0" "$@" ;;
        gnome-terminal) exec "$_t" --title "Qji Installer" -- bash "$0" "$@" ;;
        *)              exec "$_t" -T "Qji Installer" -e bash "$0" "$@" ;;
    esac
    exit $?
fi

# 1. Prefer the directory this script lives in
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -f "$SELF_DIR/install_en.sh" ]; then
    cd "$SELF_DIR"
    exec bash install_en.sh
fi

# 2. Search common download locations for the qji_installer folder
echo "Searching for install_en.sh..."
for base in "$HOME" "$(xdg-user-dir DOWNLOAD 2>/dev/null)" "$HOME/Downloads" "$HOME/ダウンロード" "$HOME/Desktop" "$(xdg-user-dir DESKTOP 2>/dev/null)"; do
    [ -z "$base" ] && continue
    found=$(find "$base" -maxdepth 5 -type f -iname "install_en.sh" -path "*[Qq]ji_installer*" 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        cd "$(dirname "$found")"
        exec bash install_en.sh
    fi
done

echo ""
echo "❌ install_en.sh could not be found."
echo "   Please make sure this file is inside the qji_installer"
echo "   folder, then try again."
echo ""
read -rp "Press Enter to close..." _
