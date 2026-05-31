# MoleMac

macOS GUI for [Mole CLI](https://github.com/tw93/Mole).

## Commands

```bash
make build      # Compile the Swift executable
make app        # Build MoleMac.app with bundled Mole runtime
make test       # Build + verify
make clean      # Remove build artifacts
```

## Safety

Never run destructive `mo` commands without `--dry-run` first. The app follows this invariant: preview before delete. The app uses the pinned bundled runtime in `Vendor/MoleRuntime`, not Homebrew Mole, for packaged builds.

## Agent Workflow: Plan → Build → Check

All feature work follows this harness cycle. The agent orchestrates built-in skills automatically.

### Phase 1: Plan (use `/think`)

Given a goal or question:
1. Run `/think` to produce a decision-complete plan
2. Break into sub-tasks, each with verifiable success criteria
3. Create task entry in `feature_list.json`
4. Get user approval before any code

### Phase 2: Build (guided by Karpathy principles)

For each approved sub-task:
1. **Think before coding** — state assumptions, present tradeoffs, ask if unclear
2. **Tests first** — write failing test that describes the desired behavior
3. **Minimum implementation** — only what the test needs, nothing speculative
4. **Surgical changes** — touch only files the sub-task requires
5. **Verify per sub-task** — `make build` && `make test` must pass
6. Update `progress.md` with evidence

### Phase 3: Review (use `/check`)

After all sub-tasks are done:
1. Run `/check` to review the full diff
2. Fix findings; hard stops must be resolved
3. Verification command must pass
4. Commit with evidence in sign-off

### Phase 4: Session Handoff

Before ending:
1. Update `feature_list.json` — status + evidence for completed features
2. Update `progress.md` — what was done, verification output, files changed
3. Write `session-handoff.md` — current state, blockers, next step
4. Leave repo clean (`make test` passes)

## Skill Routing

| Need | Skill | When |
|---|---|---|
| Plan & break down tasks | `/think` | Before any implementation |
| Review diff before merge | `/check` | After implementation |
| Research unfamiliar API | `/learn` | When domain knowledge needed |
| Fetch external docs | `/read` | For URLs, specs, references |
| Debug crashes/regressions | `/hunt` | When something breaks |
| UI/screen work | `/design` | When building or improving UI |
| Polish docs/release notes | `/write` | For prose, not code comments |

## Startup Workflow

Before writing code:
1. Run `./init.sh` to verify environment is healthy
2. Read `CLAUDE.md` completely
3. Read `feature_list.json` to see current feature state
4. Pick exactly one unfinished feature to work on

## Working Rules

- **One feature at a time**: Pick exactly one unfinished feature from `feature_list.json`
- **Stay in scope**: Only touch files named in the plan. Unrelated changes are drift.
- **Scope boundary**: Don't modify files unrelated to the current sub-task
- **Verification required**: Don't claim done without running the verification command
- **Update artifacts**: Before ending session, update `progress.md` and `feature_list.json`

## Required Artifacts

- `feature_list.json` — Feature state tracker (source of truth)
- `progress.md` — Session continuity log
- `session-handoff.md` — Session handoff template
- Verification: `make test` is the project verification command

## Definition of Done

A feature is done only when ALL are true:

- [ ] Plan approved via `/think`
- [ ] All sub-tasks implemented with verification
- [ ] `make build` and `make test` pass
- [ ] `/check` review passed (no unresolved hard stops)
- [ ] Evidence recorded in `progress.md` and `feature_list.json`
- [ ] Session handoff written if ending
