#!/usr/bin/env bash
set -euo pipefail

APP_NAME="wt"
INSTALL_ROOT="$HOME/.wt"
BIN_DIR="$INSTALL_ROOT/bin"
TARGET_BIN="$BIN_DIR/$APP_NAME"
CONFIG_FILE="$INSTALL_ROOT/config"
SHELL_RC="$HOME/.zshrc"
WT_INSTALL_REPO="${WT_INSTALL_REPO:-}"
WT_INSTALL_BRANCH="${WT_INSTALL_BRANCH:-main}"
WT_REMOTE_WT_URL="${WT_REMOTE_WT_URL:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BIN="$SCRIPT_DIR/bin/wt"
TEMP_SOURCE_BIN=""

cleanup() {
    if [ -n "$TEMP_SOURCE_BIN" ] && [ -f "$TEMP_SOURCE_BIN" ]; then
        rm -f "$TEMP_SOURCE_BIN"
    fi
}
trap cleanup EXIT

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Error: This installer supports macOS only."
    exit 1
fi

require_brew() {
    if command -v brew >/dev/null 2>&1; then
        return 0
    fi

    cat <<'EOF'
Error: Homebrew is required to auto-install dependencies.
Install Homebrew first:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
EOF
    exit 1
}

ensure_dep() {
    local dep="$1"
    if command -v "$dep" >/dev/null 2>&1; then
        echo " - $dep: found"
        return 0
    fi

    echo " - $dep: missing"
    read -r -p "Install '$dep' with Homebrew now? (y/N) " answer < /dev/tty
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        echo "Error: '$dep' is required for $APP_NAME."
        exit 1
    fi
    brew install "$dep"
}

resolve_source_bin() {
    if [ -f "$SOURCE_BIN" ]; then
        echo "$SOURCE_BIN"
        return 0
    fi

    local remote_url
    remote_url="$WT_REMOTE_WT_URL"
    if [ -z "$remote_url" ] && [ -n "$WT_INSTALL_REPO" ]; then
        remote_url="https://raw.githubusercontent.com/$WT_INSTALL_REPO/$WT_INSTALL_BRANCH/bin/wt"
    fi

    if [ -z "$remote_url" ]; then
        cat <<'EOF'
Error: Could not resolve source for bin/wt.
Use one of:
  1) Run installer from cloned repository root, or
  2) Set WT_INSTALL_REPO="<owner>/<repo>" (and optional WT_INSTALL_BRANCH), or
  3) Set WT_REMOTE_WT_URL="<raw bin/wt url>".
EOF
        exit 1
    fi

    TEMP_SOURCE_BIN="$(mktemp)"
    curl -fsSL "$remote_url" -o "$TEMP_SOURCE_BIN"
    chmod +x "$TEMP_SOURCE_BIN"
    echo "$TEMP_SOURCE_BIN"
}

ensure_config_key() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        return 0
    fi
    echo "${key}=\"${value}\"" >> "$CONFIG_FILE"
}

add_path_to_zshrc() {
    local path_line='export PATH="$PATH:$HOME/.wt/bin"'
    if grep -Fq "$path_line" "$SHELL_RC" 2>/dev/null; then
        return 0
    fi

    {
        echo ""
        echo "# wt CLI"
        echo "$path_line"
    } >> "$SHELL_RC"
}

check_gh_auth() {
    local host
    host="$(grep '^GITHUB_HOST=' "$CONFIG_FILE" | cut -d'"' -f2)"
    host="${host:-github.com}"

    if gh auth status -h "$host" >/dev/null 2>&1; then
        echo "GitHub auth check: ok ($host)"
        return 0
    fi

    echo "GitHub auth check: not logged in for $host"
    read -r -p "Run 'gh auth login -h $host' now? (y/N) " answer < /dev/tty
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        gh auth login -h "$host"
    else
        echo "Skip login. You can run later: gh auth login -h $host"
    fi
}

ensure_default_owner() {
    if grep -q "^DEFAULT_GITHUB_OWNER=" "$CONFIG_FILE"; then
        return 0
    fi

    local owner
    owner="$(gh api user --jq '.login' 2>/dev/null || true)"
    if [ -n "$owner" ]; then
        echo "DEFAULT_GITHUB_OWNER=\"$owner\"" >> "$CONFIG_FILE"
        echo "Set DEFAULT_GITHUB_OWNER to '$owner'"
    fi
}

main() {
    echo "Installing $APP_NAME (macOS + GitHub workflow bootstrap)"

    require_brew

    echo "Checking dependencies..."
    ensure_dep "curl"
    ensure_dep "git"
    ensure_dep "gh"
    ensure_dep "jq"
    ensure_dep "fzf"

    local cli_source
    cli_source="$(resolve_source_bin)"

    mkdir -p "$BIN_DIR"
    cp "$cli_source" "$TARGET_BIN"
    chmod +x "$TARGET_BIN"

    mkdir -p "$INSTALL_ROOT"
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    ensure_config_key "WORKSPACE_DIR" "$HOME/workspace"
    ensure_config_key "GITHUB_HOST" "github.com"
    ensure_config_key "GIT_PROTOCOL" "ssh"
    ensure_config_key "DEFAULT_AGENT" "codex"

    add_path_to_zshrc
    check_gh_auth
    ensure_default_owner

    cat <<EOF

Install complete.
- Binary: $TARGET_BIN
- Config: $CONFIG_FILE

Next step:
1) source $SHELL_RC
2) wt --help
EOF

}

main "$@"
