#!/usr/bin/env bash
# hitl init — what each tier stamps, and what it must not touch.
#
# init writes executable hooks into someone else's repository. The tier
# boundaries are the product; re-running it has to be safe or nobody will.

test_init_solo_writes_only_the_contract() {
  mkrepo
  run hitl init solo
  assert_ok
  assert_file AGENTS.md
  assert_file CLAUDE.md
  assert_no_file docs/method
  assert_no_file .hitl
  assert_no_file .git/hooks/pre-commit
  assert_eq "$(cat CLAUDE.md)" "@AGENTS.md"
}

test_init_build_writes_the_method_and_the_hooks() {
  mkrepo
  run hitl init build
  assert_ok
  assert_file docs/method/decision-log.md
  assert_file docs/method/packet-template.md
  assert_file docs/method/source/README.md
  assert_file .hitl/session-start.sh
  assert_file .hitl/allowed-files.sh
  assert_file .hitl/state.md
  assert_file .claude/settings.json
  assert_exec .hitl/session-start.sh
  assert_exec .hitl/allowed-files.sh
}

test_init_build_does_not_add_client_files() {
  mkrepo
  hitl init build >/dev/null 2>&1
  assert_no_file docs/method/handoff-protocol.md
  assert_no_file docs/method/handoffs
}

test_init_client_adds_the_handoff_protocol() {
  mkrepo
  run hitl init client
  assert_ok
  assert_file docs/method/handoff-protocol.md
  [ -d docs/method/handoffs ] || fail "expected docs/method/handoffs/ to exist"
}

# Re-running init is how you upgrade a tier. If it clobbers anything, it stops
# being something anyone runs on a live project.
test_init_is_additive_and_never_overwrites() {
  mkrepo
  hitl init build >/dev/null 2>&1
  echo "MY REAL CONTRACT" > AGENTS.md
  echo "my decisions" >> docs/method/decision-log.md
  run hitl init build
  assert_ok
  assert_eq "$(cat AGENTS.md)" "MY REAL CONTRACT"
  assert_contains "$(cat docs/method/decision-log.md)" "my decisions"
  assert_contains "$OUT" "skip"
}

test_init_does_not_duplicate_the_gitignore_entry() {
  mkrepo
  hitl init build >/dev/null 2>&1
  hitl init build >/dev/null 2>&1
  hitl init client >/dev/null 2>&1
  assert_eq "$(grep -c 'active-packet' .gitignore)" "1"
}

test_init_upgrades_solo_to_build() {
  mkrepo
  hitl init solo >/dev/null 2>&1
  assert_no_file .hitl
  run hitl init build
  assert_ok
  assert_file .hitl/allowed-files.sh
  assert_file docs/method/decision-log.md
}

test_init_installs_the_pre_commit_gate() {
  mkrepo
  hitl init build >/dev/null 2>&1
  assert_file .git/hooks/pre-commit
  assert_exec .git/hooks/pre-commit
  assert_contains "$(cat .git/hooks/pre-commit)" "allowed-files.sh"
}

# Regression: in a linked worktree .git is a file, not a directory, so this
# wrote nothing, said "create", and exited 0. Hooks live in the common dir and
# are shared, so the right answer here is "already installed".
test_init_in_a_worktree_shares_the_main_gate() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  git add -A && git commit -q -m "stamped" --no-verify
  git worktree add -q wt -b slice/02-thing || fail "could not create worktree"
  cd wt || fail "could not enter worktree"
  run hitl init build
  assert_ok
  assert_not_contains "$OUT" "could not install"
  assert_contains "$OUT" "gate installed"
  assert_contains "$OUT" "shared with the main checkout"
  assert_no_file .git/hooks/pre-commit
}

# Regression: writing to .git/hooks when git has been told to look elsewhere
# installs a gate that never runs.
test_init_honours_core_hooksPath() {
  mkrepo
  git config core.hooksPath .githooks
  run hitl init build
  assert_ok
  assert_file .githooks/pre-commit
  assert_exec .githooks/pre-commit
}

# Regression: a failed write reported success. A gate you believe in and do
# not have is worse than no gate at all.
test_init_reports_failure_when_the_hooks_dir_is_unwritable() {
  skip_if_root "root can write to anything"
  mkrepo
  chmod a-w .git/hooks
  run hitl init build
  chmod u+w .git/hooks   # so the temp dir can be cleaned up
  assert_contains "$OUT" "could not install the gate"
  assert_not_contains "$OUT" "create .git/hooks/pre-commit"
}

test_init_generates_valid_settings_json() {
  mkrepo
  hitl init build >/dev/null 2>&1
  run python3 -m json.tool .claude/settings.json
  assert_ok
  assert_contains "$(cat .claude/settings.json)" "SessionStart"
  assert_contains "$(cat .claude/settings.json)" "session-start.sh"
}

test_init_merges_into_an_existing_settings_file() {
  command -v jq >/dev/null 2>&1 || { echo "jq not installed"; exit 100; }
  mkrepo
  mkdir -p .claude
  printf '{"permissions":{"allow":["Bash(ls:*)"]}}\n' > .claude/settings.json
  run hitl init build
  assert_ok
  run python3 -m json.tool .claude/settings.json
  assert_ok
  assert_contains "$(cat .claude/settings.json)" "Bash(ls:*)"
  assert_contains "$(cat .claude/settings.json)" "session-start.sh"
}

test_init_leaves_an_existing_session_hook_alone() {
  mkrepo
  hitl init build >/dev/null 2>&1
  local before; before="$(cat .claude/settings.json)"
  run hitl init build
  assert_contains "$OUT" "hook present"
  assert_eq "$(cat .claude/settings.json)" "$before"
}

test_init_warns_when_claude_md_does_not_import_agents() {
  mkrepo
  echo "my own instructions" > CLAUDE.md
  run hitl init solo
  assert_ok
  assert_contains "$OUT" "does not import AGENTS.md"
  assert_eq "$(cat CLAUDE.md)" "my own instructions"
}

test_init_rejects_an_unknown_tier() {
  mkrepo
  run hitl init enterprise
  assert_fail
  assert_contains "$OUT" "unknown tier"
}

test_init_requires_a_git_repository() {
  run hitl init build
  assert_fail
  assert_contains "$OUT" "not a git repository"
}
