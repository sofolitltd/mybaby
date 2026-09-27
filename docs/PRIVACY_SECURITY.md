# MyBaby — Privacy & Security

_Companion to [ARCHITECTURE.md](./ARCHITECTURE.md). Covers what both app stores require before submission, plus the data-handling rules that follow from storing children's health data._

## Why this matters here specifically

MyBaby stores data about a minor (name, DOB, photos, health/vaccination records) — this puts it in a stricter compliance category than a typical consumer app in both app stores, and (if a public web build is offered) potentially under COPPA in the US. None of this is optional paperwork: both Apple and Google require answers to these questions *before* a listing can go live, and getting them wrong after launch means a forced update or takedown, not a warning.

## Data inventory (what we collect, per PRD.md / ARCHITECTURE.md)

| Data | Where it lives | Sensitivity |
| --- | --- | --- |
| Parent's Google account (email, name, avatar) | Firebase Auth | Standard account info |
| Baby's name, DOB, sex, blood group, birth stats | Firestore | Children's personal data |
| Growth measurements | Firestore | Children's health data |
| Vaccination records, doctor visit notes | Firestore | Children's health data (sensitive) |
| Photos, videos, scanned documents (insurance, birth certificate) | Parent's own Google Drive | Children's personal data + potentially government-ID-adjacent documents |
| Care logs (feed/sleep/diaper timestamps) | Firestore | Children's behavioral data |

Nothing here is shared with, sold to, or used by any third party for advertising — the product's entire premise is that data stays in the parent's own Firebase project and Drive account. State this plainly in every store listing; it is the app's main differentiator.

## App store requirements

### Apple — Privacy Nutrition Label
At submission, App Store Connect requires declaring, per data type, whether it's collected and whether it's linked to identity/used for tracking. For MyBaby:
- **Contact info, health & fitness, user content (photos), identifiers**: collected, linked to the user's identity, **not used for tracking**, **not used for third-party advertising**.
- No data is shared with third parties for their own purposes — Google Drive/Firebase are service providers acting on the app's behalf, not independent data recipients, which is the correct framing for the label.
- Because this app is squarely a "kids' health/parenting" app, expect Apple's review team to scrutinize the account-deletion and data-export flows explicitly — both must work before submission (see Data subject rights, below).

### Google Play — Data Safety form
Declare each data type collected (Personal info: name, DOB; Health & fitness: growth/vaccination records; Photos/videos; App activity: care logs) with purpose **"App functionality"** only — no purpose should be marked "Advertising or marketing." Declare data is encrypted in transit (true — Firebase/Drive both use TLS) and that an account/data deletion path exists (required — see below). If targeting Google Play's **Families program** (recommended given the subject matter, even though the *user* is an adult parent, not the child) additional restrictions apply: no behavioral advertising, no third-party analytics SDKs beyond Google's own approved list, and a stricter permissions review.

### Google Play — Families policy note
The *user* of MyBaby is the parent, not the child, so the app is not automatically subject to the full Designed for Families program — but if the listing's screenshots, description, or category signal "for children," Play may reclassify it. Keep store copy addressed to parents explicitly to avoid an unwanted Families-policy reclassification.

## Data subject rights (must exist before launch)

1. **Account deletion**: a self-service "Delete my account" action in Settings that removes the Firestore data tree (`users/{uid}/**`) and revokes/optionally deletes the app's Drive folder. Both stores require this to be reachable *inside the app*, not only via a support email.
2. **Data export**: since the pitch is "you own your data," a "Download my data" export (reuses the JSON backup already planned for Drive backup in ARCHITECTURE.md) doubles as the GDPR/CCPA-style data-portability answer if ever asked.
3. **Retention**: data persists until the parent deletes it or their account; no server-side analytics retention beyond what Firebase's own infra logs (state this in the privacy policy rather than leaving it implicit).

## Security posture (technical, ties to ARCHITECTURE.md)

- Firestore security rules enforce per-user isolation (`request.auth.uid == uid`) — verify with the Firestore Emulator Suite before every release, not just at initial build.
- Drive OAuth scope stays `drive.file` (app-created files only) for the life of the app — widening this scope later requires re-justifying it to both users (re-consent) and app review.
- No baby data ever leaves Firebase/Drive for a third-party analytics or crash-reporting SDK unless that SDK's data handling is added to the inventory table above and the store listings are updated to match — treat adding *any* new SDK as a privacy-review event, not just an engineering change.
- Local device storage (cached thumbnails, offline queue) should be cleared on sign-out, so a shared/borrowed device doesn't retain a previous parent's baby data.

## Privacy policy (required before either store will accept the listing)

A public, hosted privacy policy URL is mandatory for both stores. It must at minimum state: what's collected (the inventory table above, in plain language), that it's stored in the parent's own Firebase project and Google Drive rather than sold or shared, how to delete an account, and a contact method. This can be a static page generated from this document — it does not need its own separate drafting effort once the inventory above is final.
