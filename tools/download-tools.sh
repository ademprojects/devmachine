#!/usr/bin/env bash
# Download standalone developer tool tarballs / RPMs that are not mirrored in
# Nexus and drop them into the matching role's files/ directory.
#
# Usage:
#   bash tools/download-tools.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

POSTMAN_DIR="$REPO_ROOT/roles/app_postman/files"
mkdir -p "$POSTMAN_DIR"

curl_opts=( --fail --location --retry 3 --connect-timeout 15 --show-error )

echo ">>> Cleaning previous Postman tarballs in $POSTMAN_DIR"
find "$POSTMAN_DIR" -maxdepth 1 -name 'Postman-*.tar.gz' -delete 2>/dev/null || true

echo ">>> Downloading latest Postman Linux x64 tarball"
curl "${curl_opts[@]}" \
  --remote-header-name --remote-name --output-dir "$POSTMAN_DIR" \
  https://dl.pstmn.io/download/latest/linux_64

echo ""
echo "Done."
echo ""
echo "Postman files:"
ls -lh "$POSTMAN_DIR" | grep -v '^total\|\.gitkeep'
