# MyBaby — Design System (v2 — Glass)

_Companion to [UX.md](./UX.md), which stays the source of truth for screen content and interaction behavior. This doc is the visual/engineering spec: the tokens, components, and motion that deliver UX.md's principles without leaning on Material Design's defaults._

**v2 changelog**: full visual redesign — richer/more saturated primary, a new bold `accent` color (used only for the active-nav selected pill), a neutral white→light-grey background gradient (briefly tried pink/coral and a primary-to-accent button gradient; both were reverted — see below), and a frosted-glass ("transparent modern") material replacing the v1 flat-fill-plus-hairline-border look for cards, nav, and sheets. Font switched from Nunito to Inter (see §4); the type scale itself, spacing, radii, and motion durations/curves are unchanged from v1.

## 1. Purpose

MyBaby does not use Material theming (`ColorScheme.fromSeed`, `ThemeData` component themes, `Theme.of(context)`). Every visual decision — color, type, spacing, radius, motion — comes from a bespoke token tree in `lib/core/theme/` and a set of custom widgets in `lib/shared/widgets/`. `MaterialApp.router` remains the app's outer shell only for routing/localization plumbing that `go_router` expects; it carries no real styling.

If you're adding a new screen or widget: reach for `AppTheme.of(context)` and the components below, never `Theme.of(context)`.

## 2. Principles

Extends UX.md's principles with three more that are specific to the visual system:

1. **Calm, not clinical** _(from UX.md)_ — warm color, plain language, no alarm red.
2. **One-handed, at 3am** _(from UX.md)_ — large touch targets, no confirmation dialogs for routine logging.
3. **Transparent, layered, one material** — surfaces are frosted glass: blur + a tinted translucent fill + a bright hairline-highlight border, floating over a soft gradient background. Every glass surface in the app (cards, nav, sheets, app bar) uses the *same* blur radius and the *same* per-mode fill/border pair (`AppGlass`/`GlassColors`) via one shared widget (`AppGlassSurface`) — never a bespoke blur value per screen.
4. **Deliberate motion, never decorative** — every animation communicates something (this appeared, this is now selected, this is temporarily elevated). Nothing animates just to look busy; nothing bounces or overshoots.

## 3. Color

Palette is hand-picked, not algorithmically derived. `primary` is a richer, more saturated forest-sage than v1 — still warm-neutral, not clinical blue. `accent` (indigo-violet) exists as a token but isn't currently used anywhere visible — an earlier iteration used a `primary`→`accent` gradient for every selected/active chip and pill (nav item, segmented controls, toggles, step dots), but that was reverted to a single solid `primary` fill per feedback ("no gradients"). Status colors are untouched from v1: they're semantic, not decorative, so the visual redesign doesn't touch their hue.

| Token | Light | Dark | Night |
|---|---|---|---|
| `backgroundGradient` (2-stop, top→bottom) | `#FFFFFF` → `#F2F2F4` (white, barely-there grey) | `#18181B` → `#1E1E21` | `#0A0A0B` → `#0E0E10` |
| `surface` (solid fallback, e.g. text field fill) | `#FFFFFF` | `#20241D` | `#12140F` |
| `surfaceSunken` | `#EFEAE0` | `#12140F` | `#060704` |
| `hairline` | `#DEDAD0` | `#2E332A` | `#1C1F18` |
| `primary` | `#2F7A54` (richer/more saturated than v1's `#4F7A64`) | `#6FBE95` (brightened for dark bg) | `#3F6B54` (dimmed) |
| `accent` **(new)** | `#6C5CE0` | `#9C8FFF` (brightened) | `#4E4590` (dimmed) |
| `onPrimary` | `#FFFFFF` | `#12140F` | `#0A0C08` |
| `onGlassProminent` (label on `AppButton` primary) | `#23271F` | `#20241D` | `#ECF0E6` |
| `textPrimary` | `#23271F` | `#ECF0E6` | `#B9C2AE` (reduced brightness) |
| `textSecondary` | `#5F6A5A` | `#AAB3A0` | `#6D7566` |
| `textTertiary` | `#93998C` | `#6E7568` | `#454A40` |
| `status.done` | `#4C8C8A` (teal — distinct from `primary`'s green) | `#4C8C8A` | `#375F5D` (dimmed) |
| `status.dueSoon` | `#DE9A3C` | `#DE9A3C` | `#A5722C` (dimmed) |
| `status.overdue` | `#C96A57` | `#C96A57` | `#95503F` (dimmed) |
| `glass.fill` | `#EDEDF1` @ 94% (grey-tinted, not pure white — see below) | `#FFFFFF` @ 25% | `#FFFFFF` @ 15% |
| `glass.border` | `#FFFFFF` @ 80% | `#FFFFFF` @ 30% | `#FFFFFF` @ 19% |
| `glass.prominentFill` (`AppButton` primary only) | `#FFFFFF` @ 90% | `#FFFFFF` @ 70% | `#FFFFFF` @ 25% |

**Usage**: status colors are reserved for meaning (vaccination status, sync state) — never decorative. `primary` (green) is *not* used to mark selected/active tab-like states — an earlier iteration filled every selected chip/nav-item/toggle with solid `primary`, but per feedback that read as "too green" and didn't match the iOS segmented-control look being targeted. Selected states are now `colors.surface` (a solid near-white/elevated pill) with a `colors.textPrimary` (black-ish) label — nav item, segmented controls (Growth's measure toggle, baby-form's sex picker), achieved-milestone chips (Memories), onboarding step dots (`textPrimary` fill, no label) — sitting on a `colors.surfaceSunken` (grey) track/background, exactly like iOS's white-selected-segment-on-grey-track pattern. The Settings toggle follows the same idea: `colors.textTertiary` (grey) track when on, `colors.surfaceSunken` when off, white knob throughout. `primary` itself is now reserved for small accent touches only (e.g. an inline "add" icon, a focused input border) — never a selection fill. It's no longer used for the primary button either (see `AppButton` in §8: its CTA is white glass, not a color). `status.done` uses a teal rather than green specifically so a "done" pill never reads as an extension of the `primary` accent. `glass.fill`/`glass.border`/`glass.prominentFill` are used *only* through `AppGlassSurface` — never referenced directly by a screen.

**Contrast**: `textPrimary` on `surface`/glass fills meets WCAG AA (4.5:1) in all three modes. Night mode's dimmed `status.*`, `primary`, and `accent` values were chosen to still clear 4.5:1 — dimmed means lower saturation/brightness, not lower contrast. Night mode's glass opacity is also the lowest of the three modes (15%/19%), so frosted panels stay close to the near-black background rather than brightening the screen.

**Container depth**: against the now-neutral white/grey background (see below), a purely white translucent fill at low opacity didn't read as a distinct raised surface — it blended into the page. Light mode's `glass.fill` is therefore a grey-tinted white (`#EDEDF1`) at higher opacity (94%, up from v2's original 55%) rather than pure white, and `AppShadows.glass` was strengthened (`blurRadius` 40→44, opacity ~13%→~16%) so every card/nav/sheet reads as clearly sitting above the background rather than blurring into it.

## 4. Typography

Font: **Inter** (replaces v1/early-v2's Nunito — Nunito's rounded warmth read as mismatched against the glass/neutral redesign; Inter is neutral, modern, and highly legible at small sizes, closer to the system-font feel of iOS/Android). Scale (sizes/weights/line-heights) is unchanged from v1.

| Token | Size | Weight | Line height | Usage |
|---|---|---|---|---|
| `numeralXL` | 40sp | w800 | 1.1 | Hero measurements (age, weight/height on Growth) |
| `numeralL` | 28sp | w800 | 1.15 | Card-level measurements (Home growth snapshot) |
| `title` | 20sp | w800 | 1.25 | Screen/section titles, app bar |
| `subtitle` | 16sp | w700 | 1.3 | Card titles, list item primary text |
| `body` | 15sp | w500 | 1.45 | Body copy, list secondary text |
| `caption` | 13sp | w600 | 1.4 | Timestamps, helper text |
| `label` | 12sp | w700 | 1.3 | Buttons, nav labels, status pills |

Text styles carry no color — callers apply `AppColors` explicitly, so a style is never silently tied to a Material role.

**Text scaling**: no fixed-height containers around text. Quick-log buttons and nav labels must be verified at 130% system text scale (see UX.md Accessibility) — wrap in `FittedBox` or allow height to grow rather than clipping.

## 5. Spacing & Layout

Unchanged from v1. 4pt grid:

| Token | Value |
|---|---|
| `xs` | 4 |
| `s` | 8 |
| `m` | 12 |
| `l` | 16 |
| `xl` | 20 |
| `xxl` | 28 |
| `xxxl` | 40 |

Breakpoints: see `lib/core/responsive/breakpoints.dart`. Wide layout switches the bottom pill nav for a floating glass rail on the left (see §8 `AppNavShell`); `ContentColumn` caps content width at `kContentMaxWidth` (720) on wide/web viewports.

## 6. Radii, Borders & Elevation

Unchanged from v1:

| Token | Value | Usage |
|---|---|---|
| `radii.s` | 12 | Buttons, inputs |
| `radii.m` | 20 | Cards |
| `radii.l` | 28 | Sheets, wide nav rail |
| `radii.pill` | 999 | Status pills, bottom nav pill, nav indicator |

**Glass philosophy (replaces v1's "flat + border")**: every elevated surface — cards, the floating nav, bottom sheets, the app bar — is frosted glass: `BackdropFilter` blur at one fixed radius (`AppGlass.blurSigma = 20`) + the current mode's `glass.fill`/`glass.border`, built through the single shared `AppGlassSurface` widget so the material reads as consistent everywhere, never a per-screen effect.

Two shadow tokens, both reserved for things genuinely above the flow (never a flat/solid content's default):
- `AppShadows.floating` — sheets, snackbars.
- `AppShadows.glass` — cards, the floating nav pill/rail; softer and wider than `floating` so glass reads as resting just above the gradient.

## 7. Motion

Unchanged from v1. Philosophy: **calm and elegant, not playful** — longer-than-Material durations, one consistent easing family, never bounce or overshoot.

| Token | Value |
|---|---|
| `curveStandard` | `Cubic(0.2, 0.0, 0, 1.0)` — steeper deceleration than `Curves.easeOut`, no overshoot |
| `durationFast` | 150ms — tap feedback |
| `durationMedium` | 260ms — element/card transitions, page transitions |
| `durationSlow` | 420ms — sheets |

Primitives (`lib/core/theme/motion/`):

- **`TapScale`** — wraps any tappable; scales to 0.97 on press-down, reverses on release. Replaces `InkWell` ripple everywhere.
- **`AppPageTransition`** — go_router `CustomTransitionPage`: cross-fade + subtle upward slide, `durationMedium`, `curveStandard`. Replaces Material's slide-from-right.
- **`StaggeredListEntrance`** — wraps a list of children with a `flutter_animate` fade + slide-up entrance, 40–60ms stagger between items. Used for card/list content appearing on screen load.
- **`AppSheetTransition`** (`showAppSheet`) — bottom-sheet slide-up + fade, `durationSlow`, `curveStandard`, frosted-glass chrome.
- **`SyncPulse`** — a slow (1.8s), low-amplitude breathing-opacity loop for the sync indicator dot (see UX.md "Sync indicator"), using `curveStandard` like every other motion primitive.

**Don'ts**: no bounce/spring/overshoot curves anywhere in the app. No transition longer than 450ms. No animation without a semantic reason (state change, entrance, temporary elevation).

## 8. Components

All in `lib/shared/widgets/` unless noted.

### `AppGlassSurface` **(new in v2)**
The one frosted-glass container everything else is built from: `BackdropFilter` blur (`AppGlass.blurSigma`) + `ClipRRect` + `Container` with `colors.glass.fill`/`colors.glass.border`, optional `AppShadows.glass`. Takes `borderRadius`/`padding`. Any new translucent surface should be built from this, not a hand-rolled `BackdropFilter`.

### `AppCard`
Now a thin wrapper around `AppGlassSurface` (`radii.m` corners), optional `onTap` wrapped in `TapScale`. Replaces `Card` + `InkWell`.

### `AppButton`
All three variants are frosted glass — no color gradient. `primary` uses `colors.glass.prominentFill` (a brighter white glass than the ambient `glass.fill`, with label color `colors.onGlassProminent`) — the iOS-26/27-style "Liquid Glass" CTA treatment: white and translucent, standing out by brightness rather than hue. `tonal`/`secondary` use the ambient glass fill with `textPrimary` labels. 48×48dp minimum size, `TapScale` built in, label uses `AppTypography.label`.

### `AppStatusPill`
Icon + **required** text label (never color-only) on a soft `status.*`-tinted background, `radii.pill`. Replaces `Chip`. The label is a required constructor argument — structurally enforces UX.md's "color is never the only signal" rule. Unchanged visually from v1 (solid tint, not glass) so status meaning stays maximally legible.

### `AppScaffold`
Wraps `Scaffold`: paints `colors.backgroundGradient` behind everything (`extendBodyBehindAppBar: true` so it shows through the frosted app bar), applies safe-area handling, and exposes a `syncIndicator` slot pinned top-right. Still a real `Scaffold` underneath (keyboard/a11y plumbing unaffected).

### `AppSectionHeader`
Small uppercase-ish label (`AppTypography.label`, `colors.primary`) with an optional trailing action, used atop grouped content.

### `AppEmptyState`
Icon + one-line prompt, used for empty lists (growth entries, memories, vaccinations) per UX.md.

### Nav (`lib/features/shell/app_shell.dart`) **(redesigned in v2)**
- **Phone**: a floating glass pill — `AppGlassSurface` at `radii.pill`, positioned with margin on all sides (`AppSpacing.xl` sides, `AppSpacing.l` bottom) so the background shows around it and content scrolls underneath. Selected item gets a fully circular (`radii.pill`) `colors.surface` chip with a `textPrimary` icon+label (the iOS segmented-control look); unselected items are transparent with a `textTertiary` icon+label.
- **Wide/web**: the rail equivalent — a fixed-width (88) `AppGlassSurface` at `radii.l`, floating with `AppSpacing.l` margin on the left rather than docked full-height as in v1.
- **App bar**: a full-width frosted glass strip (blur + `glass.fill`/`glass.border`, bottom border only, no corner radius) rather than v1's solid fill + hairline.

_(`AppTextField`, `AppBottomSheet` as a dedicated component (its behavior already exists via `showAppSheet`, just not wrapped as a named widget), `AppAppBar`, `AppSnackbar` are part of the intended full system but not yet built — see Adoption tracker.)_

## 9. Dark Mode vs. Night Mode

These are **not** the same thing:

| | Dark | Night |
|---|---|---|
| Purpose | Standard low-light UI, matches OS dark mode | *True* low-light mode for 3am logging — minimum light output |
| Background gradient | `#18181B` → `#1E1E21` | `#0A0A0B` → `#0E0E10` (near-black) |
| Accent (`primary`) | Full-brightness `#6FBE95` | Dimmed `#3F6B54` |
| Status colors | Full-brightness | Dimmed variants |
| Glass opacity | 20%/25% (fill/border) | 12%/15% — lowest of the three modes, to avoid brightening the screen |
| Selected via | System dark mode, or explicit user choice | Explicit user choice only (Settings → Appearance) |

Night is a fourth `AppThemeMode` value (`light` / `dark` / `night` / `system`), not derived from `dark` — see `lib/core/theme/theme_controller.dart`.

## 10. Accessibility

Carried forward from UX.md, with where each is enforced:

- **Icon + text always** — no icon-only primary actions. `AppButton` requires a label; `AppIconButton` (when built) will require a tooltip/semantic label.
- **Color never the only signal** — `AppStatusPill` requires a text label alongside its color.
- **Chart data-table fallback** — unchanged, owned by the Growth screen (`fl_chart` usage), not a token concern.
- **Touch targets** — `AppButton` and quick-log controls enforce a 48×48dp minimum.
- **130% text scale** — no fixed-height text containers; verify on any new component.
- **Glass legibility** — text/icons are never placed directly on a glass surface without going through `AppTypography`'s `textPrimary`/`textSecondary` colors, which are chosen to clear 4.5:1 against the *blurred* background gradient in all three modes, not just the flat fill.

## 11. Adoption Tracker

| Screen | Status |
|---|---|
| Home | Showcased (v2 glass — inherited automatically via tokens, no changes needed) |
| App shell (nav) | Showcased (v2 glass) |
| Growth | In progress |
| Memories | In progress |
| Health | In progress |
| Care Log | In progress |
| Settings | In progress |
| Onboarding | In progress |
| Babies (add/edit forms) | In progress |
