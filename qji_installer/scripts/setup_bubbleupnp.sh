#!/bin/bash
# ============================================================
# Qji 奏在 — BubbleUPnP Server Setup
# ============================================================

if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    for _t in xfce4-terminal lxterminal mate-terminal xterm gnome-terminal konsole qterminal; do
        command -v "$_t" &>/dev/null && break
    done
    case "$_t" in
        xfce4-terminal) exec "$_t" --disable-server -T "📡 BubbleUPnP Server Setup" -x bash "$0" "$@" ;;
        gnome-terminal) exec "$_t" --title "📡 BubbleUPnP Server Setup" -- bash "$0" "$@" ;;
        *)              exec "$_t" -T "📡 BubbleUPnP Server Setup" -e bash "$0" "$@" ;;
    esac
    exit $?
fi

DEB_URL="https://bubblesoftapps.com/bubbleupnpserver/bubbleupnpserver_0.9-8_all.deb"
DEB_FILE="/tmp/bubbleupnpserver.deb"
BUBBLE_PORT=58050

clear
echo "╔══════════════════════════════════════════════════╗"
echo "║   📡 BubbleUPnP Server Setup                      ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Official site : https://bubblesoftapps.com/bubbleupnpserver2/"
echo "  Install method: .deb package (apt)"
echo "  Port          : $BUBBLE_PORT"
echo ""
echo "──────────────────────────────────────────────────"

# --- Check for existing installation ---
if dpkg -l | grep -q "bubbleupnpserver" 2>/dev/null; then
    echo ""
    echo "▶ Existing BubbleUPnP Server detected..."
    OLD_VER=$(dpkg -l bubbleupnpserver 2>/dev/null | grep "^ii" | awk '{print $3}')
    echo "  Installed version: $OLD_VER"
    read -rp "  Re-install? [y/N] " reinstall
    [[ "$reinstall" =~ ^[yY] ]] || { echo "  Skipping."; read -rp "Press Enter to close..." _; exit 0; }
fi

# --- Download ---
echo ""
echo "▶ Downloading BubbleUPnP Server..."
echo "  $DEB_URL"
echo ""

if command -v wget &>/dev/null; then
    wget -q --show-progress -O "$DEB_FILE" "$DEB_URL"
elif command -v curl &>/dev/null; then
    curl -L --progress-bar -o "$DEB_FILE" "$DEB_URL"
else
    echo "❌ wget/curl not found."
    read -rp "Press Enter to close..." _; exit 1
fi

if [ ! -f "$DEB_FILE" ]; then
    echo ""
    echo "❌ Download failed."
    echo "   Check your network connection or install manually:"
    echo "   $DEB_URL"
    read -rp "Press Enter to close..." _; exit 1
fi

# --- Install ---
echo ""
echo "▶ Installing..."
sudo apt-get install -y "$DEB_FILE"
rm -f "$DEB_FILE"

if ! command -v bubbleupnpserver &>/dev/null && \
   ! systemctl list-units --all | grep -q bubbleupnp 2>/dev/null; then
    echo ""
    echo "❌ Installation failed."
    read -rp "Press Enter to close..." _; exit 1
fi

# --- Open firewall port ---
if command -v ufw &>/dev/null; then
    echo ""
    echo "▶ Configuring firewall..."
    sudo ufw allow "$BUBBLE_PORT/tcp" >/dev/null 2>&1
    echo "  ✓ Port $BUBBLE_PORT opened"
fi

# --- Done ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ BubbleUPnP Server installed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Settings page : http://localhost:$BUBBLE_PORT"
echo ""
echo "  [First-time setup]"
echo "  1. Start the '📡 gmediarender Receiver' desktop icon first"
echo "  2. Open http://localhost:$BUBBLE_PORT in a browser"
echo "  3. Check that 'Qji Player' appears under the Devices tab"
echo "  4. Install the 'BubbleUPnP' app on your phone"
echo "  5. Enter the server address in the app:"
echo "       http://$(hostname -I | awk '{print $1}'):$BUBBLE_PORT"
echo "  6. Select 'Qji Player' as the renderer and start playback"
echo ""
echo "  Docs: https://bubblesoftapps.com/bubbleupnpserver2/docs/linux_install.html"
echo ""

# --- Start service ---
if systemctl is-active --quiet bubbleupnpserver 2>/dev/null; then
    echo "  ✓ BubbleUPnP Server is already running"
else
    read -rp "  Start BubbleUPnP Server now? [Y/n] " launch
    case "$launch" in
        [nN]*) ;;
        *) sudo systemctl start bubbleupnpserver 2>/dev/null || \
           sudo service bubbleupnpserver start 2>/dev/null
           echo "  ✓ Started"
           ;;
    esac
fi

echo ""
read -rp "Press Enter to close..." _
