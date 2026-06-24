#!/bin/bash
# ============================================================
# Qji 奏在 — gmediarender (UPnP/DLNA) Receiver
#  Signal path: gmediarender → ALSA loopback → ffmpeg (Musikverein) → DAC
# ============================================================

if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    for _t in xfce4-terminal lxterminal mate-terminal xterm gnome-terminal konsole qterminal; do
        command -v "$_t" &>/dev/null && break
    done
    case "$_t" in
        xfce4-terminal) exec "$_t" --disable-server -T "📡 gmediarender Receiver" -x bash "$0" "$@" ;;
        gnome-terminal) exec "$_t" --title "📡 gmediarender Receiver" -- bash "$0" "$@" ;;
        *)              exec "$_t" -T "📡 gmediarender Receiver" -e bash "$0" "$@" ;;
    esac
    exit $?
fi

QJI_DIR="$HOME/qji"
DEV_FILE="$QJI_DIR/.audio_devices"

if [ ! -f "$DEV_FILE" ]; then
    echo "⚠ Audio device config not found."
    echo "  Please run \"Audio Loopback Setup\" first."
    read -rp "Press Enter to close..." _
    exit 1
fi
# shellcheck disable=SC1090
source "$DEV_FILE"

cleanup() {
    echo ""
    echo "🛑 Stopping..."
    [ -n "$GMR_PID" ] && kill "$GMR_PID" 2>/dev/null
    [ -n "$FF_PID" ]  && kill "$FF_PID"  2>/dev/null
    exit 0
}
trap cleanup INT TERM

echo "════════════════════════════════════════════════════"
echo "  📡 Qji × gmediarender (UPnP/DLNA Receiver)"
echo "════════════════════════════════════════════════════"
echo "  Receive device : $LOOPBACK_OUT"
echo "  Output device  : $OUTPUT_DEVICE"
echo "  Processing     : Musikverein (Sonia Intelligence)"
echo "  Stop           : Ctrl+C"
echo "────────────────────────────────────────────────────"
echo ""

if ! command -v gmediarender &>/dev/null; then
    echo "⚠ gmediarender is not installed."
    echo "  Please re-run install_en.sh."
    read -rp "Press Enter to close..." _
    exit 1
fi

# Stop the system gmediarender service if running
if systemctl is-active --quiet gmediarender 2>/dev/null; then
    echo "ℹ System gmediarender service is running — stopping it..."
    sudo systemctl stop gmediarender 2>/dev/null
    sleep 1
fi
pkill -x gmediarender 2>/dev/null
sleep 1

trap 'echo ""; echo "----------------------------------------"; echo "An error occurred. Check the log above."; read -rp "Press Enter to close..." _; exit 1' ERR
set -e

# 1) Start gmediarender pointed at the ALSA loopback input
GMR_LOG="/tmp/qji_gmediarender.log"
LANG=C.UTF-8 LC_ALL=C.UTF-8 gmediarender -f "Qji Player" \
    --gstout-audiosink=alsasink \
    --gstout-audiodevice="${LOOPBACK_IN}" \
    > "$GMR_LOG" 2>&1 &
GMR_PID=$!
sleep 2

if ! kill -0 "$GMR_PID" 2>/dev/null; then
    echo "❌ gmediarender failed to start. Log:"
    echo "──────────────────────────────────────────"
    tail -n 30 "$GMR_LOG"
    echo "──────────────────────────────────────────"
    echo "📖 Available options (--help):"
    echo "──────────────────────────────────────────"
    gmediarender --help 2>&1 | grep -iE "gstout|audio|device|sink" | head -20
    echo "──────────────────────────────────────────"
    read -rp "Press Enter to close..." _
    exit 1
fi
echo "  ✓ gmediarender started (PID $GMR_PID)"

# 2) Loopback output → ffmpeg (Musikverein filter) → DAC
FF_LOG="/tmp/qji_gmr_ffmpeg.log"
(ffmpeg -loglevel error -f alsa -i "${LOOPBACK_OUT}" \
    -af "aresample=44100,equalizer=f=300:t=q:w=1:g=1.5,equalizer=f=5000:t=q:w=1:g=1,aecho=0.8:0.85:25:0.25,alimiter=limit=-1.5dB" \
    -f s32le -acodec pcm_s32le -ac 2 -ar 44100 - \
    | aplay -D "${OUTPUT_DEVICE}" -q -f S32_LE -c 2 -r 44100) > "$FF_LOG" 2>&1 &
FF_PID=$!
sleep 1

if ! kill -0 "$FF_PID" 2>/dev/null; then
    echo "❌ Playback pipeline failed to start. Log:"
    echo "──────────────────────────────────────────"
    tail -n 30 "$FF_LOG"
    echo "──────────────────────────────────────────"
    kill "$GMR_PID" 2>/dev/null
    read -rp "Press Enter to close..." _
    exit 1
fi
echo "  ✓ Playback pipeline started (PID $FF_PID)"
echo ""
echo "  Cast music to \"Qji Player\" from your phone or UPnP controller."
echo ""

set +e
wait
read -rp "Press Enter to close..." _
