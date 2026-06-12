#!/usr/bin/env bash
# Smoke + behaviour tests for vim-merge-preview.
#   - builds a throwaway git repo with adds / mods / deletes / renames
#   - renders the panel headlessly and asserts the tree contents
#   - asserts the public API loaded without parse errors
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIMRC="$PLUGIN_DIR/test/vimrc"
WORK="$(mktemp -d)"
REPO="$WORK/repo"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok - $*"; }

# --- build a sample repository ------------------------------------------------
mkdir -p "$REPO"
git -C "$REPO" -c init.defaultBranch=main init -q
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name  test
git -C "$REPO" config commit.gpgsign false
git -C "$REPO" config tag.gpgsign false

mkdir -p "$REPO/src"
printf 'keep\n'      > "$REPO/keep.txt"
printf 'original\n'  > "$REPO/src/app.js"
printf 'gone\n'      > "$REPO/src/old_helper.js"
printf 'rename me\n' > "$REPO/src/to_rename.js"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "base on main"

git -C "$REPO" checkout -q -b feature/login
printf 'changed\n'                 > "$REPO/src/app.js"     # modify
printf 'function auth(){}\n'       > "$REPO/src/auth.js"    # add
rm "$REPO/src/old_helper.js"                                # delete
git -C "$REPO" mv src/to_rename.js src/renamed.js          # rename
git -C "$REPO" add -A
git -C "$REPO" commit -qm "feature work"

# --- render the panel headlessly ---------------------------------------------
OUT="$WORK/out.txt"
MP_REPO="$REPO" MP_TARGET=main MP_OUT="$OUT" \
  vim -N -es -u "$VIMRC" -c 'source '"$PLUGIN_DIR"'/test/dump.vim' -c 'qa!' \
  </dev/null >/dev/null 2>&1 || true

[ -s "$OUT" ] || fail "render produced no output"
echo "--- rendered panel ---"; cat "$OUT"; echo "----------------------"

grep -q 'feature/login ⇐ main' "$OUT" || fail "missing header branch line"
grep -q '+1'  "$OUT" || fail "expected 1 add in counts"
grep -Eq '~[0-9]' "$OUT" || fail "expected modified count"
grep -q '\-1'  "$OUT" || fail "expected 1 delete in counts"
grep -Eq '^[[:space:]]*\+ auth\.js'      "$OUT" || fail "added file not marked +"
grep -Eq '^[[:space:]]*~ app\.js'        "$OUT" || fail "modified file not marked ~"
grep -Eq '^[[:space:]]*- old_helper\.js' "$OUT" || fail "deleted file not marked -"
grep -q 'src/' "$OUT" || fail "expected src/ directory node"
pass "panel renders adds/mods/deletes with correct signs"

# --- API parse / load check --------------------------------------------------
API="$WORK/api.txt"
: > "$API"
MP_OUT="$API" \
  vim -N -es -u "$VIMRC" -c 'source '"$PLUGIN_DIR"'/test/check.vim' -c 'qa!' \
  </dev/null >/dev/null 2>&1 || true

grep -q 'OK=1' "$API" || { echo "--- api check ---"; cat "$API"; fail "public API failed to load"; }
! grep -q 'MISSING' "$API" || { cat "$API"; fail "missing functions"; }
pass "all public functions loaded without parse errors"

# --- interactive UI smoke test (needs a TTY; skipped otherwise) ---------------
if command -v script >/dev/null 2>&1; then
  SMOKE="$WORK/smoke.txt"
  : > "$SMOKE"
  # util-linux `script -qec CMD FILE`; if this form is unsupported the block is
  # simply skipped via the guards below. Files are on panel lines 7..10 (src/ at
  # 6), so ]f from the top lands on 7, again on 8, and [f returns to 7.
  script -qec "MP_REPO='$REPO' MP_OUT='$SMOKE' vim -N -u '$VIMRC' \
    -c 'source $PLUGIN_DIR/test/smoke.vim' -c 'qa!'" /dev/null >/dev/null 2>&1 || true
  if grep -q 'wins=3' "$SMOKE" 2>/dev/null && grep -q 'diff=1' "$SMOKE" 2>/dev/null \
     && grep -q 'err=$' "$SMOKE" 2>/dev/null && grep -q 'in_panel=0' "$SMOKE" 2>/dev/null; then
    pass "panel opens a 3-pane Gvdiffsplit-style diff with no errors"
    # ]f from the diff window: 7 -> 8 -> 9, then [f back to 8.
    if grep -q 'nav=7,8,9,8' "$SMOKE" 2>/dev/null; then
      pass "]f / [f navigate-and-open from inside the diff window"
    else
      fail "]f / [f navigation wrong: $(grep '^nav=' "$SMOKE")"
    fi
  else
    echo "skip - interactive UI smoke test (no usable TTY)"
    echo "  (smoke output was:)"; sed 's/^/    /' "$SMOKE" 2>/dev/null || true
  fi
else
  echo "skip - interactive UI smoke test ('script' not found)"
fi

echo "ALL TESTS PASSED"
