#!/usr/bin/env bash
# Download VS Code and IntelliJ plugins into the role files/plugins directories.
#
# Usage:
#   bash tools/download-ide-plugins.sh
#
# Edit the VSCODE_EXTENSIONS and INTELLIJ_PLUGINS arrays below to control
# what gets fetched. The script always pulls the latest version unless a
# specific build is pinned (INTELLIJ_BUILD for JetBrains compat).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VSCODE_DIR="$REPO_ROOT/roles/app_vscode/files/plugins"
INTELLIJ_DIR="$REPO_ROOT/roles/app_intellij/files/plugins"

mkdir -p "$VSCODE_DIR" "$INTELLIJ_DIR"

# ---- Configure ---------------------------------------------------------------
# VS Code extensions: <publisher>.<extension> identifiers.
# Find via marketplace URL: https://marketplace.visualstudio.com/items?itemName=redhat.ansible
VSCODE_EXTENSIONS=(
  # Infra-as-code / configuration languages
  redhat.ansible
  puppet.puppet-vscode
  redhat.vscode-yaml
  redhat.vscode-xml
  editorconfig.editorconfig

  # Languages / runtimes that match the dev VM stack
  ms-python.python
  vscjava.vscode-java-pack
  vmware.vscode-spring-boot

  # Containers
  ms-azuretools.vscode-docker

  # Productivity
  gruntfuggly.todo-tree
  eamodio.gitlens
  humao.rest-client

  # GitLab CI / pipeline editing and validation
  gitlab.gitlab-workflow

  # Testing
  ms-playwright.playwright

  # Look & feel
  pkief.material-icon-theme
)

# IntelliJ plugins: numeric plugin IDs from plugins.jetbrains.com.
# Find via plugin URL: https://plugins.jetbrains.com/plugin/<id>-<slug>  -> first segment is the id.
#
# IntelliJ IDEA Ultimate already bundles the typical dev stack:
#   - Spring + Spring Boot (full support: run configs, application.properties autocomplete,
#     beans navigation, actuator endpoints)
#   - Python (the Pro plugin, same engine as PyCharm Professional — do NOT add
#     "Python Community Edition" (7322), it is Community-only and conflicts)
#   - Lombok (bundled since IDEA 2020.3 — do NOT add id 6317)
#   - JavaScript / TypeScript / React / JSX / HTML / CSS
#   - Docker, Kubernetes
#   - Database tools (DataGrip features)
#   - Maven, Gradle, Git, Markdown
#
# Add IDs here only for things Ultimate does NOT bundle. Common optional additions:
#   1085    # IdeaVim — vim keybindings
#   12559   # Rainbow Brackets — color-coded bracket pairs
#   7495    # .ignore — improved .gitignore / .dockerignore support
#   18116   # GitHub Copilot — AI completion (subscription required)
INTELLIJ_PLUGINS=(
  13389   # Conventional Commit — commit message template + validation
  15075   # JPA Buddy — JPA/Hibernate entity + repository generation, DDL diff
  25859   # CI Aid for GitLab — job navigation, includes resolution on top of bundled GitLab plugin
  23695   # WireMock — API simulation, stub management, WireMock Cloud integration
  22113   # Save Actions X — reformat / optimize imports on save (active fork of the discontinued Save Actions)
  9568    # Go — full Go language support (same engine as GoLand)
  7973    # SonarQube for IDE — static analysis, formerly SonarLint
  9333    # Makefile Language — syntax highlighting + targets for Makefiles
  24543   # Deutsch (German) Language Pack — UI-Lokalisierung
  7179    # MavenHelper — dependency tree, conflict resolution, "run/debug Maven goal" gutter
  10044   # Atom Material Icons — pure icon pack (no theme change), matches VS Code's material-icon-theme
)

# Optional: pin IntelliJ build for compatibility filter (leave empty for latest).
# Example: "IIC-262.7321" (IntelliJ IDEA Community 2026.1.2 build).
INTELLIJ_BUILD=""
# ------------------------------------------------------------------------------

curl_opts=( --fail --location --retry 3 --connect-timeout 15 --show-error --silent )

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

# Wipes everything in $1 except .gitkeep. Each role's files/<sub>/ dir is
# dedicated, so this is safe and lets us avoid the curl --remote-header-name
# "won't overwrite" failure when upstream filenames change between runs.
cleanup_dir() {
  find "$1" -maxdepth 1 -type f ! -name '.gitkeep' -delete 2>/dev/null || true
}

# Resolves the latest update file path (pluginId/updateId/name.zip) for an
# IntelliJ plugin via the marketplace API. The old
# /plugin/download?pluginId=<id> URL was retired and now returns 404; the
# current working endpoint is /files/<path>. INTELLIJ_BUILD filters by IDE
# compatibility when set.
intellij_plugin_file() {
  local id="$1"
  local api_url="https://plugins.jetbrains.com/api/plugins/${id}/updates?size=1"
  [[ -n "$INTELLIJ_BUILD" ]] && api_url="${api_url}&build=${INTELLIJ_BUILD}"
  curl "${curl_opts[@]}" -s "$api_url" \
    | grep -oE '"file":"[^"]+"' \
    | head -1 \
    | sed -E 's/"file":"([^"]+)"/\1/'
}

echo ">>> Downloading VS Code extensions to $VSCODE_DIR"
for ext in "${VSCODE_EXTENSIONS[@]}"; do
  publisher="${ext%%.*}"
  name="${ext#*.}"
  url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${publisher}/vsextensions/${name}/latest/vspackage"
  target="$VSCODE_DIR/${ext}.vsix"
  printf '  - %-50s -> %s\n' "$ext" "$(basename "$target")"
  curl "${curl_opts[@]}" --compressed -o "$target" "$url"
  assert_nonempty "$target" "$ext"
done

echo ">>> Cleaning previous IntelliJ plugin files in $INTELLIJ_DIR"
cleanup_dir "$INTELLIJ_DIR"

echo ">>> Downloading IntelliJ plugins to $INTELLIJ_DIR"
for id in "${INTELLIJ_PLUGINS[@]}"; do
  printf '  - plugin id %s\n' "$id"
  file=$(intellij_plugin_file "$id")
  [[ -n "$file" ]] || { echo "ERROR: no update found for IntelliJ plugin id $id (build=$INTELLIJ_BUILD)" >&2; exit 1; }
  (cd "$INTELLIJ_DIR" && curl "${curl_opts[@]}" --remote-header-name --remote-name \
    "https://plugins.jetbrains.com/files/${file}")
  saved=$(newest_in "$INTELLIJ_DIR")
  assert_nonempty "$saved" "IntelliJ plugin id $id"
done

echo ""
echo "Done."
echo ""
echo "VS Code plugins:"
ls -lh "$VSCODE_DIR" | grep -Ev '^total|\.gitkeep'
echo ""
echo "IntelliJ plugins:"
ls -lh "$INTELLIJ_DIR" | grep -Ev '^total|\.gitkeep'
echo ""
echo "SHA256 (paste into host_vars / role defaults if pinning):"
find "$VSCODE_DIR" "$INTELLIJ_DIR" -type f ! -name '.gitkeep' -print0 \
  | sort -z | xargs -0 -r sha256sum
