#!/usr/bin/env bash
# hitl — test runner.
#
#   tests/run.sh                    run everything
#   tests/run.sh tests/test_gate.sh run one file
#   tests/run.sh test_gate.sh gate_blocks_deletion_of_unlisted_file
#   KEEP=1 tests/run.sh             leave the temp repos behind for poking at
#
# No bats, no node, no package manager. The tool claims to need nothing but
# bash and git, and a suite that needs more does not run on the machine that
# has the bug.
#
# Every test runs in its own subshell, in its own empty temp directory, with
# global and system git config switched off. Tests cannot see each other and
# cannot see your machine.

set -uo pipefail

export HITL_TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HITL_ROOT="$(cd "$HITL_TESTS/.." && pwd)"
export HITL="$HITL_ROOT/bin/hitl"

[ -x "$HITL" ] || { echo "not executable: $HITL" >&2; exit 2; }

# Hermetic git: no user config, no system config, identity from the env.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME="hitl tests"      GIT_AUTHOR_EMAIL="tests@hitl.invalid"
export GIT_COMMITTER_NAME="hitl tests"   GIT_COMMITTER_EMAIL="tests@hitl.invalid"
export GIT_TERMINAL_PROMPT=0

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; BLD=$'\033[1m'; OFF=$'\033[0m'
[ -t 1 ] || { RED=""; GRN=""; YEL=""; DIM=""; BLD=""; OFF=""; }

# --- arguments ----------------------------------------------------------

# Paths must be absolute: every test runs with its cwd inside a temp repo.
abspath() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }

FILES=(); ONLY=""
for a in "$@"; do
  if [ -f "$a" ]; then FILES+=("$(abspath "$a")")
  elif [ -f "$HITL_TESTS/$a" ]; then FILES+=("$HITL_TESTS/$a")
  else ONLY="$a"
  fi
done
if [ ${#FILES[@]} -eq 0 ]; then
  mapfile -t FILES < <(find "$HITL_TESTS" -maxdepth 1 -name 'test_*.sh' | sort)
fi

# --- running ------------------------------------------------------------

list_tests() {
  bash -c 'source "$1" >/dev/null 2>&1; declare -F' _ "$1" \
    | awk '{print $3}' | grep '^test_' | sort
}

run_one() { # <file> <fn>  -> 0 pass, 1 fail, 100 skip; output on $OUTFILE
  local file="$1" fn="$2" tmp rc
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/hitl-test-XXXXXX")"
  (
    cd "$tmp" || exit 1
    source "$HITL_TESTS/lib.sh"
    source "$file"
    "$fn"
  ) >"$OUTFILE" 2>&1
  rc=$?
  if [ "${KEEP:-0}" = "1" ]; then echo "  ${DIM}kept: $tmp${OFF}"; else rm -rf "$tmp"; fi
  return $rc
}

PASS=0; FAILN=0; SKIP=0; FAILED=()
OUTFILE="$(mktemp)"
trap 'rm -f "$OUTFILE"' EXIT

start=$SECONDS
for file in "${FILES[@]}"; do
  echo "${BLD}$(basename "$file")${OFF}"
  while read -r fn; do
    [ -n "$fn" ] || continue
    [ -n "$ONLY" ] && [ "$fn" != "$ONLY" ] && continue
    run_one "$file" "$fn"
    case $? in
      0)   PASS=$((PASS+1)); echo "  ${GRN}✓${OFF} ${fn#test_}" ;;
      100) SKIP=$((SKIP+1)); echo "  ${YEL}−${OFF} ${fn#test_} ${DIM}($(head -1 "$OUTFILE"))${OFF}" ;;
      *)   FAILN=$((FAILN+1)); FAILED+=("$(basename "$file") $fn")
           echo "  ${RED}✗${OFF} ${fn#test_}"
           sed 's/^/      /' "$OUTFILE" ;;
    esac
  done < <(list_tests "$file")
done

echo
if [ "$FAILN" -eq 0 ]; then
  echo "${GRN}${PASS} passed${OFF}${SKIP:+, $SKIP skipped} ${DIM}in $((SECONDS-start))s${OFF}"
  exit 0
fi
echo "${RED}${FAILN} failed${OFF}, $PASS passed${SKIP:+, $SKIP skipped}"
for f in "${FAILED[@]}"; do echo "  ${RED}$f${OFF}"; done
exit 1
