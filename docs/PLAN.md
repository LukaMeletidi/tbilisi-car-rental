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
- The "Make a booking" button is fixed at the bottom and opens the booking form.

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
- Known limit: searching "mx5" does not find "MX-5" (punctuation is not ignored).
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
  2.8 that screen showed only the thank-you sentence and "Back to the cars"; since
  step 2.8 it also shows the summary (Section 2.4).
- App bar: the logo next to the back arrow, as on the car screen. The first card of
  the form shows the car (title and price per day, no photo).
- Time picker: Flutter's own, any minute, 24-hour form in all three languages. Both
  pickers open as white dialogs with dark text.
- A chosen date and time is shown in numbers, the same in every language:
  "10.01.2026 18:00" (day.month.year hours:minutes).
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
- While a request is being sent, going back is blocked (at most 20 seconds): the back
  arrow is disabled and the system back button does nothing. The browser's Back button
  cannot be blocked; if the form is gone when the answer arrives, the app does not
  open the thank-you screen and forgets the sent booking at once.
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

Decisions (step 2.8):
- Two white cards under the thank-you sentence. "Your request": the car, pickup and
  dropoff (date and time, the line "Tbilisi time (GMT+4)", the place), the extras
  ("None" when there are none), the notes (only when not empty), the rental days and
  the total. "Your details": name, phone (in its stored form), WhatsApp and Telegram
  when ticked, and e-mail.
- The summary shows what was sent: the days come from the two stored dates and the
  total is the stored one. Nothing is calculated again from the current prices. More
  than 7 days shows "Estimated total" and the individual-price note, as in the form.
- Not shown: the document ID (no use to the customer), and the prices per day of the
  car and the extras.
- Dates are the stored UTC moments shown as Tbilisi time, in numbers
  ("10.01.2026 18:00").
- The name of a fixed place is looked up in settings when the screen is shown, in the
  current language. If the settings are not loaded or the place is no longer there,
  the line says "A place from our list"; the stored id is never shown and the screen
  never waits for the settings or shows an error for them.
- A language switch changes the labels, the extras and the place names, never the
  stored booking.
- Unchanged from step 2.7: the screen keeps its own copy, the shared sent booking is
  cleared when the user leaves, and without a sent booking the screen goes to the
  catalog.

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

Phase 3 decisions (the steps are in Section 18):
- Addresses: /admin (the bookings list) and /admin/login; later admin screens go below
  /admin. Nothing in the public app links to them.
- Entry on Android: no visible entry; a long press on the logo in the catalog app bar
  opens /admin/login. On web the address is typed by hand.
- A signed-out visitor of anything under /admin is sent to /admin/login. A signed-in
  account without the admin claim sees "This account has no admin access" and Sign
  out; no admin data is requested.
- Admin screens have a plain app bar for now. The navigation shell (bottom bar on
  phones, side rail on wide screens) comes in Phase 4.
- A booking document that cannot be read is skipped; the list shows the count
  "N bookings could not be read" and the reason is logged. The same holds for cars.
- Delete: a Delete button in the detail screen, with a confirmation; it is permanent.
  It is the last feature step of Phase 3.
- No conflict warning in Phase 3: it comes in Phase 5 (Section 3.4). Until then an
  admin can set "confirmed" without any warning.
- createdAt is always server time, also for a booking created by hand.
- The one shared admin password is long and random; there is no password reset flow
  in the app.
- Session and redirect (logic written in step 3.4, used by the router in step 3.5):
  - The session is one of: unknown (Firebase has not answered yet), signed out, no
    access (signed in without the claim), admin. Admin means the claim "admin" is
    exactly the boolean true, as in the rules.
  - The claim is read at app start, at sign-in, and each time Firebase renews the
    sign-in token (idTokenChanges, about once an hour). No polling and no "refresh"
    button. A claim removed with the script takes effect in the app within about an
    hour; the rules refuse as soon as the old token has expired.
  - Two more addresses: /admin/no-access (the "no admin access" page) and
    /admin/checking (only a spinner, while the session is unknown). No login page
    flashes and no admin page is built before the session is known.
  - The address a visitor asked for travels along as "?from=...". It is used only
    when it is a plain address inside /admin: never one of the three gate pages,
    another site or a public route, and nothing with "?", "#", a backslash, ".." or
    "//". Otherwise the admin lands on /admin.
  - "/admin/" and "/admin/login/" are treated as the same pages as without the slash.
  - The public routes are never redirected.
  - An error while reading the session becomes "signed out", never "admin". An admin
    who loses the connection at that moment may see the login page; that is accepted:
    no data is shown and the rules decide.
  - Sign-in failures shown to the admin: empty field, e-mail format, wrong e-mail or
    password (never which of the two), too many attempts, no connection, account
    disabled, and "unknown" for anything else. The raw code of Firebase is logged for
    the developer and never shown. The e-mail and the password are never logged and
    never kept after the call.
- For step 3.5:
  - The router must run the redirect again whenever the session changes (go_router's
    refreshListenable, fed by the session provider), and the unknown state must show
    only the spinner page.
  - On web the sign-in is kept for the browser session only (closing the browser signs
    out). On Android the sign-in stays on the device between app starts; Firebase does
    not let an app change that.
- Decisions of step 3.5 (the admin pages and the router):
  - Pages: /admin/login (e-mail, password with a show/hide button, "Sign in"),
    /admin/checking (only a spinner), /admin/no-access ("This account has no admin
    access." and Sign out), and /admin, for now a placeholder ("Signed in as an
    administrator." and Sign out) that reads no data and shows no e-mail. The
    bookings list replaces it in step 3.6.
  - The four admin routes sit side by side below the catalog, NOT one below the
    other: a page below /admin would have the admin page built underneath it, also
    for a visitor who is not signed in.
  - The router asks the redirect function for every address and asks again whenever
    the session changes. Sign out therefore needs no navigation of its own: the
    session becomes "signed out" and the login page appears.
  - The session is read from the start of the app, so Firebase Auth listens for every
    visitor, public ones too. A public visitor is simply "signed out"; accepted.
  - The back arrow of the login page always goes to the catalog (a typed web address
    has no page to go back to).
  - After a refused sign-in the password field is cleared and the e-mail kept. The
    password exists only in its text field; it is never in a provider, the state or a
    log. Done on the keyboard, or Enter on web, sends the form.
  - The long press: on the logo of the catalog app bar only, Flutter's standard long
    press (about half a second). No tooltip, no ripple, nothing extra for screen
    readers; a tap does nothing. An admin who is already signed in lands on /admin.
  - On web, session-only sign-in is set once at app start (web only; a failure or 5
    seconds without an answer is logged and the app starts anyway).
  - An address under /admin that does not exist shows go_router's own "page not
    found" for now.
  - The admin texts are English constants in one Dart file, not ARB keys. The admin
    feature reuses the message widget of the catalog feature.
  - Never in the repository: a real e-mail address, password or UID. Tests use
    made-up values.
- Decisions of step 3.6 (the bookings list on /admin, read only):
  - The query: the "bookings" collection, ordered by createdAt, newest first, the
    newest 50, as a live listener: a new or changed booking appears by itself. "Load
    more" adds 50 and is offered only when the last answer was exactly as long as the
    limit. A new sign-in starts again with 50.
  - Reads: opening the list costs up to 50 booking reads plus one read per car (all
    cars are read once, also hidden ones, to show the car of each row); each new or
    changed booking costs 1 read; "Load more" is counted as a fresh query. Spark
    allows 50,000 reads a day.
  - The listener exists only while the session is "admin". The provider watches the
    session and closes the listener itself when it changes; the screen also closes it
    before it signs out, so nothing is listening when the sign-in token goes. An
    error that still arrives after a sign-out is not shown.
  - One row: the customer's name and phone; a status chip that always carries its word
    (New grey, Pending amber, Confirmed green, Cancelled red); the car; pickup and
    dropoff as "10 Jan 2026 18:00" in Tbilisi time; the days and the stored total,
    marked "estimate" for more than 7 days; "Received 9 Oct 2026 17:34". The note
    "Tbilisi time (GMT+4)" stands once above the list. Rows cannot be tapped yet.
  - The car line: the title; the title with "(hidden)" for a hidden car; "Car not
    found" when no car has that id. The stored car id is never shown.
  - A document that cannot be read as a booking is skipped and counted among the
    loaded documents: "N bookings could not be read." In debug builds only, the id
    and the reason of each are listed, never the contents.
  - States: a spinner; "No bookings yet."; "You do not have access to the bookings."
    for a refusal of the rules; "Could not load the bookings." with "Try again".
  - "Offline: showing saved data" appears only when the answers have come from the
    copy saved on the device for 3 seconds without a break, never on the first such
    answer, and goes as soon as the server answers.
  - Dates are converted with the project's one helper (TbilisiDateTime.fromUtc); the
    English month names of the admin area are a small table in the admin code.
  - The Firestore cache settings are NOT touched in this step. On Android the
    bookings an admin has read stay in the local copy; decide in step 3.12.
  - An unknown address under /admin shows "This admin page does not exist." with a
    way back to the bookings, only to an admin. An unknown public address keeps
    go_router's own screen; a public "page not found" page is left for the polish
    phase.
  - Known and accepted: the query orders by createdAt, so a document without
    createdAt (possible only if made by hand in the console) is not listed at all and
    is not counted as unreadable either.
  - Never in the repository: a real name, phone number, e-mail or booking id from the
    real database. Tests use made-up values.
- Decisions of step 3.7 (filter, search and sort of the bookings list):
  - Everything works on the bookings that are already loaded (client side). No new
    Firestore query, no index, no extra reads: the one listener of step 3.6 stays.
  - Status chips in one row: All, New, Pending, Confirmed, Cancelled, each with its
    count ("New 2"); one is selected at a time. On a narrow phone the row scrolls
    sideways.
  - A search field for the customer's name and phone. Every typed word must be found
    in the name (upper and lower case ignored) or, for a word with digits, in the
    phone. A text written like a phone number is compared as digits in one piece, so
    "555 12" finds "+995555123456". Only the name and the phone are searched.
  - The counts on the chips follow the search and ignore the chosen chip: each chip
    shows how many bookings a tap on it would show.
  - Three orders, in a menu next to the search field: newest first (the default),
    oldest first, and pickup date (coming pickups first, the soonest on top; past
    pickups after them, the most recent on top). Bookings that are equal for the
    chosen order keep the order they were loaded in.
  - The pickup order needs the current time; the pure code gets it as a parameter and
    the provider passes it from the clock provider.
  - While older bookings can still be loaded, a line says "Filters and counts cover
    the N loaded bookings. Load more to include older ones.", with the real number.
    "Load more" stays available with a filter active. When nothing matches: "No
    bookings match." with "Clear filters" (which keeps the order).
  - The choice lives in memory only. It is kept while the admin stays signed in and
    is reset to "All, empty search, newest first" whenever the session is not admin,
    also when the session ends by itself.
  - The search text can be a name or a phone number: it is never logged and never
    stored, and the search field tells the keyboard not to learn it (no autocorrect,
    no suggestions, no autofill hints).
  - Not built: a car filter and a date filter. The search and the pickup order cover
    most of that need; the calendar of Phase 5 is the tool for dates.
  - A status with a wrong value written by hand in the console makes the document
    unreadable; it is counted in "N bookings could not be read", as before.
- Decisions of step 3.8 (booking detail and status change):
  - A tap on a row of the list opens the detail, at /admin/bookings/<id>. It is built
    below the list, so Back returns to the list. The redirect of step 3.4 already
    covers the address: only an admin ever sees it, and a signed-out visitor is sent
    to the login page and on to the booking after the sign-in.
  - The detail has its own live read of that one document (one read, plus one for
    its car), so a change made elsewhere, or a deletion, shows at once. It is tied to
    the admin session like the list and is closed when the screen is left.
  - Shown: the status, the customer (name, phone, WhatsApp/Telegram, e-mail, the
    language used), the car, pickup and drop-off in Tbilisi time with the place, the
    extras, the notes when there are any, the days and the stored total ("estimate"
    for more than 7 days), "Received ...", "Created by ..." when set, and the booking
    ID in small text. The phone, the e-mail and the ID are selectable text. Every
    value is the stored one; nothing is calculated again from current prices. Only
    the English names of the fixed places come from settings, with the neutral text
    "A place from our list" when they cannot be found.
  - Any status can follow any other. The status card shows the chip of the list (same
    words, same colours) and one button for each other status.
  - A question "Change the status?" is asked only for the two changes that are hard
    on a customer: to Cancelled, and away from Confirmed. All other changes happen
    at once.
  - A change writes only the field "status", in a transaction that is tried once and
    waits up to 20 seconds for the server. Nothing is queued while offline. During
    the wait the buttons are disabled and the card says "Saving…".
  - The chip always follows the live read, never the attempt. "Saved" appears only
    after the server's answer. A failure says "Not saved." with the reason: "No
    connection." (unavailable, deadline-exceeded), "The change was refused."
    (permission-denied), "This booking no longer exists." (the document is gone),
    "Please try again." (anything else).
  - A transaction that gives up after 20 seconds may still have been committed. The
    text is then not "Not saved" but "No answer from the server. The status shown is
    the current one."
  - The change runs in two stages: a check, then the write. The check is empty today;
    the conflict warning of Phase 5 will be put there.
  - "Offline: showing saved data" uses the same pure function and the same 3-second
    rule as the list. The status buttons stay enabled; a change then fails with "No
    connection." because a transaction needs the server.
  - A booking that does not exist (also one deleted while it is open) shows "This
    booking does not exist. It may have been deleted." The saved copy of the device
    not having it is not taken as "does not exist": the screen waits for the server
    and says "Could not load the booking." after 3 seconds. An ID that cannot be a
    document ID (anything but letters, digits, "_" and "-") is "does not exist"
    without asking Firestore. A document that cannot be read as a booking shows
    "This booking cannot be read."; the reason is shown in debug builds only.
  - Extra cost of a direct link: the list is built under the detail, so opening
    #/admin/bookings/<id> on web also starts the list's listener (up to 50 reads)
    next to the 2 reads of the detail. Accepted.
  - Not stored: who changed the status and when. The rules refuse any field outside
    the fixed list (see Open reminders).
  - No customer data is logged. Rules, ARB files, packages and indexes are unchanged.
- Decisions of step 3.9a (editing a booking: logic, repository and notifier; the
  screen and the route come in 3.9b):
  - Editable: the customer (name, phone, WhatsApp and Telegram, e-mail), the
    language, the notes, the car, pickup and drop-off time and place, the extras.
    Never written by an edit: the ID, createdAt, createdBy and the status (the
    status keeps its own control on the detail). A booking can be edited in every
    status, also Cancelled.
  - Validation uses the helpers and limits of the public form. The admin may do two
    things the public may not, as the rules allow: a pickup in the past (the form
    will show a note) and a hidden car (marked "(hidden)"). A fixed place must be in
    settings, except the place the booking already has: a place that was removed
    from settings stays possible in its own field.
  - The total. The form shows the stored total beside a new total: days x (the
    car's price per day + the extras per day), at the CURRENT prices; the price card
    will say so. Old prices are not stored anywhere.
    - Car, dates and extras unchanged: no choice; the total is not sent.
    - One of them changed and the new total differs (or cannot be calculated): the
      admin must choose "keep the stored total" or "use the new total". Nothing is
      chosen for them, and without a choice nothing is saved. Changing car, dates or
      extras again removes the choice.
    - One of them changed but the new total equals the stored one: no choice.
    - The prices or the car cannot be loaded: only "keep the stored total".
    - The stored total is never changed silently, also not when a price went up.
    - Not built: a free, typed total. The rules would accept one (they only check 0
      to 1,000,000). Possible later addition, as its own step.
  - What is sent: only the top-level fields that changed, in one update. A nested
    map (the customer, a place) and the list of extras are sent whole. createdAt is
    never sent, so the rule "createdAt unchanged" holds by construction.
  - A part the admin did not touch keeps its stored value exactly and is not sent:
    the customer (its five inputs together), the notes, each place and each date.
    Nothing is trimmed and the phone is not put into its plain form unless that
    part was touched. Only a touched part is cleaned. The validation still runs on
    the whole form.
  - Saving uses the transaction pattern of the status change: one attempt, 20
    seconds, nothing queued, "Saved" only after the server's answer, "No answer
    from the server" for a timeout, and the same "Not saved" texts.
  - Before it writes, the transaction reads the booking and the car, and stops with
    a clear message instead of a bare "refused" when:
    - the booking is gone;
    - the stored document has a field the rules do not know (the field is named);
    - the stored document has no createdAt;
    - the car does not exist (any more);
    - an edited part was changed elsewhere since the edit started (a conflict).
    The rules check the WHOLE document on every update, which is why the first
    three matter also for an edit that is itself fine.
  - The conflict check compares, for each edited part, the value the edit started
    from with the stored value, both normalised the same way: a date as milliseconds
    since the epoch in UTC (Firestore keeps microseconds, a browser milliseconds),
    a number as a double, maps and lists deeply, the extras as a set. A part the
    admin did not edit is not compared, so a status change elsewhere is no conflict.
    One exception: when the total is written ("use the new total"), the car, both
    dates and the extras are compared as well, edited or not, because the new total
    was calculated from them. With "keep the stored total" nothing extra is
    compared. The repository and the form use the same function for this.
    After a conflict the form offers "Keep editing" (the typed values stay readable)
    and "Load the current booking" (the edits are dropped).
  - While the form has no unsaved changes it follows the live read; with unsaved
    changes it keeps its starting point, and knows which edited parts were changed
    elsewhere.
  - The status change of step 3.8 got the same check of the stored document: a
    field the rules do not know, or a missing createdAt, is now said by name there
    too. The bare "The change was refused." stays for a real refusal (for example a
    removed admin claim) and is covered by tests only.
  - The key list of the app (admin_booking_document.dart) is tied to the rules by a
    test that reads firestore.rules. The rules emulator script got the updates the
    edit sends (accepted and refused) and the five hand-made documents: 209 admin
    and signed-in checks now.
  - Known limits of 3.9a:
    - A customer map or a place map with an extra key written by hand is reported
      as a conflict of that part, not as an unknown field. The rules refuse such a
      document anyway.
    - A booking that is deleted while it is being edited replaces the form with
      "does not exist"; the values the admin typed are lost.
    - The status change of step 3.8 does not have the check for a stored value in
      another format (next point): on such a hand-made document it still ends with
      the bare "Not saved. The change was refused." The edit form names the part.
  - A stored value the rules refuse, in a part that was not touched. A value
    written by hand in the console can be readable for the app and still refused by
    the rules, which check the whole document on every update. Checked on the
    emulator, with an edit of another part (the language):
    - a phone with spaces: refused;
    - a name with a space at the end: refused;
    - an e-mail with a space at the end: refused;
    - the text of a place with a space at the end: refused;
    - notes with a space at the end: accepted (the rules only limit their length).
    For the four refused ones the validation of the edit form reports the part by
    name while it is untouched: "The phone number is stored in a format the app
    does not accept. Edit it to correct it." (also: The name, The e-mail address,
    The pickup place, The drop-off place). Touching the part removes the error; a
    touched part is cleaned and sent. Notes stay silent. The app itself cannot
    store such a value.
  - Nothing is logged except the type of an unexpected error. Rules, ARB files,
    packages and indexes are unchanged.

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
  Decided for Phase 3: the script lives in tool/admin/ with its own package.json
  (package firebase-admin; node_modules is ignored). It uses a service account key
  that is created, used and deleted in one sitting. The key file stays outside the
  repository and outside any synced folder and is never committed; the script never
  prints its contents and refuses to run when the key path is inside the repository
  or when the key's project is not exactly tbilisi-car-rental. After the claim is
  set, the admin signs out and in again: the claim is inside the sign-in token.
- Live rules: since step 3.3 the live Firestore rules are those of commit 0a7eb27
  (deployed 2026-10-09, 13:34 UTC). To go back to an earlier version, use the Rules
  history in the Firebase console (Firestore Database > Rules). A new ruleset reaches
  new requests within about a minute and open listeners within about 10 minutes.
- Admin rules (written in step 3.1; deployed in step 3.3):
  - isAdmin(): signed in AND the token has admin == true. A token without the claim,
    or with any other value, is treated exactly like the public.
  - bookings: an admin may read, list, update and delete. The public create is
    unchanged. An admin may also create a booking by hand.
  - Admin writes are still checked for their shape, with the same limits as a
    customer request. Differences: any of the four statuses; createdBy (1 to 100
    characters) is allowed; the pickup may be in the past; the car must exist but
    may be hidden. createdAt is server time on create and cannot be changed later.
  - cars: an admin may read every car, also a hidden one. Writes stay closed until
    Phase 4. settings: writes stay closed until Phase 6.
  - Everything else, including mail, is denied for an admin too.
- Admin setup, step by step (step 3.2). Order: the code is committed first, the key
  is created only afterwards, and steps D to F happen in one sitting.
  - A. Firebase console > Authentication > Sign-in method: enable Email/Password;
    leave "Email link" off.
  - B. Authentication > Users > Add user: the one shared admin account, with a long
    random password. Copy its "User UID" (the UID is not a secret).
  - C. Authentication > Settings > User actions: switch "Enable create (sign-up)" off
    if it is offered. If it is not, leave it: an account without the claim has no
    rights.
  - D. Firebase console > Project settings > Service accounts > "Generate new private
    key". Move the downloaded file at once to C:\keys\tbilisi, a folder outside the
    repository and outside OneDrive.
  - E. In tool/admin, in PowerShell: set the variable ADMIN_KEY_FILE to the full path
    of the key file for this terminal only, then run
    "node set_admin_claim.mjs <UID>" (shows the account, changes nothing),
    "node set_admin_claim.mjs set <UID>" (asks for the account's e-mail, then sets
    admin: true and reads it back), and the first command again. Remove the
    variable afterwards (Remove-Item Env:ADMIN_KEY_FILE).
  - F. Google Cloud console > IAM & Admin > Service Accounts > the
    firebase-adminsdk account > Keys: delete the key. Then delete the JSON file and
    empty the Recycle Bin.
  - G. Proof: "Claims: (none)" before and "Claims: {"admin":true}" after. The app
    sees the claim after the next sign-in (sign out, sign in).
  - The script (tool/admin/set_admin_claim.mjs) shows by default and changes only
    with "set" or "remove". It refuses a key inside the repository or inside
    OneDrive (real paths are compared, so a link cannot trick it), a relative path,
    and a key of any project other than tbilisi-car-rental. It keeps every other
    claim, touches no other account and no data, and never prints the key or the
    path of the key file.
  - Never commit, and never paste into a chat: the key file or any part of it, the
    private key, the admin password, an App Check debug token, or a screenshot that
    shows one of these. .gitignore has patterns for key files as a second net.
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
- Firebase App Check (step 2.9; details and open points in Open reminders):
  - What it adds: with enforcement on, Firestore refuses requests that do not carry a
    token from a registered build of our app. Plain scripts that only know the public
    web API key are then refused before the rules run.
  - What it does not do: it does not limit how often a real client writes (valid
    bookings can still be sent many times from the real app), and it does not identify
    a person. Firebase itself says it prevents some, but not all, abuse.
  - Enforcement is per product, not per collection: for Firestore it covers reading
    the cars and settings too, not only creating bookings. A build without a valid
    token then cannot load the catalog at all.
  - Step 2.9a: App Check is activated only in debug builds on Android, with the debug
    provider, and is NOT enforced (monitoring only). The strict rules for bookings
    stay the real protection.
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
  on white. A text field inside an AppCard gets a thin grey outline (purple when
  focused, red on error), because a white field cannot be seen on a white card; a field
  directly on the purple page (the search field) has no outline (step 2.7).
- A car document that cannot be parsed is skipped and logged, so one typo in the
  console does not blank the whole catalog.
- Firebase access: one thin repository per collection. Flow: UI -> provider ->
  repository -> Firestore. Widgets and providers never import cloud_firestore.
  The same holds for Firebase Auth: only lib/features/admin/data imports
  firebase_auth; screens and providers see the session and failure types of the
  domain layer.
- Pricing, overlap and Tbilisi-time conversion are pure Dart with no Firebase or
  Flutter imports, so they are unit-testable.
- Config: no flavors. A single firebase_options.dart generated by flutterfire configure.
- Imports use the full package:tbilisi_car_rental/... form.
- Test strategy: unit tests for pricing, overlap and Tbilisi-time conversion, and for
  any other new logic. No widget tests by default. The Firestore rules for bookings
  are tested on the local emulator with tool/check_booking_rules.mjs (decided in step
  2.6). Since step 3.1 the script also covers the admin and signed-in cases, with
  unsigned test tokens that only the emulator accepts. Its 104 public checks are
  guarded: the script fails when their number changes.
- The safety checks of the admin claim script have their own tests, run with Node's
  built-in test runner (no key, no network, no installed package):
    node --test tool/admin/guards.test.mjs
  Name the file: with only the folder (node --test tool/admin/) Node 24 fails.
- Approved exception to "no widget tests": catalog_screen_test.dart covers the catalog
  states (loading, error with "Try again", empty, no match with "Reset filters") and
  the search field (no match by search; Reset clears the search and the filters), with
  the cars provider overridden (no Firebase). The car detail screen has the same kind
  of tests (car_detail_screen_test.dart, catalog_navigation_test.dart). The booking
  form has the same kind of tests (booking_form_screen_test.dart), with the car, the
  settings, the booking repository and the clock overridden. The thank-you screen has
  them too (booking_sent_screen_test.dart), with the sent booking put into its provider
  and the places overridden. The admin area has admin_login_screen_test.dart and
  admin_navigation_test.dart (step 3.5), with a fake auth repository
  (test/support/fake_admin_auth_repository.dart). Every test that builds the real
  router needs that fake, because the router reads the admin session. The bookings
  list has admin_bookings_screen_test.dart (step 3.6), with a fake bookings
  repository (test/support/fake_admin_bookings_repository.dart); the provider that
  ties the listener to the session has admin_bookings_provider_test.dart, which
  builds no widgets and uses testWidgets only for its controllable clock. Step 3.7
  adds admin_bookings_filter_test.dart (pure filter, search, counts and order),
  admin_bookings_filter_provider_test.dart (the choice and its reset with the
  session), and more widget tests in admin_bookings_screen_test.dart. Step 3.8
  adds admin_booking_detail_test.dart (pure: reading one answer, the selectable
  statuses, when to ask, the error codes), admin_booking_detail_provider_test.dart
  (the live read, the session tie, the offline note and the status change; no
  widgets, testWidgets for the clock), admin_booking_detail_screen_test.dart, and
  navigation tests for the detail in admin_navigation_test.dart. Step 3.9a adds
  admin_booking_document_test.dart (the allowed keys, unknown fields, missing
  createdAt), admin_booking_edit_test.dart (pure: the draft, validation, the total
  and its choice, what changed, the update map, the conflict check with
  microseconds), admin_booking_edit_texts_test.dart (the English messages),
  admin_booking_edit_provider_test.dart (the notifier; no widgets), and more tests
  in booking_rules_limits_test.dart (the app's key list equals the rules' list)
  and booking_firestore_mapping_test.dart (the update of an edit).
- Packages installed: firebase_core 4.15.0, flutter_riverpod 3.4.3, go_router 18.0.2,
  flutter_localizations (Flutter SDK), intl 0.20.2, cloud_firestore 6.10.0,
  firebase_app_check 0.4.8 (added in step 2.9a), firebase_auth 6.7.0 (added in step
  3.4).
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
7. Cloud Functions + compliance + polish (App Check step 2.9b, consent banner, Privacy
   Policy, TTL, email, README with screenshots, launcher icon). The launcher icon is
   still open; it needs the package flutter_launcher_icons, which needs the owner's
   permission then.
   README: screenshots; an honest "how I worked" paragraph (architecture and business
   rules are the owner's decisions, Claude Code writes the code under supervision, the
   owner reviews and approves every change); a note that iOS could not be tested on
   Windows.

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
- App Check (checked against the official documentation in step 2.9):
  - Done in step 2.9a: the package firebase_app_check; activation in lib/main.dart only
    for debug builds on Android, with the debug provider. I register the debug token
    of each development device by hand in the Firebase console (Security > App Check >
    Apps > the Android app > Manage debug tokens). The token is a secret: never in a
    file, never committed, never in a build argument that ends up in the repo.
  - Not enforced. App Check itself is free on the Spark plan.
  - Web: nothing yet. reCAPTCHA needs the domain of the site, and the site has no
    public address (Hosting is undecided). Firebase recommends reCAPTCHA Enterprise
    for new integrations: 10,000 assessments per month at no cost; on Spark only four
    score levels can be chosen. Not settled from the documentation: whether creating
    the key needs a billing account in Google Cloud, and what happens above 10,000
    without billing. Never add localhost to a production key.
  - Android release: the app will NOT be published on Google Play (portfolio project),
    so Play Integrity is not planned. A sideloaded APK then cannot get a real App
    Check token. The debug provider must never be shipped in a build for users.
  - iOS: no App Check setup (it cannot be set up or tested on Windows); note it in the
    README.
  - LOCK-OUT RISK: enforcing App Check for Firestore while Android users have a
    sideloaded APK would lock that app out completely (no catalog, no booking).
  - OPEN for step 2.9b (Phase 7, with the public-demo decision), not decided:
    (a) no enforcement at all, the rules stay the only protection;
    (b) enforcement only if the public demo is a hosted web build with reCAPTCHA (and
        no Android build is handed out, or the Android app is accepted as locked out);
    (c) another option from the documentation at that time, for example a custom
        App Check provider with our own server (needs Cloud Functions and Blaze).
  - Rollout when it is enforced: watch the request metrics first (verified, outdated
    client, unknown origin, invalid); press Enforce for Cloud Firestore only after a
    booking was made from the real release build; it can take up to 15 minutes to
    take effect; check the catalog and one booking at once.
  - Undo: Firebase console > Security > App Check > Cloud Firestore > Set up >
    "Unenforced (monitoring only)". No code change or deploy is needed. The
    documentation gives no time for this direction; expect up to 15 minutes too.
  - My anonymous REST checks against the live database (steps 2.3 and 2.6) stop
    working once Firestore is enforced; that is the intended effect.
  - The admin panel runs on web too. An enforced Firestore would need an App Check
    provider for the admin web build as well; add this to the 2.9b decision.
  - Learned in steps 2.9a and 2.10: the debug token is created per app install. After
    a reinstall (for example after flutter run --release, or an uninstall) a NEW token
    appears in Logcat (filter DebugAppCheckProvider) and must be registered in the
    Firebase console > App Check > Apps > Manage debug tokens; the old token can be
    deleted. After registering, the app must be stopped and started again (flutter
    run), because the token exchange happens at start; hot reload is not enough.
  - In the console, requests with no token (release build, web) show up as
    "Unverified: outdated client", and requests with an unregistered token as
    "Unverified: invalid". Nothing is enforced.
  - Never commit or share a debug token. Delete all debug tokens in the console when
    the project is finished.
- Analytics consent: Section 9 describes a web consent banner; decide in Phase 7 how
  consent works on Android (proposal: the same consent screen on all platforms, the
  choice stored with shared_preferences, Analytics off until accepted).
- Privacy Policy and the booking form: the form has no consent line yet (decided in
  step 2.7). When the Privacy Policy page exists, link it from the booking form, next
  to the Send button, and decide then whether a consent line is needed.
- Public demo: decide in Phase 7 whether it is a hosted web build, an APK, or both.
- Web URLs keep the # for now; decide clean URLs and the Firebase Hosting rewrite rule
  when we set up Hosting.
- Georgian font: not bundled. Checked in Phase 2 on the emulator with the full
  booking flow in Georgian: it looks fine.
- Offline behaviour (I checked it in step 2.10, after fully closing and reopening the
  app in airplane mode): the catalog shows the same cars as online, taken from the
  Firestore cache; the car photos are replaced by a grey placeholder with a car icon;
  sending a booking shows the "check your internet connection" error and nothing is
  sent.
- Russian and Georgian texts: I have not yet read the ru and ka texts of the booking
  form and the thank-you summary (65 keys). Check them before Phase 7.
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
  arrow, with the same toolbar height (decided in step 2.4); the booking form and the
  thank-you screen do the same (step 2.7). Decide again for each new screen.
- lib/firebase_options.dart has one import split over two lines. The file is
  generated, so leave it alone.
- The import cycle between app_router and the screens is accepted: the router imports
  the screens, and the screens import the router for the route names. It is the one
  exception to "lib/core does not import lib/features".
- Admin data on the device (accepted in Phase 3 for now): on Android, Firestore keeps
  a local copy of the bookings an admin has read, also after sign-out. They contain
  personal data. Revisit at the end of Phase 3.
- When Phase 7 adds expireAt (TTL), the admin update rule must also allow an
  unchanged expireAt, because an update is checked on the merged document.
- createdBy is not tied to who created a booking: the rules let an admin add or
  change it on any booking. A known simplification.
- Web sign-in, not verified: the app asks Firebase to keep the admin sign-in for the
  browser session only, but that closing the browser really signs out was NOT verified
  on a normal Chrome profile. "flutter run -d chrome" opens a fresh temporary profile
  each time, so being signed out after reopening proves nothing. Check it on the
  hosted web build (Phase 7), or with a normal Chrome and a local web server.
- An unknown address under /admin shows go_router's raw "Page Not Found" screen. A
  proper admin "not found" page comes in step 3.6.
- App Check state after step 3.5: Monitoring only, for Authentication and for
  Firestore (Authentication about 44% verified requests, Firestore about 68%; web
  requests carry no token). Enforcement, if ever, is the Phase 7 decision 2.9b, and
  then the admin web build needs a provider too. Never press Enforce before that.
- Notes after step 3.6:
  - The cache question stays open for step 3.12: on Android the bookings an admin has
    read remain in Firestore's local copy.
  - Sign out closes the bookings listener first (stop()), then signs out. A session
    that ends by itself is handled at the next frame; an error that arrives in
    between is ignored and never shown.
  - A booking document without createdAt is not listed and not counted as unreadable,
    because the query orders by createdAt.
- Client-side filtering (accepted in step 3.7): the status counts, the search and the
  order of the admin list cover only the loaded bookings, at first the newest 50.
  With more than 50 bookings a count such as "New 2" means "2 among the loaded" until
  "Load more" is pressed; the screen says so in one line. If the business regularly
  has more than 50 open bookings, move the filter into the Firestore query (this
  needs composite indexes and an index deploy). Mention this limit in the README
  (Phase 7).
- "Last changed" is not stored (accepted in step 3.8): a status change writes only
  "status". Fields such as updatedAt or updatedBy would be refused by the Firestore
  rules, whose key list for a booking is fixed. Adding them needs a change of
  firestore.rules (and of the emulator script) and a separate, approved deploy.
- A direct link to a booking starts the list too (accepted in step 3.8): on web,
  opening #/admin/bookings/<id> builds the list underneath, so its listener reads up
  to 50 bookings in addition to the 2 reads of the detail.
- A second admin account, if ever needed: add the user in the console, then give it
  the claim with the same script ("set <UID>"), with a new key that is created and
  deleted in one sitting (Section 8). Sign-up is switched off, so no other account can
  be created from an app.
- Known limits after Phase 2:
  - CLOSED in step 3.3: the deployed rules text was compared directly. The live text
    equals firestore.rules at commit 0a7eb27 (line endings and trailing spaces
    ignored).
  - The rules do not check the stored total against the car and extras prices (only 0
    to 1,000,000 USD).
  - Location ids are checked only by their shape, not against settings.
  - Spam from a real client is possible: App Check is not enforced, and there is no
    provider for an Android release build.
  - A timeout can in rare cases be followed by the first request still arriving, so a
    retry can create a duplicate booking.
  - The draft of the booking form lives in memory, including personal data, until it
    is sent or the app is closed.
  - Release builds were only smoke tested.
  - iOS is untested (Windows only).
  - The date and time pickers were not looked at on a 320 px wide screen.
  - The booking form has no consent line and no Privacy Policy link yet (Phase 7).
  - The chosen language is not remembered between app starts.
  - The Android build prints a Kotlin plugin warning (see the firebase_core reminder
    above).

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
  2.7b the screens and the routes — DONE (both parts). I verified the first real
  create and the offline behaviour on the emulator: the booking document was correct,
  and an offline send fails with the "Could not send..." text in about 20 seconds and
  nothing is queued.
- 2.8 Confirmation screen: the thank-you screen with the summary of the sent request
  — DONE. I checked the screen on the emulator after a real send, in English and
  Georgian.
- 2.9 App Check, in two parts:
  - 2.9a The package, activation with the debug provider in Android debug builds, the
    debug token registered by me; monitoring only, no enforcement — DONE. I registered
    the debug token and verified in the console that Cloud Firestore requests from the
    emulator are "verified", in monitoring mode.
  - 2.9b Release providers and the enforcement decision — moved to Phase 7 (see Open
    reminders).
- 2.10 Verify Phase 2 on the Android emulator — DONE.
  - Automatic checks A1 to A8 all passed: analyze, 457 tests, the Firestore rules
    script (104 of 104), a debug APK build, a web build, a secrets scan of the 203
    tracked files, a line-length scan, and the rules file identical to HEAD.
  - I checked by hand: a debug run on the emulator (catalog, search, filters, car
    page, booking form, thank-you screen, language switch); a release build smoke
    test on the emulator; the web build in Chrome (a wide window shows 3 columns; an
    unknown car address shows "This car is not available" with a way back); the
    offline behaviour; real booking sends (I deleted the test bookings in the console
    afterwards); the App Check debug token registered in the console and the
    "Verified requests" count growing again (monitoring only, nothing is enforced).

Phase 2 is complete.

## 18. Phase 3 status

Phase 3: admin sign-in and the bookings list with editing (Section 11).

- 3.1 Admin rules in the local file, and admin and signed-in cases in the emulator
  script. No app change, no deploy — DONE. The emulator run passed: 104 of 104
  public checks and 173 of 173 admin and signed-in checks. The rules are not deployed
  yet (step 3.3).
- 3.2 Auth set up in the console by me, the claim script, and one run of it; the key
  deleted afterwards — DONE. Results:
  - Email/Password sign-in is enabled; one admin account exists. Its e-mail and UID
    are not written in this repository.
  - "Enable create (sign-up)" is OFF and "Email enumeration protection" is ON
    (Authentication > Settings > User actions).
  - The script ran: "Claims: (none)" before, {"admin":true} after "set", and a fresh
    "show" read the same from the server. Its first real run worked at once.
  - The service account key was deleted in the Google Cloud console (the key list is
    empty) and the JSON file was deleted from the computer.
- 3.3 Rules deployed with my approval, a short live check, and (if it is simple) the
  deployed rules text compared with the file — DONE. Results:
  - Deployed with "firebase deploy --only firestore:rules --project
    tbilisi-car-rental" on 2026-10-09 at 13:34 UTC: the file compiled and only the
    rules were released; no error and no warning.
  - Six anonymous read-only checks one minute later, all as expected: active cars with
    the filter 200 (6 cars), all cars without the filter 403, settings/extras and
    settings/locations 200, bookings get and list 403.
  - I sent one real test booking from the app on the emulator; it was accepted (the
    thank-you screen with the summary), and I deleted it in the console.
  - I copied the live rules text from the console into a file outside the repository;
    it equals firestore.rules at commit 0a7eb27 (8808 characters, 207 lines).
  - Skipped: the live check of a hidden car (its id was not known). No refused-write
    attempts were sent to the live database.
  - The admin side is first checked live in steps 3.5 and 3.6.
- 3.4 Package firebase_auth, the auth repository and its providers, with unit tests;
  no screen yet — DONE. 522 tests pass, analyze is clean, and the debug APK builds
  with the new package. The repository was not run against real Firebase; its first
  real run is step 3.5.
- 3.5 /admin/login, the redirect, the "no admin access" state, Sign out — DONE.
  Results:
  - 565 tests pass and analyze is clean.
  - I verified the first real sign-in by eye, on the Android emulator and in Chrome.
    The admin claim reaches the app: after sign-in the admin page opens.
  - The sign-in survives a restart of the app on Android (no login page flashes) and
    a reload of the page on web.
  - Not verified: that closing the browser signs the admin out (see Open reminders).
- 3.6 Bookings list, read only — DONE. Results:
  - 643 tests pass and analyze is clean.
  - I verified the first real admin read by eye, on the Android emulator and in
    Chrome: the bookings and all cars are read with the deployed rules; the rows
    (Tbilisi times, days, totals, status chip, "estimate", the "(hidden)" car), the
    live update from a second device, the offline note, Sign out without a flash,
    and the admin "not found" page are as planned.
  - Firestore usage over 24 hours, tests included: about 363 reads, 3 writes and 3
    deletes (the Spark limit is 50,000 reads a day).
- 3.7 Filter by status, search, and sort (also by pickup date) — DONE. Results:
  - 705 tests pass and analyze is clean.
  - I verified by eye, on the Android emulator and in Chrome: the chips and their
    counts (also when a status is changed in the console), the status filter, the
    search by name and phone, the three orders, the choice kept while signed in and
    reset after Sign out, and the five chips fitting side by side in a wide window.
  - The filter, the counts and the order cover only the loaded bookings (see Open
    reminders).
- 3.8 Booking detail and status change — DONE.
  - 821 tests pass and analyze is clean. The rules emulator script still passes
    (104 public, 173 admin and signed-in); the rules were not changed.
  - I verified by eye, on the Android emulator and in Chrome: the detail shows every
    field and matches the console; a status change shows "Saving…", then "Saved",
    and the console document has only the status field changed; the confirmation
    asks for "to Cancelled" and "away from Confirmed" ("Keep" changes nothing);
    offline the page shows "Offline: showing saved data" and a change ends with
    "Not saved. No connection."; nothing was queued after the connection came back;
    a booking deleted in the console while it was open showed "This booking does
    not exist. It may have been deleted."; in Chrome a reload on the detail
    address, a made-up id and /#/admin/bookings without an id behave as planned;
    the live update between the emulator and Chrome works.
  - This was the first real transaction against the deployed rules, and it worked.
  - Not seen on a device: the text "No answer from the server. The status shown is
    the current one." It is covered by the tests only.
- 3.9 Edit all fields; the recomputed total next to the stored one — 3.9a done,
  3.9b not started.
  - 3.9a (logic, repository and notifier; no screen, no route): 1031 tests pass and
    analyze is clean. The rules emulator script passes (104 public, 209 admin and
    signed-in); the rules were not changed. The status change of step 3.8 now names
    an unknown field and a missing createdAt.
  - Not yet run against the real database: updateBooking. It is first used by the
    screen of 3.9b and verified by eye there.
  - 3.9b (the edit screen, its route, the Edit button, the manual checks) — not
    started.
- 3.10 Create a booking by hand (status confirmed, createdBy) — not started.
- 3.11 Delete a booking, with a confirmation — not started.
- 3.12 Verify Phase 3 and close it — not started.
