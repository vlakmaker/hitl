#!/usr/bin/env bash
# The allowed-files pre-commit gate.
#
# This is the file that matters. Every bug found in this tool so far has been
# here, and each one looked like success: two printed a create that had not
# happened, one printed nothing at all. A gate that silently does not fire is
# indistinguishable from a gate with nothing to complain about — unless
# something checks.

test_gate_allows_a_listed_file() {
  mkproject_with_packet
  echo "x" > src/app.ts
  git add src/app.ts
  run git commit -m "in scope"
  assert_ok
  assert_contains "$OUT" "all within packet scope"
}

test_gate_blocks_an_unlisted_file() {
  mkproject_with_packet
  echo "x" > src/app.ts
  echo "x" > elsewhere.ts
  git add src/app.ts elsewhere.ts
  run git commit -m "out of scope"
  assert_fail
  assert_contains "$OUT" "files outside the packet's allowed list"
  assert_contains "$OUT" "elsewhere.ts"
  assert_contains "$OUT" "stop condition"
}

# Regression: --diff-filter=ACMR excluded D, so this commit staged nothing the
# gate could see, and the hook exited 0 without printing a word.
test_gate_blocks_deleting_an_unlisted_file() {
  mkproject_with_packet
  git rm -q seed.txt
  run git commit -m "delete out of scope"
  assert_fail
  assert_contains "$OUT" "seed.txt"
}

test_gate_blocks_moving_a_listed_file_to_an_unlisted_path() {
  mkproject_with_packet
  echo "x" > src/app.ts
  git add src/app.ts
  git commit -q -m "in scope"
  git mv src/app.ts src/moved.ts
  run git commit -m "rename out of scope"
  assert_fail
  assert_contains "$OUT" "src/moved.ts"
}

# Regression, and the sharp end of it: git reports a rename as its destination
# only. Move an unlisted file ONTO an allowed path and the destination looks
# perfectly in scope — the deletion of the source is the part nobody sees.
# --no-renames splits it back into the delete and the add it really is.
test_gate_blocks_moving_an_unlisted_file_into_the_list() {
  mkproject_with_packet
  git mv seed.txt src/app.ts
  run git commit -m "rename an unlisted file into scope"
  assert_fail
  assert_contains "$OUT" "seed.txt"
}

# Regression: [ref] is an everyday Next.js route segment and also a bash
# character class, so the gate rejected the exact path the packet allowed.
test_gate_allows_a_bracketed_route_path() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  hitl packet 07 "route" >/dev/null 2>&1
  fill_packet docs/method/packets/07-route.md 'src/app/booking/[ref]/page.tsx'
  hitl slice 07 >/dev/null 2>&1
  mkdir -p 'src/app/booking/[ref]'
  echo "x" > 'src/app/booking/[ref]/page.tsx'
  git add -A -- 'src/app/booking/[ref]/page.tsx'
  run git commit -m "dynamic route"
  assert_ok
  assert_contains "$OUT" "all within packet scope"
}

test_gate_allows_a_trailing_slash_directory() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  hitl packet 07 "dir" >/dev/null 2>&1
  fill_packet docs/method/packets/07-dir.md 'pay/'
  hitl slice 07 >/dev/null 2>&1
  mkdir -p pay/nested
  echo "x" > pay/nested/deep.ts
  git add pay/nested/deep.ts
  run git commit -m "inside the directory"
  assert_ok
}

# The implementer always owns the packet it is working from — review notes get
# written during the slice, not after it.
test_gate_allows_the_packet_itself() {
  mkproject_with_packet
  echo "note" >> docs/method/packets/07-confirmation-page.md
  git add docs/method/packets/07-confirmation-page.md
  run git commit -m "packet notes"
  assert_ok
}

test_gate_allows_handoff_files() {
  mkproject_with_packet
  mkdir -p docs/method/handoffs
  echo "handoff" > docs/method/handoffs/07-confirmation-page.md
  git add docs/method/handoffs/07-confirmation-page.md
  run git commit -m "handoff"
  assert_ok
}

# Not every commit is slice work, and a gate that blocks ordinary commits is a
# gate that gets uninstalled.
test_gate_allows_when_there_is_no_packet() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  echo "x" > anything.ts
  git add anything.ts
  run git commit -m "no packet"
  assert_ok
  assert_contains "$OUT" "no active packet"
}

test_gate_refuses_when_strict_and_no_packet() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  echo "x" > anything.ts
  git add anything.ts
  run env HITL_STRICT=1 git commit -m "no packet, strict"
  assert_fail
  assert_contains "$OUT" "HITL_STRICT=1"
}

# Worktrees do not share .hitl/active-packet, so the branch name is the
# fallback that makes per-slice worktrees usable at all.
test_gate_resolves_the_packet_from_the_branch_name() {
  mkproject_with_packet
  rm -f .hitl/active-packet
  git checkout -q -b slice/07-confirmation
  echo "x" > src/app.ts
  echo "x" > elsewhere.ts
  git add src/app.ts elsewhere.ts
  run git commit -m "resolved from branch"
  assert_fail
  assert_contains "$OUT" "elsewhere.ts"
  assert_contains "$OUT" "07-confirmation-page.md"
}

test_gate_honours_HITL_PACKET() {
  mkproject_with_packet
  hitl packet 08 "other" >/dev/null 2>&1
  fill_packet docs/method/packets/08-other.md "only/this.ts"
  mkdir -p only
  echo "x" > only/this.ts
  echo "x" > src/app.ts
  git add only/this.ts src/app.ts
  run env HITL_PACKET="$PWD/docs/method/packets/08-other.md" git commit -m "override"
  assert_fail
  assert_contains "$OUT" "src/app.ts"
  assert_contains "$OUT" "08-other.md"
}

test_gate_skips_when_the_packet_lists_nothing() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  hitl packet 07 "empty" >/dev/null 2>&1
  fill_packet docs/method/packets/07-empty.md
  hitl slice 07 >/dev/null 2>&1
  echo "x" > anything.ts
  git add anything.ts
  run git commit -m "nothing to enforce"
  assert_ok
  assert_contains "$OUT" "no allowed-files list"
}

# A packet armed with --force still has {{placeholders}} where paths belong.
# Those are missing information, not patterns to match against.
test_gate_ignores_placeholder_lines() {
  mkrepo_with_commit
  hitl init build >/dev/null 2>&1
  hitl packet 07 "raw" >/dev/null 2>&1
  hitl slice 07 --force >/dev/null 2>&1
  echo "x" > anything.ts
  git add anything.ts
  run git commit -m "template packet"
  assert_ok
  assert_contains "$OUT" "no allowed-files list"
}
