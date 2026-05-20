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
)

# IntelliJ plugins: numeric plugin IDs from plugins.jetbrains.com.
# Find via plugin URL: https://plugins.jetbrains.com/plugin/<id>-<slug>  -> first segment is the id.
#
# IntelliJ IDEA Ultimate already bundles the typical dev stack:
#   - Spring + Spring Boot (full support: run configs, application.properties autocomplete,
#     beans navigation, actuator endpoints)
#   - JavaScript / TypeScript / React / JSX / HTML / CSS
#   - Docker, Kubernetes
#   - Database tools (DataGrip features)
#   - Maven, Gradle, Git, Markdown
#
# Add IDs here only for things Ultimate does NOT bundle. Common optional additions:
#   1085    # IdeaVim — vim keybindings
#   7973    # SonarLint — static analysis
#   12559   # Rainbow Brackets — color-coded bracket pairs
#   7495    # .ignore — improved .gitignore / .dockerignore support
#   18116   # GitHub Copilot — AI completion (subscription required)
INTELLIJ_PLUGINS=(
  13389   # Conventional Commit — commit message template + validation
  15075   # JPA Buddy — JPA/Hibernate entity + repository generation, DDL diff
  25859   # CI Aid for GitLab — job navigation, includes resolution on top of bundled GitLab plugin
  23695   # WireMock — API simulation, stub management, WireMock Cloud integration
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

echo ">>> Downloading IntelliJ plugins to $INTELLIJ_DIR"
for id in "${INTELLIJ_PLUGINS[@]}"; do
  url="https://plugins.jetbrains.com/plugin/download?pluginId=${id}"
  if [[ -n "$INTELLIJ_BUILD" ]]; then
    url="${url}&build=${INTELLIJ_BUILD}"
  fi
  printf '  - plugin id %s\n' "$id"
  (cd "$INTELLIJ_DIR" && curl "${curl_opts[@]}" --remote-header-name --remote-name "$url")
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
