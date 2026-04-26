#!/usr/bin/env bash
# Build + push (+ optionally capture) for the japanese-ink-heartrate watch face.
#
# Usage:
#   bash scripts/build-and-run.sh
#       -> build + push only (sim must already be running)
#
#   bash scripts/build-and-run.sh <absolute-png-path>
#       -> build + push + screenshot to the given path
#
# PRECONDITION — the simulator must already be running. Launch it once per
# session via:
#
#   "$SDK/bin/connectiq.bat"
#
# The simulator window is blank until monkeydo pushes the .prg — expected.
#
# Device id is `fr265`. `fr265_sim` is a VS Code F5-only target; CLI monkeydo
# triggers an "unable to load device" popup if you use it. See PROCEDURE.md §7.

set -euo pipefail

SDK="C:/Users/John/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b"
REPO="c:/Users/John/Documents/Personal_Projects/my-garmin-watchfaces"
KEY="C:/Users/John/MonkeyC/developer_key"
DEVICE="fr265"
PRG="$REPO/bin/mygarminwatchfaces.prg"
JUNGLE="$REPO/monkey.jungle"
CAPTURE_PS1="$REPO/watch-faces/japanese-ink-heartrate/art/checkpoints/procedural/save-sim-capture.ps1"

CAPTURE_PATH="${1:-}"

echo "[build] monkeyc -> $PRG  (device $DEVICE)"
"$SDK/bin/monkeyc.bat" \
  -o "$PRG" \
  -f "$JUNGLE" \
  -y "$KEY" \
  -d "$DEVICE" \
  -w -l 2

echo "[push]  monkeydo -> $DEVICE  (backgrounded; monkeydo holds a debug session open)"
"$SDK/bin/monkeydo.bat" "$PRG" "$DEVICE" >/dev/null 2>&1 &
MONKEYDO_PID=$!

# Give the simulator time to receive the push and render.
sleep 4

if [[ -n "$CAPTURE_PATH" ]]; then
  echo "[capture] $CAPTURE_PATH"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$CAPTURE_PS1" -OutputPath "$CAPTURE_PATH"
fi

# monkeydo stays resident as a debug session; nothing further to do.
# It'll get cleaned up when the sim closes or the session ends.
echo "[done] monkeydo pid=$MONKEYDO_PID left in background"
