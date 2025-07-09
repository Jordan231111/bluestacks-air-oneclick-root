#!/bin/bash
# Simple installer/launcher for BlueStacks Air rooting tool.
# Usage (SIP disabled):
#   bash <(curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/installer.sh) root
# Usage (SIP enabled):
#   bash <(curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/installer.sh) manual

set -euo pipefail

# Constants
REPO_URL="https://github.com/Jordan231111/bluestacks-air-oneclick-root"
WORK_DIR="/tmp/root-bluestacks-air-$$"

function usage() {
  cat <<EOF
BlueStacks Air Root Installer

This script bootstraps the rooting process with one command. It clones the
latest version of the rooting repository to a temporary directory, then runs
the unified tool with the appropriate options.

Usage:
  installer.sh [root|manual|unroot]

Commands:
  root     Perform an automatic root (requires SIP disabled; uses sudo).
  manual   Generate a patched initrd for SIP-enabled systems.
  unroot   Restore original initrd (requires sudo).
EOF
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

CMD="$1"
shift || true

# Ensure curl and git are available
for bin in git curl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "[!] $bin is required but not installed. Aborting." >&2
    exit 1
  fi
done

# Clone repo quietly
if [[ -d "$WORK_DIR" ]]; then
  rm -rf "$WORK_DIR"
fi

echo "[*] Cloning repository..."
GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 "$REPO_URL" "$WORK_DIR"

cd "$WORK_DIR"
chmod +x bluestacks-air-tool.sh

echo "[*] Running command: $CMD"
case "$CMD" in
  root)
    sudo ./bluestacks-air-tool.sh root "$@" ;;
  manual)
    ./bluestacks-air-tool.sh root -o ./initrd_hvf.img.patched "$@"
    echo "\n[!] Manual mode complete. The patched file is at: $WORK_DIR/initrd_hvf.img.patched" ;;
  unroot)
    sudo ./bluestacks-air-tool.sh unroot "$@" ;;
  *)
    echo "Invalid command: $CMD" >&2
    usage
    exit 1 ;;
esac

echo "[*] Cleaning up..."
rm -rf "$WORK_DIR"

echo "[*] Done." 