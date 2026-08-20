# What's missing

An audit of this repo against its own claims, 2026-08-20. Every item was
checked against the code or reproduced in a throwaway repo — nothing here is
inferred from reading the prose.

Three bugs found in the audit are already fixed; they are listed under *Fixed*
at the bottom, with what they cost, because the interesting part is that all
three were in the enforcement layer and none had a test.

---

## ~~The gap that matters most: nothing is tested~~ — closed

`tests/run.sh`, 62 cases, no dependencies the tool does not already have. Six
of them cover bugs that actually shipped, and each was checked by reverting the
fix and watching the right test go red — a test that has never failed is a
claim, not a check.

Still open here:

- **CI is written but not running.** `.github/workflows/tests.yml` exists; the
  suite is only in-path once it runs on push without anyone remembering it.
- **The no-`jq` branch of `install_session_hook` is untested.** Testing it
  needs a PATH sandbox that would be more fragile than the code it covers.
- **The `gh`-dependent part of `session-start.sh` is untested.** It needs a
  fake `gh` or a network. Low value either way.
- **Nothing runs on macOS.** `realpath --relative-to` and `sed -i` are GNU
  spellings; stock macOS has neither. This has never been run there, and the
  README now says so rather than implying otherwise.

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

A listed path is now compared literally before it is compared as a glob, which
is what makes a Next.js segment like `src/app/booking/[ref]/page.tsx` work at
all. The residual is still there: that same line is *also* tried as a glob, so
`src/app/booking/r/page.tsx` would pass too. Closing it properly means deciding
whether a packet line is a path or a pattern, and saying so in the template.

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
- **`python3` is an undeclared dependency.** `install_session_hook` shells out
  to it to validate the generated `settings.json`, and when it is missing the
  check fails open in the noisiest way: valid JSON gets reported as invalid.
  The README now names it; the code should degrade rather than lie.
- **No install path.** Install is two commands in the README and nothing more:
  no install script, no uninstall, and no check that `~/.local/bin` is actually
  on `PATH`. It shipped naming the wrong directory, which nothing would catch.
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
made outside the discipline the repo sells — including the commits that
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

**A bracketed path matched as a character class, never as itself.**
The gate compared each staged file to the packet's list with bash `==`, which
globs. `src/app/booking/[ref]/page.tsx` — an everyday Next.js dynamic route —
is a valid filename and also a pattern meaning "one character from r, e, f", so
the gate rejected the exact path the packet allowed and accepted three paths it
did not. Now the comparison is literal first, glob second. The looser half of
that is still open, above.

All three bugs lived in the enforcement layer, which is the argument the first
item on this list used to make. There is a suite there now, and these three are
the cases it opens with.
