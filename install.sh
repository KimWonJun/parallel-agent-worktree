#!/usr/bin/env bash
set -euo pipefail

APP_NAME="wt"
INSTALL_ROOT="$HOME/.wt"
BIN_DIR="$INSTALL_ROOT/bin"
TARGET_BIN="$BIN_DIR/$APP_NAME"
TEMPLATE_DIR="$INSTALL_ROOT/templates"
CONFIG_FILE="$INSTALL_ROOT/config"
SHELL_RC="$HOME/.zshrc"
WT_INSTALL_REPO="${WT_INSTALL_REPO:-}"
WT_INSTALL_BRANCH="${WT_INSTALL_BRANCH:-main}"
WT_REMOTE_WT_URL="${WT_REMOTE_WT_URL:-}"
WT_REMOTE_REPO_TOML_URL="${WT_REMOTE_REPO_TOML_URL:-}"
WT_REMOTE_MCP_GUIDE_URL="${WT_REMOTE_MCP_GUIDE_URL:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BIN="$SCRIPT_DIR/bin/wt"
SOURCE_REPO_TOML="$SCRIPT_DIR/repo.toml"
SOURCE_MCP_GUIDE="$SCRIPT_DIR/mcp-usage-guidelines.md"
TEMP_SOURCE_BIN=""
TEMP_SOURCE_REPO_TOML=""
TEMP_SOURCE_MCP_GUIDE=""

cleanup() {
    if [ -n "$TEMP_SOURCE_BIN" ] && [ -f "$TEMP_SOURCE_BIN" ]; then
        rm -f "$TEMP_SOURCE_BIN"
    fi
    if [ -n "$TEMP_SOURCE_REPO_TOML" ] && [ -f "$TEMP_SOURCE_REPO_TOML" ]; then
        rm -f "$TEMP_SOURCE_REPO_TOML"
    fi
    if [ -n "$TEMP_SOURCE_MCP_GUIDE" ] && [ -f "$TEMP_SOURCE_MCP_GUIDE" ]; then
        rm -f "$TEMP_SOURCE_MCP_GUIDE"
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

resolve_template_file() {
    local local_path="$1"
    local explicit_url="$2"
    local fallback_relpath="$3"
    local temp_var_name="$4"
    local out

    if [ -f "$local_path" ]; then
        echo "$local_path"
        return 0
    fi

    local remote_url
    remote_url="$explicit_url"
    if [ -z "$remote_url" ] && [ -n "$WT_INSTALL_REPO" ]; then
        remote_url="https://raw.githubusercontent.com/$WT_INSTALL_REPO/$WT_INSTALL_BRANCH/$fallback_relpath"
    fi

    if [ -z "$remote_url" ]; then
        echo ""
        return 0
    fi

    out="$(mktemp)"
    if curl -fsSL "$remote_url" -o "$out"; then
        eval "$temp_var_name=\"$out\""
        echo "$out"
        return 0
    fi

    rm -f "$out"
    echo ""
}

ensure_config_key() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        return 0
    fi
    echo "${key}=\"${value}\"" >> "$CONFIG_FILE"
}

upsert_config_key() {
    local key="$1"
    local value="$2"
    local temp_file
    temp_file="$(mktemp)"

    awk -v key="$key" -v value="$value" '
        BEGIN { updated = 0 }
        $0 ~ "^" key "=" {
            if (updated == 0) {
                print key "=\"" value "\""
                updated = 1
            }
            next
        }
        { print }
        END {
            if (updated == 0) {
                print key "=\"" value "\""
            }
        }
    ' "$CONFIG_FILE" > "$temp_file"

    mv "$temp_file" "$CONFIG_FILE"
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
    echo "Choose authentication method:"
    echo "1) GitHub login flow (browser/device code)"
    echo "2) Personal Access Token"
    echo "3) Skip for now"
    read -r -p "Select [1/2/3]: " choice < /dev/tty

    case "$choice" in
        1)
            gh auth login -h "$host"
            ;;
        2)
            local token
            read -r -s -p "Enter GitHub token: " token < /dev/tty
            echo ""
            if [ -z "$token" ]; then
                echo "No token entered. Skipping auth."
                return 0
            fi
            printf '%s\n' "$token" | gh auth login -h "$host" --with-token

            local current_protocol
            current_protocol="$(grep '^GIT_PROTOCOL=' "$CONFIG_FILE" | cut -d'"' -f2)"
            if [ "$current_protocol" = "ssh" ]; then
                read -r -p "Token auth works best with HTTPS cloning. Switch GIT_PROTOCOL to https? (Y/n) " switch_proto < /dev/tty
                if [[ "$switch_proto" != "n" && "$switch_proto" != "N" ]]; then
                    upsert_config_key "GIT_PROTOCOL" "https"
                    echo "Updated GIT_PROTOCOL to https"
                fi
            fi
            ;;
        *)
            echo "Skip login. You can run later: gh auth login -h $host"
            ;;
    esac
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

ensure_repository_list() {
    if grep -q "^REPOSITORY_LIST=" "$CONFIG_FILE"; then
        return 0
    fi

    echo "Optional: configure repository list used by 'wt init' selector."
    read -r -p "Enter comma-separated owner/repo list (blank to skip): " repo_list < /dev/tty
    repo_list="$(echo "$repo_list" | sed 's/[[:space:]]//g')"
    if [ -n "$repo_list" ]; then
        ensure_config_key "REPOSITORY_LIST" "$repo_list"
        echo "Set REPOSITORY_LIST."
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
    local repo_toml_source
    repo_toml_source="$(resolve_template_file "$SOURCE_REPO_TOML" "$WT_REMOTE_REPO_TOML_URL" "repo.toml" "TEMP_SOURCE_REPO_TOML")"
    local mcp_guide_source
    mcp_guide_source="$(resolve_template_file "$SOURCE_MCP_GUIDE" "$WT_REMOTE_MCP_GUIDE_URL" "mcp-usage-guidelines.md" "TEMP_SOURCE_MCP_GUIDE")"

    mkdir -p "$BIN_DIR"
    cp "$cli_source" "$TARGET_BIN"
    chmod +x "$TARGET_BIN"
    mkdir -p "$TEMPLATE_DIR"
    if [ -n "$repo_toml_source" ] && [ -f "$repo_toml_source" ]; then
        cp "$repo_toml_source" "$TEMPLATE_DIR/repo.toml"
    else
        echo "Warning: repo.toml template not found. Initial context will be partial."
    fi
    if [ -n "$mcp_guide_source" ] && [ -f "$mcp_guide_source" ]; then
        cp "$mcp_guide_source" "$TEMPLATE_DIR/mcp-usage-guidelines.md"
    else
        echo "Warning: mcp-usage-guidelines.md template not found. Initial context will be partial."
    fi

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
    ensure_repository_list

    cat <<EOF

Install complete.
- Binary: $TARGET_BIN
- Config: $CONFIG_FILE
- Templates: $TEMPLATE_DIR

Next step:
1) source $SHELL_RC
2) wt --help
EOF

}

main "$@"
