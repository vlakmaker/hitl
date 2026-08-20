#!/usr/bin/env bash
# hitl packet — creating a slice packet from the template.

test_packet_creates_a_file_from_the_template() {
  mkrepo
  hitl init build >/dev/null 2>&1
  run hitl packet 07 "confirmation page"
  assert_ok
  assert_file docs/method/packets/07-confirmation-page.md
  local body; body="$(cat docs/method/packets/07-confirmation-page.md)"
  assert_contains "$body" "# Packet 07 — confirmation page"
  assert_contains "$body" "## Files allowed to change"
  assert_contains "$body" "## Stop and report if"
}

# Punctuation is stripped rather than transliterated, which leaves runs of
# hyphens behind if nothing collapses them.
test_packet_slugifies_punctuation() {
  mkrepo
  hitl init build >/dev/null 2>&1
  run hitl packet 12 "Checkout — step 2: payment"
  assert_ok
  assert_file docs/method/packets/12-checkout-step-2-payment.md
}

test_packet_refuses_to_overwrite() {
  mkrepo
  hitl init build >/dev/null 2>&1
  hitl packet 07 "first" >/dev/null 2>&1
  echo "MY PACKET" > docs/method/packets/07-first.md
  run hitl packet 07 "first"
  assert_fail
  assert_contains "$OUT" "already exists"
  assert_eq "$(cat docs/method/packets/07-first.md)" "MY PACKET"
}

test_packet_requires_a_number_and_a_name() {
  mkrepo
  hitl init build >/dev/null 2>&1
  run hitl packet 07
  assert_fail
  assert_contains "$OUT" "usage: hitl packet"
}

test_packet_rejects_a_name_that_slugifies_to_nothing() {
  mkrepo
  hitl init build >/dev/null 2>&1
  run hitl packet 07 "!!!"
  assert_fail
  assert_contains "$OUT" "empty slug"
}
