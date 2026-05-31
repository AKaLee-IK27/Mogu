# Session Progress Log

## Current State

**Last Updated:** 2026-05-31
**Active Feature:** feat-002 — Build Mole from Source (submodule)

## Completed Sub-Tasks This Session

| ID | Sub-Task | Status | Notes |
|---|---|---|---|
| 1 | Install Go | done | go 1.26.3 darwin/arm64 via Homebrew |
| 2 | Remove Vendor/MoleRuntime | done | Deleted pre-built binaries |
| 3 | Add Mole as git submodule | done | Vendor/Mole at main (4f931b8) |
| 4 | Update build_app.sh | done | Builds Go binaries, copies runtime artifacts only |
| 5 | Verify MoService.swift paths | done | No changes needed (still MoleRuntime) |
| 6 | Update CLAUDE.md | done | Build instructions updated |
| 7 | Full build + launch verify | done | App launches, runtime version 1.40.0 |

## Verification Evidence

| Check | Command | Output | Pass? |
|---|---|---|---|
| Swift build | `make build` | Build complete! | ✓ |
| Test | `make test` | Build passed | ✓ |
| Full app build | `make app` | Go binaries built, app signed, installed | ✓ |
| Go binaries | `file Vendor/Mole/bin/status-go` | Mach-O 64-bit executable arm64 | ✓ |
| App launch | `open /Applications/MoleMac.app` | Process running, mo subprocess active | ✓ |
| Runtime version | build output | Bundled Mole runtime: 1.40.0 | ✓ |

## Decisions Made

- **Git submodule over pre-built**: Clone Mole repo and build Go binaries from source during `make app` for native performance and version control.
- **Targeted copy in build_app.sh**: Only copy runtime artifacts (`mo`, `mole`, `bin/`, `lib/`), not the full repo (no `.git`, source, docs, tests in app bundle).
- **Version detection fallback**: Extract VERSION from `mole` script since submodule has no VERSION file.

## Files Modified

- `build_app.sh` — Build Go binaries from source, targeted copy, version fallback
- `CLAUDE.md` — Build instructions, safety note updated
- `init.sh` — Added submodule check
- `feature_list.json` — Updated with feat-002 completed
- `progress.md` — Updated with evidence
- `Vendor/MoleRuntime/` — Deleted (replaced by submodule)
- `Vendor/Mole/` — Added as git submodule
- `.gitmodules` — Created for submodule

## Notes for Next Session

- Go is required to build (`brew install go`)
- First `make app` after clone needs `git submodule update --init --recursive`
- App installed to `/Applications/MoleMac.app` with bundled runtime from source
