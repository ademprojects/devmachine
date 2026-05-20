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

assert_nonempty() {
  # Usage: assert_nonempty <path> <context>
  local f="$1" ctx="$2"
  [[ -s "$f" ]] || { echo "ERROR: empty/missing download: $f ($ctx)" >&2; exit 1; }
}

github_latest_tag() {
  # Resolves the latest release tag for a GitHub repo. Set GH_TOKEN in the env
  # to authenticate the call (unauth limit: 60 requests/hour per IP).
  local repo="$1"
  local api_url="https://api.github.com/repos/${repo}/releases/latest"
  local auth=()
  [[ -n "${GH_TOKEN:-}" ]] && auth=( -H "Authorization: Bearer ${GH_TOKEN}" )
  local tag
  tag=$(curl "${curl_opts[@]}" -s "${auth[@]}" "$api_url" \
    | grep -oE '"tag_name":\s*"[^"]+"' \
    | head -1 \
    | sed -E 's/.*"([^"]+)"$/\1/')
  if [[ -z "$tag" ]]; then
    echo "ERROR: could not resolve latest tag for ${repo} via ${api_url}" >&2
    echo "       (GitHub API may be rate-limited — export GH_TOKEN with a personal access token)" >&2
    return 1
  fi
  printf '%s' "$tag"
}

# ---- Postman ----------------------------------------------------------------

echo ">>> Cleaning previous Postman tarballs in $POSTMAN_DIR"
find "$POSTMAN_DIR" -maxdepth 1 -name 'Postman-*.tar.gz' -delete 2>/dev/null || true

echo ">>> Downloading latest Postman Linux x64 tarball"
postman_saved=$(curl "${curl_opts[@]}" \
  --remote-header-name --remote-name --output-dir "$POSTMAN_DIR" \
  --write-out '%{filename_effective}' \
  https://dl.pstmn.io/download/latest/linux_64)
assert_nonempty "$postman_saved" "Postman"

# ---- Nextcloud desktop client ----------------------------------------------

echo ">>> Cleaning previous Nextcloud AppImages in $NEXTCLOUD_DIR"
find "$NEXTCLOUD_DIR" -maxdepth 1 -name 'Nextcloud-*-x86_64.AppImage' -delete 2>/dev/null || true

NC_TAG="$(github_latest_tag nextcloud/desktop)" || exit 1
NC_VER="${NC_TAG#v}"
NC_FILE="Nextcloud-${NC_VER}-x86_64.AppImage"
echo ">>> Downloading Nextcloud ${NC_VER}"
curl "${curl_opts[@]}" \
  --output "$NEXTCLOUD_DIR/$NC_FILE" \
  "https://github.com/nextcloud/desktop/releases/download/${NC_TAG}/${NC_FILE}"
assert_nonempty "$NEXTCLOUD_DIR/$NC_FILE" "Nextcloud $NC_VER"

# ---- KeePassXC --------------------------------------------------------------

echo ">>> Cleaning previous KeePassXC AppImages in $KEEPASSXC_DIR"
find "$KEEPASSXC_DIR" -maxdepth 1 -name 'KeePassXC-*-x86_64.AppImage' -delete 2>/dev/null || true

KPXC_TAG="$(github_latest_tag keepassxreboot/keepassxc)" || exit 1
KPXC_VER="${KPXC_TAG#v}"
KPXC_FILE="KeePassXC-${KPXC_VER}-x86_64.AppImage"
echo ">>> Downloading KeePassXC ${KPXC_VER}"
curl "${curl_opts[@]}" \
  --output "$KEEPASSXC_DIR/$KPXC_FILE" \
  "https://github.com/keepassxreboot/keepassxc/releases/download/${KPXC_TAG}/${KPXC_FILE}"
assert_nonempty "$KEEPASSXC_DIR/$KPXC_FILE" "KeePassXC $KPXC_VER"

echo ""
echo "Done."
echo ""
echo "Postman files:"
ls -lh "$POSTMAN_DIR" | grep -Ev '^total|\.gitkeep' || true
echo ""
echo "Nextcloud files:"
ls -lh "$NEXTCLOUD_DIR" | grep -Ev '^total|\.gitkeep' || true
echo ""
echo "KeePassXC files:"
ls -lh "$KEEPASSXC_DIR" | grep -Ev '^total|\.gitkeep' || true
echo ""
echo "SHA256 (paste into host_vars / role defaults if pinning):"
find "$POSTMAN_DIR" "$NEXTCLOUD_DIR" "$KEEPASSXC_DIR" -type f ! -name '.gitkeep' -print0 \
  | sort -z | xargs -0 -r sha256sum
