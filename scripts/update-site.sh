#!/usr/bin/env bash
# Build Zimodem and lay out an AT&U update site on disk:
#   <stem>-latest-version.txt         the version AT&U / AT&U6502 installs
#   <stem>-firmware-<version>.bin     the image (earlier ones are kept, for AT&U=<version>)
#   <stem>-firmware-<version>.txt     its build-info.txt
# Serve the directory over plain HTTP, e.g.
#   python3 -m http.server 8000 -d build/update-site
# and point the modem at it with AT&U"http://<host>:8000" then AT&W (a
# Frankless build defaults to http://claude-box.seg9.com:8000).
#
# Environment overrides:
#   SITE_DIR    the update site directory   (default: $BUILD_DIR/update-site)
#   NO_BUILD    set to 1 to publish the existing build instead of building
#   BUILD_DIR, BUILD_ID, FQBN, SKETCH       passed to scripts/build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="${BUILD_DIR:-build}"
SITE_DIR="${SITE_DIR:-$BUILD_DIR/update-site}"
export BUILD_DIR

[[ "${NO_BUILD:-}" == 1 ]] || scripts/build.sh

info() { sed -n "s/^$1=//p" "$BUILD_DIR/build-info.txt"; }
version="$(info firmware_version)"
stem="$(info update_stem)"
sketch_name="$(basename "$(info sketch)")"
if [[ -z "$stem" || -z "$version" ]]; then
  echo "error: no update_stem/firmware_version in $BUILD_DIR/build-info.txt" \
       "(is INCLUDE_OTH_UPDATES on?)" >&2
  exit 1
fi

mkdir -p "$SITE_DIR"
cp "$BUILD_DIR/$sketch_name.ino.bin" "$SITE_DIR/$stem-firmware-$version.bin"
cp "$BUILD_DIR/build-info.txt" "$SITE_DIR/$stem-firmware-$version.txt"
# Written last, so a modem never sees a version whose image is not there yet.
printf '%s\n' "$version" > "$SITE_DIR/$stem-latest-version.txt.tmp"
mv "$SITE_DIR/$stem-latest-version.txt.tmp" "$SITE_DIR/$stem-latest-version.txt"

echo "Update site: $SITE_DIR (latest $version)"
ls -l "$SITE_DIR"
