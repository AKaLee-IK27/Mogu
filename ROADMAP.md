# Mogu Roadmap

Mogu is a Mac-first utility: a native SwiftUI shell over the bundled Mole runtime. The roadmap prioritizes install trust, safety clarity, and release reliability before new surfaces.

## Product principles

- **Preview before delete:** destructive flows must show a dry-run preview or explicit confirmation first.
- **Mac-first:** Mogu cleans and inspects the Mac it is running on. A mobile cleaner is out of scope.
- **No permission wall:** the app should launch without prompts; Administrator and Full Disk Access stay contextual.
- **Bundled runtime:** packaged builds use the pinned Mole submodule, not Homebrew Mole.
- **Credit upstream:** Mogu remains an independent GUI and points users to Mole and the official Mole for Mac app.

## Now

- Ship the public landing page with a clear GitHub Releases download path.
- Keep the v1.0 macOS app stable across Status, Clean, Uninstall, Analyze, Optimize, Purge, Permissions, and Settings.
- Preserve preview-first copy and UI affordances across destructive flows.
- Fix the known first-run onboarding dismissal persistence issue.
- Keep parser fixtures aligned with the bundled Mole output format when the submodule changes.

## Next

- Improve release trust: signing, notarization notes, checksums, and clearer install instructions.
- Tighten the Sparkle/appcast release workflow so update metadata is easy to verify before publishing.
- Add clearer cleanup history and receipt-style summaries for what changed after a run.
- Improve first-run guidance around optional Full Disk Access and Administrator prompts.
- Capture fresh runtime screenshots whenever the design system or major screens change.

## Later

- Automate release packaging, appcast signing, artifact verification, and screenshot capture.
- Add localization only after real user demand appears.
- Explore a read-only remote or mobile companion only if users repeatedly ask to monitor multiple Macs from another device.
- Consider deeper Analyze and Purge filtering once the core install/update path is boringly reliable.

## Not planned

- An iOS cleaner. iOS cannot inspect or clean a Mac filesystem.
- Background auto-cleaning without review.
- Bypassing dry-run previews for speed.
- Replacing or competing with the official paid Mole for Mac app.

## How to influence the roadmap

Open an issue with:

1. The Mac cleanup or maintenance job you are trying to do.
2. What you expected Mogu to show before changing files.
3. Whether the request is about safety, clarity, speed, or distribution.
