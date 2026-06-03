# Session Handoff

## Last Session

**Date:** 2026-06-04
**Branch:** `main`
**Work:** feat-035, Landing Page and Public Roadmap.

## What changed

- Added `index.html`, a static responsive landing page for Mogu.
- Added `ROADMAP.md` with product principles, Now / Next / Later priorities, non-goals, and issue guidance.
- Updated `feature_list.json` and `progress.md` for feat-035.

## Behavior boundaries

- No app runtime behavior changed.
- No new web framework, package manager, analytics, payment provider, or external runtime dependency added.
- Landing page uses existing repo assets: `icon.png` and `screenshots/*.png`.
- Download CTA points to GitHub Releases latest: `https://github.com/AKaLee-IK27/Mogu/releases/latest`.

## Verification

All verification passed in this session:

```bash
make build
make test
make parser-test
```

Browser verification:

- Opened `file:///Users/rowlet/Repos/mogu/index.html` with agent-browser.
- Snapshot confirmed key sections and links render: hero, Features, Screenshots, Safety, Roadmap, Mole credit, FAQ, final CTA.
- Desktop overflow check: `scrollWidth <= innerWidth` at `1280x900`.
- Mobile overflow check: `scrollWidth <= innerWidth` at `375x900`.
- Console messages: none.
- Page errors: none.
- Screenshots captured:
  - `/tmp/mogu-landing-feat035-desktop.png`
  - `/tmp/mogu-landing-feat035-mobile.png`
  - `/tmp/mogu-landing-feat035-light.png`

## Current State

- feat-035 is complete locally.
- Root landing page and public roadmap are ready for review or GitHub Pages-style publishing.
- Existing known issue remains: first-run onboarding dismissal may not persist `hasSeenOnboarding`; still out of scope for feat-035.

## Next Step / Open items

- Review the landing page visually and adjust copy if desired.
- Optionally configure GitHub Pages or publish via another static host.
- Run `/check` before merging or release follow-through.
