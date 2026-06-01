# Parser golden fixtures

Captured Mole 1.40.0 output, used by `MoOutputParserTests` to detect when
Mole's text format drifts (the parsers silently return empty on drift).

| Fixture | Provenance |
|---|---|
| `clean-list.txt` | **Real.** Verbatim `~/.config/mole/clean-list.txt` written by `mo clean --dry-run` on macOS (2026-06-01). 15 `===` sections, 46 `# size` lines. |
| `optimize.txt` | **Real.** Verbatim stdout of `mo optimize --dry-run` (2026-06-01). 22 `➤` step headers with `→` detail lines, all successful. |
| `purge.txt` | **Format-verified, not live.** This machine had no purgeable project artifacts, so a live non-empty capture was unavailable. The `━━━ Name ━━━` header is verified against `Vendor/Mole/bin/purge.sh:40`; the `path  # size` line convention matches the proven clean-list format (same `note_activity` mechanism in `lib/core/base.sh`). Regenerate from a real machine with build artifacts when possible. |

To refresh: `mo clean --dry-run` then copy `~/.config/mole/clean-list.txt`;
`mo optimize --dry-run > optimize.txt`.
