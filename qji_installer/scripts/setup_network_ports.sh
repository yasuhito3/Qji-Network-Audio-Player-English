#!/bin/bash
# ============================================================
# Qji 奏在 — Open network ports
# For AirPlay (shairport-sync) / gmediarender (UPnP-DLNA)
# ============================================================

if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    for _t in xfce4-terminal lxterminal mate-terminal xterm gnome-terminal konsole qterminal; do
        command -v "$_t" &>/dev/null && break
    done
    case "$_t" in
        xfce4-terminal) exec "$_t" --disable-server -T "🌐 Network Setup" -x bash "$0" "$@" ;;
        gnome-terminal) exec "$_t" --title "🌐 Network Setup" -- bash "$0" "$@" ;;
        *)              exec "$_t" -T "🌐 Network Setup" -e bash "$0" "$@" ;;
    esac
    exit $?
fi

trap 'ec=$?; echo ""; echo "Error (exit code: $ec). Press Enter to close..."; read _; exit 1' ERR

echo "╔══════════════════════════════════════════╗"
echo "║   Qji 奏在 — Open Network Ports           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

if ! command -v ufw &>/dev/null; then
    echo "ufw not found — installing..."
    sudo apt-get update -qq && sudo apt-get install -y ufw
fi

echo "Target network (local LAN only):"
read -rp "  Subnet [192.168.0.0/16]: " SUBNET
SUBNET="${SUBNET:-192.168.0.0/16}"
echo ""

# ------------------------------------------------------------
# Port definitions by service
# ------------------------------------------------------------
declare -A AIRPLAY_PORTS=(
    ["5353/udp"]="mDNS / Bonjour (device discovery)"
    ["7000/tcp"]="RTSP (AirPlay control)"
    ["319/udp"]="PTP timing (AirPlay 2)"
    ["320/udp"]="PTP timing (AirPlay 2)"
    ["6000:6009/udp"]="Audio / control / timing (shairport-sync)"
)

declare -A DLNA_PORTS=(
    ["1900/udp"]="SSDP (UPnP device discovery)"
    ["49152:49999/tcp"]="gmediarender dynamic HTTP ports"
    ["49152:49999/udp"]="gmediarender dynamic ports"
)

echo "▶ AirPlay (shairport-sync) ports"
for port in "${!AIRPLAY_PORTS[@]}"; do
    echo "  - $port  (${AIRPLAY_PORTS[$port]})"
done
echo ""
echo "▶ gmediarender (UPnP/DLNA) ports"
for port in "${!DLNA_PORTS[@]}"; do
    echo "  - $port  (${DLNA_PORTS[$port]})"
done
echo ""

read -rp "Open the above ports for local LAN ($SUBNET) only. Continue? [Y/n] " ans
case "$ans" in
    [nN]*) echo "Cancelled."; read -rp "Press Enter to close..." _; exit 0 ;;
esac

echo ""
echo "▶ Adding firewall rules..."

for port in "${!AIRPLAY_PORTS[@]}" "${!DLNA_PORTS[@]}"; do
    sudo ufw allow from "$SUBNET" to any port "${port%%/*}" proto "${port##*/}" >/dev/null
    echo "  ✓ $port"
done

sudo ufw reload >/dev/null
echo ""
echo "✅ Done. Current rules:"
sudo ufw status numbered | grep -E "5353|7000|319|320|6000|1900|4915" || true

echo ""
read -rp "Press Enter to close..." _
