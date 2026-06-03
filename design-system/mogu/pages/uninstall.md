# Uninstall Screen

Uninstall is a batch-selection and preview-before-removal surface. It should make
scope, reversibility, and admin deferral obvious before any app is moved to Trash.

## Job

1. Show what Mogu found: installed app count, total app size, and filtered result count.
2. Make current batch scope obvious: selected app count and selected size.
3. Keep admin-required apps visible but disabled, with factual Terminal guidance.
4. Require dry-run preview before the confirmation sheet can move anything to Trash.
5. Make the confirmation sheet read like a receipt: selected apps, leftovers, total size, and Trash recovery.

## Layout

- Header: title, compact subtitle, search field, installed-size pill, refresh.
- If selected: replace passive summary with selection pill, Clear, and Uninstall preview action.
- Main content: summary card, Trash safety note, sortable app list card.
- App rows: checkbox/lock, app icon placeholder, name, bundle ID, Admin badge when needed, size.
- Confirmation sheet: danger-tinted header, total size, scrollable app/path receipt, Cancel, Move to Trash.

## Copy rules

- Use "preview" before "uninstall" until the confirmation sheet.
- Use "Move to Trash" for the final destructive action.
- Do not imply admin apps are removable from this UI.
- Say "selected apps and leftovers" when describing batch scope.
