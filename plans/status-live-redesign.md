# Handoff: Live (streaming) System Status + data-viz redesign

**Owner:** Pi (execution) · **Controller/verifier:** Claude
**Status:** Approved, not started
**Verification gate:** runtime launch + screenshot (NOT `make build` alone)

---

## Goal

Turn the Status screen from a one-shot static snapshot into a **live, auto-updating
dashboard**: poll `mo status --json` every ~3s into a rolling history buffer, and
redesign it with **Swift Charts** time-series visuals that surface the metrics
currently decoded but never rendered.

## Scope

- Status screen only. Do **not** touch Clean / Uninstall / Analyze / Optimize / Purge / Permissions.
- 5 files total: 3 modified, 2 new. No new dependency (`import Charts` is a system framework).

## Non-scope (explicitly rejected)

- True sub-second streaming — impossible; `mo status --json` is one-shot, only the
  unparseable TUI is live. 3s polling + animated transitions is the ceiling.
- Native macOS metric APIs (`host_statistics`) to bypass `mo` — abandons the
  "thin shell over `mo`" architecture. Rejected.
- User-facing pause/play or interval controls — auto-live, gated only.

---

## The two asks are ONE architecture

`poll → accumulate history → chart`. Polling makes it live; the accumulated buffer
is what makes sparklines/trends drawable (a single snapshot can't show a trend).

## Measured facts (do not re-measure, already verified)

- Each snapshot = ~1.05s CPU sampling window (1.09 / 0.96 / 1.11s back-to-back).
- Payload ~4.5 KB JSON.
- `mo status --json` has **no** watch/interval flag — one-shot only.
- These fields are **already decoded** in `SystemStatus` but rendered NOWHERE:
  `cpu.per_core`, `memory.swap_used`/`swap_total`/`cached`, `disk_io`, `proxy`, `uptime`.

---

## Key decisions (locked)

1. **Poll cadence = 3s, no overlap.** Never issue poll N+1 until N returns. 3s keeps
   `status-go` from running ~50% of the time and inflating its own CPU number.

2. **Gated polling — THE load-bearing safety requirement.** All six views live in a
   `ZStack` in `ContentView` and never deinit, so a naive timer polls `mo` forever on
   hidden tabs (battery drain + `status-go` polluting the process list it renders).
   Poll **only when `selectedItem == .status` AND the app is frontmost.**
   - Thread `isActive: Bool` from `ContentView` into `StatusView`.
   - Combine with `@Environment(\.scenePhase) == .active`.
   - Drive an `.task(id:)` loop keyed on the combined gate; loop exits when gate is false.
   - Switching tabs or backgrounding the app MUST stop subprocess spawning.

3. **Honest animation (anti-pattern #11 — no invented data).** Snap each bar/number to
   its real measured value with a ~0.3s spring, then hold until the next real sample.
   Do **NOT** tween bar positions smoothly across the 3s gap — that paints values never
   measured. Sparkline lines *between* real sample points are fine (charting convention).

4. **Real sample time.** Add `collected_at` to the model; use it for the "last updated"
   label instead of `Date()`.

5. **Surface the hidden data** (the concrete answer to "bad for visualizing"):
   `per_core` → P/E-colored bar strip; `swap`+`cached` → memory breakdown;
   `disk_io` read/write → sparklines; `network` rx/tx → sparklines; `uptime` → header;
   `proxy` → badge.

6. **Stable process rows.** Top-processes keeps a **stable sort order** between polls
   with values animating in place — no row reordering jitter every 3s.

---

## Components (Swift Charts)

- `LiveSparkline` — `Chart { LineMark }` over history buffer. Reused for CPU%,
  disk read, disk write, net rx, net tx.
- `PerCoreStrip` — compact bars from `cpu.per_core`, P-cores vs E-cores color-coded.
- `MemoryBreakdownBar` — segmented bar: used / cached / free + swap indicator.
- `StatusHistory` — ring buffer (~60 samples ≈ 3 min at 3s); capped to bound memory.
- Keep existing `ProgressBar` / `MiniBar` for instantaneous gauges.

## Target layout (reference)

```
System Status        ● live        75 ▓
M4 Pro · 24GB · macOS 26.5 · up 1d 5h
──────────────────────────────────────
CPU  12.4%   ╱╲╱‾╲╱╲   (sparkline)
  P ▕▏▕▎▍▏   E ▏▎▏▏    per-core strip
──────────────────────────────────────
MEM 46%  used 11G ┃ cached 4G ┃ swap 0
DISK I/O  ↓2.1 ╱╲╱   ↑0.4 ╲╱‾
NET en0   ↓12.4 ╱╲   ↑1.1 ╲╱‾
──────────────────────────────────────
Top processes (stable order, live %)
```

---

## Files

**Modify**
- `Sources/Models/SystemStatus.swift` — add `collectedAt: String?` (key `"collected_at"`),
  optionally `procs: Int?`. (`per_core`/`swap`/`cached`/`disk_io`/`proxy`/`uptime` already decoded.)
- `Sources/Views/StatusView.swift` — replace one-shot `.task` (line ~47) with gated polling
  loop + history buffer; new charted layout; stable process order; `collected_at` timestamp.
  Current refresh logic is at `refresh()` (line ~285); single `.task { await refresh() }` at line ~47.
- `Sources/ContentView.swift` — pass `isActive: selectedItem == .status` into
  `StatusView(...)` at line ~117.

**Create**
- `Sources/Models/StatusHistory.swift` — ring buffer + sample type.
- `Sources/Views/Components/StatusCharts.swift` — `LiveSparkline`, `PerCoreStrip`,
  `MemoryBreakdownBar`.

---

## Crash guards (MANDATORY — known macOS 26.5 SIGTRAPs)

- **No `.toolbar` / `ToolbarItem` / `ToolbarItemGroup`.** Header actions stay inline `Button`s.
- **No `.searchable`.** (Not needed here anyway.)
- Don't hardcode colors — use `DesignTokens`. Add chart colors there if needed.

---

## Verification (runtime — anti-pattern #20; compile is NOT sufficient)

1. `make app`
2. `DRILBUR_SCREEN=status /Applications/Drilbur.app/Contents/MacOS/Drilbur`
3. Numbers/bars update on ~3s cadence; sparklines accumulate a trend. **Screenshot.**
4. Switch to another tab → Activity Monitor shows `status-go` **stops** spawning (proves
   gating). Background the app → same.
5. No launch/interaction crash.

`make build` / `make test` is a necessary compile gate but NOT sufficient evidence of done.

## Rollback

Pure UI + one additive optional model field. Revert the 5 files. No persisted/external
state touched.

## Most fragile assumption

Assumes ~3s cadence reads as "live." If sub-second smoothness is expected, polling a
subprocess can't deliver it without abandoning the `mo`-shell architecture. Flag before building.
