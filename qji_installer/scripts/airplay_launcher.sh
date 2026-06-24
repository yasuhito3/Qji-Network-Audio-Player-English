#!/bin/bash
# ============================================================
# Qji 奏在 — AirPlay Receiver
#  Signal path: shairport-sync → ALSA loopback → ffmpeg (Musikverein) → DAC
# ============================================================

if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    for _t in xfce4-terminal lxterminal mate-terminal xterm gnome-terminal konsole qterminal; do
        command -v "$_t" &>/dev/null && break
    done
    case "$_t" in
        xfce4-terminal) exec "$_t" --disable-server -T "📱 AirPlay Receiver" -x bash "$0" "$@" ;;
        gnome-terminal) exec "$_t" --title "📱 AirPlay Receiver" -- bash "$0" "$@" ;;
        *)              exec "$_t" -T "📱 AirPlay Receiver" -e bash "$0" "$@" ;;
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
    [ -n "$SPS_PID" ] && kill "$SPS_PID" 2>/dev/null
    [ -n "$FF_PID" ]  && kill "$FF_PID"  2>/dev/null
    exit 0
}
trap cleanup INT TERM

echo "════════════════════════════════════════════════════"
echo "  📱 Qji × AirPlay Receiver"
echo "════════════════════════════════════════════════════"
echo "  Receive device : $LOOPBACK_OUT"
echo "  Output device  : $OUTPUT_DEVICE"
echo "  Processing     : Musikverein (Sonia Intelligence)"
echo "  Stop           : Ctrl+C"
echo "────────────────────────────────────────────────────"
echo ""

if ! command -v shairport-sync &>/dev/null; then
    echo "⚠ shairport-sync is not installed."
    echo "  Please re-run install_en.sh."
    read -rp "Press Enter to close..." _
    exit 1
fi

# Stop the system shairport-sync service if running
# (it would hold the output device and block Qji playback)
if systemctl is-active --quiet shairport-sync 2>/dev/null; then
    echo "ℹ System shairport-sync service is running — stopping it..."
    sudo systemctl stop shairport-sync 2>/dev/null
    sleep 1
fi
pkill -x shairport-sync 2>/dev/null
sleep 1

DEVICE_NAME="Qji 奏在"

# 1) Start shairport-sync pointed at the ALSA loopback input
SPS_LOG="/tmp/qji_shairport.log"
shairport-sync -a "$DEVICE_NAME" -o alsa -- -d "${LOOPBACK_IN}" > "$SPS_LOG" 2>&1 &
SPS_PID=$!
sleep 2

if ! kill -0 "$SPS_PID" 2>/dev/null; then
    echo "❌ shairport-sync failed to start. Log:"
    echo "──────────────────────────────────────────"
    tail -n 30 "$SPS_LOG"
    echo "──────────────────────────────────────────"
    read -rp "Press Enter to close..." _
    exit 1
fi
echo "  ✓ shairport-sync started (PID $SPS_PID) — device name: $DEVICE_NAME"

# 2) Loopback output → ffmpeg (Musikverein filter) → DAC
FF_LOG="/tmp/qji_airplay_ffmpeg.log"
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
    kill "$SPS_PID" 2>/dev/null
    read -rp "Press Enter to close..." _
    exit 1
fi
echo "  ✓ Playback pipeline started (PID $FF_PID)"
echo ""
echo "  Select \"$DEVICE_NAME\" as AirPlay output on your iPhone / Mac."
echo ""

set +e
wait
read -rp "Press Enter to close..." _
