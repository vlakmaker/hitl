# The method

What survived one paid client build, one dead memory server, and one abandoned
memory skill. Written 2026-08-14, after archiving the client build.

---

## The one rule that explains all the others

**In-path or it dies.**

Evidence, from this machine:

| Artifact | Where it lived | Fate |
|---|---|---|
| `decision-log.md` | in the repo, cited by packets | grew to 502 lines |
| `prompt-packets/` | in the repo, cited by `CLAUDE.md` | grew to 80 files |
| vibelore MCP server | separate store, separate act of recall | **zero invocations, ever** |
| `para-memory-files` | separate store, separate act of recall | 2 notes, dead in 3 weeks |
| global `agent-memory/` | separate store, auto-loaded | stale in 4 months, and leaked client data |

Three memory systems were built and three died, while two in-repo files thrived
over the same period. The difference was never quality or discipline. It was
whether reading the file was **part of doing the work** or a separate thing to
remember.

So: every artifact this method creates lives in the repo it describes, and is
named in a file an agent must read to start the task. Nothing lives in a
sidecar store. If you find yourself building a place to put knowledge, stop.

---

## What carried over from the client build

These worked. They are the method.

### 1. Slices, not features
Smallest shippable deliverable. One slice, one packet, one PR. A bad slice costs
ten minutes to roll back; a bad feature costs a day. This is the single highest
-leverage habit and it needs no tooling at all.

### 2. The packet is a contract, not a prompt
Goal / preconditions / **files allowed to change** / acceptance criteria (happy
*and* error paths) / out of scope / **stop conditions** / verification commands.
The two bolded sections do most of the work. "Files allowed to change" prevents
drive-by refactors; "stop conditions" is what stops an agent inventing
architecture when it hits a gap.

### 3. Rules are numbered and non-negotiable
`architecture-rules.md` was 24 numbered rules, and rule 23 was itself a stop
condition: *stop and report if schema or business rules are missing; do not
invent architecture*. Numbering matters — a packet can say "violates rule 12"
and that is reviewable.

### 4. Source extracts beat memory
`source-extracts/` held the client's actual price lists as raw `.txt`/`.csv`.
When an agent needs a number, it reads the extract instead of recalling it. This
is the cheapest anti-hallucination measure available and almost nobody does it.
Generalised: **for any fact the work depends on, keep the source in the repo.**

### 5. One writer per file
Enforced by worktrees, and by naming the hotspot out loud. `App.css` was 6,000
lines and single-writer; saying so prevented most of the collisions.

### 6. Independent verification
The verifier must not be the builder, and preferably not the same vendor. A
structured Verifier Report with a three-way recommendation (merge / merge after
fixes / do not merge) — a recommendation, never an action.

### 7. Merge is human, always
PRs merged only on an explicit "Merge PR #X". This is what you sell. Automate
typing, never decisions.

---

## What failed, and what replaces it

### The method was trapped in one repo
146 files of working method existed in exactly one project. What spread to other
projects was only the thin contract file. The packets, decision log, handoff
protocol and slice tracker never left.

→ **This repo is the fix.** `hitl-init` stamps the method into a project in
seconds. If it takes longer than that, it won't happen under deadline.

### Vendor lock-in by filename
Everything was `CLAUDE.md`. The orchestrator was GPT and the verifier was Kilo,
so both worked from whatever got pasted into them.

→ **`AGENTS.md` is the source of truth; `CLAUDE.md` is one line: `@AGENTS.md`.**
Claude Code still does not read `AGENTS.md` natively (verified Aug 2026), so the
import stays until it does. Every other vendor reads `AGENTS.md` directly.

### Prose where a gate belonged
"Files allowed to change" was the most-repeated instruction in the whole method
and it was never enforced by anything. Zero hooks existed in the client repo.

→ **`hooks/allowed-files.sh`** turns the packet's own list into a pre-commit
gate. Instruction files shape behaviour; they never guarantee it.

### State kept in a head and a context window
"The orchestrator is the memory the other agents don't have" is a single point
of failure written as a feature.

→ **Derive state, don't type it.** `git branch`, `git worktree list`,
`gh pr list` are ground truth and cannot drift. The `SessionStart` hook injects
them. The only hand-written state is what no command can compute: who owns which
file right now, and what is blocked on someone else. ~15 lines, not a document.

### Hours reconstructed after the argument, not before
78 hours invoiced against 118–155 provable from commit timestamps. 13 working
days never registered at all. The reconstruction worked perfectly — six weeks
too late to change the conversation.

→ **`hitl-hours` runs weekly, not at invoice time.** Note the limit: git cannot
see the four hours of architecture work that predate the first commit. The
decision log can. Read both.

### Client data in global scope
`client-patterns.md` sat in `~/.claude/agent-memory/code-reviewer/`,
auto-loading in every project, carrying the client's architecture, an unfixed P1
bug and a security landmine. It would have loaded during the next client's code
review.

→ **Two tiers, hard wall.** Portable technique may be global. Anything naming a
client's tables, routes, pricing, or bugs lives in that client's repo and dies
with it. When a lesson is genuinely portable, strip it to the shape and leave
the specifics behind — the RLS audit lesson below is what that looks like.

---

## Portable lessons (tier 1 — safe in any project)

Kept deliberately free of any client's names, tables, or numbers.

**Auditing direct-from-browser writes.** A browser client writing straight to
config tables is not automatically a finding. If the real authority is a
server-side row-level policy, a client-side gate is UX and nothing more. Audit
the migration, not the component. It *is* a finding when the policy is missing,
when the payload has no column allowlist on a table carrying foreign keys or
prices, or when the same pattern is used for records that need server-side
authority (orders, payments, anything priced).

**Money.** Integer cents server-side, or 2-decimal strings — never floats. One
formatter, imported everywhere. Duplicated price formatting across seven files
is how rounding bugs get in.

**Dates.** Inject the current time; never let an agent read the clock. Name the
timezone in the rules. Day-of-week indexing disagreeing between two layers
(Monday=0 one side, Sunday=0 the other) is a bug that survives review because
both sides look correct alone.

**Feature flags that are landmines.** A flag whose "on" state was never actually
shipped will break everything the day someone flips it. Either the flag works or
it is deleted. Record it in the decision log if it must stay.

**Squash-merge PR numbers into commit subjects.** It made the whole history
auditable afterwards, and it is what made the hours reconstruction possible.

---

## Choosing a tier

Tier by **stakes**, not by size. A small client site needs the evidence trail; a
large personal experiment does not.

| Tier | When | What lands |
|---|---|---|
| `solo` | Experiments, weekends, throwaway | `AGENTS.md` only |
| `build` | Personal work you'll return to in a month | `+ decision-log`, `packets/`, SessionStart hook |
| `client` | Someone pays for it or depends on it | `+ handoff protocol`, allowed-files gate, hours tracking |

Upgrading is additive — `hitl-init build` on a `solo` project adds what's
missing and never overwrites.

---

## The test for any future addition

Before adding anything to this method, answer:

1. **Is it in-path?** Will an agent read it as part of doing the task, or does
   someone have to remember it exists? If the latter, it is already dead.
2. **Does it remove typing or a decision?** Typing: automate it. Decisions: never.
3. **Can a command derive it?** Then never type it.
4. **Would it survive being read aloud to a different client?** If not, it is
   tier 2 and belongs in one repo only.
