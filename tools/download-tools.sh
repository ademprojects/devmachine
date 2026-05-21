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
PYENV_DIR="$REPO_ROOT/roles/app_pyenv/files"
NVM_DIR="$REPO_ROOT/roles/app_nvm/files"
GO_DIR="$REPO_ROOT/roles/app_go/files"
MAVEN_DIR="$REPO_ROOT/roles/app_maven/files"
VSCODE_DIR="$REPO_ROOT/roles/app_vscode/files"
mkdir -p "$POSTMAN_DIR" "$NEXTCLOUD_DIR" "$KEEPASSXC_DIR" "$PYENV_DIR" "$NVM_DIR" "$GO_DIR" "$MAVEN_DIR" "$VSCODE_DIR"

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

# ---- pyenv + CPython source -----------------------------------------------
# pyenv itself is a shell tool, not a PyPI package — no Nexus pip mirror can
# help. Pull the tagged tarball from GitHub; the role discovers whichever
# pyenv-*.tar.gz landed here and unpacks it on the target.
#
# pyenv install <X.Y.Z> normally downloads the CPython source from
# PYTHON_BUILD_MIRROR_URL (defaults to a Nexus raw repo that may not exist).
# We instead pre-fetch Python-<ver>.tar.xz from python.org here and the role
# drops it into $PYENV_ROOT/cache/ — python-build then uses the cache and
# never tries to reach the mirror. Override PYTHON_VERSION env var to bundle
# a different release (must match app_pyenv_python_version at Ansible time).

echo ">>> Cleaning previous pyenv files in $PYENV_DIR"
cleanup_dir "$PYENV_DIR"

PYENV_TAG="$(github_latest_tag pyenv/pyenv)" || exit 1
PYENV_VER="${PYENV_TAG#v}"
PYENV_FILE="pyenv-${PYENV_VER}.tar.gz"
echo ">>> Downloading pyenv ${PYENV_VER}"
curl "${curl_opts[@]}" \
  --output "$PYENV_DIR/$PYENV_FILE" \
  "https://github.com/pyenv/pyenv/archive/refs/tags/${PYENV_TAG}.tar.gz"
assert_nonempty "$PYENV_DIR/$PYENV_FILE" "pyenv $PYENV_VER"

# Bundle every CPython line the devmachine ships. Override via env:
# `PYTHON_VERSIONS="3.14.5 3.12.13" tools/download-tools.sh`
read -ra PYTHON_VERSIONS <<< "${PYTHON_VERSIONS:-3.14.5 3.12.13}"
for pyver in "${PYTHON_VERSIONS[@]}"; do
  py_file="Python-${pyver}.tar.xz"
  echo ">>> Downloading CPython ${pyver} source tarball"
  curl "${curl_opts[@]}" \
    --output "$PYENV_DIR/$py_file" \
    "https://www.python.org/ftp/python/${pyver}/${py_file}"
  assert_nonempty "$PYENV_DIR/$py_file" "Python ${pyver}"
done

# ---- nvm + Node binaries --------------------------------------------------
# nvm is a shell tool — not on the npm registry, not on PyPI. The role uses
# Auto-Discovery and serves the Node binaries via a local file:// mirror,
# so neither the Nexus raw repo for nvm nor the Nexus nodejs-dist mirror is
# required at provisioning time. Keep NODE_VERSIONS in sync with
# app_nvm_node_versions in roles/app_nvm/defaults/main.yml.

echo ">>> Cleaning previous nvm files in $NVM_DIR"
cleanup_dir "$NVM_DIR"

NVM_TAG="$(github_latest_tag nvm-sh/nvm)" || exit 1
NVM_VER="${NVM_TAG#v}"
NVM_FILE="nvm-${NVM_VER}.tar.gz"
echo ">>> Downloading nvm ${NVM_VER}"
curl "${curl_opts[@]}" \
  --output "$NVM_DIR/$NVM_FILE" \
  "https://github.com/nvm-sh/nvm/archive/refs/tags/${NVM_TAG}.tar.gz"
assert_nonempty "$NVM_DIR/$NVM_FILE" "nvm $NVM_VER"

# Bundle every LTS line the devmachine ships. Override via env:
# `NODE_VERSIONS="v24.15.0 v22.22.3" tools/download-tools.sh`
# SHASUMS256.txt is not fetched — the role generates a one-line checksum file
# from the bundled tarball at provisioning time. Keeps the bundle smaller and
# avoids depending on nodejs.org being reachable for the SHASUMS file.
read -ra NODE_VERSIONS <<< "${NODE_VERSIONS:-v24.15.0 v22.22.3}"
for ver in "${NODE_VERSIONS[@]}"; do
  node_file="node-${ver}-linux-x64.tar.xz"
  echo ">>> Downloading Node ${ver} binary"
  curl "${curl_opts[@]}" \
    --output "$NVM_DIR/$node_file" \
    "https://nodejs.org/dist/${ver}/node-${ver}-linux-x64.tar.xz"
  assert_nonempty "$NVM_DIR/$node_file" "Node ${ver} binary"
done

# ---- Go toolchain ---------------------------------------------------------
# Pre-built Linux/amd64 tarball from go.dev. Override via env:
# `GO_VERSION=1.25.10 tools/download-tools.sh`. Keep in sync with the
# bundled version the role auto-discovers (no separate version var in
# defaults — derived from the tarball filename).

echo ">>> Cleaning previous Go files in $GO_DIR"
cleanup_dir "$GO_DIR"

GO_VERSION="${GO_VERSION:-1.26.3}"
GO_FILE="go${GO_VERSION}.linux-amd64.tar.gz"
echo ">>> Downloading Go ${GO_VERSION}"
curl "${curl_opts[@]}" \
  --output "$GO_DIR/$GO_FILE" \
  "https://go.dev/dl/${GO_FILE}"
assert_nonempty "$GO_DIR/$GO_FILE" "Go ${GO_VERSION}"

# ---- Maven ---------------------------------------------------------------
# Multi-version bundle from Apache archive (works for both current and older
# releases). Override via env:
# `MAVEN_VERSIONS="3.9.16 3.9.12" tools/download-tools.sh`. Keep in sync with
# app_maven_versions in roles/app_maven/defaults/main.yml.

echo ">>> Cleaning previous Maven files in $MAVEN_DIR"
cleanup_dir "$MAVEN_DIR"

read -ra MAVEN_VERSIONS <<< "${MAVEN_VERSIONS:-3.9.16 3.9.12}"
for ver in "${MAVEN_VERSIONS[@]}"; do
  mvn_file="apache-maven-${ver}-bin.tar.gz"
  echo ">>> Downloading Maven ${ver}"
  curl "${curl_opts[@]}" \
    --output "$MAVEN_DIR/$mvn_file" \
    "https://archive.apache.org/dist/maven/maven-3/${ver}/binaries/${mvn_file}"
  assert_nonempty "$MAVEN_DIR/$mvn_file" "Maven ${ver}"
done

# ---- VS Code (RPM + Remote-SSH server tarball) ----------------------------
# RPM (Linux desktop install via xrdp): defaults to latest stable —
# unabhängig von der Windows-VS-Code-Version.
# Server tarball (Remote-SSH from Windows): MUSS zur Windows-VS-Code-Version
# passen — sonst lädt VS Code Desktop beim Connect den Server neu runter.
# Auf Windows: `code --version` zeigt Version + 40-char commit.
# Override via env:
#   VSCODE_VERSION=latest         (Linux RPM)
#   VSCODE_SERVER_VERSION=1.108.1 (matched to Windows)

echo ">>> Cleaning previous VS Code files in $VSCODE_DIR"
cleanup_dir "$VSCODE_DIR"

VSCODE_VERSION="${VSCODE_VERSION:-latest}"
VSCODE_SERVER_VERSION="${VSCODE_SERVER_VERSION:-1.108.1}"

echo ">>> Downloading VS Code ${VSCODE_VERSION} Linux RPM"
(cd "$VSCODE_DIR" && curl "${curl_opts[@]}" --remote-header-name --remote-name \
  "https://update.code.visualstudio.com/${VSCODE_VERSION}/linux-rpm-x64/stable")
vscode_rpm=$(newest_in "$VSCODE_DIR")
assert_nonempty "$vscode_rpm" "VS Code ${VSCODE_VERSION} RPM"

echo ">>> Resolving VS Code Server commit for ${VSCODE_SERVER_VERSION}"
server_final_url=$(curl -sIL "https://update.code.visualstudio.com/${VSCODE_SERVER_VERSION}/server-linux-x64/stable" \
  | awk 'tolower($1)=="location:" {print $2}' | tail -1 | tr -d '\r')
vscode_commit=$(echo "$server_final_url" | grep -oE '[a-f0-9]{40}' | head -1)
[[ -n "$vscode_commit" ]] || { echo "ERROR: could not extract VS Code Server commit from $server_final_url" >&2; exit 1; }
echo ">>> Downloading VS Code Server ${VSCODE_SERVER_VERSION} (commit ${vscode_commit})"
curl "${curl_opts[@]}" \
  --output "$VSCODE_DIR/vscode-server-linux-x64-${vscode_commit}.tar.gz" \
  "$server_final_url"
assert_nonempty "$VSCODE_DIR/vscode-server-linux-x64-${vscode_commit}.tar.gz" "VS Code Server ${VSCODE_SERVER_VERSION}"

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
echo "pyenv files:"
ls -lh "$PYENV_DIR" | grep -Ev '^total|\.gitkeep' || true
echo ""
echo "nvm files:"
ls -lh "$NVM_DIR" | grep -Ev '^total|\.gitkeep' || true
echo ""
echo "Go files:"
ls -lh "$GO_DIR" | grep -Ev '^total|\.gitkeep' || true
echo ""
echo "Maven files:"
ls -lh "$MAVEN_DIR" | grep -Ev '^total|\.gitkeep' || true
echo ""
echo "VS Code files:"
ls -lh "$VSCODE_DIR" | grep -Ev '^total|\.gitkeep' || true
echo ""
echo "SHA256 (paste into host_vars / role defaults if pinning):"
find "$POSTMAN_DIR" "$NEXTCLOUD_DIR" "$KEEPASSXC_DIR" "$PYENV_DIR" "$NVM_DIR" "$GO_DIR" "$MAVEN_DIR" "$VSCODE_DIR" -type f ! -name '.gitkeep' -print0 \
  | sort -z | xargs -0 -r sha256sum
