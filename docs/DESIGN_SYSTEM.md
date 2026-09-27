# MyBaby — Design System (v3 — Serene Nurture)

_Companion to [UX.md](./UX.md), which stays the source of truth for screen content and interaction behavior. This doc is the visual/engineering spec: the tokens, components, and motion that deliver UX.md's principles without leaning on Material Design's defaults._

**v3 changelog**: full visual redesign following a Stitch design system called "Serene Nurture" — a flat, card-based "organic minimalism" replacing v2's frosted-glass look. Cards, nav, sheets, and buttons are now opaque surfaces with soft ambient shadows instead of `BackdropFilter` blur. Primary color is now a calmer eucalyptus green, with two new semantic accents (warm amber, soft coral) used to tint activity types (sleep/feed/diaper). Font switched from Inter to Plus Jakarta Sans. Radii, spacing rhythm, and motion durations/curves are otherwise unchanged from v2.

## 1. Purpose

MyBaby does not use Material theming (`ColorScheme.fromSeed`, `ThemeData` component themes, `Theme.of(context)`). Every visual decision — color, type, spacing, radius, motion — comes from a bespoke token tree in `lib/core/theme/` and a set of custom widgets in `lib/shared/widgets/`. `MaterialApp.router` remains the app's outer shell only for routing/localization plumbing that `go_router` expects; it carries no real styling.

If you're adding a new screen or widget: reach for `AppTheme.of(context)` and the components below, never `Theme.of(context)`.

## 2. Principles

Extends UX.md's principles with three more that are specific to the visual system:

1. **Calm, not clinical** _(from UX.md)_ — warm color, plain language, no alarm red.
2. **One-handed, at 3am** _(from UX.md)_ — large touch targets, no confirmation dialogs for routine logging.
3. **Flat and legible, not decorative** — surfaces are opaque cards with soft ambient shadows, not translucent/blurred glass. Every elevated surface in the app (cards, nav, sheets, buttons) uses the same fill/border/shadow recipe (`AppColors.surface` + `AppColors.hairline` + one of `AppShadows`) via one shared widget (`AppGlassSurface`) — never a bespoke shadow value per screen.
4. **Deliberate motion, never decorative** — every animation communicates something (this appeared, this is now selected, this is temporarily elevated). Nothing animates just to look busy; nothing bounces or overshoots.

## 3. Color

Palette follows the Stitch "Serene Nurture" design system for light mode; `dark` and `night` are derived from the same hue family (brightened for dark, dimmed for night) since the source design is light-only.

| Token | Light | Dark | Night |
|---|---|---|---|
| `background` (canvas) | `#F8F9FA` | `#18181B` | `#0A0A0B` |
| `surface` (cards, fields) | `#FFFFFF` | `#1F2422` | `#141715` |
| `surfaceSunken` (tracks, chip backgrounds) | `#F3F4F6` | `#262B28` | `#1B1E1A` |
| `hairline` | `#E5E7EB` | `#32382F` | `#24271F` |
| `primary` (eucalyptus — sleep, primary CTA, active nav) | `#2D6A4F` | `#52A37A` | `#3F6B54` (dimmed) |
| `secondary` (warm amber — feed, reminders) | `#D97706` | `#F2A65A` | `#8A5A25` (dimmed) |
| `tertiary` (soft coral — diaper, wellness) | `#E07A5F` | `#F0947D` | `#8A5546` (dimmed) |
| `onPrimary` | `#FFFFFF` | `#0B1F16` | `#E9ECE6` |
| `textPrimary` | `#1F2937` | `#ECEFEA` | `#A9B0A6` (reduced brightness) |
| `textSecondary` | `#4B5563` | `#AEB6AA` | `#6B7268` |
| `textTertiary` | `#9CA3AF` | `#6E7568` | `#45493F` |
| `status.done` | `#4C8C8A` | `#6FBBB8` | `#3C6664` (dimmed) |
| `status.dueSoon` (= `secondary`) | `#D97706` | `#F2A65A` | `#8A5A25` |
| `status.overdue` (= `tertiary`) | `#E07A5F` | `#F0947D` | `#8A5546` |
| `info` (sleep only) | `#6366F1` | `#8B87F0` | `#4B4894` (dimmed) |

**Usage**: activity-type tinting (`lib/shared/care_log_type_style.dart`, used by Home's quick-log cards and the Care Log timeline) follows the actual Stitch mockups rather than the Serene Nurture prose: **amber (`secondary`) for feed, indigo (`info`) for sleep, eucalyptus (`primary`) for diaper** — the mockups consistently render sleep with a blue/lavender icon that has no equivalent in the exported token list, so `info` was added specifically for it. Status colors are reserved for meaning (vaccination status) — never decorative; `status.dueSoon`/`status.overdue` deliberately alias `secondary`/`tertiary`, while `status.done` stays a distinct teal so "done" never reads as an extension of `primary`. Selected/active states (nav items, chips, segmented controls) use a soft `primary.withValues(alpha: 0.12)` tint rather than a solid fill, so the accent stays legible without dominating the flat white surfaces around it.

**Contrast**: `textPrimary` on `surface` meets WCAG AA (4.5:1) in all three modes. Night mode's dimmed `primary`/`secondary`/`tertiary`/`status.*` values were chosen to still clear 4.5:1 against `night`'s near-black background — dimmed means lower saturation/brightness, not lower contrast.

## 4. Typography

Font: **Plus Jakarta Sans** (replaces v2's Inter, per the Stitch spec — a slightly warmer, more humanist geometry than Inter while staying highly legible at small sizes). Scale (sizes/weights/line-heights) is unchanged from v2.

| Token | Size | Weight | Line height | Usage |
|---|---|---|---|---|
| `numeralXL` | 40sp | w800 | 1.1 | Hero measurements (age, weight/height on Growth) |
| `numeralL` | 28sp | w800 | 1.15 | Card-level measurements (Home growth snapshot, Care Log stats) |
| `title` | 20sp | w800 | 1.25 | Screen/section titles, app bar |
| `subtitle` | 16sp | w700 | 1.3 | Card titles, list item primary text |
| `body` | 15sp | w500 | 1.45 | Body copy, list secondary text |
| `caption` | 13sp | w600 | 1.4 | Timestamps, helper text |
| `label` | 12sp | w700 | 1.3 | Buttons, nav labels, status pills, chips |

Text styles carry no color — callers apply `AppColors` explicitly, so a style is never silently tied to a Material role.

**Text scaling**: no fixed-height containers around text. Quick-log buttons and nav labels must be verified at 130% system text scale (see UX.md Accessibility) — wrap in `FittedBox` or allow height to grow rather than clipping.

## 5. Spacing & Layout

Unchanged from v1/v2. 4pt grid:

| Token | Value |
|---|---|
| `xs` | 4 |
| `s` | 8 |
| `m` | 12 |
| `l` | 16 |
| `xl` | 20 |
| `xxl` | 28 |
| `xxxl` | 40 |

Breakpoints: see `lib/core/responsive/breakpoints.dart`. Wide layout switches the bottom tab bar for a floating flat rail on the left (see §7 `AppShell`); `ContentColumn` caps content width at `kContentMaxWidth` (720) on wide/web viewports.

## 6. Radii, Borders & Elevation

Retargeted to the Serene Nurture spec's scale (values changed from v2; token names unchanged):

| Token | Value | Usage |
|---|---|---|
| `radii.s` | 8 | Inputs, small chips |
| `radii.m` | 16 | Cards — every informational container shares this curvature |
| `radii.l` | 24 | Sheet top corners |
| `radii.pill` | 999 | Buttons, chips, nav items |

Elevation is now expressed as soft ambient shadows on opaque surfaces, not blur:

- `AppShadows.card` — Level 1, cards resting on the canvas: `0 4px 20px rgba(17,24,39,.04)` + `0 2px 6px rgba(17,24,39,.02)`.
- `AppShadows.nav` — Level 2, docked/floating navigation: `0 12px 32px rgba(17,24,39,.08)` + `0 4px 12px rgba(17,24,39,.03)`.
- `AppShadows.modal` — Level 3, bottom sheets: `0 -8px 30px rgba(0,0,0,.08)`, diffused upward.

## 7. Motion

Unchanged from v1/v2. Philosophy: **calm and elegant, not playful** — longer-than-Material durations, one consistent easing family, never bounce or overshoot.

| Token | Value |
|---|---|
| `curveStandard` | `Cubic(0.2, 0.0, 0, 1.0)` — steeper deceleration than `Curves.easeOut`, no overshoot |
| `durationFast` | 150ms — tap feedback |
| `durationMedium` | 260ms — element/card transitions, page transitions |
| `durationSlow` | 420ms — sheets |

Primitives (`lib/core/theme/motion/`) are unaffected by the visual redesign — durations/curves/`TapScale`/`StaggeredListEntrance`/`SyncPulse`/`AppPageTransition` are independent of the glass-vs-flat material choice.

**Don'ts**: no bounce/spring/overshoot curves anywhere in the app. No transition longer than 450ms. No animation without a semantic reason (state change, entrance, temporary elevation).

## 8. Components

All in `lib/shared/widgets/` unless noted.

### `AppGlassSurface`
The one elevated-surface primitive every card, button, nav bar, and sheet in the app is built from: an opaque `colors.surface` fill (or an override, e.g. `AppButton`'s primary variant filling with `colors.primary`), an optional hairline border (`border: true` by default), and one of `AppShadows`'s elevation levels. Despite the name (kept from v2 to avoid unnecessary churn), it no longer blurs anything — see §2 principle 3.

### `AppCard`
A thin wrapper around `AppGlassSurface` at `radii.m` (16px), optional `onTap` wrapped in `TapScale`. Replaces `Card` + `InkWell`.

### `AppButton`
Full pill geometry (`radii.pill`), three variants: `primary` is a solid `colors.primary` fill with `colors.onPrimary` label; `tonal` is a soft `colors.primary`-tinted fill with `colors.primary` label; `secondary` is a hairline-bordered `colors.surfaceSunken` fill with `colors.textPrimary` label. 48×48dp minimum size, `TapScale` built in.

### `AppChip`
A flat selectable pill — used for the Care Log activity filter row (`All / Feed / Sleep / Diaper`) and Memories' milestone chips. Selected = soft `primary`-tinted fill + `primary` label; unselected = `surfaceSunken` fill + `textSecondary` label.

### `AppStatusPill`
Icon + **required** text label (never color-only) on a soft `status.*`-tinted background, `radii.pill`. Replaces `Chip`. The label is a required constructor argument — structurally enforces UX.md's "color is never the only signal" rule.

### `AppScaffold`
Wraps `Scaffold`: paints the flat `colors.background` canvas fill behind everything, applies safe-area handling, and exposes a `syncIndicator` slot pinned top-right.

### `AppSectionHeader`
Small uppercase-ish label (`AppTypography.label`, `colors.primary`) with an optional trailing action, used atop grouped content.

### `AppEmptyState`
Icon + one-line prompt, used for empty lists (growth entries, memories, vaccinations) per UX.md.

### Per-activity tinting (`lib/shared/care_log_type_style.dart`)
`careLogTypeColor`/`careLogTypeIconLabel` map `CareLogType` (feed/sleep/diaper) to the icon, label, and tint (`secondary`/`info`/`primary` respectively) used by Home's quick-log cards, Home's "Today's Activity" feed, and the Care Log timeline, so no two screens drift apart on which color means which activity. `computeDailyStats`/`isToday` in the same file are the shared "today's sleep/feed/diaper totals" calculation Home and Care Log both build on.

### Nav (`lib/features/shell/app_shell.dart`) **(redesigned in v3)**
- **Phone**: a flush, full-width flat bottom tab bar (`colors.surface`, top hairline, `AppShadows.nav`), passed to `AppScaffold`'s real `bottomNavigationBar` slot — replaces v2's floating glass pill. Selected item gets a soft `primary`-tinted pill background with a `primary` icon+label; unselected items are `textTertiary`.
- **Wide/web**: a floating flat rail (`AppGlassSurface` at `radii.l`), same layout as v2, just flat instead of glass.
- **App bar**: a flat `colors.surface` strip with a bottom hairline border, no blur — replaces v2's frosted strip.

_(`AppTextField`, `AppBottomSheet` as a dedicated component (its behavior already exists via `showAppSheet`, just not wrapped as a named widget), `AppAppBar`, `AppSnackbar` are part of the intended full system but not yet built — see Adoption tracker.)_

## 9. Dark Mode vs. Night Mode

These are **not** the same thing:

| | Dark | Night |
|---|---|---|
| Purpose | Standard low-light UI, matches OS dark mode | *True* low-light mode for 3am logging — minimum light output |
| Background | `#18181B` | `#0A0A0B` (near-black) |
| Accent (`primary`) | Brightened `#52A37A` | Dimmed `#3F6B54` |
| Status colors | Brightened | Dimmed variants |
| Selected via | System dark mode, or explicit user choice | Explicit user choice only (Settings → Appearance) |

Night is a fourth `AppThemeMode` value (`light` / `dark` / `night` / `system`), not derived from `dark` — see `lib/core/theme/theme_controller.dart`. Neither mode is in the source Stitch design (which is light-only); both are extrapolated from the same eucalyptus/amber/coral hue family using the same brighten-for-dark/dim-for-night approach v2 used.

## 10. Accessibility

Carried forward from UX.md, with where each is enforced:

- **Icon + text always** — no icon-only primary actions. `AppButton` requires a label; `AppIconButton` (when built) will require a tooltip/semantic label.
- **Color never the only signal** — `AppStatusPill` requires a text label alongside its color.
- **Chart data-table fallback** — unchanged, owned by the Growth screen (`fl_chart` usage), not a token concern.
- **Touch targets** — `AppButton` and quick-log controls enforce a 48×48dp minimum.
- **130% text scale** — no fixed-height text containers; verify on any new component.
- **Surface legibility** — text/icons use `AppTypography`'s `textPrimary`/`textSecondary` colors, chosen to clear 4.5:1 against the flat `surface`/`background` fills in all three modes.

## 11. Adoption Tracker

| Screen | Status |
|---|---|
| Home | Rebuilt to match the mockup's structure: combined growth+today's-stats card, inline (non-fixed) Quick Log section, live "Today's Activity" feed reading `careLogProvider`. Dropped the old separate vaccination-due/recent-memory cards, which the mockup doesn't show. |
| App shell (nav) | Rebuilt: flush bottom bar + flat rail/top bar (no structural gap vs. mockup). |
| Growth | Rebuilt: "Current Age" pill + big current-value readout above the segmented control, delta-since-previous-entry on each entry row, full-width bottom "Add Measurement" button (was a small floating chip). **Known gap**: the mockup's WHO percentile curve/tooltip isn't implemented — that needs an age/sex percentile reference dataset the app doesn't have; the chart still just plots the baby's own points. |
| Memories | Rebuilt: milestones are now a boxed grid of icon-topped tiles (was a horizontal chip scroller), "Recent Memories" header with a pill "New Entry" button, full-width bottom "Capture Memory" button. **Known gap**: the mockup's colored category tag per memory ("Outdoor"/"Milestone") isn't implemented — `Memory` has no category field. |
| Health | Rebuilt: added the "Health Status" summary card (protected/action-needed, derived from real vaccination data), merged the three separate add-actions into one full-width "Add Health Record" button with a type picker. |
| Care Log | Rebuilt: richer "Today's Summary" card (icon + value + caption per stat), explicit "+ Add Entry" action, filter chips (`All`/`Feed`/`Sleep`/`Diaper`). |
| Settings | Rebuilt: baby profile row with avatar + "N registered" badge, reminders grouped into one card (+ a third toggle), sign-out row shows the signed-in email. **Known gap**: the mockup's Units & Preferences and Family/Partner-sharing sections aren't implemented — both need new persisted settings/data models this pass didn't add. |
| Onboarding | Already flat pre-v3 — inherited via tokens, no structural gap vs. mockup style. |
| Babies (add/edit forms) | Already flat pre-v3 — inherited via tokens; mockup's richer "Add Baby" (birth measurements, Drive/partner toggles) not built — needs new model fields. |
