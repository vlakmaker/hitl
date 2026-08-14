#!/usr/bin/env bash
# hitl — SessionStart context injection
#
# stdout is injected into the agent's context at session start. Everything here
# is DERIVED from git/gh, so it cannot drift the way a hand-maintained state
# file does. The only hand-written part is .hitl/state.md, which is reserved
# for the two things no command can compute: who owns which file right now,
# and what is blocked on someone else.
#
# Wired up by hitl-init in .claude/settings.json.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

echo "# Project state (derived $(date -u +%Y-%m-%dT%H:%MZ))"
echo

echo "## Branch"
git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repo)"
echo

if [ -f .hitl/active-packet ]; then
  p="$(tr -d '[:space:]' < .hitl/active-packet)"
  echo "## Active packet"
  echo "\`docs/method/packets/$p\` — read it before writing anything."
  echo
fi

echo "## Recent commits"
git log --oneline -8 2>/dev/null || true
echo

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "## Uncommitted"
  git status --short 2>/dev/null | head -15
  echo
fi

wt="$(git worktree list 2>/dev/null | tail -n +2)"
if [ -n "$wt" ]; then
  echo "## Worktrees (other agents may be working here)"
  echo "$wt"
  echo
fi

if command -v gh >/dev/null 2>&1; then
  prs="$(gh pr list --limit 12 --json number,title,isDraft \
         --template '{{range .}}#{{.number}} {{.title}}{{if .isDraft}} (draft){{end}}
{{end}}' 2>/dev/null)"
  if [ -n "$prs" ]; then
    echo "## Open PRs"
    echo "$prs"
    echo
  fi
fi

# Open questions block slices. Surface them — they are the most common reason
# an agent should stop rather than proceed.
if [ -f docs/method/decision-log.md ]; then
  q="$(awk '/^##[[:space:]]+Open questions/{f=1;next} f&&/^##[[:space:]]/{exit} f&&/^###/{print}' \
       docs/method/decision-log.md 2>/dev/null | grep -v '{{' | head -8)"
  if [ -n "$q" ]; then
    echo "## Open questions (blocking)"
    echo "$q"
    echo
  fi
fi

if [ -f .hitl/state.md ]; then
  echo "## Ownership and blockers (hand-maintained)"
  cat .hitl/state.md
  echo
fi

echo "---"
echo "Rules: \`AGENTS.md\`. Method: \`docs/method/\`. No packet means no slice — stop and say so."
