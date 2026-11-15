# Shared environment for scripts/*.sh (sourced, not run). Sets ROOT-relative
# defaults for the arduino-cli install and data dirs, and loads toolchain.env
# without clobbering values already set in the environment.

while IFS='=' read -r key value; do
  [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
  [[ -n "${!key:-}" ]] || printf -v "$key" '%s' "$value"
done < "$ROOT/toolchain.env"

export ARDUINO_DIRECTORIES_DATA="${ARDUINO_DIRECTORIES_DATA:-$ROOT/.arduino15}"
export ARDUINO_DIRECTORIES_DOWNLOADS="${ARDUINO_DIRECTORIES_DOWNLOADS:-$ARDUINO_DIRECTORIES_DATA/staging}"
export ARDUINO_DIRECTORIES_USER="${ARDUINO_DIRECTORIES_USER:-$ROOT/.arduino-user}"
INSTALL_DIR="${INSTALL_DIR:-$ARDUINO_DIRECTORIES_DATA/bin}"
ARDUINO_CLI="${ARDUINO_CLI:-$INSTALL_DIR/arduino-cli}"
