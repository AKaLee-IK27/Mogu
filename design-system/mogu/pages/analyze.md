# Analyze Screen

Analyze is a disk-usage visualization and large-file finding surface. It should
surface what's consuming space and where, with Full Disk Access status clear.

## Job

1. Show the scan scope: total analyzed size, file count, and scanned path.
2. Present the largest directories as a ranked, scannable list with proportional size bars.
3. Surface large individual files separately when they dominate the total.
4. Make Full Disk Access status obvious, with a direct Settings link.

## Layout

- Header: title, compact subtitle, total-size pill, refresh.
- Optional FDA banner with Open Settings button.
- Summary card: total size, total files, scanned path.
- Top-entries card: ranked directory list with proportional size bars and percentage.
- Large-files card: ranked individual files with size.

## Copy rules

- Use "analyzed" for the total scan size.
- Use "Top entries" for the largest directories found by Mole.
- Use "Large files" for individual files that dominate disk space.
- Do not imply that files can be deleted from this screen.
