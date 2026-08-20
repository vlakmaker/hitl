#!/usr/bin/env bash
# hitl — test helpers.
#
# Sourced fresh for every test, into a subshell whose cwd is an empty temp
# directory. Tests therefore start from nothing and cannot see each other.
#
# A test fails by calling fail(), or by any assertion doing it for them.

# --- assertions ---------------------------------------------------------

fail() { echo "ASSERT: $*" >&2; exit 1; }

assert_ok()   { [ "$RC" -eq 0 ] || fail "expected success, got rc=$RC${NL}$OUT"; }
assert_fail() { [ "$RC" -ne 0 ] || fail "expected failure, got rc=0${NL}$OUT"; }

assert_contains() {
  case "$1" in *"$2"*) return 0 ;; esac
  fail "expected to find: $2${NL}in:${NL}$1"
}

assert_not_contains() {
  case "$1" in *"$2"*) fail "expected NOT to find: $2${NL}in:${NL}$1" ;; esac
}

assert_file()    { [ -f "$1" ] || fail "expected file to exist: $1"; }
assert_no_file() { [ ! -e "$1" ] || fail "expected file NOT to exist: $1"; }
assert_exec()    { [ -x "$1" ] || fail "expected file to be executable: $1"; }

assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }

# Some behaviour cannot be tested as root, which can write to anything.
skip_if_root() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "SKIP: $*"
    exit 100
  fi
}

# --- running things -----------------------------------------------------

NL=$'\n'

# run <cmd...> — capture stdout+stderr into $OUT and the status into $RC.
# ANSI colour is stripped, so assertions match what a human reads.
run() {
  OUT="$("$@" 2>&1)"; RC=$?
  OUT="$(printf '%s' "$OUT" | sed -e 's/\x1b\[[0-9;]*m//g')"
  return 0
}

hitl() { "$HITL" "$@"; }

# --- fixtures -----------------------------------------------------------

# A git repo in the current (empty, temp) directory. Identity comes from the
# GIT_AUTHOR_*/GIT_COMMITTER_* the runner exports, so no config is needed and
# nothing leaks in from the machine's global config.
mkrepo() {
  git init -q -b main . || fail "git init failed"
}

# A repo with one commit, so HEAD exists — several code paths need it.
mkrepo_with_commit() {
  mkrepo
  echo "seed" > seed.txt
  git add seed.txt
  git commit -q -m "seed" --no-verify
}

# fill_packet <file> <allowed path>... — make a template packet into a real
# one: replace the allowed-files block, and drop the {{ }} markers so the
# packet no longer reads as a template. The prose inside them stays; only the
# markers go, which is exactly the state `hitl slice` is checking for.
fill_packet() {
  local f="$1"; shift
  local paths; paths="$(printf '%s\n' "$@")"
  awk -v paths="$paths" '
    /^## Files allowed to change/ { insec=1; print; next }
    insec && /^```/ {
      if (!opened) { opened=1; print; print paths; next }
      print; insec=0; next
    }
    insec && opened { next }
    { print }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  sed -i 's/{{//g; s/}}//g' "$f"
}

# A build-tier project with packet 07 armed and two paths allowed.
# Returns with the repo ready for a commit that the gate will judge.
mkproject_with_packet() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1 || fail "hitl init failed"
  hitl packet 07 "confirmation page" >/dev/null 2>&1 || fail "hitl packet failed"
  fill_packet docs/method/packets/07-confirmation-page.md "src/app.ts" "tests/app.test.ts"
  hitl slice 07 >/dev/null 2>&1 || fail "hitl slice failed"
  mkdir -p src tests
}
