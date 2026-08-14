# Handoff protocol

Two artifacts. Both are structured, both get posted where they survive the
session that produced them.

**Where to post.** On the PR *and* in `docs/method/handoffs/NN-slice.md`. The
PR comment is convenient; the file is what still exists when the remote goes
away. That is not hypothetical — the client's remote stopped resolving
after delivery and took 228 PRs' worth of handoffs with it.

**One writer per file.** Each agent writes only its own handoff file. Nobody
appends to a shared log; that is how concurrent writes clobber each other.

---

## Agent Handoff

Posted by the implementer when the slice is done.

```markdown
## Agent Handoff — packet {{NN}} {{slice name}}

**Commit:** {{hash}} on `{{branch}}`
**Packet:** `docs/method/packets/{{NN}}-{{name}}.md`

### Files changed
{{list — and confirm every one appears in the packet's allowed list}}

### Verification
- Tests: {{129/129 pass}}
- Lint: {{0 errors}}
- Typecheck: {{clean}}
- Build: {{success}}

### Smoke status
{{What was checked by hand, at which breakpoints, and what was seen.}}

### Guardrails confirmed
- [ ] No file outside the allowed list was touched
- [ ] No secret, key, or real customer record committed
- [ ] No unrelated refactor included

### Risks and caveats
{{What the next agent needs to know. Anything left deliberately unfinished.
"None" is a valid answer and must be stated, not omitted.}}

### Requested action
{{What you want the orchestrator or the human to do next.}}
```

---

## Verifier Report

Posted by an agent that did **not** write the code, ideally not even the same
vendor. Independence is the whole value; a verifier that shares the builder's
context shares its blind spots.

```markdown
## Verifier Report — packet {{NN}}

**Commit verified:** {{hash}}
**Verdict:** {{PASS | FAIL}}

### Findings
{{Numbered. Each one cites a rule number from AGENTS.md or an acceptance
criterion from the packet. A finding that cites neither is an opinion — say so
and put it under Optional.}}

### Required fixes
{{Blocking. Empty means nothing blocks.}}

### Optional improvements
{{Non-blocking. Never mix these with required fixes.}}

### Verification summary
- Ran: {{exact commands}}
- Result: {{output}}
- Checked diff against packet's allowed-files list: {{yes/no + result}}

### Merge recommendation
{{MERGE | MERGE AFTER FIXES | DO NOT MERGE}}
```

---

## The rule that makes this work

A merge recommendation is a **recommendation**. The verifier never merges, the
implementer never merges, and no hook ever merges. A human types "Merge PR #X".

Automate the retry on mechanical failures — lint, tests, build. Never automate
the judgement. The moment merging is automatic, the thing you actually sell
stops happening.
