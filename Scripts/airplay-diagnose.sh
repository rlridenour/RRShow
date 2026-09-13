#!/bin/bash
#
# airplay-diagnose.sh — why did the Mac's AirPlay display drop?
#
# Mac AirPlay carries an entire display over AWDL, Apple's peer-to-peer Wi-Fi
# link. When AWDL gets into trouble the display drops, and no application can
# prevent it or even see it happen. This tells you whether that is what hit you.
#
# The unified log is retroactive, so run this AFTER a drop — there is no need to
# start a capture and wait for one. Info- and debug-level messages are where the
# Wi-Fi detail lives, hence --info --debug.
#
# Usage:
#   Scripts/airplay-diagnose.sh            # last 60 minutes
#   Scripts/airplay-diagnose.sh 120        # last 2 hours
#   Scripts/airplay-diagnose.sh 60 --save  # also write the full log to a file
#
set -uo pipefail

MINUTES="${1:-60}"
SAVE=""
[[ "${2:-}" == "--save" ]] && SAVE="$HOME/Desktop/airplay-$(date +%Y%m%d-%H%M%S).log"

if ! [[ "$MINUTES" =~ ^[0-9]+$ ]]; then
    echo "usage: $(basename "$0") [minutes] [--save]" >&2
    exit 2
fi

PRED='eventMessage CONTAINS[c] "awdl" OR eventMessage CONTAINS[c] "airplay" OR subsystem CONTAINS "airplay"'
RAW="$(mktemp -t airplay-diagnose)"
trap 'rm -f "$RAW"' EXIT

echo "Reading the last ${MINUTES} minutes of the unified log…"
log show --last "${MINUTES}m" --info --debug --style compact --predicate "$PRED" > "$RAW" 2>/dev/null

TOTAL=$(wc -l < "$RAW" | tr -d ' ')
if [[ "$TOTAL" -lt 2 ]]; then
    echo
    echo "No AirPlay or AWDL activity recorded in that window."
    echo "Either nothing was streaming, or the window is older than the log retains."
    exit 0
fi
echo "  ${TOTAL} lines of AirPlay / AWDL activity"
echo

# The smoking gun: the Wi-Fi layer failing, repeatedly, to register the AirPlay
# traffic stream. Seen at several hundred per minute during a bad spell.
REG_FAIL=$(grep -c "Failed to recover traffic registration" "$RAW" || true)

# Another device flooding the AWDL channel.
BAD_PEER=$(grep -c "Bad Peer" "$RAW" || true)

echo "Wi-Fi layer"
echo "  traffic-registration failures : ${REG_FAIL}"
echo "  'Bad Peer' action-frame floods: ${BAD_PEER}"

if [[ "$REG_FAIL" -gt 0 ]]; then
    echo
    echo "  When they happened (per minute):"
    grep "Failed to recover traffic registration" "$RAW" \
        | awk '{print "    " substr($2,1,5)}' | uniq -c | awk '{print "   " $2 "  " $1 " errors"}' \
        | tail -25
    echo
    echo "  Example:"
    grep -m1 "Failed to recover traffic registration" "$RAW" | cut -c1-200 | sed 's/^/    /'
fi

echo
echo "Verdict"
if [[ "$REG_FAIL" -gt 20 ]]; then
    cat <<'VERDICT'
  AWDL was failing to carry the AirPlay stream. This is below anything an
  app touches — RRShow cannot cause it and cannot work around it.

  What actually helps:
    - Use HDMI for anything that matters. A lecture should not ride on
      peer-to-peer Wi-Fi.
    - Turn Bluetooth off on the Mac while presenting. AWDL and Bluetooth
      share a radio, and coexistence is the usual source of this error.
    - Set AirDrop to "Receiving Off", which stops a lot of AWDL churn.
    - A high 'Bad Peer' count means a nearby device is flooding the
      channel — often a fixture of one particular room.
VERDICT
else
    cat <<'VERDICT'
  No sign of AWDL trouble in this window. If the display still dropped,
  the cause is somewhere else — capture a wider window with a larger
  [minutes] argument, or re-run right after the next drop.
VERDICT
fi

if [[ -n "$SAVE" ]]; then
    cp "$RAW" "$SAVE"
    echo
    echo "Full log written to $SAVE"
fi
