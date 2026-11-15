#!/usr/bin/env bash
# Install a pinned arduino-cli and ESP8266 Arduino core for building Zimodem.
#
# Versions come from toolchain.env; any of its variables can be overridden
# from the environment (e.g. ESP8266_CORE_VERSION=3.1.2 to try another core).
#
# Everything goes under the repo by default (.arduino15/, git-ignored), so
# nothing is installed system-wide. Environment overrides:
#   INSTALL_DIR                  where arduino-cli is placed (default: .arduino15/bin)
#   ARDUINO_DIRECTORIES_DATA     arduino-cli data dir        (default: .arduino15)
#   ARDUINO_DIRECTORIES_DOWNLOADS                            (default: .arduino15/staging)
#   ARDUINO_DIRECTORIES_USER     sketchbook/libraries dir    (default: .arduino-user)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh"

cli="$INSTALL_DIR/arduino-cli"
if ! "$cli" version 2>/dev/null | grep -q "Version: $ARDUINO_CLI_VERSION "; then
  tarball="arduino-cli_${ARDUINO_CLI_VERSION}_Linux_64bit.tar.gz"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -sSfL -o "$tmp/$tarball" \
    "https://github.com/arduino/arduino-cli/releases/download/v${ARDUINO_CLI_VERSION}/$tarball"
  echo "$ARDUINO_CLI_SHA256  $tmp/$tarball" | sha256sum -c -
  mkdir -p "$INSTALL_DIR"
  tar -xzf "$tmp/$tarball" -C "$INSTALL_DIR" arduino-cli
fi
"$cli" version

CLI=("$cli" --config-file "$ROOT/arduino-cli.yaml")
"${CLI[@]}" core update-index
"${CLI[@]}" core install "esp8266:esp8266@${ESP8266_CORE_VERSION}"
"${CLI[@]}" core list
