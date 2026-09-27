# MyBaby — UX Design Guide

_Companion to [PRD.md](./PRD.md) and [ARCHITECTURE.md](./ARCHITECTURE.md)._

## Design principles

1. **One-handed, at 3am.** The most frequent actions (log a feed, log a diaper, log sleep) must be reachable in one tap from Home, with large touch targets and no confirmation dialogs for routine logging.
2. **Trend over data entry.** Growth and care screens lead with the chart/summary, not a raw list — a parent should see "is this normal?" before they see numbers.
3. **Calm, not clinical.** Health/vaccination screens use plain-language status ("Due in 2 weeks", not "Status: PENDING") and warm, non-alarming color for overdue items (amber, not red-siren).
4. **Own your data, visibly.** Settings surfaces Drive storage usage and last-backup time as a first-class item, not buried — this is a stated trust feature, not a technical footnote.
5. **Never block on connectivity.** Every write-path (quick-log, add memory, mark milestone) succeeds locally and shows a subtle "syncing" indicator rather than a spinner or error when offline.

## Navigation model

- **Bottom navigation bar** (mobile) / **left rail** (web/tablet width): Home · Growth · Memories · Health · Care Log. Settings lives behind the profile avatar, not in the main bar — it's not a daily-use screen.
- **Baby switcher**: a persistent avatar chip in the app bar, always visible, opens a bottom sheet listing all babies + "Add baby". Switching baby re-scopes every tab instantly (no navigation reset, no reload flash — swap the active `babyId` provider and let cached Firestore streams repaint).
- **Deep, not wide**: each tab is shallow (list → detail → edit), never more than two levels deep, so the back button always makes sense.

## Screen-by-screen

### Onboarding
1. Google Sign-In button (single primary action, no email/password alternative in v1 — reduces surface area).
2. Drive permission consent screen: **explain before asking** — one short line ("MyBaby stores your photos and documents in your own Google Drive, not on our servers") before the OAuth prompt, so the permission dialog isn't a surprise.
3. First baby profile form: name + DOB required, everything else (photo, blood group, birth stats) optional and skippable — never block onboarding on optional fields.

### Home (dashboard)
- Top: active baby's name + age ("14 weeks old").
- Growth snapshot card: last weight/height entry + a mini trend sparkline, tap-through to Growth tab.
- Next vaccination due card (only shown if something is due within 30 days — otherwise hidden, not "None due").
- Recent memory card: latest photo/note, tap-through to Memories.
- **Quick-log bar**: three large buttons (Feed / Sleep / Diaper) fixed above the bottom nav — feeding and sleep open a running timer with a single tap to stop; diaper logs instantly with a type picker (wet/dirty/both) as a bottom sheet, no separate confirm step.

### Growth
- Chart first: WHO percentile curve with the baby's plotted points, one measurement type selectable via segmented control (Weight / Height / Head circumference).
- Entry list below the chart, newest first, each row editable/deletable via swipe.
- "+ Add entry" floating action button opens a short form (date defaults to today, one numeric field, optional note).

### Memories
- Milestone checklist as a horizontally-scrolling row of chips at the top (achieved ones filled/checked, tap any to mark with a date picker defaulting to today).
- Memory timeline below: a vertical feed, newest first, photo/video thumbnails full-width, caption + date beneath.
- "+ Add memory" opens the device photo/video picker directly (no intermediate screen) then a single caption field.

### Health
- Three sections in one scrollable screen (not sub-tabs, since each is short): **Vaccinations** (list with status pill: Done / Due soon / Overdue), **Doctor visits** (chronological list, tap to see notes + linked files), **Documents** (grid of file thumbnails/icons by category).
- Vaccination status pills use plain language and warm color, not alarm red, for overdue items — the goal is a nudge, not anxiety.
- Uploading a document: pick file → auto-suggest category from filename/type → confirm — minimize manual categorization.

### Care Log
- Today's timeline: a vertical strip of small entries (icon + time + short label: "🍼 2:15pm, 20min"), grouped by day, scrollable back through history.
- Weekly stats card pinned above the timeline: total sleep, feed count, diaper count — three numbers, no chart (a week of care-log totals doesn't need percentile-style trend framing).

### Settings
- Manage baby profiles (edit/delete/reorder).
- Notification preferences (vaccination reminders, growth check-in reminders — toggle each independently).
- **Drive storage & backup status**: last backup timestamp, storage used, a manual "Back up now" button — this is the trust-building screen, give it visual weight.
- Theme (light/dark/system), sign-out.

## Interaction details worth calling out

- **Timers (feed/sleep)**: starting a timer from Home should survive app backgrounding — persist start time locally so the timer is correct even if the OS kills the app.
- **Undo, not confirm**: destructive actions (delete a log entry, delete a memory) use a snackbar "Undo" pattern rather than an "Are you sure?" dialog — faster for the common case, still recoverable.
- **Empty states**: every list (growth entries, memories, vaccinations before a schedule is set) needs a specific empty-state illustration + one-line prompt ("No growth entries yet — add your first measurement"), never a blank screen.
- **Sync indicator**: a small, unobtrusive dot/icon near the app bar (not a banner) shows "syncing" vs "up to date" vs "offline, will sync" — visible on demand, never interrupts.

## Visual design

- **Color**: warm, soft palette (avoid clinical blues/whites); status colors reserved for meaning (amber = due soon, muted red = overdue, green = done) — never decorative.
- **Typography**: one clear hierarchy — large numerals for ages/measurements, generous line height for tired-parent readability.
- **Dark / night mode**: a true low-light mode (near-black background, reduced-brightness accent colors) for logging at night without a bright flash — distinct from a generic "dark theme," tuned for minimum light output.
- **Touch targets**: minimum 48×48dp on all quick-log controls; the three Home quick-log buttons should be reachable by thumb on the largest common phone size without shifting grip.

## Accessibility

- All icons paired with text labels (no icon-only buttons on primary actions).
- Color is never the only signal for vaccination/status — pair with a text label.
- Charts include an accessible data-table fallback or summary for screen readers (e.g. "Weight: 6.2kg, 55th percentile, as of Sep 20").
- Support system font-scaling without breaking quick-log button layout (test at 130% text scale).
