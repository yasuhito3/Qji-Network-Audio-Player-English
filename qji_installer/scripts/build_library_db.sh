#!/bin/bash
# ============================================================
# Qji 奏在 — Build Music Library DB (music_mood_db.json)
# ============================================================

if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    for _t in xfce4-terminal lxterminal mate-terminal xterm gnome-terminal konsole qterminal; do
        command -v "$_t" &>/dev/null && break
    done
    case "$_t" in
        xfce4-terminal) exec "$_t" --disable-server -T "🗄 Build Music Library" -x bash "$0" "$@" ;;
        gnome-terminal) exec "$_t" --title "🗄 Build Music Library" -- bash "$0" "$@" ;;
        *)              exec "$_t" -T "🗄 Build Music Library" -e bash "$0" "$@" ;;
    esac
    exit $?
fi

QJI_DIR="$HOME/qji"
MARKER="$HOME/.qji_library_scanned"

# Locate the XDG Music folder
MUSIC_XDG="$(xdg-user-dir MUSIC 2>/dev/null)"
[ -z "$MUSIC_XDG" ] && MUSIC_XDG="$HOME/Music"

# Fallback if $USER is not set
QJI_USER="${USER:-$(whoami)}"

# Build list of directories to scan (existing only)
SCAN_DIRS=()
[ -d "$MUSIC_XDG" ] && SCAN_DIRS+=("$MUSIC_XDG")
[ -d "$HOME/Music" ] && [ "$HOME/Music" != "$MUSIC_XDG" ] && SCAN_DIRS+=("$HOME/Music")
[ -d "/media/$QJI_USER" ] && SCAN_DIRS+=("/media/$QJI_USER")
[ -d "/run/media/$QJI_USER" ] && SCAN_DIRS+=("/run/media/$QJI_USER")
[ -d "/media" ] && SCAN_DIRS+=("/media")
[ -d "/mnt" ] && SCAN_DIRS+=("/mnt")
[ -d "/run/user/$(id -u)/gvfs" ] && SCAN_DIRS+=("/run/user/$(id -u)/gvfs")

# Remove duplicate / nested paths (e.g. /media and /media/$USER)
UNIQ_DIRS=()
for d in "${SCAN_DIRS[@]}"; do
    skip=0
    for u in "${UNIQ_DIRS[@]}"; do
        case "$d/" in "$u"/*) skip=1; break;; esac
    done
    [ $skip -eq 0 ] && UNIQ_DIRS+=("$d")
done
SCAN_DIRS=("${UNIQ_DIRS[@]}")

# If a directory argument was given, use that instead
if [ -n "$1" ]; then
    SCAN_DIRS=("$1")
fi

clear
LOG_FILE="$QJI_DIR/library_build_debug.log"
exec > >(tee "$LOG_FILE") 2>&1

echo "╔══════════════════════════════════════════════════╗"
echo "║   🗄  Qji 奏在 — Build Music Library DB           ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Scan targets:"
for d in "${SCAN_DIRS[@]}"; do
    echo "    - $d"
done
echo "  Output : ~/music_mood_db.json"
echo "  Log    : $LOG_FILE  ← contents can be copied"
echo ""

# ── Pre-check: count supported audio files ──────────────────
echo "▶ Pre-check (supported audio files found):"
EXTS="flac mp3 wav m4a aac ogg wma aiff aif dsf dff ape opus"
FIND_EXPR=()
for e in $EXTS; do
    FIND_EXPR+=(-iname "*.${e}" -o)
done
unset 'FIND_EXPR[${#FIND_EXPR[@]}-1]'  # remove trailing -o

TOTAL=0
for d in "${SCAN_DIRS[@]}"; do
    cnt=$(find "$d" -type f \( "${FIND_EXPR[@]}" \) 2>/dev/null | wc -l)
    echo "    $d : ${cnt} file(s)"
    TOTAL=$((TOTAL + cnt))
done
echo "    Total: ${TOTAL} file(s)"
echo ""

if [ "$TOTAL" -eq 0 ]; then
    echo "⚠ No supported audio files found."
    echo ""
    echo "  Contents of /media, /run/user/$(id -u)/gvfs:"
    echo "──────────────────────────────────────────────────"
    for p in "/media" "/media/$QJI_USER" "/run/media/$QJI_USER" "/run/user/$(id -u)/gvfs"; do
        if [ -d "$p" ]; then
            echo "  $p :"
            ls -la "$p" 2>/dev/null | sed 's/^/    /'
        fi
    done
    echo ""
    echo "  Current mount points"
    echo "──────────────────────────────────────────────────"
    mount | grep -E "/media|/mnt|gvfs|AudioFiles" | sed 's/^/    /'
    echo "──────────────────────────────────────────────────"
    echo ""
    read -rp "Press Enter to close..." _
    exit 1
fi

echo "  Note: the first run may take a while for large libraries"
echo "  (API lookups add a short wait per track)."
echo "  Press Ctrl+C to interrupt at any time."
echo "  (Progress is saved up to the point of interruption.)"
echo ""
echo "──────────────────────────────────────────────────"
echo ""

python3 "$QJI_DIR/scripts/music_library_analyzer.py" --dirs "${SCAN_DIRS[@]}" --no-wait
EXIT_CODE=$?

echo ""
echo "──────────────────────────────────────────────────"
if [ $EXIT_CODE -eq 0 ]; then
    touch "$MARKER"
    echo "✅ Music library DB built successfully."
    echo "   Launch Qji 奏在 and enjoy!"
else
    echo "⚠ Exit code: $EXIT_CODE"
    echo "   An error occurred or the build was interrupted."
    echo "   Run this again to resume from where it left off."
fi
echo ""
read -rp "Press Enter to close..." _
