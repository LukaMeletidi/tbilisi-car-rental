# Tbilisi Car-Rental — Project Plan

A portfolio project built with Claude Code under the developer's direction and approval.

This file is the full plan with all decisions agreed so far. Short rules for daily work
are in CLAUDE.md.

## 0. How we work

- Before any change, show a plan (and the full text of new or changed files) and wait
  for approval. Nothing is decided until we agree on it together.
- Work in small, reviewable steps. At the end of each step, summarize what changed and
  wait for my approval before continuing.
- Do not decide business rules on your own. If something is ambiguous, ask.
- Do not add packages, features or Cloud Functions that are not in this plan without
  asking.
- Explain reasoning in plain language, including costs and downsides of each choice,
  not only benefits.
- Git: show `git status` and the list of files before every commit; ask before every
  commit and every push; never use --force.

## 1. Overview

- A car rental app for a fictional Tbilisi company, serving mostly international
  tourists.
- This is a PORTFOLIO project. It will never be used by a real company.
- No end-user authentication: the public catalog and booking form are open to anyone.
- A single shared administrator account (not per-staff accounts) manages the fleet and
  bookings. Multiple admins can be logged in simultaneously from different devices, with
  real-time sync (Firestore listeners).
- Backend: Firebase (Firestore, Authentication, Storage, Cloud Functions in the last
  phase only).
- Frontend: Flutter, one codebase. Platforms are described in Section 1.1.
- There is ONE Firebase project (no dev/prod split). Firebase Emulator Suite is optional.
- Demo data: a handful of hand-entered demo cars so the demo looks good. The public
  catalog must show a friendly empty state ("No cars available yet") when there are no
  cars.
- The app will be published as a public demo. Whether that is a hosted web build
  (Firebase Hosting), an APK, or both is decided in Phase 7.
- Admin in the demo: same build, with an unlinked /admin route protected by rules. The
  admin login route does not appear in public navigation. Admin screens will be shown to
  recruiters via README screenshots/video later.
- The public booking form shows a visible note: "This is a portfolio demo — no real
  booking is made." Users must not be encouraged to enter real personal data.
- Stack (same as my first app): Flutter, Riverpod (Notifier/AsyncNotifier), go_router.
  Drift is NOT needed here because Firebase is the backend.

### 1.1 Platforms

- The public app is mobile-first. Android is the primary platform and the main test
  platform (Android emulator, not Chrome).
- Web is only for the admin panel on large screens and for hosting the public demo.
- Admin screens are responsive (desktop and phone).
- iOS config exists but cannot be built or tested on Windows.
- Desktop folders (linux, macos, windows) were removed and are not used.
- Step 0.8 and all later verification run on the Android emulator.

### 1.2 Project facts

- Firebase project ID: tbilisi-car-rental. Spark plan. Firestore (default) database,
  created in production mode, region eur3. Google Analytics was enabled when the project
  was created; no Analytics SDK is added yet.
- Every firebase/flutterfire command must name tbilisi-car-rental explicitly. The older
  projects on the same account are never touched.
- App ID: com.greek.tbilisicarrental (Android applicationId and namespace, iOS bundle
  ID; the iOS test target keeps the .RunnerTests suffix).
- Dart package name: tbilisi_car_rental.
- GitHub: https://github.com/LukaMeletidi/tbilisi-car-rental.git (private), branch main.

## 2. Public (Customer-Facing) App

### 2.1 Catalog

List of active cars, each with photo(s) and:
- Brand / model, year
- Drivetrain: FWD / RWD / AWD
- Transmission: automatic / manual
- Fuel type: petrol / diesel / hybrid / electric
- Seats: the exact number is stored per car
- Engine size: optional; hidden for electric cars (no kW)
- Price per day (USD)
- Description in the current UI language

Phase 1 decisions:
- Each car is a large card: one photo, "Brand Model, year", spec chips, price, and 2-3
  lines of description. A separate detail screen with all photos, the full description
  and the "Make a booking" button comes in Phase 2.
- Cars are sorted by price ascending, in the app.
- Price: whole dollars are displayed, in the format "$45 / day" (translated). Decimals
  are allowed in the model.
- Engine size is shown as "1.8 L". It is shown for hybrid and hidden only for electric.
- If the description is missing in the current language, show English; if that is
  missing too, show nothing.
- The catalog updates in real time (Firestore stream).
- Wide screens: a simple multi-column grid of the same cards.
- "No cars available yet" is shown only when there are no active cars at all.

Car detail screen (step 2.4):
- Address: /cars/<id>, below the catalog. A catalog card opens it; going back returns
  to the catalog with the search text and filters kept. A direct link works on web.
- It shows all photos (swipe, with dots), the title, the price per day, the spec chips,
  and the full description in the current language (English if missing; no section if
  there is none).
- A car that does not exist or is not active shows "This car is not available" with a
  way back to the catalog, never a raw error.
- One centred column, at most 720 px wide, on every screen size.
- The "Make a booking" button is fixed at the bottom. Until the booking form exists
  (step 2.7) it is disabled, with the line "Online booking is coming soon".

A car's booked/available status is never shown to the public. Availability for the
requested dates is resolved internally by staff after a request comes in.

### 2.2 Filters

- Seats: Any / 2 / 4 / 5 / 7+ ("7+" means 7 or more seats)
- Fuel type: Any / Petrol / Diesel / Hybrid / Electric
- Transmission: Any / Automatic / Manual

Phase 1 decisions:
- Cars with 3 or 6 seats appear only under "Any".
- A "Filters" button above the list opens a bottom sheet. The button shows the number
  of active filters. The sheet has a Reset action.
- When no car matches the filters: a separate text "No cars match your filters" with a
  "Reset filters" button.
- Filtering runs in the app on the already-loaded list of active cars.

Search (step 1.10):
- A search field sits in the same row as the Filters button.
- It searches the brand and the model: every word typed must be contained in
  "brand model", ignoring letter case. An empty search shows all cars.
- The input is not restricted. Georgian or Russian text simply finds nothing.
- Search and filters combine (both must match). The "Filters (n)" counter does not
  count the search.
- It runs in the app on the loaded cars: no new Firestore query.
- When nothing matches, the reset button clears both the search and the filters. If
  only a search is active, the text is "No cars match your search" and the button is
  "Clear search".

### 2.3 Booking request form

Triggered by a "Make a booking" button on a car. Fields:
- Full name and surname (as in passport) — required
- Phone number (international format) — required
- Checkboxes next to phone: WhatsApp / Telegram (multi-select) — optional
- Email — required
- Pickup date & time — required
- Dropoff date & time — required
- Pickup location — required; dropdown: Tbilisi Airport / Kutaisi Airport / Batumi
  Airport / Tbilisi Office / Other (free text, anywhere in Georgia)
- Dropoff location — required; same dropdown, chosen independently
- Extras (checkboxes, each with its own per-day price): Snow chains, Child seat,
  Infant seat (under 1 year), Booster seat. Each extra can be selected at most once;
  extra quantities go in the notes.
- Special requests / notes — optional; free text, max 500 characters
- Total price, calculated automatically (see Section 6)

Rules:
- Every date/time field shows a visible label: "Tbilisi time (GMT+4)".
- Pickup must be in the future. Dropoff must be after pickup. There is no minimum lead
  time. The maximum rental length is the form limit of 365 days
  (bookingMaxRentalDays).
- "Other" location has the same price as the fixed locations; there is no delivery fee.

Validation decisions (step 2.5); the same limits go into the Firestore rules in
step 2.6:
- Text is trimmed; only spaces counts as empty.
- Full name: 2 to 100 characters.
- Phone: international format, "+" and 8 to 15 digits; spaces, hyphens, dots and
  brackets are removed before storing.
- Email: at most 254 characters, one "@", a domain with a dot.
- "Other" location: 1 to 200 characters. Notes: at most 500.
- Pickup must be later than the current moment; dropoff strictly after pickup. Times
  are entered as Tbilisi time and compared in UTC.
- The dropoff may be at most 365 days after the pickup (exactly 365 days is allowed).
  This is a limit of the form, not a pricing rule.
- A fixed location must be one of the ids in settings; "other" is a reserved id.
- The car must be active.
- The checks do not prove that a phone number or an email address exists.

Form decisions (step 2.7; built in two parts: 2.7a logic, state and texts, 2.7b
screens and routes):
- Address: /cars/<id>/book, below the car screen; Back returns to the car. After
  sending: /booking-sent, below the catalog, so Back leads to the catalog. Until step
  2.8 that screen shows only the thank-you sentence and "Back to the cars".
- App bar: the logo next to the back arrow, as on the car screen. The first card of
  the form shows the car (title and price per day, no photo).
- Time picker: Flutter's own, any minute, 24-hour form in all three languages.
- Limits of the pickers only (not rules of the form): the pickup can be chosen up to
  2 years ahead; the dropoff up to 365 days after the pickup.
- The pickers open on today and the next full hour (Tbilisi); the dropoff one day
  after the pickup. No field is pre-filled.
- "Today" and "now" come from the UTC moment plus 4 hours, never from the time zone of
  the device. The code reads the moment from one clock provider.
- Errors: a field shows its error after the user has left or changed it; after the
  first press of Send every field does; from then on they update live. A failed Send
  scrolls to the first field with an error.
- The Send button is at the end of the form, not fixed at the bottom.
- The draft is kept in memory per car until it is sent or the app is closed, so Back
  does not lose it. While a request is being sent the form is locked; a second press
  sends nothing.
- A failed sending shows a message above the button and keeps the draft; Send tries
  again (with a new document ID).
- The sent booking is kept in memory only (it contains personal data) for the
  thank-you screen and is cleared when the user leaves that screen (step 2.8).
- An extra with the price 0 shows "Free". The names and age ranges of the extras are
  in the ARB files only. The age ranges are final (infant seat 0-12 months, child seat
  1-4 years, booster seat 3-16 years; the overlap 3-4 years is accepted), and the
  extras prices in settings are final too.
- Notes: the counter ("430 / 500") appears from 400 characters; typing is not cut off.
  The other text fields have no counter.
- Every number in a text (length limits, 365 days, 7 days) comes from the constants in
  the code, never typed into a translation.
- No consent line in the form for now (see Open reminders).
- The booking feature may import from the catalog feature (the car provider, the
  price and title helpers, the message widget), never the other way round.

### 2.4 Confirmation screen

After submitting, the customer sees:
- "Thank you for your trust — our representative will contact you shortly to confirm
  the details."
- Below it, a full summary: car, dates, pickup/dropoff locations, selected extras,
  total price.

### 2.5 About Us page

Company information, contact details, working hours, address/map, social links. All of
this comes from the `settings` collection (Section 5). Company info starts EMPTY, so
this page needs a friendly empty state. The map is an external Google Maps link, not an
embedded map.

### 2.6 Localization

- Public UI in three languages: Georgian (ka), Russian (ru), English (en), via
  flutter_localizations + ARB files.
- Admin panel UI is English only.
- Do not conflate:
  - Interface text (button labels, static strings, translated category names such as
    transmission/fuel type) -> ARB files.
  - Data-level content (a specific car's description) -> stored per car document as
    { ka, ru, en }, authored by admin staff.
- Every booking stores the customer's UI language (`language` field) so staff know
  which language to respond in.
- Starting language: the first SUPPORTED language (ka, ru or en) from the browser/device
  language list; if none is supported, English. Examples: ['de','ru'] -> ru; nothing
  supported -> en; empty list -> en; matching is case-insensitive.
- The manual language choice is not remembered yet (shared_preferences comes later).
- Language names are not in ARB files. Each is always shown in its own language:
  English / ქართული / Русский.
- The brand name "Tbilisi Car Rental" stays untranslated in all three languages.
- The language switcher is a menu in the app bar.
- Georgian font: NOT bundled initially. Add Noto Sans Georgian only if needed (see Open
  reminders).

## 3. Admin Panel (English only, protected)

Admin on phones: the bookings list and status changes must work well. The calendar only
needs horizontal scrolling, no special mobile design.

### 3.1 Bookings list

- Lists all documents in the `bookings` collection (Section 4).
- Sort/filter by status and by pickup date.
- Admin can edit ALL fields of a document (this covers changing booking details later).
- Admin can change the status: new (displayed as a neutral "New" badge) / pending /
  confirmed / cancelled.
- Admin can also create a booking manually (e.g. a phone request) directly with status
  `confirmed`. For such bookings, `createdBy` (free-text staff name) is filled in.
- There is no "Convert to booking" copy operation: a customer request and a confirmed
  booking are the same document at different stages.
- The totalPrice sent by the public form is an ESTIMATE. The admin screen shows the
  recomputed value next to the stored one.

### 3.2 Fleet activity calendar

- Grid: cars on one axis, dates on the other. Built by hand, no calendar package.
- Shows ONLY `confirmed` bookings, so staff see which cars are free when.
- Real-time updates across all logged-in devices.

### 3.3 Fleet management

- Add / edit / hide cars. "Remove" = `active: false` (soft delete), never hard delete.
- Photo upload.
- Description fields for ka/ru/en.
- Fixed-category specs (transmission, fuel type, drivetrain) via dropdowns/selectors,
  not free text. Seats is the exact number.
- Price per day (USD), set individually per car.
- Every field must have clear helper text or a placeholder example, because the person
  filling it in is non-technical staff.

### 3.4 Booking conflict warning

When a booking is saved with status `confirmed` (directly, or when an existing booking
is changed to `confirmed`, or when its car/dates change while confirmed), check for
conflicts with other `confirmed` bookings on the same car (Section 7). If found, show a
NON-blocking warning ("This car is already booked from X to Y. Continue anyway?"). The
save is never silently blocked.

### 3.5 Extras & Prices screen

Separate admin screen where admin edits the global per-day prices of the four extras.

### 3.6 Company Info screen

Separate admin screen to fill in company info (name, phone, email, address, working
hours, social links, map location). Starts empty.

### 3.7 New booking email notifications

LAST PHASE ONLY — see Section 12.

## 4. Data Model (Firestore)

High-level; final field names to be agreed in implementation.

cars (field names are final, agreed in Phase 1; document ID is auto-generated and not
stored inside the document)
- brand, model: string
- year: number
- drivetrain: string, one of "fwd" | "rwd" | "awd"
- transmission: string, one of "automatic" | "manual"
- fuelType: string, one of "petrol" | "diesel" | "hybrid" | "electric"
- seats: number (exact number)
- engineSize: number, in litres; optional (left out for electric cars)
- pricePerDay: number (USD)
- description: map { ka, ru, en } of strings
- photos: array of strings (URLs)
- active: boolean (soft delete)

Until the Storage decision (before Phase 4), demo photos are image URLs of freely
licensed photos, picked by me and stored in `photos`.

bookings (ONE collection for customer requests and confirmed bookings; field names
agreed in step 2.5)
- customer: map with fullName, phone ("+" and digits only), whatsapp (boolean),
  telegram (boolean), email
- carId
- pickupDateTime, dropoffDateTime (stored in UTC)
- pickupLocation, dropoffLocation: each a map with id (a location id from settings, or
  "other") and, only for "other", text. "other" is a reserved id: no location in
  settings may use it.
- extras: list of selected extras; stored names: snowChains, childSeat, infantSeat,
  boosterSeat
- notes: always present, may be empty (<= 500 chars)
- totalPrice: fixed number in USD with at most two decimals, NOT recomputed on display
- language (ka/ru/en)
- status: new | pending | confirmed | cancelled
- createdAt (server time)
- createdBy (only for admin-created bookings)
- expireAt (set server-side in the last phase; absent until then)
- Not stored: the number of days and the "individual price" flag. Both are calculated
  from the two dates.

Statuses:
- new: submitted by a customer, nobody has handled it yet.
- pending: admin contacted the customer, order still in progress.
- confirmed: a real booking. Only these appear on the calendar and count for conflicts.
- cancelled: cancelled. No rejection reason field.

There is no `contacted` status and no `completed` status.
No full snapshot of car data is required; storing the final totalPrice is enough.

settings (document and field names agreed in step 2.3)
- settings/extras: pricesPerDay, a map with a number for each of snowChains, childSeat,
  infantSeat, boosterSeat (USD per day).
- settings/locations: items, an array of maps in dropdown order; each has id (stable
  text stored in bookings) and name { ka, ru, en }. The English name is required.
  "Other" is not stored; it is a fixed option of the form.
- company info (name, phone, email, address, working hours, social links, map): its
  own document, defined in Phase 6.
- A missing or invalid settings document is an error. The app never uses default
  prices or default locations.

## 5. Settings collection

Public read, admin write. Company info starts empty; the public About Us page must
handle that with an empty state.

## 6. Pricing rules

- Currency: USD everywhere. Price per day is set individually per car. Extras prices
  are global (same for every car), per day.
- Rental days = max(1, ceil((dropoff - pickup - 2 hours) / 24 hours)).
  One day = 24 hours, with a 2-hour free grace period.
- Total = days * (car price per day + sum of selected extras' per-day prices).
- Test cases (pickup on the 10th at 18:00): return on the 15th at 20:00 -> 5 days;
  15th at 20:01 -> 6 days; 16th at 20:01 -> 7 days.
- Rental <= 7 days: show the calculated total.
- Rental > 7 days: still show an estimated total, alongside a clearly visible note:
  "For rentals longer than 7 days, the price is individual — our team will contact you
  to confirm the final price."
- Admin editing: the price field is auto-filled by the calculator and admin may
  override it manually. If admin then changes dates, car or extras, the price is
  recalculated and overwrites the manual value, with a short on-screen notice
  explaining this.
- Unit tests for the price calculation (including the cases above) are MANDATORY.

Implementation decisions (step 2.1):
- Rental days are computed in whole minutes; seconds are ignored.
- The grace period (2 hours) and the limit for a normal price (7 days) are named
  constants.
- Exactly 7 days is a normal price. From 8 days the result is flagged as an individual
  price; the total is still calculated as an estimate.
- The total is calculated in whole cents, so 3 * 19.99 is exactly 59.97.
- The calculator refuses invalid input with an error: dropoff not after pickup, a date
  that is not UTC, a selected extra without a price, or a price that is negative or
  not a number. A missing price is never counted as 0.

## 7. Time rules

- Store timestamps in UTC. ALL date/time pickers interpret and display time as
  Asia/Tbilisi (GMT+4, no DST), regardless of the device time zone.
- Implementation: a small fixed +4 hours helper in lib/core, no time zone package.
- Every date/time field shows the label "Tbilisi time (GMT+4)".
- Conflict check (warning only, never blocking, never silent): a booking conflicts with
  an existing `confirmed` booking on the same car if
  newPickup < existingDropoff + 5 hours AND newDropoff + 5 hours > existingPickup.
  Example: a car returned at 10:00 can be picked up again from 15:00.
- The 5-hour buffer is a single named constant in code.
- `new`, `pending` and `cancelled` bookings do not block a car.
- Unit tests for the overlap logic are MANDATORY.

Implementation decisions (step 2.2):
- The offset is one named constant: 4 hours, the same all year.
- A Tbilisi date and time is its own small type (TbilisiDateTime: year, month, day,
  hour, minute), not a DateTime, so it cannot be stored by mistake as if it were UTC.
- Stored moments are converted for display with TbilisiDateTime.fromUtc; what the user
  picks is converted for storing with toUtc.
- The code never uses the device's time zone.
- It works in whole minutes; seconds are dropped.
- Invalid input is refused with an error: a date that is not UTC, or a date or time
  that does not exist (for example 30 February).

## 8. Security

- Admin identity: Firebase Auth custom claim `admin: true`, checked in
  Firestore/Storage rules. UI hiding alone is never protection.
- The claim is set via a one-off Admin SDK script. Document it as an explicit setup
  step, including how the ID token is refreshed after the claim is set.
- cars: public read of active cars only (active == true); writes admin only. Until
  admin auth exists (Phase 3), nobody can write.
- settings: public read; writes admin only.
- The settings collection is publicly readable. Never put anything private in it
  (admin e-mails, keys, internal notes).
- bookings: public `create` only, with strict validation in rules: allowed field set
  only, status == 'new', createdAt == request.time, notes <= 500 chars, string length
  limits, `expireAt` NOT accepted from the client. No public get/list/update/delete.
  Read/update/delete admin only.
  Implemented in step 2.6: the exact key list, the limits of booking_limits.dart (a
  unit test keeps them equal), an active car (one read per attempt), pickup in the
  future, dropoff at most 365 days after pickup, and a total between 0 and 1,000,000
  USD. Not checked by the rules: that a location id exists in settings (only its shape
  is checked; the settings parser enforces the same shape), and that the total matches
  the prices; the total is an estimate that staff recalculate.
- `mail` collection (Trigger Email extension): clients must never read or write it.
- Firebase App Check on the public booking form (reCAPTCHA on web; Android approach in
  Open reminders).
- The admin login route must not appear in public navigation.

## 9. Analytics & Compliance

- Firebase Analytics: track car views and filter usage.
- Cookie/consent banner (web): Analytics is disabled until the user accepts; the choice
  is stored on the device; the banner links to the Privacy Policy.
- Privacy Policy page: what is collected, why, retention period 12 months.
- Retention via Firestore TTL policy on the `expireAt` field (no custom cleanup job).

## 10. Architecture (approved)

- Folder structure: feature-first, with a small shared core.
  lib/features/<feature>/{data,domain,presentation}; shared code in lib/core (shared
  models in lib/core/models, router, theme, Tbilisi time helper, constants, shared
  widgets); ARB files in lib/l10n.
- Riverpod: manual Notifier/AsyncNotifier, no code generation. Models are hand-written
  (fromMap/toMap), no freezed or json_serializable.
- Approved exception: read-only Firestore streams (the active cars, the extras prices,
  the locations) use a StreamProvider instead of a Notifier.
- Cars stream: automatic retry is turned off (error state with a "Try again" button),
  the provider is auto-dispose, and paused providers keep the default behaviour.
- The provider that creates a repository lives in the repository's data/ file, so no
  presentation provider imports cloud_firestore.
- White areas are always built with AppCard or OnWhite (lib/core/widgets/app_card.dart).
  They switch the text inside to dark; text on a white area without them would be white
  on white.
- A car document that cannot be parsed is skipped and logged, so one typo in the
  console does not blank the whole catalog.
- Firebase access: one thin repository per collection. Flow: UI -> provider ->
  repository -> Firestore. Widgets and providers never import cloud_firestore.
- Pricing, overlap and Tbilisi-time conversion are pure Dart with no Firebase or
  Flutter imports, so they are unit-testable.
- Config: no flavors. A single firebase_options.dart generated by flutterfire configure.
- Imports use the full package:tbilisi_car_rental/... form.
- Test strategy: unit tests for pricing, overlap and Tbilisi-time conversion, and for
  any other new logic. No widget tests by default. The Firestore rules for bookings
  are tested on the local emulator with tool/check_booking_rules.mjs (decided in step
  2.6).
- Approved exception to "no widget tests": catalog_screen_test.dart covers the catalog
  states (loading, error with "Try again", empty, no match with "Reset filters") and
  the search field (no match by search; Reset clears the search and the filters), with
  the cars provider overridden (no Firebase). The car detail screen has the same kind
  of tests (car_detail_screen_test.dart, catalog_navigation_test.dart).
- Packages installed: firebase_core 4.15.0, flutter_riverpod 3.4.3, go_router 18.0.2,
  flutter_localizations (Flutter SDK), intl 0.20.2, cloud_firestore 6.10.0.
- Package approved for Phase 1: cloud_firestore.
- Packages approved for later: url_launcher, shared_preferences, image_picker
  (Phase 4). Other Firebase packages are added in the phase that first uses them, with
  approval.
- Not added for now: cached_network_image, flutter_launcher_icons.

## 11. Phased delivery plan

0. Setup: Firebase project, project skeleton, CLAUDE.md, localization scaffolding
1. Public catalog (read-only) + filters + localization + empty states + purple theme +
   app name. Basic Firestore rules start here (public read of active cars).
   Demo cars are entered by hand in the Firebase console.
2. Booking form + price calculation + confirmation screen + Firestore rules +
   App Check. Extras prices and the location list are seeded by hand in the Firebase
   console, because the admin screens for them come in Phase 6.
3. Admin auth (custom claim script) + bookings list and editing
4. Fleet management + photo upload
5. Calendar + conflict warning
6. Settings screens (Extras & Prices, Company Info) + About Us page
7. Cloud Functions + compliance + polish (consent banner, Privacy Policy, TTL, email,
   README with screenshots, launcher icon). The launcher icon is still open; it needs
   the package flutter_launcher_icons, which needs the owner's permission then.

## 12. Cloud Functions — LAST PHASE ONLY

The app must be fully functional without the Blaze plan until the last phase. In the
last phase:
1. onCreate trigger on `bookings` -> writes to the `mail` collection (Trigger Email
   extension, needs an SMTP provider such as a free-tier SendGrid account).
2. The same (or a second) function sets `expireAt` = createdAt + 12 months.

Before this phase starts, remind me about the Blaze plan requirement and to set a
Google Cloud budget alert.

Also: verify whether Cloud Storage for Firebase (photo upload, Phase 4) currently
requires the Blaze plan for new projects, and tell me BEFORE Phase 4 what my options
are.

## 13. Design

- Purple (#673AB7) page background and app bar with white text; white cards, white text
  fields and white filled buttons with purple text. Buttons inside white cards are purple
  with white text. Theme in lib/core/theme; the purple is one named constant,
  appBackgroundColor.
- Text placed directly on the purple is white; text inside white cards is dark. No faint
  or low-contrast text anywhere. The one exception: disabled controls keep the normal
  faded Material look.
- One fixed theme: no dark mode. Material calls the colour scheme "dark" only because
  its text is light.
- No gradient for now (flat colour only); it may be revisited in the polish phase.
- I chose the colour on the emulator in step 1.5 from a temporary preview screen
  (option F of options A to H). The preview screen has been deleted.
- App name: "Tbilisi Car Rental" (Android label, iOS display name, web title).
- Launcher icon: postponed to Phase 7.

## 14. Phase 0 status

- 0.1 Git and cleanup — DONE. Repository initialised on main; desktop folders (linux,
  macos, windows) removed; pushed to GitHub. Commits fdd84ee, 872939b.
- App ID set to com.greek.tbilisicarrental — DONE. Commit 5feafb2.
- 0.2 Firebase project — DONE (created by me in the console; see Section 1.2).
- 0.3 Connect Flutter to Firebase — DONE. Commit c1e19ae.
  - flutterfire configure registered web, Android and iOS apps and generated
    lib/firebase_options.dart and android/app/google-services.json.
  - No ios/Runner/GoogleService-Info.plist was written on Windows; re-run
    flutterfire configure on a Mac if iOS is ever built.
  - .firebaserc, the firestore section of firebase.json, firestore.rules (deny-all) and
    firestore.indexes.json were written by hand. Nothing was deployed.
- 0.4 Core dependencies — DONE. Commit f53e36d. The Android debug build passes.
- 0.5 App skeleton — DONE. Commit 5a906fe. lib/main.dart (Firebase init,
  ProviderScope, MaterialApp.router), lib/core/router/app_router.dart, and a temporary
  placeholder home page that Phase 1 replaces.
- 0.6 Localization scaffolding — DONE. Commit a08cf4a. l10n.yaml, three ARB files,
  generated code committed in lib/l10n/generated, the starting-language rule with unit
  tests, and a language switcher on the placeholder page.
- 0.7 CLAUDE.md and docs/PLAN.md — DONE. Commit 91eb7b9.
- 0.8 Verify on the Android emulator — DONE. I asked Claude Code to run the app on the
  emulator; its flutter run debug connection did not attach from Claude Code's shell,
  so I ran the app myself and checked it by hand: the app starts, Firebase initialises,
  Georgian text renders correctly, the starting language is picked automatically from
  the device language, and the language buttons switch the text.

Phase 0 is complete.

## 15. Open reminders

- Before Phase 4: re-check live docs on whether Cloud Storage needs the Blaze plan; I
  decide the option (Blaze early / no upload / build now, enable later).
- Before Phase 7: switch to Blaze, set a Google Cloud budget alert; Cloud Functions use
  Node 22 (Node 20 is being shut down).
- firebase_core 4.15.0 still applies the Kotlin Gradle Plugin the old way (build
  warning). Do not run flutter upgrade mid-project; check for a newer FlutterFire
  release first.
- Riverpod is 3.4.3: automatic retry of failing providers (consider turning it off for
  Firestore streams), paused providers (relevant to real-time admin screens), no
  separate AutoDispose classes, legacy providers moved. Confirm each against the
  installed version when we first use it.
- App Check: reCAPTCHA is the web mechanism; on Android use Play Integrity (a debug
  provider for development). Propose the approach in Phase 2 and ask me before enabling.
- Analytics consent: Section 9 describes a web consent banner; decide in Phase 7 how
  consent works on Android (proposal: the same consent screen on all platforms, the
  choice stored with shared_preferences, Analytics off until accepted).
- Privacy Policy and the booking form: the form has no consent line yet (decided in
  step 2.7). When the Privacy Policy page exists, link it from the booking form, next
  to the Send button, and decide then whether a consent line is needed.
- Public demo: decide in Phase 7 whether it is a hosted web build, an APK, or both.
- Web URLs keep the # for now; decide clean URLs and the Firebase Hosting rewrite rule
  when we set up Hosting.
- Georgian font: not bundled; renders fine so far in Chrome and on the Android emulator
  (short placeholder text only). Re-check in Phase 1 with more text.
- Language choice is not remembered yet (shared_preferences comes later).
- Rules tests run on the local Firebase emulator, never against the real project, with
  this command (one line):
    firebase emulators:exec --only firestore
      --project demo-tbilisi-car-rental "node tool/check_booking_rules.mjs"
  Java comes from "C:\Program Files\Android\Android Studio1\jbr", set (JAVA_HOME and
  PATH) for that one command only; the folder "Android Studio\jbr" is broken. No
  system-wide Java is installed.
- Before making the repo public: review it for secrets (google-services.json and
  firebase_options.dart are not secret and are allowed).
- README is written in the last phase: screenshots, an honest "how I worked" paragraph
  (architecture and business rules are my decisions; Claude Code writes the code under
  my supervision; I review and approve every change), and a note that iOS could not be
  tested on Windows.
- OPEN QUESTION, not a decision: Navigation between screens is not decided. Proposal to
  decide later: the public app uses plain back navigation for the booking flow and a
  small app bar menu for the About Us and Privacy Policy pages (decide in Phase 6); the
  admin panel uses a responsive shell (a bottom navigation bar on phones, a side
  navigation rail on wide screens) with go_router's ShellRoute (decide in Phase 3).
- App bar on other screens: the car detail screen reuses AppBarLogo next to the back
  arrow, with the same toolbar height (decided in step 2.4). Decide again for each new
  screen.

## 16. Phase 1 status

- 1.1 Docs: Phase 1 decisions recorded in this file — DONE.
- 1.2 Car model and filter logic with unit tests (pure Dart) — DONE. Commit 4476931.
- 1.3 Firestore access: cloud_firestore, car repository, local firestore.rules — DONE.
  The rules are changed on disk only; they are not deployed yet.
- 1.4 Rules deploy (one approved command) and demo cars — DONE. The rules are live; an
  anonymous read check confirmed that a query filtered on active == true succeeds and a
  query without that filter is denied.
- 1.5 Theme: purple page theme applied (background #673AB7, option F, chosen by me on
  the emulator); temporary preview screen deleted — DONE.
- 1.6 Catalog screen: providers, card, loading/error/empty states, ARB strings;
  placeholder page removed; language menu in the app bar — DONE.
- 1.7 Filters UI: button, bottom sheet, reset — DONE.
- 1.8 App name on Android, iOS and web — DONE. The launcher icon stays postponed to
  Phase 7.
- 1.9 Verify on the Android emulator — DONE. After a fresh install I checked by hand:
  the launcher label, the catalog sorted by price, the three languages, the filter
  sheet, the no-match state, Reset, and that the filter survives a language change and
  rotation. The error state cannot be triggered safely on a device; it is covered by a
  widget test.
- 1.10 Catalog search: a search field next to the Filters button; search by brand and
  model, combined with the filters — DONE.
- 1.11 Logo in the app bar: assets/images/app_bar_logo.png replaces the text title on
  the catalog screen (logo height 48, toolbar height 64). The app name stays as the
  screen-reader label and as the fallback text — DONE.

Phase 1 is complete.

## 17. Phase 2 status

- 2.1 Price calculator and the list of extras (pure Dart, mandatory unit tests) — DONE.
- 2.2 Tbilisi time helper (pure Dart, unit tests) — DONE.
- 2.3 Settings, read-only: extras prices and locations; rule "settings: public read";
  settings entered by me in the console — DONE.
- 2.4 Car detail screen with the "Make a booking" button — DONE.
- 2.5 Booking model and form validation (pure Dart, unit tests) — DONE.
- 2.6 Firestore rules for bookings (public create only) and the create method in the
  repository; deploy with my approval — DONE. The rules were deployed on 2026-10-08;
  the first valid create is tested from the real app in step 2.7.
- 2.7 Booking form screen, in two parts: 2.7a the logic, the state and the texts;
  2.7b the screens and the routes — not started.
- 2.8 Confirmation screen — not started.
- 2.9 App Check (approach proposed first, enabled only with my approval) — not
  started.
- 2.10 Verify Phase 2 on the Android emulator — not started.
