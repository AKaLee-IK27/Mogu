# Mogu Design System

> Global source of truth for Mogu UI work. Page-specific files may live under
> `design-system/mogu/pages/`; if a page file exists, it can override this file
> for that page only.

**Project:** Mogu  
**Platform:** SwiftUI macOS app  
**Source seed:** Curated for native macOS utility use  
**Last updated:** 2026-06-03

## Visual thesis

Mogu is a compact native macOS utility: calm system surfaces, navy/indigo brand
accents, precise monospaced metrics, and clear safety states. The UI should feel
like a reliable tool, not a marketing dashboard or a generic web app.

## Non-negotiable project rules

- Never use SwiftUI `.toolbar`, `ToolbarItem`, `ToolbarItemGroup`, or `.searchable`.
  These crash on the target macOS runtime. Put controls in the normal view tree.
- Do not change destructive behavior. Preview-before-delete remains the product
  invariant.
- Launch runtime checks with `open --env MOGU_SCREEN=<tab> /Applications/Mogu.app`.
  Do not direct-exec the binary for FDA-sensitive verification.
- Use `DesignTokens` for color, typography, spacing, radius, shadow, and motion.
  Do not hardcode new colors in views.
- Use SF Symbols for icons. No emoji icons.

## Design direction

| Axis | Decision |
|---|---|
| Product type | Native macOS cleaner and system utility |
| Style | Data-dense utility dashboard, not SaaS landing page |
| Mood | Precise, safe, quiet, fast |
| Signature | Navy/indigo app mark plus monospaced live metrics |
| Primary mode | System light/dark, both fully supported |
| Density | Compact, scan-first, 14 pt body text |

## Color system

Canonical implementation: `Sources/Theme/DesignTokens.swift`.

| Token | Light | Dark | Use |
|---|---:|---:|---|
| `sidebar` | `#E9EBF3` | `#171922` | Left navigation canvas |
| `pageBackground` | `#F4F5FA` | `#0F1117` | Main canvas |
| `cardBackground` | `#FFFFFF` | `#1A1D27` | Cards and controls |
| `elevatedBackground` | `#FFFFFF` | `#222636` | Prominent overlays |
| `insetBackground` | `#EDF0F7` | `#121520` | Recessed strips, code/feed areas |
| `separator` | `#CFD3DF` | `#373C4D` | Structural dividers |
| `separatorLight` | `#E1E4ED` | `#2A2F3E` | Internal row dividers |
| `primary` | `#1B1D27` | `#F4F6FB` | Primary text |
| `secondary` | `#51586A` | `#A9AFBD` | Secondary text |
| `tertiary` | `#7B8190` | `#737A8A` | Captions and muted affordances |
| `accent` | `#34489E` | `#7185EF` | Primary Mogu action and selected state |
| `accentSoft` | `#E7EAF8` | `#22284D` | Accent pill background |
| `accentTint` | `#2B3D8E` | `#8FA1FF` | Accent text on neutral surfaces |

Semantic states:

| State | Use |
|---|---|
| `success*` | Health score, completed actions, safe state |
| `warning*` | Admin escalation, medium health, user attention |
| `danger*` | Delete/uninstall, critical health, failure |
| `purgeAccent` | Purge identity only |

## Typography

Use native San Francisco via `Font.system`. Do not add web fonts or Google Fonts.
A prior draft considered Fira, but that would make a native macOS app feel
non-native and would add distribution complexity.

| Role | Token | Rule |
|---|---|---|
| Page title | `Font.page` | 24 pt bold |
| Section title | `Font.section` | 17 pt semibold |
| Body | `Font.body` | 14 pt regular |
| Body emphasis | `Font.bodyStrong` | 14 pt medium |
| Captions | `Font.caption` / `captionStrong` | 12 pt regular/semibold |
| Labels | `Font.label` / `labelUppercase` | 11 pt medium/semibold |
| Metrics | `Font.mono*` / `displayNumber*` | Monospaced, tabular by construction |
| Code/feed | `Font.code` | Monospaced 13 pt |

Rules:

- Numbers, sizes, percentages, and process CPU/memory columns use monospaced fonts.
- Headings use sentence case, not title case unless it is a product name.
- Success copy says what happened without exclamation marks.
- Errors should say what failed and what the user can do next.

## Spacing, radius, and depth

Implemented tokens:

| Scale | Values |
|---|---|
| Spacing | `xxs 3`, `xs 6`, `sm 8`, `md 12`, `lg 16`, `xl 20`, `xxl 24`, `xxxl 32` |
| Radius | `tiny 4`, `small 6`, `medium 9`, `large 14`, `xLarge 18`, `pill 999` |
| Layout | Sidebar `230`, header X `32`, header Y `18`, card padding `18`, min hit `40` |
| Shadow | `Shadow.card` for cards, `Shadow.control` for compact controls |

Surface hierarchy:

- Sidebar and main canvas must differ in both light and dark appearances.
- Cards should lift with shadow in light mode and luminance stepping in dark mode.
- Use borders for dividers and table rows, not as decorative card fences.

## Components

### App shell

- Sidebar width is fixed at `DesignTokens.Layout.sidebarWidth`.
- Selected sidebar rows use `selectedOverlay` plus the feature accent rail.
- Sidebar icons use each tab's semantic color, but text remains neutral.

### Screen headers

- In-view header only. No window toolbar.
- Horizontal padding: `Layout.headerHorizontalPadding`.
- Vertical padding: `Layout.headerVerticalPadding`.
- Left side: title and short functional subtitle.
- Right side: summary pill, search field, refresh, and primary action as needed.

### Controls

- Icon-only controls have at least a `40 x 40` hit area.
- Header icon buttons use a compact visible square with a larger hit frame.
- Primary actions use native `.borderedProminent` unless a screen has a strong
  destructive state, then use semantic danger tint.
- Search is `InlineSearchField`, never `.searchable`.

### Cards and lists

- Cards use `cardBackground`, `Radius.large`, `Shadow.card`, and `Layout.cardPadding`.
- Dense rows should keep 8 to 12 pt vertical padding.
- Numbers align right, labels align left.
- Keep row separators subtle with `separatorLight`.

### Loading, empty, and error states

- Use `FeatureLoadingView` with per-tab icon and tint.
- Use `ErrorStateView` for mo-backed load failures.
- Empty states should answer: what was checked, why nothing appears, and what to try next.

## Screen-specific notes

| Screen | Design job |
|---|---|
| Status | Orient, show live health, surface hidden system metrics |
| Clean | Preview cleanup impact, make safety obvious |
| Uninstall | Batch selection, admin deferral, leftover preview |
| Analyze | File hierarchy and large-file insight |
| Optimize | Step-by-step progress and admin fallback |
| Purge | Developer artifact scan with terminal-style activity feed |
| Permissions | Explain optional grants, avoid pressure |
| Settings | Native preferences, minimal toggles |

## Motion

- Default micro-interaction: `DesignTokens.spring` for view entrance and value updates.
- Use opacity and offset for staged reveals.
- No ornamental spinning except loading states.
- Respect reduced-motion in any future long-running animation work.

## Verification checklist

Before considering a design-system change done:

- [ ] `make build`
- [ ] `make test`
- [ ] `make parser-test`
- [ ] `make app`
- [ ] Launch at least the changed tab with `open --env MOGU_SCREEN=<tab> /Applications/Mogu.app`
- [ ] Verify light and dark mode if colors or surface tokens changed
- [ ] Grep confirms no `.toolbar`, `ToolbarItem`, `ToolbarItemGroup`, or `.searchable` in changed UI code
- [ ] No destructive `mo` command was run without dry-run preview

## Agent prompt guide

When asking an agent to build a Mogu UI surface, say:

> Use `design-system/mogu/MASTER.md` and `Sources/Theme/DesignTokens.swift`.
> Build a native SwiftUI macOS utility surface with compact density, Mogu navy
> accents, SF Symbols, monospaced metrics, `Radius.large` cards, and no toolbar
> or searchable modifiers. Verify with `make app` and `open --env MOGU_SCREEN=<tab> /Applications/Mogu.app`.
