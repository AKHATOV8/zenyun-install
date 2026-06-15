#!/usr/bin/env bash
# Create a clean distribution archive from the local ZenyunVPN project (macOS/Linux).
# Usage: ./pack-release.sh [version]   (default: v1.2.0)
set -euo pipefail

VERSION="${1:-v1.2.0}"
PROJECT_DIR="${PROJECT_DIR:-$HOME/Desktop/zenyun vpn proxy}"
OUTPUT="${OUTPUT:-$HOME/Desktop/zenyun-vpn-${VERSION}.tar.gz}"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Project directory not found: $PROJECT_DIR" >&2
  exit 1
fi

cd "$PROJECT_DIR"

# --no-xattrs: omit macOS extended attributes (avoids LIBARCHIVE.xattr warnings on Linux)
tar -czf "$OUTPUT" \
  --no-xattrs \
  --exclude='.env' \
  --exclude='backups' \
  --exclude='logs' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='.git' \
  --exclude='.deploy_key' \
  --exclude='.deploy_key.pub' \
  --exclude='.DS_Store' \
  --exclude='*.log' \
  --exclude='*.sqlite' \
  --exclude='*.tar.gz' \
  .

echo "Archive: $OUTPUT"
shasum -a 256 "$OUTPUT"
