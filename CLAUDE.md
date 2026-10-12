# Tbilisi Car-Rental (Flutter + Firebase)

Portfolio project: car rental app for a fictional Tbilisi company.
Full plan, business rules and open reminders: docs/PLAN.md (read it before any feature work).

## Scope
- Portfolio only, never a real company. One Firebase project: tbilisi-car-rental.
- NEVER touch the older projects. Every firebase/flutterfire command
  must name --project=tbilisi-car-rental explicitly.
- Only exception: the Firebase emulator runs with --project demo-tbilisi-car-rental,
  never against the real project.
- Single currency USD. No payments. No end-user accounts. One shared admin account.

## Stack
Flutter, Riverpod (manual Notifier/AsyncNotifier, no codegen), go_router, Firebase
(Firestore, Auth, Storage, Analytics, App Check; Cloud Functions in the last phase only),
intl + flutter_localizations (ka, ru, en). No Drift.

## Architecture
- Feature-first: lib/features/<feature>/{data,domain,presentation}; shared code in lib/core
  (shared models in lib/core/models, router, theme, Tbilisi time helper, constants).
- Riverpod: manual Notifier/AsyncNotifier. Models hand-written (fromMap/toMap), no freezed.
- Firestore is accessed ONLY in repositories (one thin repository per collection).
  Flow: UI -> provider -> repository -> Firestore. Widgets and providers never import
  cloud_firestore.
- Pricing, overlap and Tbilisi-time logic are pure Dart in domain/ (no Firebase or Flutter
  imports) so they are unit-testable.
- Every screen handles loading, error and empty states.
- Interface text lives in ARB files (ka/ru/en); car descriptions live in Firestore as
  {ka, ru, en}. Admin UI is English only.

## Key business rules (details in docs/PLAN.md)
- One `bookings` collection; statuses: new | pending | confirmed | cancelled.
- Days = max(1, ceil((dropoff - pickup - 2h) / 24h)). Total = days * (car price + extras).
- All times stored in UTC, shown in Asia/Tbilisi (GMT+4), label "Tbilisi time (GMT+4)".
- Conflict warning (never blocking) against confirmed bookings only; 5-hour buffer as a
  single named constant.

## Working rules
- Before making changes, show a plan and wait for confirmation.
- One task at a time, small changes, pause for approval at the end of each step.
- Do not add packages or Firebase services without permission.
- Do not decide business rules; ask.
- Write unit tests for new logic. After changes run `flutter analyze` and `flutter test`.
- Explain changes briefly and state the reason.
- Code, comments, commit messages and identifiers are in English.

## Safety
- Never commit secrets (service-account keys, .env, key.properties).
  firebase_options.dart is allowed.
- Never run `firebase deploy`, change Firestore rules, create the admin claim, or enable
  Blaze/Storage/Auth without explicit approval.
- Security is enforced in Firestore rules, never only by hiding UI.
- Clients must never read or write the `mail` collection.

## Design
- Purple (#673AB7) page background and app bar with white text; white cards, white text
  fields and white filled buttons with purple text. Theme in lib/core/theme. White areas
  must always be built with AppCard or OnWhite (lib/core/widgets/app_card.dart), otherwise
  text is white on white. One fixed theme: no dark mode, no gradient for now.

## Commands
- Run (Android emulator): `flutter run`
- Run web (admin panel): `flutter run -d chrome`
- Analyze: `flutter analyze`
- Test: `flutter test`
- Secrets scan, before every commit: `node tool/check_secrets.mjs`
  (everything git would commit) and `node tool/check_secrets.mjs --staged`
  (only what is staged). It must end with "Errors: 0".
- Tests of the secrets scan: `node --test tool/check_secrets.test.mjs`
- Optional and local only: `tool/private_denylist.txt` (git ignores it) lists
  texts the scan must never find, one per line. Never print, paste or commit it.

## Platforms
The public app is mobile-first: Android is the primary target and the main test platform
(Android emulator). Web is used for the admin panel on large screens and to host the
public demo. iOS config exists but cannot be tested on Windows. Desktop folders (linux,
macos, windows) are not used.
