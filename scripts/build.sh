#!/usr/bin/env bash
# Build Zimodem with arduino-cli (no Arduino IDE required).
#
# The default board is a 4 MB ESP-12F (AI-Thinker or "ESP8266MOD"): Generic
# ESP8266 module, 160 MHz, DIO flash (the stock AT firmware's mode, which
# every module boots), 4 MB with a 1 MB filesystem for SPIFFS. The README
# suggests 1M/160k, which is for the 1 MB ESP-01.
#
# Environment overrides:
#   SKETCH      sketch directory            (default: zimodem)
#   FQBN        fully qualified board name  (default: see above)
#   BUILD_DIR   output directory            (default: build)
#   BUILD_ID    digits appended to the version, 4.0.3-<BUILD_ID>, which AT&U
#               compares against the update site (default: UTC YYYYMMDDHHMMSS)
#   ARDUINO_CLI arduino-cli binary          (default: .arduino15/bin/arduino-cli)
#   FRANKLESS_HW_FLOW  0: the Frankless build's CTS/RTS on GPIO5/GPIO4 in
#               software (the older J8 wiring), set by ATS49/ATS51; unset or
#               1: fixed on GPIO13/GPIO15, the UART's own (see BUILDING.md)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh"

SKETCH="${SKETCH:-zimodem}"
FQBN="${FQBN:-esp8266:esp8266:generic:xtal=160,FlashMode=dio,FlashFreq=40,eesz=4M1M,ResetMethod=nodemcu}"
BUILD_DIR="${BUILD_DIR:-build}"
CLI=("$ARDUINO_CLI" --config-file "$ROOT/arduino-cli.yaml")

sketch_name="$(basename "$SKETCH")"
ino="$SKETCH/$sketch_name.ino"
base_version="$(sed -n 's/^#define[[:space:]]\+ZIMODEM_VERSION[[:space:]]\+"\(.*\)".*/\1/p' "$ino")"
BUILD_ID="${BUILD_ID:-$(date -u +%Y%m%d%H%M%S)}"
if [[ ! "$BUILD_ID" =~ ^[0-9]+$ ]]; then
  # AT&U=<version> stops reading an unquoted version at the first letter.
  echo "error: BUILD_ID must be digits only (got '$BUILD_ID')" >&2
  exit 1
fi
version="$base_version-$BUILD_ID"

mkdir -p "$BUILD_DIR"

git_sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
git_describe="$(git describe --always --dirty 2>/dev/null || echo unknown)"
build_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

"${CLI[@]}" compile \
  --fqbn "$FQBN" \
  --build-path "$BUILD_DIR/work" \
  --output-dir "$BUILD_DIR" \
  --warnings default \
  --build-property "compiler.cpp.extra_flags=-DZIMODEM_BUILD_ID=$BUILD_ID${FRANKLESS_HW_FLOW:+ -DFRANKLESS_HW_FLOW=$FRANKLESS_HW_FLOW}" \
  "$SKETCH" 2>&1 | tee "$BUILD_DIR/compile.log"

# The AT&U file stem, from the firmware's "/%s%s<stem>-latest-version.txt".
update_stem="$(grep -a -o '%s%s[A-Za-z0-9_]*-latest-version\.txt' "$BUILD_DIR/$sketch_name.ino.bin" \
  | head -1 | sed 's/^%s%s//; s/-latest-version\.txt$//')"

core_version="$("${CLI[@]}" core list --json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((p["installed_version"] for p in d.get("platforms",[]) if p["id"]=="esp8266:esp8266"),"unknown"))')"

{
  echo "firmware_version=$version"
  echo "build_id=$BUILD_ID"
  echo "update_stem=$update_stem"
  echo "sketch=$SKETCH"
  echo "fqbn=$FQBN"
  echo "frankless_hw_flow=${FRANKLESS_HW_FLOW:-default}"
  echo "esp8266_core=$core_version"
  echo "arduino_cli=$("$ARDUINO_CLI" version | head -1)"
  echo "git_sha=$git_sha"
  echo "git_describe=$git_describe"
  echo "build_date=$build_date"
} > "$BUILD_DIR/build-info.txt"

cat "$BUILD_DIR/build-info.txt"
ls -l "$BUILD_DIR/$sketch_name.ino.bin"
