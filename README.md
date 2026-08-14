# hitl

A working method for building with agents, extracted from one paid client
build and stamped into new projects in one command.

Not a framework. A convention plus about 300 lines of bash. The reasoning
behind every part of it is in **[METHOD.md](METHOD.md)** — read that first if
you want to know *why*, this file only covers *how*.

```sh
cd my-project
hitl init build
```

---

## Install

```sh
ln -s ~/framework/bin/hitl ~/.local/bin/hitl
```

Requires `bash` and `git`. Uses `gh` and `jq` if present, works without them.

## Commands

| | |
|---|---|
| `hitl init [solo\|build\|client]` | Scaffold this repo. Additive — never overwrites, safe to re-run. |
| `hitl packet <NN> <name>` | New slice packet from the template. |
| `hitl slice <NN>` | Set the active packet. Drives the pre-commit gate. |
| `hitl status` | Print exactly what an agent sees at session start. |

## Tiers

By **stakes**, not size. A small paid site needs the trail; a big personal
experiment does not.

| | `solo` | `build` | `client` |
|---|:-:|:-:|:-:|
| `AGENTS.md` + `CLAUDE.md` | ● | ● | ● |
| decision log, packets, source extracts | | ● | ● |
| SessionStart context injection | | ● | ● |
| handoff + verifier protocol | | | ● |
| allowed-files pre-commit gate | | | ● |

Upgrading is just re-running: `hitl init client` on a `build` project adds the
missing pieces and touches nothing else.

## What lands in a project

```
AGENTS.md                        the contract — every vendor reads this
CLAUDE.md                        one line: @AGENTS.md
docs/method/
  decision-log.md                why, which git never records
  packet-template.md
  packets/NN-name.md             one slice, one packet, one PR
  source/                        facts in raw form, so nothing gets recalled
  handoff-protocol.md            client tier
  handoffs/NN-slice.md           client tier — survives the remote disappearing
.hitl/
  session-start.sh               derived state injection
  allowed-files.sh               the gate
  state.md                       ~15 lines: ownership + blockers, nothing derivable
  active-packet                  gitignored, per-worktree
.claude/settings.json            SessionStart hook
.git/hooks/pre-commit            the gate
```

## The loop

```sh
hitl packet 07 "confirmation page"   # write it by hand, fill allowed-files first
hitl slice 07                        # arms the gate
git checkout -b slice/07-confirmation
# ... agent implements against the packet ...
# ... agent writes docs/method/handoffs/07-confirmation.md ...
# ... a different agent, ideally a different vendor, posts a Verifier Report ...
# ... you read it and type: Merge PR #N
```

The gate blocks a commit touching anything the packet did not list. That is a
stop condition, not an obstacle — either the change is out of scope or the
packet was wrong, and both deserve a human. `--no-verify` exists for when
you've decided; a gate nobody can bypass is a gate that gets deleted.

## Two rules worth repeating

**In-path or it dies.** Every artifact lives in the repo it describes and is
named in a file an agent must read to start. Sidecar knowledge stores were
tried three times here and died three times. See METHOD.md.

**Automate typing, never decisions.** Retry lint and tests automatically.
Never auto-merge. The merge is the thing you actually sell.
