# MyBaby — Product Requirements Document (v1)

_As of 2026-09-27_

## Context

`mybaby` is a brand-new Flutter project (bare `flutter create` scaffold, no app code yet). The goal: a mobile-first app where a parent manages everything about one or more babies — profile, growth, milestones/memories, health documents, and daily care logs — in one place, with data that feels privately *owned* by the parent rather than sitting in a vendor-controlled cloud silo. Google Drive is used the way WhatsApp uses it for backups: the parent's own Drive account holds their media, so family data lives under their own Google account.

Decisions locked in before this PRD was written:

- V1 ships all four feature areas together (profiles+growth, milestones/memories, health+documents, daily care logs), plus a few expert-recommended additions.
- Storage split: Firebase Auth for sign-in, Cloud Firestore for structured data, Google Drive for files/photos/documents — not Firebase Storage. See [ARCHITECTURE.md](./ARCHITECTURE.md) for the technical detail.
- Single-account only for v1 — no co-parent sharing yet, but the data model shouldn't block adding it later.
- Platforms: iOS + Android + Web, offline-first as a hard requirement (web offline support is best-effort).

## Goals and personas

The product succeeds if a tired parent can log a care event, check a growth trend, store a health record, or save a memory — for one or more kids — without unlocking a heavy workflow. Four goals drive every design decision below:

1. One place for care logs, growth, health records, and memories.
2. Logging fast enough to do one-handed at 3am (quick-action first).
3. Data that feels family-owned — Drive-backed storage and exportability are trust features, not afterthoughts.
4. Reliable under flaky/no connectivity (nurseries, hospitals, cars), syncing cleanly once back online.

**Primary parent** (either parent, the main user): logs daily care, checks growth trends, uploads documents after doctor visits — wants speed and reassurance ("is this normal?").

**Secondary/occasional user** (grandparent, the other parent on their own device): out of scope for shared accounts in v1 — they'd need their own login and a separate profile today. A known limitation, not a broken flow.

## V1 feature scope

### Baby profiles and growth

Multi-baby support with a fast profile switcher (avatar chips in app bar/drawer). Profile fields: name, DOB, sex, photo, blood group, birth stats. Growth log: weight, height/length, head circumference, with date + optional note, rendered against WHO percentile curves (weight-for-age, length/height-for-age, head-circumference-for-age) so a trend is visible at a glance. Monthly growth check-in reminder.

### Milestones and memories

Preset milestone checklist (rolls over, sits up, crawls, first tooth, first steps, first words, etc.) — tap to mark achieved with a date. Free-form memory entries (photo/video/text + date + tags) shown as a scrollable timeline.

*Expert addition:* one-tap "Memory Book" export — compiles milestones + memories into a shareable PDF/photo-album. Ships in v1 if time allows, else v1.1.

### Health and documents

Vaccination schedule (preloaded standard template, configurable by country/region at setup) tracking scheduled vs. administered dates, dose number, status. Doctor visit log (date, doctor, reason, notes, linked files). Document vault (scanned reports, insurance cards, birth certificate) stored in the parent's Google Drive, referenced by metadata in Firestore.

*Expert additions:* reminder notifications for upcoming vaccinations and overdue growth check-ins; a one-tap "Doctor Visit Summary" PDF combining recent growth, vaccination status, and notes — handy to bring to a pediatrician.

### Daily care logs

Quick-action buttons for feeding (breast/bottle/solid, duration or amount), sleep (start/end), diaper (wet/dirty/both). Today's log as a simple timeline; weekly rollup stats (total sleep, feeds/day).

### Cross-cutting additions

- Notification reminders for vaccinations and growth check-ins.
- Drive-backed backup/restore: a periodic JSON snapshot of Firestore data written to the app's Drive folder — the "WhatsApp-style" safety net, separate from live sync.
- Dark mode, large touch targets, and a low-light night mode for logging without waking anyone.

### Deferred to v2

Co-parent sharing/invites, desktop targets, multi-language localization, home-screen widgets, advanced sleep/feeding analytics.

## Information architecture

See [UX.md](./UX.md) for the full screen-by-screen flows and interaction details. Every screen below is implicitly scoped to whichever baby is active in the persistent switcher (app bar/drawer).

| Screen | Purpose |
| --- | --- |
| Onboarding | Google Sign-In → Drive permission consent → create first baby profile |
| Home | Dashboard: growth snapshot, next vaccination due, recent memory, quick-log buttons |
| Growth | Percentile charts + entry list + add-entry sheet |
| Memories | Milestone checklist + memory timeline + add-memory sheet |
| Health | Vaccination schedule + doctor visits + document vault |
| Care Log | Today's timeline + quick-action bar + weekly stats |
| Settings | Manage baby profiles, notifications, Drive storage/backup status, theme, sign-out |

## Phased roadmap

```
 v1 — MVP                core loop stable    v1.1                  sharing scoped   v2
 ─────────────────  ───────────────────►  ──────────────────  ──────────────────►  ──────────────────────
 Profiles + growth                        Memory Book export                      Co-parent sharing
 Milestones/memories                      Doctor visit summary                    Desktop, localization
 Health + documents                       Backup/restore polish                   Sleep/feed analytics
 Care logs + reminders
```

- **v1 (MVP)**: profiles + growth + charts, milestones/memories, vaccination schedule + doc vault, daily care logs, reminder notifications, Drive-backed file storage + JSON backup, offline-first on mobile, web with noted offline caveats.
- **v1.1**: Memory Book export, Doctor Visit Summary export, backup/restore polish.
- **v2**: co-parent sharing/invites (requires loosening Firestore rules + an invite flow), desktop targets, localization, home-screen widgets, sleep/feeding analytics.

## Open decision points

1. Drive folder visibility: visible app folder (`drive.file`, recommended) vs. hidden `appDataFolder` (closer to literal WhatsApp behavior, but the parent can't browse it in the Drive UI). See [ARCHITECTURE.md](./ARCHITECTURE.md#data-architecture).
2. Default vaccination schedule template/region at profile creation — affects localization of the preset schedule.
3. Whether the Memory Book and Doctor Visit Summary exports ship in v1 or slip to v1.1, depending on timeline pressure.

## Verification plan

- Manual QA checklist per feature area: profile CRUD, growth entry + chart render, milestone/memory add, vaccination status transitions, care-log quick actions, document upload/download.
- Firestore Emulator Suite to test security rules (per-user isolation) before touching production data.
- Offline test pass: airplane-mode a device, perform one action from each feature area, restore connectivity, confirm all queued Firestore writes and pending Drive uploads sync correctly.
- Cross-device sync test: sign into the same account on two devices, confirm real-time Firestore updates propagate.
