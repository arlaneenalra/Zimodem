#!/usr/bin/env bash
# Run the pinned arduino-cli with this repo's config and data dirs, e.g.
#   scripts/cli.sh board details -b esp8266:esp8266:generic
#   scripts/cli.sh upload -p /dev/ttyUSB0 -b <fqbn> --input-dir build zimodem
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh"
exec "$ARDUINO_CLI" --config-file "$ROOT/arduino-cli.yaml" "$@"
