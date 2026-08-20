#!/usr/bin/env bash
# hitl slice — arming a packet.
#
# The refusal is the feature. An unfilled packet is worse than no packet: the
# gate has nothing to enforce, and the agent reads the placeholder text as if
# it were the brief.

test_slice_arms_a_filled_packet_and_counts_the_paths() {
  mkrepo
  hitl init build >/dev/null 2>&1
  hitl packet 07 "confirmation page" >/dev/null 2>&1
  fill_packet docs/method/packets/07-confirmation-page.md "src/app.ts" "tests/app.test.ts"
  run hitl slice 07
  assert_ok
  assert_contains "$OUT" "active packet: 07-confirmation-page.md"
  assert_contains "$OUT" "2 path(s) allowed"
  assert_eq "$(cat .hitl/active-packet)" "07-confirmation-page.md"
}

test_slice_refuses_a_packet_that_is_still_a_template() {
  mkrepo
  hitl init build >/dev/null 2>&1
  hitl packet 07 "raw" >/dev/null 2>&1
  run hitl slice 07
  assert_fail
  assert_contains "$OUT" "still a template"
  assert_no_file .hitl/active-packet
}

test_slice_names_the_unfilled_sections() {
  mkrepo
  hitl init build >/dev/null 2>&1
  hitl packet 07 "raw" >/dev/null 2>&1
  run hitl slice 07
  assert_fail
  assert_contains "$OUT" "Files allowed to change"
  assert_contains "$OUT" "Goal"
  assert_contains "$OUT" "Acceptance criteria"
}

# The escape hatch has to exist, or the refusal is what gets deleted.
test_slice_force_arms_a_template_anyway() {
  mkrepo
  hitl init build >/dev/null 2>&1
  hitl packet 07 "raw" >/dev/null 2>&1
  run hitl slice 07 --force
  assert_ok
  assert_eq "$(cat .hitl/active-packet)" "07-raw.md"
}

test_slice_warns_when_the_packet_lists_no_files() {
  mkrepo
  hitl init build >/dev/null 2>&1
  hitl packet 07 "empty" >/dev/null 2>&1
  fill_packet docs/method/packets/07-empty.md
  run hitl slice 07
  assert_ok
  assert_contains "$OUT" "the gate will not apply"
}

test_slice_fails_on_an_unknown_number() {
  mkrepo
  hitl init build >/dev/null 2>&1
  run hitl slice 42
  assert_fail
  assert_contains "$OUT" "no packet found"
}
