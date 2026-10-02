#!/bin/bash
set -euo pipefail

REPO="https://github.com/Kasys/ProxmoxBox/archive/refs/heads/main.tar.gz"
INSTALL_DIR="/root/ProxmoxBox"

echo "Downloading ProxmoxBox..."

mkdir -p /root

TMP=$(mktemp -d)

curl -L "$REPO" -o "$TMP/repo.tar.gz"

echo "Extracting..."

tar -xzf "$TMP/repo.tar.gz" -C "$TMP"

rm -rf "$INSTALL_DIR"
mv "$TMP/ProxmoxBox-main" "$INSTALL_DIR"

rm -rf "$TMP"

echo "Making scripts executable..."

find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} \;

if [ "${BOOTSTRAP_SKIP_SETUP+x}" ]; then
    exit 0
fi

echo "Running setup.sh..."

cd "$INSTALL_DIR"
./setup.sh

echo "Done!"