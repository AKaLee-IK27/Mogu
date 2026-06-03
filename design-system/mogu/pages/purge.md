# Purge Screen

Purge is a read-only developer-artifact scan. It surfaces build caches and
dependency folders across common project directories. It never deletes from
the GUI — cleanup must happen in Terminal.

## Job

1. Show what was scanned: total artifact size, project count, and scanned paths.
2. Surface the biggest build caches: node_modules, target, .build, dist.
3. Make it obvious that purge is read-only; interactive cleanup requires Terminal.
4. Keep the terminal-style activity feed visible during the scan.

## Layout

- Header: title, compact subtitle, search field, total-size pill, refresh.
- Summary card: total artifact size, project count, scan paths.
- Read-only note with Terminal guidance.
- Project list: ranked by size, with type badges and monospaced sizes.
- Loading state: terminal-style activity feed.

## Copy rules

- Use "artifact scan" not "purge" as the primary label.
- Use "Read-only scan" when describing what Purge does.
- Say "Interactive cleanup requires Terminal: mo purge" for the action guidance.
- Do not imply this screen can delete anything.
