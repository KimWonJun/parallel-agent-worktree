#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WT_BIN="$ROOT_DIR/bin/wt"

if [ ! -x "$WT_BIN" ]; then
    echo "Error: wt binary not found or not executable: $WT_BIN" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_BIN="$TMP_DIR/test-bin"
WORKSPACE_DIR="$TMP_DIR/workspace"
WT_ROOT="$TMP_DIR/wt-root"
GH_LOG="$TMP_DIR/gh.log"
mkdir -p "$TEST_BIN" "$WORKSPACE_DIR" "$WT_ROOT"
: > "$GH_LOG"

cat > "$TEST_BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
LOG_FILE="${GH_LOG_FILE:-/tmp/gh.log}"
if [ "${1:-}" = "auth" ] && [ "${2:-}" = "status" ]; then
  exit 0
fi
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "create" ]; then
  printf "gh pr create %s\n" "$*" >> "$LOG_FILE"
  echo "https://github.com/example/example/pull/1"
  exit 0
fi
if [ "${1:-}" = "repo" ] && [ "${2:-}" = "list" ]; then
  echo "[]"
  exit 0
fi
printf "gh %s\n" "$*" >> "$LOG_FILE"
exit 0
EOF

cat > "$TEST_BIN/fzf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
head -n 1
EOF

chmod +x "$TEST_BIN/gh" "$TEST_BIN/fzf"

export PATH="$TEST_BIN:$PATH"
export WT_ROOT WORKSPACE_DIR
export GH_LOG_FILE="$GH_LOG"

assert_contains() {
    local text="$1"
    local pattern="$2"
    if ! grep -q -- "$pattern" <<<"$text"; then
        echo "Assertion failed: expected pattern '$pattern'" >&2
        echo "Actual text:" >&2
        echo "$text" >&2
        exit 1
    fi
}

expect_fail() {
    local out
    set +e
    out="$("$@" 2>&1)"
    local rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
        echo "Expected failure but command succeeded: $*" >&2
        echo "$out" >&2
        exit 1
    fi
    echo "$out"
}

create_remote_repo() {
    local repo_name="$1"
    local with_develop="${2:-0}"
    local remote="$TMP_DIR/$repo_name-remote.git"
    local seed="$TMP_DIR/$repo_name-seed"

    git init --bare "$remote" >/dev/null
    git clone "$remote" "$seed" >/dev/null 2>&1
    git -C "$seed" config user.email "test@example.com"
    git -C "$seed" config user.name "wt-test"

    echo "line" > "$seed/app.txt"
    git -C "$seed" add app.txt
    git -C "$seed" commit -m "init main" >/dev/null
    git -C "$seed" branch -M main
    git -C "$seed" push origin main >/dev/null

    if [ "$with_develop" = "1" ]; then
        git -C "$seed" switch -c develop >/dev/null
        echo "develop base" >> "$seed/app.txt"
        git -C "$seed" commit -am "init develop" >/dev/null
        git -C "$seed" push origin develop >/dev/null
    fi

    git -C "$remote" symbolic-ref HEAD refs/heads/main
    rm -rf "$seed"
    echo "$remote"
}

init_workspace_repo() {
    local repo_name="$1"
    local remote="$2"
    local repo_dir="$WORKSPACE_DIR/$repo_name"
    local bare_dir="$repo_dir/.bare"
    mkdir -p "$repo_dir"
    git clone --bare "$remote" "$bare_dir" >/dev/null
    git -C "$bare_dir" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
}

echo "[1/6] Setup repositories"
remote_with_develop="$(create_remote_repo "repo-with-develop" "1")"
remote_main_only="$(create_remote_repo "repo-main-only" "0")"
init_workspace_repo "repo-with-develop" "$remote_with_develop"
init_workspace_repo "repo-main-only" "$remote_main_only"

echo "[2/6] Validate main is blocked as explicit base"
out="$(expect_fail "$WT_BIN" branch repo-with-develop feat/main-block main)"
assert_contains "$out" "base branch 'main' is not allowed"

echo "[3/6] Validate main-only repo prompts non-main base creation"
out="$(printf "develop\n" | "$WT_BIN" branch repo-main-only feat/auto-base 2>&1)"
assert_contains "$out" "Created base branch 'develop'"
main_only_wt="$WORKSPACE_DIR/repo-main-only/feat-auto-base"
assert_contains "$(cat "$main_only_wt/.wt/metadata")" "source_base_branch=develop"

echo "[4/6] Validate source_base_branch is persisted and visible"
"$WT_BIN" branch repo-with-develop feat/policy develop >/dev/null
policy_wt="$WORKSPACE_DIR/repo-with-develop/feat-policy"
assert_contains "$(cat "$policy_wt/.wt/metadata")" "source_base_branch=develop"
status_out="$("$WT_BIN" status repo-with-develop)"
assert_contains "$status_out" "source_base_branch: develop"

echo "[5/6] Validate wt pr enforces base/head and blocks invalid flags"
out="$(expect_fail "$WT_BIN" pr --base develop "$policy_wt")"
assert_contains "$out" "--base is not allowed"
git -C "$policy_wt" config user.email "test@example.com"
git -C "$policy_wt" config user.name "wt-test"
echo "feature change" >> "$policy_wt/app.txt"
git -C "$policy_wt" commit -am "feature commit" >/dev/null
"$WT_BIN" pr "$policy_wt" >/dev/null
assert_contains "$(cat "$GH_LOG")" "--base develop --head feat/policy"

echo "[6/6] Validate rebase conflict blocks PR creation"
"$WT_BIN" branch repo-with-develop feat/conflict develop >/dev/null
conflict_wt="$WORKSPACE_DIR/repo-with-develop/feat-conflict"
git -C "$conflict_wt" config user.email "test@example.com"
git -C "$conflict_wt" config user.name "wt-test"

echo "feature conflict line" > "$conflict_wt/conflict.txt"
git -C "$conflict_wt" add conflict.txt
git -C "$conflict_wt" commit -m "feature conflict commit" >/dev/null

tmp_updater="$TMP_DIR/updater"
git clone "$remote_with_develop" "$tmp_updater" >/dev/null 2>&1
git -C "$tmp_updater" config user.email "test@example.com"
git -C "$tmp_updater" config user.name "wt-test"
git -C "$tmp_updater" switch develop >/dev/null
echo "base conflict line" > "$tmp_updater/conflict.txt"
git -C "$tmp_updater" add conflict.txt
git -C "$tmp_updater" commit -m "base conflict commit" >/dev/null
git -C "$tmp_updater" push origin develop >/dev/null

gh_log_before="$(cat "$GH_LOG")"
out="$(expect_fail "$WT_BIN" pr "$conflict_wt")"
assert_contains "$out" "Rebase conflict detected. PR creation stopped."
gh_log_after="$(cat "$GH_LOG")"
if [ "$gh_log_before" != "$gh_log_after" ]; then
    echo "Assertion failed: gh pr create should not run on rebase conflict" >&2
    exit 1
fi

if [ -d "$conflict_wt/.git/rebase-merge" ] || [ -d "$conflict_wt/.git/rebase-apply" ]; then
    git -C "$conflict_wt" rebase --abort >/dev/null 2>&1 || true
fi

echo "Phase 5 E2E checks passed."
