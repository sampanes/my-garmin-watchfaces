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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -W)"
REPO="$(cd -- "$SCRIPT_DIR/.." && pwd -W)"

SDK="${CONNECTIQ_SDK_PATH:-}"
if [[ -z "$SDK" ]]; then
  if [[ -z "${APPDATA:-}" ]]; then
    echo "APPDATA is not set; set CONNECTIQ_SDK_PATH to the Connect IQ SDK directory." >&2
    exit 1
  fi

  APPDATA_POSIX="${APPDATA//\\//}"
  shopt -s nullglob
  SDK_CANDIDATES=("$APPDATA_POSIX/Garmin/ConnectIQ/Sdks"/connectiq-sdk-win-*)
  shopt -u nullglob
  if (( ${#SDK_CANDIDATES[@]} == 0 )); then
    echo "No Connect IQ SDK found; set CONNECTIQ_SDK_PATH." >&2
    exit 1
  fi

  SDK="${SDK_CANDIDATES[0]}"
  for candidate in "${SDK_CANDIDATES[@]:1}"; do
    [[ "$candidate" -nt "$SDK" ]] && SDK="$candidate"
  done
fi

KEY="${MONKEYC_DEVELOPER_KEY:-}"
if [[ -z "$KEY" ]]; then
  if [[ -z "${USERPROFILE:-}" ]]; then
    echo "USERPROFILE is not set; set MONKEYC_DEVELOPER_KEY to the developer key path." >&2
    exit 1
  fi
  KEY="${USERPROFILE//\\//}/MonkeyC/developer_key"
fi

SDK="${SDK//\\//}"
KEY="${KEY//\\//}"
DEVICE="fr265"
PRG="$REPO/bin/mygarminwatchfaces.prg"
JUNGLE="$REPO/monkey.jungle"
CAPTURE_PS1="$REPO/watch-faces/japanese-ink-heartrate/art/checkpoints/procedural/save-sim-capture.ps1"

[[ -f "$SDK/bin/monkeyc.bat" ]] || { echo "Connect IQ compiler not found under $SDK." >&2; exit 1; }
[[ -f "$KEY" ]] || { echo "Developer key not found; set MONKEYC_DEVELOPER_KEY." >&2; exit 1; }
mkdir -p "$(dirname -- "$PRG")"

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
