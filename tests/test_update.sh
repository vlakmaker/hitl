#!/usr/bin/env bash
# hitl update — refreshing a stamped project from this repo.
#
# This command overwrites executable hooks in projects someone else is paying
# for. The distinction it has to keep straight: machinery is replaced, content
# is only ever reported.

test_update_refreshes_a_changed_hook() {
  mkrepo
  hitl init build >/dev/null 2>&1
  echo "# local edit" >> .hitl/session-start.sh
  run hitl update
  assert_ok
  assert_contains "$OUT" "updated"
  cmp -s "$HITL_ROOT/hooks/session-start.sh" .hitl/session-start.sh \
    || fail "hook was not refreshed from $HITL_ROOT"
  assert_exec .hitl/session-start.sh
}

test_update_reports_nothing_to_do() {
  mkrepo
  hitl init build >/dev/null 2>&1
  run hitl update
  assert_ok
  assert_contains "$OUT" "Up to date"
}

test_update_dry_run_writes_nothing() {
  mkrepo
  hitl init build >/dev/null 2>&1
  echo "# local edit" >> .hitl/session-start.sh
  local before; before="$(cat .hitl/session-start.sh)"
  run hitl update --dry-run
  assert_ok
  assert_contains "$OUT" "would update"
  assert_eq "$(cat .hitl/session-start.sh)" "$before"
}

# You may have edited a template on purpose. Machinery is yours to lose;
# content is not.
test_update_reports_template_drift_without_replacing_it() {
  mkrepo
  hitl init build >/dev/null 2>&1
  echo "## My extra section" >> docs/method/packet-template.md
  run hitl update
  assert_ok
  assert_contains "$OUT" "drift"
  assert_contains "$(cat docs/method/packet-template.md)" "My extra section"
}

test_update_replaces_templates_when_asked() {
  mkrepo
  hitl init build >/dev/null 2>&1
  echo "## My extra section" >> docs/method/packet-template.md
  run hitl update --templates
  assert_ok
  assert_not_contains "$(cat docs/method/packet-template.md)" "My extra section"
  cmp -s "$HITL_ROOT/templates/packet.md.tmpl" docs/method/packet-template.md \
    || fail "template was not replaced"
}

# The hook wiring has been silently broken before, which is why update checks
# it rather than assuming it.
test_update_repairs_broken_settings_json() {
  mkrepo
  hitl init build >/dev/null 2>&1
  echo '{ not json' > .claude/settings.json
  run hitl update
  assert_ok
  assert_contains "$OUT" "not valid JSON"
  assert_file .claude/settings.json.broken
  run python3 -m json.tool .claude/settings.json
  assert_ok
  assert_contains "$(cat .claude/settings.json)" "session-start.sh"
}

test_update_reinstalls_a_missing_session_hook() {
  command -v jq >/dev/null 2>&1 || { echo "jq not installed"; exit 100; }
  mkrepo
  hitl init build >/dev/null 2>&1
  printf '{"permissions":{"allow":["Bash(ls:*)"]}}\n' > .claude/settings.json
  run hitl update
  assert_ok
  assert_contains "$OUT" "missing"
  assert_contains "$(cat .claude/settings.json)" "session-start.sh"
  assert_contains "$(cat .claude/settings.json)" "Bash(ls:*)"
}

test_update_requires_an_initialised_project() {
  mkrepo
  run hitl update
  assert_fail
  assert_contains "$OUT" "run: hitl init"
}

test_update_rejects_an_unknown_flag() {
  mkrepo
  hitl init build >/dev/null 2>&1
  run hitl update --force
  assert_fail
  assert_contains "$OUT" "unknown flag"
}
