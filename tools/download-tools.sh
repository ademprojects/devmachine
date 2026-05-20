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

# Returns the most recently modified non-.gitkeep file in $1. Used to find
# the file curl just wrote via --remote-header-name --remote-name (older
# curls report the wrong filename via --write-out %{filename_effective}).
newest_in() {
  find "$1" -maxdepth 1 -type f ! -name '.gitkeep' -printf '%T@ %p\n' \
    | sort -rn | head -1 | cut -d' ' -f2-
}

# Wipes everything in $1 except .gitkeep. Each role's files/ dir is
# dedicated, so this is safe and lets us avoid the curl --remote-header-name
# "won't overwrite" failure when upstream filenames change between runs
# (e.g. Postman renamed Postman-linux-x64-<ver>.tar.gz to
# postman-linux-x64.tar.gz without a version segment).
cleanup_dir() {
  find "$1" -maxdepth 1 -type f ! -name '.gitkeep' -delete 2>/dev/null || true
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

echo ">>> Cleaning previous Postman files in $POSTMAN_DIR"
cleanup_dir "$POSTMAN_DIR"

echo ">>> Downloading latest Postman Linux x64 tarball"
(cd "$POSTMAN_DIR" && curl "${curl_opts[@]}" \
  --remote-header-name --remote-name \
  https://dl.pstmn.io/download/latest/linux_64)
postman_saved=$(newest_in "$POSTMAN_DIR")
assert_nonempty "$postman_saved" "Postman"

# ---- Nextcloud desktop client ----------------------------------------------
# Binaries live in nextcloud-releases/desktop, not the source repo
# nextcloud/desktop (the source repo's releases have no attached assets).

echo ">>> Cleaning previous Nextcloud files in $NEXTCLOUD_DIR"
cleanup_dir "$NEXTCLOUD_DIR"

NC_TAG="$(github_latest_tag nextcloud-releases/desktop)" || exit 1
NC_VER="${NC_TAG#v}"
NC_FILE="Nextcloud-${NC_VER}-x86_64.AppImage"
echo ">>> Downloading Nextcloud ${NC_VER}"
curl "${curl_opts[@]}" \
  --output "$NEXTCLOUD_DIR/$NC_FILE" \
  "https://github.com/nextcloud-releases/desktop/releases/download/${NC_TAG}/${NC_FILE}"
assert_nonempty "$NEXTCLOUD_DIR/$NC_FILE" "Nextcloud $NC_VER"

# ---- KeePassXC --------------------------------------------------------------

echo ">>> Cleaning previous KeePassXC files in $KEEPASSXC_DIR"
cleanup_dir "$KEEPASSXC_DIR"

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
