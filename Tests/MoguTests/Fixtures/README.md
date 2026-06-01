# Parser golden fixtures

Captured Mole 1.40.0 output, used by `MoOutputParserTests` to detect when
Mole's text format drifts (the parsers silently return empty on drift).

| Fixture | Provenance |
|---|---|
| `clean-list.txt` | **Real.** Verbatim `~/.config/mole/clean-list.txt` written by `mo clean --dry-run` on macOS (2026-06-01). 15 `===` sections, 46 `# size` lines. |
| `optimize.txt` | **Real.** Verbatim stdout of `mo optimize --dry-run` (2026-06-01). 22 `➤` step headers with `→` detail lines, all successful. |
| `purge.txt` | **Format-verified, not live.** This machine had no purgeable project artifacts, so a live non-empty capture was unavailable. The `━━━ Name ━━━` header is verified against `Vendor/Mole/bin/purge.sh:40`; the `path  # size` line convention matches the proven clean-list format (same `note_activity` mechanism in `lib/core/base.sh`). Regenerate from a real machine with build artifacts when possible. |
| `uninstall-preview.txt` | **Real.** Verbatim merged stdout+stderr of `printf 'y\n' \| mo uninstall "IINA" "Bruno" --dry-run` on macOS (2026-06-02), captured exactly as the in-app `streamFeeding` path sees it (includes the ANSI clear-screen / scan-spinner noise the parser must strip). 2 `◎` app groups, 12 `✓` leftover lines, the `➤ Remove 2 apps, 707.3MB` total line. |

To refresh: `mo clean --dry-run` then copy `~/.config/mole/clean-list.txt`;
`mo optimize --dry-run > optimize.txt`; for uninstall,
`printf 'y\n' | LC_ALL=C LANG=C mo uninstall "<App A>" "<App B>" --dry-run > uninstall-preview.txt 2>&1`
(use apps present on the capture machine; the fixture is a static snapshot).

Capture with `LC_ALL=C LANG=C` (as the runtime does — see `MoService.makeEnvironment`).
Re-capturing under a localized locale yields different relative-time/number
formatting and would not match what the app feeds the parser at runtime.
