# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# MoleMac

SwiftUI macOS GUI for [Mole CLI](https://github.com/tw93/Mole). Requires macOS 14+, Swift 6.3+, and Go 1.21+ (to build the bundled runtime).

## Commands

```bash
make build      # Compile the Swift executable (swift build)
make app        # Build MoleMac.app with bundled Mole runtime (runs build_app.sh)
make test       # Build + verify — NOTE: build-only, there is no unit-test suite
make clean      # Remove build artifacts
```

There is no lint step and no test target. `make test` only confirms the build
compiles. Real verification is **build + launch the app** (see Gotchas) — a
compile pass does not catch the runtime issues this codebase is prone to.

## Safety

Never run destructive `mo` commands without `--dry-run` first. The app follows this invariant: preview before delete. The app builds the Mole runtime from source in `Vendor/Mole` (git submodule), not Homebrew Mole, for packaged builds.

## Build

The app bundles the Mole runtime from source during `make app`. This requires Go 1.21+ installed.

```bash
# Initialize submodule (first clone only)
git submodule update --init --recursive

# Build the app bundle (compiles Mole Go binaries + Swift app)
make app

# Rebuild Mole Go binaries after updating submodule
cd Vendor/Mole && make build
```

## Code Architecture

The app is a thin SwiftUI shell over the bundled `mo` CLI. Three layers matter:

**`Services/MoService.swift` — an `actor` that shells out to `mo`.** All CLI
calls funnel through `runCommandResult` (sets `NO_COLOR`/`TERM=dumb`/`LANG=C`,
captures stdout/stderr via temp files). The key non-obvious fact: **Mole 1.40.0
only exposes `--json` for `status`, `uninstall --list`, and `analyze`.** Clean,
purge, and optimize have **no JSON**, so their results are produced by *parsing
human-readable text output* (`parseCleanPreview`, `parsePurgePreview`,
`parseOptimizePreview`) keyed on glyph markers (`===`, `━━━`, `➤`). Clean's
preview is read from the side file `~/.config/mole/clean-list.txt`, not stdout.
If `mo`'s output format changes, these parsers silently return empty results.
The `cleanPreviewReady` flag enforces preview-before-delete: `executeClean()`
refuses to run unless a preview was generated first.

**Runtime resolution** (`MoService.resolveMoPath`): bundled
`Contents/Resources/MoleRuntime/mo` → `MOLEMAC_MO_PATH` env override → (DEBUG
only) Homebrew `mo` → nonexistent-path sentinel. `make app` builds the runtime
from the `Vendor/Mole` submodule; packaged builds never use Homebrew Mole.

**`ContentView.swift` — the navigation + action wiring.** All six screens live
**simultaneously** in a `ZStack` (`StickyTab`), toggled by opacity — so **every
view's `.task` fires at launch** (six `mo` calls run on startup). ContentView
declares per-screen `UUID` "trigger" bindings and loading-state bindings that
it threads into each view. Each view's destructive/refresh actions are
**in-view header buttons** (`HeaderIconButton` / `HeaderActionButton`), wired
directly to the view's own async methods (`loadPreview`, `runClean`, etc.).
There is **no window `.toolbar`** — see Gotchas. (The trigger UUID bindings are
now vestigial leftovers from the removed toolbar; harmless, not load-bearing.)

`Theme/DesignTokens.swift` centralizes all fonts/colors/spacing as adaptive
light/dark values — never hardcode colors in views.

## Critical Gotchas

- **NEVER use SwiftUI `.toolbar` (or `ToolbarItem`/`ToolbarItemGroup`).** On
  macOS 26.5 every `.toolbar` usage triggers `SIGTRAP` in
  `[NSToolbar _insertNewItemWithItemIdentifier:]` during initial layout — an
  immediate launch crash. Put actions in the view body as ordinary `Button`s.
- **Preview operations are slow, not hung.** `clean --dry-run` takes ~35–40s and
  `optimize --dry-run` ~5s. Always show a loading spinner while a preview runs;
  a disabled action button with no spinner reads as broken.
- **`MOLEMAC_SCREEN=<status|clean|uninstall|analyze|optimize|purge>`** launches
  straight to one tab (set in `ContentView.init`) — useful for verification
  screenshots. **`open` does NOT propagate env vars**, so to use it run the
  bundle executable directly:
  `MOLEMAC_SCREEN=clean /Applications/MoleMac.app/Contents/MacOS/MoleMac`.
- **TCC / Full Disk Access depends on code signing.** `build_app.sh` signs every
  child binary (`mo`, `mole`, Go binaries, shell scripts) with the **same**
  bundle identifier as the parent so they share one signature domain and inherit
  Full Disk Access. Changing identifiers per-binary breaks permission inheritance.
- For UI verification, launch the **`.app` bundle** (`open MoleMac.app`); a bare
  `swift build` debug binary won't activate or raise its window properly.

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
