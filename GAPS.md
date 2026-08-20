# What's missing

An audit of this repo against its own claims, 2026-08-20. Every item was
checked against the code or reproduced in a throwaway repo — nothing here is
inferred from reading the prose.

Two bugs found in the audit are already fixed; they are listed under *Fixed*
at the bottom, with what they cost, because the interesting part is that both
were in the enforcement layer and neither had a test.

---

## The gap that matters most: nothing is tested

843 lines that install git hooks, append to `.gitignore`, and rewrite
`.claude/settings.json` in someone else's repo — with no test suite and no CI.
Both bugs fixed below would have been caught by ten lines of `bats`.

This is the sharpest contradiction in the method. `AGENTS.md` demands a
verification command before any handoff; the tool that stamps `AGENTS.md` has
none.

**In-path test:** a test suite is only in-path if it runs without being
remembered. That means CI on push, not a script someone runs.

---

## Promised in the docs, absent from the code

### `hitl hours`
METHOD.md commits to it by name — *"`hitl-hours` runs weekly, not at invoice
time"* — and the tier table sells "hours tracking" as part of client tier. It
does not exist. The 78-invoiced-against-118-provable story is the most concrete
loss recorded in this method and it is the one lesson with no tooling behind it.

Note the constraint METHOD.md already states: git cannot see work that predates
the first commit. So `hitl hours` is commit timestamps *plus* whatever the
decision log's `**Time:**` fields say — the template already has that field and
nothing reads it.

### `hitl handoff <NN>`
Client tier installs `handoff-protocol.md` and creates an empty `handoffs/`
directory. Nothing ever stamps `docs/method/handoffs/NN-slice.md` from the
protocol. Writing the handoff therefore depends on someone remembering the
protocol exists — which is the exact failure mode "in-path or it dies"
describes. The gate already whitelists `docs/method/handoffs/*` for every
packet, so the slot is reserved and empty.

### A slice tracker
`packet.md.tmpl` opens with `**Status:** {{DRAFT | READY | GATED | DONE}}` and
no code anywhere reads that field. There is no `hitl list`, so there is no
answer to "what is in flight" other than reading the directory. METHOD.md names
the slice tracker as one of the artifacts that never escaped the client repo —
it still hasn't.

---

## Gaps in the enforcement story

### The gate does not survive a clone
`.git/hooks/pre-commit` is not versioned. Clone a project that was stamped at
build tier and you get every method file, the packet, the allowed-files list —
and no gate, with nothing anywhere saying so. The instructions are all present
and the enforcement is silently absent, which is worse than either alone.

Options: `core.hooksPath` pointing at a tracked `.hitl/hooks/`, or a check in
`session-start.sh` that says out loud when the gate is missing. The second is
cheaper and is in-path by construction.

### Nothing enforces the packet on the PR side
The gate is local and `--no-verify` is deliberate policy. Fine — but a bypass
leaves no trace anywhere a reviewer looks. For client tier, where the point is
an evidence trail someone else reads, the allowed-files check belongs in CI
against the PR diff, and its absence from a PR is itself information.

### `AGENTS.md` is stamped as a template and never refused
`hitl slice` refuses to arm a packet containing `{{placeholders}}` — the right
call, for exactly the stated reason: an agent reads placeholder text as the
brief. `hitl init` then writes an `AGENTS.md` that is *entirely* placeholders,
and no command ever objects. The more important file has the weaker guard.

### Glob semantics are looser than the template implies
The gate matches with bash `==`, where `*` crosses `/`. So `src/*` in a packet
allows `src/anything/nested/deep.ts`. That may be what you want, but the packet
template says "one glob per line" and says nothing about this, so the list a
human writes and the list the gate enforces can differ.

### Rule 4 is prose only
`AGENTS.md` rule 4 — never commit a secret, a key, or a real customer record —
is enforced by nothing. The allowed-files gate limits *where* a secret can
land, not whether it lands. METHOD.md's own history includes a security
landmine that shipped inside an auto-loading file.

---

## Distribution and provenance

- **No version stamp.** A stamped project records nothing about which version
  of the method it received. `hitl update` can only diff against whatever
  `~/framework` happens to be at that moment, and a project cannot tell you it
  is behind.
- **No install path.** The README's `ln -s ~/framework/bin/hitl ...` assumes the
  repo is cloned to exactly `~/framework` and that `~/.local/bin` is on `PATH`.
  No install script, no uninstall, no check.
- **No LICENSE.** Now that this is public, its absence means all rights
  reserved by default — the opposite of the intent.
- **Vendor neutrality is asserted, not shipped.** `AGENTS.md` is the source of
  truth and exactly one vendor shim gets generated (`CLAUDE.md`). Cursor,
  Copilot, Gemini, Kilo each read their own filename. The method was built
  across three vendors; the tool supports one.

---

## Dead weight

`reference/vibe-engineering.md` — 470 lines, linked from no file, stamped into
no project, read by nothing. It is a sidecar knowledge store living in the repo
whose founding rule is that sidecar knowledge stores die. Either cite it from
`METHOD.md` so it is in-path, fold what's load-bearing into the method, or
delete it.

## This repo does not use its own method

No `AGENTS.md`, no `.hitl/`, no packets, no decision log. Every commit here was
made outside the discipline the repo sells — including the two commits that
introduced the bugs below. `hitl init build` on itself is the cheapest possible
demonstration that the method survives contact with its own author.

---

## Fixed in this pass

**Deletions and renames bypassed the gate entirely.**
`git diff --cached --name-only --diff-filter=ACMR` excluded `D`, so a commit
that deleted a file the packet never named passed with no output at all — the
staged list came back empty and the hook exited 0. Separately, git reports a
rename as its destination only, so `git mv` could move a file *out* of the
allowed list unseen. Now `--no-renames --diff-filter=ACMRD`: a rename is
checked as its delete and its add, and deleting an unlisted file is treated as
what it is — a change to a file outside the packet.

**`hitl init` claimed to install a gate it had not installed.**
In a linked worktree `.git` is a file, not a directory, so the write to
`$ROOT/.git/hooks/pre-commit` failed with "Not a directory" — and `init`
printed `create .git/hooks/pre-commit` anyway and exited 0. The method leans on
worktrees for one-writer-per-file, so this was the normal path, not an exotic
one. Now the hooks directory is resolved through `core.hooksPath` and
`--git-common-dir` (a worktree correctly inherits the main checkout's gate and
says so), and a failed install reports failure instead of success.

Both bugs lived in the enforcement layer. That is the argument for the first
item on this list.
