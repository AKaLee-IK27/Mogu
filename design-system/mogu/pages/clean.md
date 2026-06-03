# Clean Screen

Clean is a preview-first safety surface, not a speed-run cleaner.

## Job

1. Show that a dry-run preview has already happened.
2. Make the potential cleanup impact obvious: total size, category count, and inspected locations.
3. Explain that the bundled Mole runtime cleans the whole preview, so category rows are read-only inspection affordances.
4. Keep system/admin cleanup as a separate confirmation after an elevated dry-run preview.

## Layout

- Header: title, short safety subtitle, previewed-size pill, refresh, Clean All.
- First card after preflight: cleanup summary with one large monospaced size and compact stats.
- Second card: read-only category list with expandable paths.
- Optional card: system-level cleanup confirmation after admin preview succeeds.
- Loading and running states must show visible progress because `clean --dry-run` is slow.

## Copy rules

- Say "preview" before "clean".
- Do not imply category-level cleaning is supported.
- Destructive action copy must say what scope runs: user-owned only or user + system.
- Admin copy should be factual, not alarming.
