#!/usr/bin/env bash
# Download standalone developer tool tarballs / AppImages / RPMs that are not
# mirrored in Nexus and drop them into the matching role's files/ directory.
#
# Usage:
#   bash tools/download-tools.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

POSTMAN_DIR="$REPO_ROOT/roles/app_postman/files"
NEXTCLOUD_DIR="$REPO_ROOT/roles/app_nextcloud/files"
KEEPASSXC_DIR="$REPO_ROOT/roles/app_keepassxc/files"
mkdir -p "$POSTMAN_DIR" "$NEXTCLOUD_DIR" "$KEEPASSXC_DIR"

curl_opts=( --fail --location --retry 3 --connect-timeout 15 --show-error )

github_latest_tag() {
  local repo="$1"
  curl "${curl_opts[@]}" -s "https://api.github.com/repos/${repo}/releases/latest" \
    | grep -oE '"tag_name":\s*"[^"]+"' \
    | head -1 \
    | sed -E 's/.*"([^"]+)"$/\1/'
}

# ---- Postman ----------------------------------------------------------------

echo ">>> Cleaning previous Postman tarballs in $POSTMAN_DIR"
find "$POSTMAN_DIR" -maxdepth 1 -name 'Postman-*.tar.gz' -delete 2>/dev/null || true

echo ">>> Downloading latest Postman Linux x64 tarball"
curl "${curl_opts[@]}" \
  --remote-header-name --remote-name --output-dir "$POSTMAN_DIR" \
  https://dl.pstmn.io/download/latest/linux_64

# ---- Nextcloud desktop client ----------------------------------------------

echo ">>> Cleaning previous Nextcloud AppImages in $NEXTCLOUD_DIR"
find "$NEXTCLOUD_DIR" -maxdepth 1 -name 'Nextcloud-*-x86_64.AppImage' -delete 2>/dev/null || true

NC_TAG="$(github_latest_tag nextcloud/desktop)"
NC_VER="${NC_TAG#v}"
NC_FILE="Nextcloud-${NC_VER}-x86_64.AppImage"
echo ">>> Downloading Nextcloud ${NC_VER}"
curl "${curl_opts[@]}" \
  --output "$NEXTCLOUD_DIR/$NC_FILE" \
  "https://github.com/nextcloud/desktop/releases/download/${NC_TAG}/${NC_FILE}"

# ---- KeePassXC --------------------------------------------------------------

echo ">>> Cleaning previous KeePassXC AppImages in $KEEPASSXC_DIR"
find "$KEEPASSXC_DIR" -maxdepth 1 -name 'KeePassXC-*-x86_64.AppImage' -delete 2>/dev/null || true

KPXC_TAG="$(github_latest_tag keepassxreboot/keepassxc)"
KPXC_VER="${KPXC_TAG#v}"
KPXC_FILE="KeePassXC-${KPXC_VER}-x86_64.AppImage"
echo ">>> Downloading KeePassXC ${KPXC_VER}"
curl "${curl_opts[@]}" \
  --output "$KEEPASSXC_DIR/$KPXC_FILE" \
  "https://github.com/keepassxreboot/keepassxc/releases/download/${KPXC_TAG}/${KPXC_FILE}"

echo ""
echo "Done."
echo ""
echo "Postman files:"
ls -lh "$POSTMAN_DIR" | grep -v '^total\|\.gitkeep' || true
echo ""
echo "Nextcloud files:"
ls -lh "$NEXTCLOUD_DIR" | grep -v '^total\|\.gitkeep' || true
echo ""
echo "KeePassXC files:"
ls -lh "$KEEPASSXC_DIR" | grep -v '^total\|\.gitkeep' || true
