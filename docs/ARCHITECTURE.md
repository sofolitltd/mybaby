# MyBaby — Technical Architecture

_Companion to [PRD.md](./PRD.md) (product scope), [UX.md](./UX.md) (screens and interaction design), and [PRIVACY_SECURITY.md](./PRIVACY_SECURITY.md) (compliance and data handling)._

## Data architecture

**Firestore** is the source of truth for structured, queryable data (profiles, growth points, log entries, vaccination status) — real-time sync across the parent's own devices, with built-in offline caching on mobile. **Google Drive** holds every actual file/blob (photos, videos, scanned documents, PDFs) inside a per-user app folder in the parent's own Drive; Firestore documents store only the Drive `fileId` plus light metadata (mime type, thumbnail link). This avoids Firebase Storage costs entirely and keeps media physically inside the parent's own Google account — inspectable, exportable, and deletable by them independent of the app.

```
                    UI — ConsumerWidgets
                             │
                             ▼
              Riverpod — streams and notifiers
                             │
                             ▼
        Repositories — Auth / Firestore / Drive
                    │                 │
                    ▼                 ▼
          Cloud Firestore        Google Drive
   (profiles, growth, logs,   (photos, videos,
        metadata)                 documents)
```

**Recommendation:** request Drive scope `drive.file` against a single visible app-created folder (e.g. "MyBaby App"), rather than the hidden `appDataFolder`. Visible-but-app-managed gives the parent Drive-quota visibility and lets them browse/export files themselves, while still keeping other Drive content untouched. *(Open decision — see PRD.md §Open decision points.)*

### Firestore schema (flat top-level collections, per-user, single-account model)

Every document lives in its own top-level collection (no nested subcollections). Each carries a denormalized `uid` (so security rules can check ownership without an extra read) and, except `babies` and `users` themselves, a `babyId` foreign key pointing at its owning baby.

```
users/{uid}
  { driveFolderId }

babies/{babyId}
  { uid, name, dob, sex, photoDriveFileId, bloodGroup, birthStats, createdAt }

growthEntries/{entryId}      { uid, babyId, date, weightKg, heightCm, headCircumferenceCm, note }
milestones/{milestoneId}     { uid, babyId, type, customLabel, achievedDate, note, mediaDriveFileIds[] }
memories/{memoryId}          { uid, babyId, date, caption, mediaDriveFileIds[], tags[] }
vaccinations/{vaccineId}     { uid, babyId, name, doseNumber, scheduledDate, administeredDate, status }
documents/{docId}            { uid, babyId, title, category, driveFileId, mimeType, date, tags[] }
doctorVisits/{visitId}       { uid, babyId, date, doctorName, reason, notes, prescriptionDriveFileIds[] }
careLogs/{logId}             { uid, babyId, type: feed|sleep|diaper, startTime, endTime, subtype, amount, note }
```

Security rule shape: one rule block per collection, checking the `uid` field on the document rather than a path segment — e.g. `match /growthEntries/{entryId} { allow read, update, delete: if request.auth.uid == resource.data.uid; allow create: if request.auth.uid == request.resource.data.uid; }`. `users/{uid}` is the one exception, keyed directly by `uid` as the doc id rather than a `uid` field: `match /users/{uid} { allow read, write: if request.auth.uid == uid; }`. See `firestore.rules`.

Every query against a child collection (`growthEntries`, `milestones`, etc.) must filter on both `uid` and `babyId` — repositories should never issue a bare collection query. This needs composite indexes (`uid` + `babyId` + the sort field, e.g. `date`) declared in `firestore.indexes.json`.

**Tradeoffs vs. the nested-subcollection shape this replaces:**
- ✅ Cross-baby queries (e.g. "all vaccinations due this week across every baby") and per-entity pagination/indexing are straightforward — not possible with `collectionGroup` gymnastics under nesting.
- ✅ Flat collections read closer to separate relational tables, which is easier to reason about and to eventually mirror in a Postgres-based backend if that migration ever happens.
- ⚠️ Deleting a baby no longer cascades for free (a subcollection under a deleted parent doc doesn't auto-delete in Firestore either, but the flat shape makes this explicit): baby deletion must be an explicit batched delete across every child collection filtered by `babyId` — implement this once in `BabyRepository.deleteBaby()`, never as an ad hoc query from a screen.
- ⚠️ Security rules are now one block per collection instead of one blanket rule — keep them mechanical (copy-paste the same `uid` check) so a new entity type is a 4-line addition, not a redesign.

### Offline strategy

- **Firestore**: offline persistence enabled (built into the mobile SDKs, IndexedDB-backed on web) — structured reads/writes queue automatically and sync on reconnect.
- **Drive uploads**: not covered by Firestore's offline cache. A file picked offline saves to local device storage immediately; the Firestore doc is written with `pendingUpload: true`; a background upload queue (retry with backoff) pushes to Drive once connectivity returns and clears the flag.
- **Web caveat**: Flutter Web offline support is best-effort. Firestore's web SDK supports offline persistence, but Drive uploads and background sync are less reliable in a browser tab that isn't foregrounded — not full parity with mobile.

## Technical stack

- Flutter (existing scaffold) + Riverpod (`hooks_riverpod` + `riverpod_generator`) for state management.
- `firebase_auth` + `google_sign_in` for auth; `cloud_firestore` for the database; `googleapis` (`drive/v3`) for Drive file operations using the OAuth token from Google Sign-In.
- `go_router` for navigation between baby-scoped tabs.
- `freezed` + `json_serializable` for immutable data models mapped to Firestore documents.
- `fl_chart` (or Syncfusion charts, if richer percentile-curve rendering is needed) for growth charts.
- `hive` (or `isar`) for the local pending-upload queue and cached media thumbnails.
- `flutter_local_notifications` for vaccination/growth reminders.

## Layering

- **Data layer**: `AuthRepository` (Firebase Auth + Google Sign-In), one `FirestoreRepository<T>` per entity (growth, milestones, care logs, etc.), `DriveRepository` (upload/download/delete against the app's Drive folder).
- **Domain/state layer**: Riverpod `StreamProvider`s wrapping Firestore collection streams for live UI updates; `AsyncNotifier`s for actions that mutate state (quick-log a feed, mark a milestone).
- **UI layer**: `ConsumerWidget`s per screen, consuming the above providers only — no widget calls Firestore or Drive directly.

Drive OAuth scope requested at sign-in: `drive.file` (app-created files only) — never full Drive access, to keep the permission ask minimal and trustworthy.

## Non-functional requirements

- **Privacy/security:** Firestore rules enforce per-user isolation; Drive access is scoped to app-created files only; no baby data lives anywhere the parent doesn't control.
- **Performance:** chart rendering and log lists must stay smooth with a full year-plus of daily care-log entries — paginated/virtualized Firestore queries (`limit()` + pagination), never full-collection loads.
- **Accessibility:** large tap targets for quick-log buttons, dark/night mode, adequate contrast for 3am one-handed use.
- **Cost:** Firestore-only for structured data (no Firebase Storage) keeps this comfortably inside Firebase's free tier for realistic single- or multi-family usage.

## Verification plan

- Manual QA checklist per feature area: profile CRUD, growth entry + chart render, milestone/memory add, vaccination status transitions, care-log quick actions, document upload/download.
- Firestore Emulator Suite to test security rules (per-user isolation) before touching production data.
- Offline test pass: airplane-mode a device, perform one action from each feature area, restore connectivity, confirm all queued Firestore writes and pending Drive uploads sync correctly.
- Cross-device sync test: sign into the same account on two devices, confirm real-time Firestore updates propagate.
