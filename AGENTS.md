# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

# Mogu

SwiftUI macOS GUI for [Mole CLI](https://github.com/tw93/Mole). Requires macOS 14+, Swift 6.3+, and Go 1.21+ (to build the bundled runtime).

## Commands

```bash
make build       # Compile the Swift executable (swift build)
make app         # Build Mogu.app with bundled Mole runtime (runs build_app.sh)
make test        # Build + verify — build-only, confirms the app compiles
make parser-test # swift test: regression guard for the fragile text parsers
make clean       # Remove build artifacts
```

There is no lint step. `make test` only confirms the build compiles. The **one**
test target is `MoguTests` (`make parser-test`), which guards the fragile
`MoOutputParser` text parsers against golden fixtures — it does **not** cover UI
or runtime behavior. Real verification is still **build + launch the app** (see
Gotchas); a compile pass does not catch the runtime issues this codebase is
prone to.

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

**App icon / brand mark.** The Mogu icon is generated from `icon-source.png`
(an original transparent-background PNG) by `scripts/make_icon.sh` (built-ins
only: swift/sips/iconutil) — it composites the art onto a macOS squircle (with a
~6% inset so the raised drill-claws don't clip at the rounded corners) and emits
`AppIcon.icns` (full multi-res iconset), `icon.png`, and `SidebarLogo.png`.
`build_app.sh` copies `AppIcon.icns` and `SidebarLogo.png` into
`Contents/Resources`; `ContentView.brandMark` loads the sidebar logo from there
(falls back to a bolt glyph if absent). Re-run `./scripts/make_icon.sh` after
replacing `icon-source.png`. The accent palette (`DesignTokens.Color.accent*`)
is Mogu navy/indigo.

## Code Architecture

The app is a thin SwiftUI shell over the bundled `mo` CLI. Three layers matter:

**`Services/MoService.swift` — an `actor` that shells out to `mo`.** All CLI
calls funnel through `runCommandResult` (sets `NO_COLOR`/`TERM=dumb`/`LANG=C`,
captures stdout/stderr via temp files). The key non-obvious fact: **Mole 1.40.0
only exposes `--json` for `status`, `uninstall --list`, and `analyze`.** Clean,
purge, and optimize have **no JSON**, so their results are produced by *parsing
human-readable text output* keyed on glyph markers (`===`, `━━━`, `➤`/`→`). The
pure parsing logic now lives in **`Services/MoOutputParser.swift`** (extracted
out of the `MoService` actor so it is unit-testable); `MoService` reads the
bytes and delegates. Clean's preview is read from the side file
`~/.config/mole/clean-list.txt`, not stdout. If `mo`'s output format changes,
these parsers silently return empty results. `make parser-test` (golden fixtures
in `Tests/MoguTests/Fixtures`) guards the parser **code** against regressions
and pins the format the parsers expect — but the fixtures are static snapshots,
so they do **not** auto-detect live Mole drift. They surface drift only when a
human re-captures them, e.g. on a `Vendor/Mole` submodule bump (regenerate per
`Fixtures/README.md`). The optimize stream parser is `StepStreamParser`
(`ProcessStep.swift`).
The `cleanPreviewReady` flag enforces preview-before-delete: `executeClean()`
refuses to run unless a preview was generated first.

**Uninstall (in-app, no Terminal).** `uninstall --list` returns JSON (the browse
list with sizes), but Mole's actual uninstall and its `--dry-run` have **no
JSON**. So the uninstall flow drives `mo uninstall <names…>` directly and parses
its text: `MoOutputParser.parseUninstallPreview` reads the `Files to be removed:`
block (`◎ <name> , <size>` group headers, `  ✓ <path>` leftover lines, the
`➤ Remove N apps, <total>` terminator), stripping the ANSI / scan-spinner noise
that the merged stdout+stderr carries. The parse is glyph-tolerant (file lines
are detected by a `/` or `~/` remainder, not by the exact bullet glyph) and
golden-fixture guarded (`Tests/MoguTests/Fixtures/uninstall-preview.txt`). Mole's
uninstall prompts twice (`read -r confirm` for `[y/N]`, then a single-key
`Enter/ESC`), so the run is driven by **`streamFeeding(args:input:)`**, which
feeds `y\n` to stdin then closes it: the first prompt consumes the `y`, the
second proceeds on EOF. `streamFeeding` is **uninstall-only**; `stream` /
`streamElevated` keep `nullDevice` stdin (the `[[ -t 0 ]]` hang gotcha). Flow:
a dry-run preview (`previewUninstall`) populates the confirmation sheet and arms
`uninstallPreviewReady` **only when the parse is non-empty** (preview-before-delete);
the execute (`runUninstall`) re-validates that the live selection still matches the
previewed set before deleting. Removal runs **unprivileged** with the default
`MOLE_DELETE_MODE=trash`, so items go to the Trash (recoverable) and `~/Library`
leftovers resolve in the user's own context. Root-owned/non-writable
admin-required apps are selectable only in **admin-only batches**: Mogu still
runs the dry-run preview first, then Mole requests the administrator password
during execute after Mogu's final confirmation. The app deliberately does **not**
run the whole uninstall as root, preserving the invoking user's `$HOME`, logs,
and Trash ownership. Homebrew casks stay non-selectable with Admin/Brew badges;
users should remove those with `brew uninstall --cask --zap` so Homebrew's own
state remains consistent. The list is sortable by name or size, ascending or
descending, via Finder-style column headers (default size-descending).

**Permissions model (minimal / works-everywhere).** The app requires **no**
permission to start — `PermissionKind` is `.administrator` (for elevation) plus
`.fullDiskAccess` (optional; granting it silences the per-folder TCC "Files &
Folders" prompts during home-dir scanning; probed via the system
`/Library/Application Support/com.apple.TCC/TCC.db`). The app still requires no
permission to *start* (no prompt on launch or tab switch). But when the user
**initiates** a Clean or Optimize, the admin password is requested **up front**
(`cleanAllAdminFirst` / `optimizeAllAdminFirst` → `previewElevatedClean` /
`previewElevatedOptimize`, the elevated dry-run that triggers the osascript
password dialog). Protected app uninstall is different: preview remains
unprivileged, then Mole requests the password only during final execute for an
admin-only non-Homebrew batch, preserving the user's Trash context. **Granted**
→ the user confirms a combined run that cleans
user-owned items unprivileged (`stream(…)`) **then** system items elevated
(`streamElevated(…)`, `runFullClean`/`runFullOptimize`). **Cancelled/declined**
→ fall back to the unprivileged run only (user-owned items). This is **admin-first
with graceful fallback** — it replaced an earlier "unprivileged-first, then
progressively offer escalation" model. Two `mo` runs are needed because elevated
`mo` runs as root (`$HOME=/var/root`); the user-tier items must be cleaned in the
user's own context first. The escalation goes **straight to the osascript admin
password dialog** (`do shell script … with administrator privileges`). Touch ID is
**not** used: macOS's script-driven admin authorization (`system.privilege.admin`)
is password-only, and `pam_tid` + `sudo` was verified **not** to present Touch ID
when spawned from this GUI app (no controlling TTY) on macOS 26.5 — so a Touch ID
path was tried and removed in favor of the plain password prompt. (Real
Touch-ID-grants-admin would need a Developer-ID-signed privileged helper,
infeasible under this ad-hoc-signed build.)
Preview-before-delete is enforced at **both** tiers with function-level guards: the
unprivileged run via `cleanPreviewIsReady()`, the elevated run via its own elevated
dry-run (`runElevatedClean`/`runElevatedOptimize` guard on
`systemClean/OptimizePreviewReady`). The app must run `mo` **non-interactively**:
`stream`/`streamElevated` set `standardInput = .nullDevice` because Mole's
`clean.sh` decides interactive mode by a TTY check (`[[ -t 0 ]]`), not an env var —
an inherited TTY stdin would hang the unprivileged execute on `read_key`.

**Runtime resolution** (`MoService.resolveMoPath`): bundled
`Contents/Resources/MoleRuntime/mo` → `MOGU_MO_PATH` env override → (DEBUG
only) Homebrew `mo` → nonexistent-path sentinel. `make app` builds the runtime
from the `Vendor/Mole` submodule; packaged builds never use Homebrew Mole.

**`ContentView.swift` — the navigation + action wiring.** Tabs live in a
`ZStack` but lazy-load via `StickyTab` (`isActive || loadedTabs`) — so only the
active tab runs its `mo` call at launch, and switching keeps a tab loaded
(sticky). ContentView declares per-screen `UUID` "trigger" bindings and
loading-state bindings that it threads into each view. Each view's
destructive/refresh actions are
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
- **Preview operations are slow, not hung.** `clean --dry-run` takes ~35–40s,
  `optimize --dry-run` ~5s, and `uninstall … --dry-run` runs a full app scan
  (~5-10s, dominated by the scan, not the app count). Always show a loading
  spinner while a preview runs; a disabled action button with no spinner reads
  as broken.
- **`MOGU_SCREEN=<status|clean|uninstall|analyze|optimize|purge|installer|history|permissions>`** launches
  straight to one tab (set in `ContentView.init`) — useful for verification
  screenshots. Plain `open` does not propagate env vars, but **`open --env`
  does**: `open --env MOGU_SCREEN=clean /Applications/Mogu.app`. Prefer
  this over direct-exec'ing the `MacOS/Mogu` binary — see the FDA gotcha below.
- **Verify FDA state with `open`, never by direct-exec'ing the binary.** macOS
  TCC attributes a permission check to the *responsible process*. Launching
  `…/MacOS/Mogu` from a terminal that has Full Disk Access makes Mogu
  inherit the terminal's FDA, so `probeFullDiskAccess` reads a **false
  "Granted"**. Launch via `open` (LaunchServices) so Mogu is its own
  responsible process and the probe reports truthfully. The probe reads the
  system `/Library/Application Support/com.apple.TCC/TCC.db`.
- **Full Disk Access is optional, not required.** It is surfaced as a quiet-scan
  convenience for Analyze/home-dir scans and probed by reading the system TCC DB;
  Administrator remains optional and only for user-chosen elevation. The signing
  detail still holds and is worth keeping: `build_app.sh` signs every child binary
  (`mo`, `mole`, Go binaries, shell scripts) with the **same** bundle identifier as
  the parent so they share one signature domain; changing identifiers per-binary
  breaks that inheritance.
- For UI verification, launch the **`.app` bundle** (`open Mogu.app`); a bare
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
2. Read `AGENTS.md` completely
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
