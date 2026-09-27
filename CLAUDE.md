# CLAUDE.md

Guidance for working in this repo. See `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/UX.md`, and `docs/PRIVACY_SECURITY.md` for product/technical/design/compliance context — read the relevant one before starting a feature, don't re-derive it from scratch.

## Project

Flutter app (mobile + web), Riverpod for state, Firebase Auth + Firestore for data, Google Drive for file/photo storage. No shared-account/co-parent support in v1 — Firestore uses flat top-level collections (`babies`, `growthEntries`, `milestones`, etc.), each document carrying a `uid` field for ownership and a `babyId` FK; see `docs/ARCHITECTURE.md#firestore-schema`.

## Folder structure (target — create as needed, don't scaffold ahead of actual features)

```
lib/
  main.dart
  app.dart                 # MaterialApp/router root
  core/
    theme/                 # colors, typography, light/dark + night mode
    routing/                # go_router config
  features/
    auth/
    babies/                 # profile CRUD, active-baby switcher
    growth/
    memories/                # milestones + memory feed
    health/                  # vaccinations, doctor visits, documents
    care_log/
    settings/
  data/
    firestore/               # FirestoreRepository<T> implementations
    drive/                    # DriveRepository, upload queue
    models/                   # freezed data classes, one file per entity
  shared/
    widgets/                 # cross-feature reusable widgets
```

Each `features/<x>/` folder holds its own `screens/`, `widgets/`, and `providers/` — don't create a global `providers/` or `widgets/` dumping ground for feature-specific code.

## Conventions

- **State management**: Riverpod only. `StreamProvider` for live Firestore collection reads, `AsyncNotifier`/`Notifier` for actions that mutate state (quick-log, mark milestone). No `setState` outside of pure local UI state (e.g. a text field's focus).
- **No direct backend calls from widgets.** Widgets consume providers; providers call repositories; repositories talk to Firestore/Drive. If a widget imports `cloud_firestore` or `googleapis` directly, that's a layering violation — see `docs/ARCHITECTURE.md#layering`.
- **Models**: `freezed` + `json_serializable`, one model per Firestore entity, matching the schema in `docs/ARCHITECTURE.md#firestore-schema`. Update that doc's schema block in the same PR as a model shape change — they must never drift apart.
- **Every Firestore document write scoped to the active `uid`.** Every document, including `babies` itself, must set `uid` from `AuthRepository`'s current user, and every child-entity document (`growthEntries`, `milestones`, etc.) must also set `babyId`. Never issue a bare collection query — always filter by `uid` (and `babyId` where applicable).
- **Offline-safe writes**: any write path that touches Drive (photo/document upload) must go through the pending-upload queue described in `docs/ARCHITECTURE.md#offline-strategy` — never a bare synchronous upload call from a form's submit handler.
- **Naming**: `snake_case.dart` filenames, `PascalCase` classes, providers named `<thing>Provider` (e.g. `activeBabyProvider`, `growthEntriesProvider`).

## Testing

- Widget tests per feature screen for the primary interaction (quick-log a feed, add a growth entry, mark a milestone).
- Firestore security rules tested against the Firestore Emulator Suite, not against production — see `docs/PRIVACY_SECURITY.md#security-posture` for what the rules must guarantee (per-user isolation).
- Before any release: run the manual offline test pass and cross-device sync test listed in `docs/ARCHITECTURE.md#verification-plan`.

## Commands

```
flutter pub get
flutter analyze
flutter test
flutter run
```

## Before adding a new dependency

If it's a new analytics, crash-reporting, or any SDK that touches user/baby data, update the data inventory table in `docs/PRIVACY_SECURITY.md` first — this project treats new data-touching dependencies as a privacy-review event, not just an engineering change.
