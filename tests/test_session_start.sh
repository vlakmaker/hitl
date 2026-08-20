#!/usr/bin/env bash
# The SessionStart context injection, via `hitl status` — which is the same
# script, so what you read here is exactly what an agent is handed.
#
# Everything in it is derived from git, deliberately: a hand-maintained state
# file drifts, and an agent cannot tell that it has.

test_status_prints_the_branch_and_recent_commits() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  run hitl status
  assert_ok
  assert_contains "$OUT" "## Branch"
  assert_contains "$OUT" "main"
  assert_contains "$OUT" "## Recent commits"
  assert_contains "$OUT" "seed"
}

test_status_names_the_active_packet() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  hitl packet 07 "confirmation page" >/dev/null 2>&1
  fill_packet docs/method/packets/07-confirmation-page.md "src/app.ts"
  hitl slice 07 >/dev/null 2>&1
  run hitl status
  assert_ok
  assert_contains "$OUT" "## Active packet"
  assert_contains "$OUT" "07-confirmation-page.md"
  assert_contains "$OUT" "read it before writing anything"
  assert_not_contains "$OUT" "still a template"
}

# Only reachable via `hitl slice --force`, which is exactly when an agent most
# needs telling that the brief in front of it is not a brief.
test_status_warns_when_the_active_packet_is_a_template() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  hitl packet 07 "raw" >/dev/null 2>&1
  hitl slice 07 --force >/dev/null 2>&1
  run hitl status
  assert_ok
  assert_contains "$OUT" "This packet is still a template"
  assert_contains "$OUT" "stop and report"
}

test_status_shows_uncommitted_work() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  echo "wip" > wip.txt
  run hitl status
  assert_ok
  assert_contains "$OUT" "## Uncommitted"
  assert_contains "$OUT" "wip.txt"
}

# Open questions block slices, so they are the most common legitimate reason
# for an agent to stop rather than proceed.
test_status_surfaces_open_questions_from_the_decision_log() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  awk '1; /^## Open questions/ { print ""; print "### 2026-08-20 — Which VAT rate applies to gift cards?" }' \
    docs/method/decision-log.md > dl.tmp && mv dl.tmp docs/method/decision-log.md
  run hitl status
  assert_ok
  assert_contains "$OUT" "## Open questions (blocking)"
  assert_contains "$OUT" "Which VAT rate applies to gift cards?"
}

# The template's own placeholder questions are not questions.
test_status_does_not_surface_placeholder_questions() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  run hitl status
  assert_ok
  assert_not_contains "$OUT" "Open questions (blocking)"
}

test_status_includes_the_hand_written_state() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  printf '\n- Vera owns src/App.css until Friday\n' >> .hitl/state.md
  run hitl status
  assert_ok
  assert_contains "$OUT" "Ownership and blockers"
  assert_contains "$OUT" "owns src/App.css until Friday"
}

test_status_lists_other_worktrees() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  git add -A && git commit -q -m "stamped" --no-verify
  git worktree add -q wt -b slice/02-thing
  run hitl status
  assert_ok
  assert_contains "$OUT" "other agents may be working here"
  assert_contains "$OUT" "slice/02-thing"
}

test_status_always_says_where_the_rules_are() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  run hitl status
  assert_ok
  assert_contains "$OUT" "Rules: \`AGENTS.md\`"
  assert_contains "$OUT" "No packet means no slice"
}

test_status_requires_an_initialised_project() {
  mkrepo_with_commit
  run hitl status
  assert_fail
  assert_contains "$OUT" "run: hitl init"
}
