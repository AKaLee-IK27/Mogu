# Optimize Screen

Optimize is a step-by-step system maintenance surface. It should make progress
visible, admin escalation clear, and the final state obvious.

## Job

1. Show the maintenance plan before running anything: preview steps stream in live.
2. Make each step's state obvious: pending, running, done, failed, skipped.
3. Keep admin/system steps visible but deferred until an elevated dry-run preview succeeds.
4. Provide a clear complete state with an "Optimize Again" action.

## Layout

- Header: title, compact subtitle, refresh, Run action (disabled until preview ready).
- Optional PreflightBanner (FDA/permissions).
- Status banner card: adapts to previewing/ready/running/complete/error phases.
- System-level optimization card: shown after elevated preview succeeds.
- Step list: live step-by-step rendering with state icons, admin badges, and detail lines.
- Complete state: "Optimize Again" button to re-preview.

## Copy rules

- Use "preview" before "run" or "optimize".
- Use "steps" for the individual maintenance tasks.
- Say "Ready to optimize" when preview finishes without running.
- Say "Optimization complete" when all steps finish successfully.
