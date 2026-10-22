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

Phase 6 decisions (made before step 6.1; the steps are in Section 21):
- Address: /about. Since Phase 6b (Section 22) it is the About/Contact tab of
  the public bottom navigation (step 6b.8); the info icon planned in step 6.1
  is dropped. One screen: a static about text, the company data and tappable
  contacts.
- The page reads settings/company live, like the other settings documents (its
  fields are in Section 4), with the mechanism of the admin forms: an answer
  from memory that holds the document is shown; when memory has nothing, the
  spinner, and after 3 seconds (serverAnswerWait) the error text with "Try
  again". Never the empty state without the answer of the server.
- A settings/company that the SERVER says does not exist, or one with no field
  set, shows the friendly empty state. This is the one exception to "a missing
  settings document is an error" (Section 4).
- Only the fields that are set are shown. The address and the working hours are
  shown in the current language; the name, phone, e-mail and links as stored.
- The contacts are tappable with url_launcher (step 6b.8; the package needs
  its own approval). Only addresses the app builds itself are opened: tel: from
  the stored phone, mailto: from the stored e-mail, and the stored https links
  after the app has checked that they start with https://. Nothing else. A
  failed launch shows a short message and never crashes.
- The static texts of the page (title, about text, labels, empty state, error)
  are in the ARB files (ka, ru, en). Since Phase 6b the owner supplies them in
  all three languages; Claude Code neither writes nor translates them (Section
  22).

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
    and signed-in checks (210 since step 3.9b).
  - Known limits of 3.9a:
    - A customer map or a place map with an extra key written by hand is reported
      as a conflict of that part, not as an unknown field. The rules refuse such a
      document anyway.
    - A booking that is deleted while it is being edited replaces the form with
      "does not exist"; the values the admin typed are lost.
    - (Closed in step 3.9b: the status change of step 3.8 now has the check for a
      stored value in another format too, see the next point and step 3.9b.)
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
- Decisions of step 3.12b (no data left on the device; honest screens without a
  connection):
  - Android and iOS: Firestore keeps no copy of the data on disk any more
    (lib/core/data/firestore_start_up.dart, called once in main before the app
    starts). Reason: the admin reads names, phone numbers and e-mail addresses, and
    they stayed in a file on the device after the app was closed and after Sign out.
    Web is not touched: a browser kept nothing.
  - The copy an earlier version left behind is removed at the start. Order: first the
    setting, then the removal; the other way round the removal would create Firestore
    with a disk copy. If the removal fails or takes longer than 5 seconds, the app
    starts anyway and only the type of the error is logged. Checked on the emulator
    (names and sizes of the files only): the file was gone after the first start
    after the update, and no new one appeared while the app was used and closed.
  - One rule for every read (lib/core/data/server_answer.dart, pure Dart): an answer
    that holds nothing AND did not come from the server says nothing. It is not "no
    cars", not "no bookings" and not "the document does not exist". Only the server
    can say that. Reason: without a disk copy, every first answer without a
    connection looks exactly like that.
  - Such an answer is waited out for 3 seconds (one constant, also used for the
    admin "Offline" note). Then the screen shows its connection or load error with
    "Try again". The listener stays open, so the data appears by itself when the
    server answers.
  - Where it applies: the catalog, one car, settings/extras and settings/locations
    (so also the booking form and the admin forms), the admin bookings list, and the
    two one-time reads of cars in the admin area. The admin detail and edit pages
    had the rule since step 3.8 and now use the same function. Writes were never
    affected: they are transactions that ask the server.
  - A document the SERVER says does not exist keeps its old meaning: "This car is
    not available", a FormatException for a missing settings document, "This booking
    does not exist."
  - New admin text: "No connection. The bookings could not be loaded." No public
    text was added: the existing error texts are used. ARB files are unchanged.
  - Public error screens (catalog, car, booking form) show only the translated text
    and "Try again". The technical line under it is gone; it was shown in debug
    builds only, never in a release build. The type of the error is logged for the
    developer, never its text.
  - Data that is in memory is shown also without a connection, with the "Offline"
    note in the admin area.
  - Checked by hand: on the Android emulator a start without a connection (catalog,
    booking form, admin list), the recovery by itself, "Try again", and the
    "Offline" note in a running session. In Chrome only a running session (the open
    admin list with the network set to Offline). A start without a connection on
    the web was not checked by hand; tests cover it.
  - Known limits:
    - The admin detail and edit pages give up after the same 3 seconds, but they stop
      listening then: they need "Try again" and do not recover by themselves.
    - "Load more" without a connection: the loaded list stays and the button comes
      back after 3 seconds; there is no message. Tested with a fake repository only.
    - Memory holds only what a screen is showing. Leaving a screen and coming back
      without a connection shows the load error, not the earlier data.
    - Car photos without a connection were not checked again in this step.
    - iOS cannot be tested on Windows.
    - The admin area is web-first; Android admin is secondary.
    - The first start after the update clears the old copy: the file is dropped,
      not shredded.
    - The 3 seconds are a guess for a slow connection: on a very slow one the error
      can show for a moment before the data arrives by itself.
  - Rules, ARB files, packages and indexes are unchanged.
- Decisions of step 3.12a (the secrets scan, tool/check_secrets.mjs):
  - A plain Node script without packages. It only reads: it never changes a file
    and never contacts a network. It is run before every commit:
    "node tool/check_secrets.mjs" checks every tracked file and every new file
    that is not ignored; with "--staged" it checks only what is staged, read as it
    is staged (not the working copy).
  - Errors (the script ends with exit code 1): a private key block; the marks of a
    service account key file; a Google API key outside the two allowed Firebase
    configuration files; a password, token or secret written as a value; a file
    that must not be in the repository at all (.env, key.properties, a keystore, a
    service account key file); an e-mail address that is not on the allow list;
    something shaped like an App Check debug token; a text of the local deny list.
  - Allowed e-mail addresses: only addresses that can never be real. These are the
    domains reserved for examples, example.com, example.net and example.org with
    their sub-domains, and every domain whose last label is "example", "invalid",
    "test" or "localhost" (RFC 2606 and RFC 6761); plus two exact addresses, the
    "no e-mail" placeholder and the address of the commit trailer. The whole
    domain is checked from its end, so "example.com.evil.org" or "notexample.org"
    is not allowed. Test data therefore uses these domains only.
  - The API key exemption is narrow: in lib/firebase_options.dart and
    android/app/google-services.json only a value that is the API key itself is
    let through. Any other password-like value in these two files is an error.
  - The local deny list, tool/private_denylist.txt, is optional. It is for the
    texts that must never appear in the repository: the admin's UID and e-mail
    address and any real name, phone number or address. The owner fills it by hand
    on this machine; nobody pastes its content anywhere, and the script never
    prints it. Each line is an exact text (empty lines and lines starting with #
    are skipped), compared without regard to the case of letters; a hit is the
    error "denylist-match". A line of fewer than 4 characters is not used and is
    reported as a warning with its line number only. The file is listed in
    .gitignore; if git does not ignore it, or tracks it, that is the error
    "denylist-not-ignored" and the list is not used. The list itself is never
    scanned.
  - Warnings (exit code 0): a phone number that is not a made-up 555 number, and a
    quoted text shaped like a Firestore document ID or an account UID. They are
    warnings only because they have too many false alarms: validation tests need
    other made-up numbers, and many harmless texts have 20 or 28 characters. They
    are still printed and must be looked at.
  - The first run found four sample phone numbers of the search tests of step 3.7
    that had the shape of real mobile numbers. They were replaced by made-up 555
    numbers. The six phone warnings that remain are the intentionally invalid
    values of validation tests (a leading zero, too many digits, the upper limit).
  - A found value is never printed, not even in part: the output has the file, the
    line, the name of the rule and the length of the value.
  - Not looked into: build folders, node_modules, lock files, the generated
    localisation files and binary files. A forbidden file NAME is reported also
    there.
  - Its tests (tool/check_secrets.test.mjs, run with "node --test") build every
    sample at run time, so neither file holds anything the scan reports.
  - Known limits:
    - It reads files, not the git history: a secret that was committed once and
      removed later is not found.
    - A password that is not in quotes (password=abc in an ordinary file) is not
      caught. A .env file is caught by its name.
    - A value that starts with "made-up", "fake", "example", "test", "dummy" or
      "placeholder" is not reported as a password.
    - Every UUID counts as a possible App Check debug token, so a legitimate UUID
      would stop the scan until it is looked at.
    - It knows a fixed list of shapes and cannot find every secret; it does not
      replace reading a change before it is committed.
- Decisions of step 3.11 (deleting a booking):
  - The action is only on the detail, at the very end of the page under the
    booking ID: a red text button "Delete this booking" in a white card. It is not
    in the app bar, where a slip of the finger is easy. It is shown for a booking
    that is found, in every status.
  - The question "Delete this booking?" says which booking it is (the customer's
    name, the car, the pickup in Tbilisi time, the status), then "This cannot be
    undone. To keep the booking but mark it as not taking place, set its status to
    Cancelled instead." For a confirmed booking there is one more line: "This
    booking is confirmed. The customer expects the car." The buttons are "Keep" and
    a red "Delete".
  - Only a tap on "Delete" deletes. "Keep", a tap beside the question and Back all
    close it without deleting.
  - The rules: "delete: if isAdmin()". An admin may delete any booking; the stored
    document is not checked (unlike on an update), so a hand-made document with an
    unknown field, a phone in another format or no createdAt can be deleted too.
    Everybody else is refused. No rules change was needed.
  - The delete is a transaction with one attempt and a 20 second limit; nothing is
    queued while offline. It reads the booking first. No booking: nothing is
    written, "already deleted". The status is no longer the one the admin saw in
    the question: nothing is deleted. Otherwise the document is deleted.
  - Only a changed status stops a delete (somebody confirming or cancelling the
    booking changes what a delete means); changed notes or dates do not. The status
    is compared twice: with the booking on screen when "Delete" is tapped, and
    with the stored document inside the transaction.
  - While it runs the page says "Deleting…"; the delete button, the status buttons
    and the pencil are disabled, and a second call does nothing.
  - After the booking is gone the app returns to the list, which says once
    "Booking deleted." (or "This booking was already deleted."). The list updates
    by itself. A detail or an edit form open on another device shows "This booking
    does not exist. It may have been deleted."
  - The live read can be faster than the transaction. While a delete started on
    this device runs, a "missing" from the live read is the expected outcome: the
    page does not turn into "does not exist", it waits for the transaction. If the
    transaction then reports no answer or a failure although the live read said
    "missing", the booking is gone all the same: the list says "Booking deleted."
  - Not deleted, the booking stays on screen: "Not deleted. No connection.", "Not
    deleted. The change was refused.", "Not deleted. The status of this booking was
    changed elsewhere. Look at it again.", "Not deleted. Please try again." After
    no answer in time: "No answer from the server. If the booking is still shown
    here, it was not deleted."; when it was deleted after all, the page says "does
    not exist" by itself.
  - The notice on the list is a one-time marker like the "Saved" marker of step
    3.10b: in memory only, without any data of the booking, not set when nobody is
    signed in as an admin. It goes when it is closed, when the list is left, when
    another booking or the "new booking" form is opened, and when the session
    ends.
  - Nothing is logged except the type of an unexpected error. Rules, ARB files,
    packages and indexes are unchanged. The rules emulator script got the delete
    cases: 244 admin and signed-in checks now.
  - Known limits of 3.11:
    - A delete cannot be undone, and there is no archive. The placement of the
      button and the question are the only guard.
    - A booking that cannot be read ("This booking cannot be read.") has no delete
      button; remove such a document in the Firebase console.
    - The "no answer from the server" path cannot be forced by hand; it is covered
      by tests only.
  - Checked by hand by the owner on the Android emulator and in Chrome, with two
    throw-away bookings (made-up names only, no real data); every item of the
    checklist passed. The "no answer" path is covered by tests only.
- Decisions of step 3.10b (the "new booking" screen):
  - The form is at /admin/bookings/new, below the list; Back returns to the list.
    A floating button "New booking" (white, purple text) is always on the list
    page, also for an empty list. The list leaves room below its last row, so the
    button never covers the last booking or "Load more".
  - "new" would also pass as a booking ID. The route of the form therefore comes
    BEFORE the route of the detail (routes are tried in order), and the detail and
    the edit route show the admin "not found" page for the ID "new"
    (/admin/bookings/new/edit).
  - The five field cards (customer, car, dates and places, extras, notes) of the
    edit form moved, unchanged, into one shared widget that both forms use; the
    text controllers live there. The edit form kept its banner, its price card and
    its Save. All tests of step 3.9b passed without a change after the move.
  - The form: a status card (a list with the four statuses, Confirmed chosen), the
    field cards (empty, the language English), the total, Save.
  - "The customer has no e-mail" is a switch under the e-mail field. On: the field
    is greyed out, keeps what was typed and shows no error; the placeholder is
    stored. Off: the field is back with its text.
  - The total card shows the total line of step 3.10a and "The total uses today's
    prices."; or "Choose a car and the dates to see the total."; or "The total
    cannot be calculated: the prices could not be loaded." (Save is then disabled).
    It never shows the text the edit form has for a missing new total.
  - Cars not loaded: "The cars could not be loaded." with "Try again".
  - After "no answer from the server" every field is disabled, the message cannot
    be hidden, and Save is replaced by "Check again" ("Checking…" while it runs).
  - After the server confirmed the booking, the detail of the new booking opens
    and says "Saved". For this the form leaves a one-time marker (the ID, kept in
    memory only). The detail takes it only when it has really found the booking;
    "not known yet" and "missing" leave it. It is forgotten when the detail of
    that booking is left and whenever the session is not admin. The edit screen
    keeps its own, verified way to show "Saved".
  - A second "New booking" gives an empty form with a new document ID: the form's
    state lives only while its page is open.
  - Back (the arrow and the system Back): with something filled in, "Discard your
    changes?" with "Keep editing" and "Discard". While the booking may already
    exist, "Leave this form?" with "The booking may already exist. Check the
    bookings list." and "Stay" / "Leave". While a save or a check runs, Back does
    nothing. Browser Back is not intercepted (the verified limit of step 3.9b).
  - "No e-mail" is shown instead of the placeholder in the detail. The list never
    showed an e-mail, so it needed no change (a test checks that the placeholder
    does not appear there). The edit form shows the placeholder as it is: it has
    no "no e-mail" switch yet. To give such a customer an e-mail, replace the
    placeholder in the edit form.
  - Name, phone, e-mail, address and notes: autocorrect off, suggestions off, no
    autofill hints, as in the edit form (it is the same widget).
  - Extra cost of a direct link: opening #/admin/bookings/new on web builds the
    list underneath (up to 50 bookings and all cars); the form reads all cars and
    the two settings documents.
  - Known limits of 3.10b:
    - The "no answer" path (the locked form, "Check again", the stronger words on
      Back) cannot be forced by hand; it is covered by tests only.
    - A session that ends while the form is open closes it; the typed values are
      lost.
    - Deleting a booking in the app comes in step 3.11; until then a test booking
      is deleted in the Firebase console.
  - Checked by hand by the owner on the Android emulator and in Chrome; the
    checklist passed:
    - The first real createBooking ran against the deployed rules. A booking with
      every field: 13 fields, createdBy "admin", createdAt from the server, status
      Confirmed, the stored total equal to the total shown, the dates equal to the
      Tbilisi time shown.
    - A booking with "no e-mail": the placeholder is stored, the detail shows "No
      e-mail". A pickup in the past and a hidden car save.
    - Airplane mode: "Not saved. No connection.", and no document appeared later.
    - Back asks; a fast double tap on Save made one document; a second "New
      booking" gives an empty form.
    - Chrome: /#/admin/bookings/new opens the form directly and after F5;
      /new/edit shows the admin "not found" page; a booking created in Chrome
      appeared on the emulator by itself.
    - The edit screen passed its short re-check after the refactor.
    - The "changed elsewhere" banner of the edit form shows only when a part that
      is being written was changed elsewhere. A date edit on one device and a
      notes change on the other is no conflict, and the other device's notes are
      kept. This is by design and was verified. (Step 35 of the checklist was
      worded wrongly: it needs the SAME field on both devices.)
    - The "no answer" path stays covered by tests only.
    - The Firebase console shows timestamps in the time zone of the browser
      (UTC+4 here), not in UTC.
    - The "Create Test" bookings were deleted in the console; the original three
      test bookings stay.
- Decisions of step 3.10a (creating a booking by hand: logic, mapping, repository
  and notifier; the screen, the route and the button come in 3.10b):
  - Fields: the customer (name, phone, WhatsApp, Telegram, e-mail), the language
    (English when the form opens), the car, pickup and drop-off time and place, the
    extras, the notes, and the status: all four can be chosen, Confirmed is
    preselected. No car and no dates are preselected.
  - createdBy is the fixed word "admin", in one named constant. There is one shared
    admin account, so the address of the account adds no information and must not
    end up in the data. No address and no UID is read or written for it.
  - A customer without e-mail: the rules require an e-mail, so the form has the
    switch "The customer has no e-mail", which stores the placeholder
    none@no-email.invalid (one named constant). The ending ".invalid" is reserved;
    such an address can never receive mail. Checked on the emulator: the rules
    accept it. Screens show "No e-mail" instead (3.10b). ANYTHING THAT SENDS MAIL
    (the last phase) MUST SKIP THIS ADDRESS.
  - Validation is the one of the edit form without a stored booking: a fixed place
    must be in settings, and nothing is "stored in another format". A pickup in the
    past and a hidden car are allowed. With the switch on, the e-mail field is not
    checked.
  - The total is always calculated from today's prices: days x (the car's price
    per day + the extras per day). There is no typed amount. The form shows "Total:
    5 days × ($45 car + $5 extras) = $250" (with "estimate" above 7 days) and "The
    total uses today's prices."; before a car and the dates are chosen "Choose a
    car and the dates to see the total."; when the prices cannot be loaded "The
    total cannot be calculated: the prices could not be loaded.", and then nothing
    can be saved (a new booking has no stored total to fall back on). A total above
    1,000,000 is an error.
  - No duplicates. The ID of the document is made once, when the form opens
    (Firestore makes it on the device, without a request), and every attempt of
    that form uses it. The save is a transaction with one attempt and a 20 second
    limit; nothing is queued. It reads the document first: when it exists, nothing
    is written and the booking counts as saved; otherwise it reads the car (it must
    exist) and creates the document with the server time as createdAt.
  - "No answer from the server" means the booking MAY exist. The form is then
    locked (the stored values could otherwise differ from the shown ones), the
    message is "No answer from the server. Press "Check again": the booking will
    not be created twice.", and only "Check again" is offered. It runs the same
    transaction with the same ID and the same booking. When that gives no certain
    answer either, the message is "Still no answer from the server. ..." and the
    form stays locked. Only "the car no longer exists" opens the form again: then
    the transaction has looked and the booking does not exist.
  - The notifier tells the screen "the booking may already exist"
    (mayAlreadyExist), for the warning on Back in 3.10b.
  - The other failures: "Not saved. No connection.", "Not saved. The booking was
    refused.", "Not saved. This car no longer exists. Choose another car.", "Not
    saved. Please try again."
  - The save has the two stages of the edit: a check (the fields and the total),
    then the write; the place for the conflict warning of Phase 5 is there and
    empty. A second call while one runs does nothing.
  - "new" would pass as a booking ID (/admin/bookings/new is the address of the
    form), so the repository refuses to create a booking with that ID.
  - validateAdminBooking takes the stored booking as an optional value now; the
    tests of step 3.9 pass unchanged.
  - The rules emulator script got the document the form creates, with a chosen ID
    (accepted and refused), and "a second create with the same ID changes nothing":
    233 admin and signed-in checks now. The keys of the created document, the word
    "admin" and the placeholder are tied to firestore.rules by tests.
  - Nothing is logged except the type of an unexpected error. Rules, ARB files,
    packages and indexes are unchanged.
  - Not yet run against the real database: createBooking. It is first used by the
    screen of 3.10b and verified by eye there.
- Decisions of step 3.9b (the edit screen):
  - The form is at /admin/bookings/<id>/edit, below the detail. The detail has an
    "Edit" icon in its app bar (tooltip "Edit"), only for a booking that is shown,
    in every status. Back returns to the detail.
  - After the server confirmed a save the screen returns to the detail, which says
    "Saved" with the notice it already has for a status change (the edit screen
    asks the detail's notifier to show it). There is no second mechanism.
  - The form has its own small admin widgets and English texts (admin_texts.dart).
    The widgets of the public form are not reused: their labels come from the
    translations. Reused are only pure functions and the public date and time
    picker function.
  - Cards: customer (name, phone, WhatsApp, Telegram, e-mail, language), car, dates
    and places, extras with today's prices, notes, total. A hidden car is marked
    "(hidden)". A car that was deleted is shown as "<id> (not found)". A stored
    place that settings no longer has stays in the list as "<id> (not in the list
    any more)". A pickup in the past only gets the note "The pickup is in the
    past."
  - The price card: "Stored total: 5 days · $225"; when the car, a date or the
    extras changed, also "New total: 7 days × ($45 car + $6.50 extras) = $360.50"
    with "The new total uses today's prices."; then the two choices "Keep the
    stored total ($225)" and "Use the new total ($360.50)", none selected. When the
    prices cannot be loaded only "Keep" is offered, with the reason.
  - Save is disabled while nothing changed, while a save runs, and while a needed
    choice of the total is missing. Other errors do not disable it: pressing Save
    shows them under their fields, with "Correct the marked fields." above the
    button, and scrolls to the first card that has one. A stored value in a format
    the rules refuse is shown at once, before any Save.
  - The draft in the notifier is the single source of truth. The text controllers
    are made from it once. Whenever the notifier itself replaces the fields ("Load
    the current booking", a change elsewhere while the form has no changes) the
    form is built anew: new controllers from the draft, the old ones disposed.
  - Changed elsewhere, before saving: a banner "This booking was changed elsewhere
    (car). Saving will be refused." After a refused save: "This booking was changed
    elsewhere (car, pickup time). Your changes were not saved." Both offer "Keep
    editing" and "Load the current booking" (which drops the edits without a
    second question).
  - Leaving: Back (the arrow of the app bar and the system Back) with unsaved
    changes asks "Discard your changes?" with "Keep editing" and "Discard". While a
    save runs, Back does nothing.
  - Name, phone, e-mail, address and notes: autocorrect off, suggestions off, no
    autofill hints.
  - The date pickers offer 5 calendar years back and 2 ahead (1 January to 31
    December). The public picker function already takes the range as parameters,
    so the public file was not changed at all.
  - The status change of step 3.8 got the stored-format check too: a phone, a name,
    an e-mail or a place text written by hand in a form the rules refuse is named
    in one sentence ("Not saved. The phone number is stored in a format the app
    does not accept. Edit it to correct it.") instead of a bare refusal.
  - Extra cost of a direct link: opening #/admin/bookings/<id>/edit on web builds
    the list and the detail underneath. Reads: up to 50 bookings and all cars for
    the list, 2 for the detail, and for the form the booking once more, all cars
    once more and the two settings documents. Accepted, as for the detail.
  - Known limits of 3.9b:
    - The picker dialogs (calendar and clock) are in the language of the app, not
      always English, although the admin area is English only. Accepted.
    - Verified in Chrome: the browser's Back button leaves the edit screen WITHOUT
      the discard question. The browser changes the address itself and Flutter's
      PopScope is not consulted. The same goes for a typed address and for closing
      the tab. Only the arrow of the app bar and the system Back of Android ask.
      No dart:html code was added for this.
    - A session that ends while the form is open closes it; the typed values are
      lost.
  - Checked by hand by the owner on the Android emulator and in Chrome; all 42
    steps of the checklist passed:
    - The first real updateBooking transactions ran against the deployed rules:
      customer and notes; dates with "Keep the stored total" and with "Use the new
      total"; a pickup in the past; a hidden car.
    - Airplane mode: "Not saved. No connection.", and nothing was queued.
    - "Discard your changes?" on the arrow of the app bar and on the system Back.
    - The changed-elsewhere banner, and the refusal message after a save, each
      with both buttons; a total conflict that names the car.
    - The zzTest check: the status change and the edit both show the sentence
      about the unknown field.
    - The three test bookings were restored to their original values.

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
- Photos: in Phase 4 https addresses typed in the form (no upload; see the Phase 4
  decisions below). A real upload is a Phase 7 question (Section 15).
- Description fields for ka/ru/en.
- Fixed-category specs (transmission, fuel type, drivetrain) via dropdowns/selectors,
  not free text. Seats is the exact number.
- Price per day (USD), set individually per car.
- Every field must have clear helper text or a placeholder example, because the person
  filling it in is non-technical staff.
  In Phase 4 the car form has a label on every field, notes for the price, the
  photos and the visibility, and error texts with examples ("for example 2019");
  there is no helper text under every field yet (Phase 7 polish, if wanted).

Phase 4 decisions (made before step 4.1; the steps are in Section 19):
- Photos in Phase 4: an https address typed or pasted by the admin. `photos` stays a
  list of addresses. There is NO upload in Phase 4: Cloud Storage for Firebase cannot
  be used on the Spark plan at all (since 3 February 2026 a Spark project has no
  access to any bucket; read in the Firebase documentation on 13 Oct 2026). A real
  upload (Storage on the Blaze plan with a budget alert) is a Phase 7 question,
  together with Cloud Functions; Blaze is not decided yet.
- A car with no photo is allowed, also a visible one; the catalog shows its
  placeholder.
- Navigation of the admin area: a responsive shell, a bottom bar on phones and a side
  rail on wide screens, with go_router's shell route. Entries for now: Bookings and
  Cars; later phases add Calendar and Settings. It is its own step (4.4a), because it
  touches the admin redirect.
- Hiding a car that has confirmed bookings in the future is allowed without a
  warning in Phase 4. The form says: "A hidden car disappears from the public
  catalog. Existing bookings are not changed." A warning comes in Phase 5, with the
  conflict warning. Added in step 5.4: the "Hide this car?" dialog names the
  confirmed bookings ahead.
- Hiding and showing a car must ALWAYS work, also for a car that was entered by hand
  before these rules and would not pass them. The rules therefore accept an update
  that changes only "active" (to true or false) without checking the rest.
- The price of a car may change while bookings exist. Stored totals stay as they
  are; one line on the form says so.
- The description is required in all three languages (ka, ru, en) to save a car.
- A new car is saved hidden by default, with a switch on the form.
- engineSize is optional for every fuel type; the rules do not forbid it for an
  electric car (the catalog does not show it there).
- The price may have decimals in the rules; the form limits it to two places.
- No new fields: a car has no createdAt or updatedAt, so no field is immutable.
- Only the one admin account writes cars; nothing changes in Authentication.
- A car is never deleted, not by an admin either: "remove" is active == false.
- Field limits (the rules and lib/features/fleet/domain/car_limits.dart hold the same
  numbers; a unit test compares them):
  - brand, model: text, 1 to 40 characters, no space at either end.
  - year: a whole number, 1990 to "this year plus one" (the clock of the server).
  - drivetrain: fwd | rwd | awd. transmission: automatic | manual. fuelType: petrol |
    diesel | hybrid | electric.
  - seats: a whole number, 1 to 9.
  - engineSize: optional; a number above 0, up to 8 (litres).
  - pricePerDay: a number above 0, up to 2000 (USD). 2000 a day for the longest
    rental of 365 days stays under the limit of a booking's total (1,000,000).
  - description: a map with exactly ka, ru and en; each a text of 1 to 1000
    characters with no space or line break at either end (line breaks inside are
    fine).
  - photos: a list of 0 to 10 addresses, none twice. Each starts with https://, has
    no space, has a dot, and is at most 500 characters long.
  - active: true or false.
  - Any other field is refused. The ID of a new car: letters, digits, "_" and "-",
    1 to 128 characters.
- Decisions of step 4.1 (the cars rules; written in step 4.1, deployed in step
  4.2 from commit 4e5fb1d):
  - An admin may create and update a car; the whole document is checked on every
    write (isValidCar), except for the hide-or-show update above. Reading is
    unchanged: the public reads active cars, an admin reads every car.
  - Year and seats must be stored as whole numbers. The price and the engine size
    may be whole or decimal: the web sends 45.0 as a whole number and Android sends
    it as a decimal, and both must pass.
  - The rules have no loops, so the photo list is checked place by place, ten lines.
    Changing the maximum means changing those lines; the unit test counts them.
  - Old cars, entered by hand in the console before these rules. Reads are not
    affected. The six active cars were read once with the public query (read-only,
    13 Oct 2026): one passes the new rules; five would fail them, all five because
    they have no "description" field, and one of them also has no "photos" field.
    Hidden cars cannot be read that way; the owner looks at them in the console.
  - What that means for an old car: it can always be hidden and shown. Any other
    change is refused until the car is complete. The edit form of step 4.5 saves
    the whole car as a replacement, so filling in what is missing repairs it in one
    save (proved by an emulator case); an unknown field is dropped the same way.
  - Known limits: the rules cannot check that a photo address really leads to an
    image, nor that a price has at most two decimals; the form does the second.
    Nothing ties a description to its language.

### 3.4 Booking conflict warning

When a booking is saved with status `confirmed` (directly, or when an existing booking
is changed to `confirmed`, or when its car/dates change while confirmed), check for
conflicts with other `confirmed` bookings on the same car (Section 7). If found, show a
NON-blocking warning ("This car is already booked from X to Y. Continue anyway?"). The
save is never silently blocked.

Note for Phase 5 (decided before step 4.1): add a warning, also non-blocking, when an
admin hides a car that has confirmed bookings in the future. In Phase 4 hiding is
allowed without any warning. Done in step 5.4.

Phase 5 decisions (made before step 5.1; the steps are in Section 20):
- A conflict is exactly the rule of Section 7: the same car, the other booking
  confirmed, and newPickup < otherDropoff + 5 h AND newDropoff + 5 h >
  otherPickup, on UTC moments. A gap of exactly 5 hours is no conflict. The
  booking itself is never its own conflict.
- The check runs when a booking becomes confirmed (status change, edit, or a
  new booking saved as confirmed), and when a confirmed booking changes its
  car, pickup or dropoff. Not for changes of notes, customer, extras or total,
  and never for new, pending or cancelled bookings.
- A conflict only warns: a dialog with "Continue anyway" and "Cancel". Cancel
  keeps the form as it was. It never blocks and is never silent.
- The check reads from the server only, with a 10 second limit. When it
  cannot be done (no connection, timeout, error), the dialog says "Conflicts
  could not be checked" with the same two buttons; an empty answer from
  memory never counts as "no conflicts".
- Any failure inside a conflict check or hide check, including a thrown
  ArgumentError, a timeout or an unexpected error, counts as 'could not be
  checked' (never a crash, never a silent pass).
- While a check runs, the Save control shows "Checking…" and cannot be pressed
  twice: a double press sends one check and one write.
- The warning shows the dates and times (Tbilisi time) of at most 3
  conflicting bookings and "and N more"; no customer names.
- Hiding a car: the "Hide this car?" dialog also names the confirmed bookings
  whose dropoff is after now (a rental in progress counts). It does not block.
- Two admins confirming at the same moment can both pass the check (it runs
  before the write, not inside it). Accepted: it is a warning, and the
  calendar shows the result.
- A new booking for a hidden car stays allowed, marked "(hidden)", with no
  extra warning.
- The calendar reads only status == confirmed and cuts the visible window in
  Dart: no composite index and no index deploy. A range query with an index
  is the later option (a known limit in Section 15).
- The calendar shows 14 days from today in Tbilisi time, with "previous" and
  "next" by 7 days; a day starts at 00:00 Tbilisi time. Rows: the visible cars
  and any hidden car with a booking in the window (marked). Today is
  highlighted. On a narrow screen it scrolls sideways with a fixed column of
  car names. Navigation order: Bookings, Calendar, Cars.
- Step 5.2 adds one emulator case (an admin may list the confirmed bookings of
  one car, the public may not); it changes tool/check_booking_rules.mjs only,
  never firestore.rules.
- The repair of the cars that need it is done by the owner in parallel, not a
  gate for any step; ideally before step 5.5b.

### 3.5 Extras & Prices screen

Separate admin screen where admin edits the global per-day prices of the four extras.

Phase 6 decisions for 3.5 and 3.6 (made before step 6.1; the steps are in
Section 21):
- Admin navigation: a fourth entry, Settings (Bookings, Calendar, Cars,
  Settings). Its page links to Extras & Prices and to Company Info.
- Extras & Prices edits ONLY the four prices of settings/extras. The English
  names and age ranges of the extras are shown read-only (admin texts); no
  extra can be added or removed. The prices and ages are final decisions
  (Section 2.3); the screen only lets the admin change a price later.
- Money, checked in the code before step 6.1: a car price may have decimals.
  The car form takes at most two (parseDecimalInput: "45", "45.5", "45.50"; a
  comma counts as the point); the rules check only number, above 0, at most
  2000, because they cannot check decimals. Every total is calculated in whole
  cents (each price is rounded to cents once, then days × cents per day), so a
  total always has at most two decimals and no rounding noise. The booking
  rules check only that the total is a number from 0 to 1,000,000.
- An extra's price follows the same rule as the car price: a number from 0 to
  100 USD per day (a named limit), at most two decimals, checked by the form
  with the same parser; the rules check number, 0 or more, at most 100. 0 is
  allowed and shows "Free" in the public app. Why 100: the longest rental is
  365 days, so the highest possible total is 365 × (2000 + 4 × 100) = 876,000,
  below the 1,000,000 limit of the booking rules.
- settings/extras is saved as a whole document (set), in exactly the shape of
  Section 4 and of the emulator seed: { pricesPerDay: { snowChains, childSeat,
  infantSeat, boosterSeat } }, nothing else.
- Company Info edits settings/company (the fields are in Section 4). Every
  field is optional. Text is trimmed; an empty text means "not set" and the key
  is left out, never stored empty. A translated field (address, working hours)
  that is set needs all three languages, as a car description does. The phone
  and the e-mail use the validators of the booking form.
- Both saves run in a transaction that checks that the document is still what
  the form loaded; otherwise "changed elsewhere", and the form reloads only on
  request (as the car edit form does). For settings/company the first save
  runs while the document does not exist yet: then "does not exist" is the
  expected state of the check.
- Both forms open from memory when it already holds the document, as the car
  form does; only when memory has nothing they wait 3 seconds and show "No
  connection" with "Try again". A stale form cannot overwrite anything: the
  save transaction reads the server copy and refuses with "changed elsewhere".
  A save without a connection fails and is never queued.
- A new extra price changes the live total of an open booking form and the
  recalculation in the admin forms; stored totals never change (Section 6).
- The admin texts are English only, in admin_texts.dart; no ARB change.

### 3.6 Company Info screen

Separate admin screen to fill in company info (name, phone, email, address, working
hours, social links, map location). Starts empty. The Phase 6 decisions are under
3.5.

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
- popular: boolean, optional, absent means false (decided in Phase 6b, Section
  22; added with its rules in steps 6b.3 to 6b.5)

Photos are image addresses (https) stored in `photos`: for the demo cars, freely
licensed photos picked by me; from Phase 4 on, addresses the admin types or pastes.
An upload to Cloud Storage is a Phase 7 question (Section 3.3, Phase 4 decisions).

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
- settings/company (decided before step 6.1): every field optional, a field that
  is not set is left out.
  - name: text, 1 to 100 characters, not translated.
  - phone: "+" and 8 to 15 digits, the booking format (spaces, hyphens, dots and
    brackets removed before storing), for example +995555000000.
  - email: at most 254 characters, the booking check, for example
    info@example.com.
  - address, workingHours: each a map { ka, ru, en }; when set, all three, each
    1 to 300 characters.
  - mapUrl: an https address (a Google Maps link), at most 500 characters.
  - social: a map with any of facebook, instagram, whatsapp and telegram, each
    an https address of at most 500 characters.
  - No other field. Texts are trimmed.
- A missing or invalid settings document is an error. The app never uses default
  prices or default locations. The one exception: a settings/company that the
  server says does not exist means "not filled in yet" (About Us shows its empty
  state, the admin form starts empty).

## 5. Settings collection

Public read, admin write. Company info starts empty; the public About Us page must
handle that with an empty state.

From Phase 6 (rules in step 6.2, deployed in step 6.3): an admin may create and
update settings/extras and settings/company; nobody may delete any settings
document; settings/locations and every other settings document stay closed for
writes (changed in the Firebase console only). Details in Section 8.

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
- Live rules: since step 6b.4 the live Firestore rules are those of commit 2c7e2a9
  (deployed 2026-10-19); earlier: 0a7eb27 (3.3), 4e5fb1d (4.2), f32d9bb (6.3). To
  go back to an earlier version, use the Rules history in the Firebase console
  (Firestore Database > Rules). A new ruleset reaches new requests within about a
  minute and open listeners within about 10 minutes.
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
- Settings writes, decided before step 6.1: written in step 6.2, deployed in step
  6.3 on 2026-10-19 from commit f32d9bb; the live text equals the local file.
  - settings/extras: an admin may create and update it. The document has exactly
    the key pricesPerDay, a map with exactly snowChains, childSeat, infantSeat
    and boosterSeat, each a number from 0 to 100. The rules cannot check
    decimals; the form does (Section 3.5).
  - settings/company: an admin may create and update it. Only the keys of
    Section 4, each optional, with its limits: name 1 to 100 characters; phone
    "+" and 8 to 15 digits; email at most 254 characters with one "@" and a dot
    in the domain; address and workingHours with exactly ka, ru and en, each 1
    to 300 characters; mapUrl and each social link https only, no spaces, at
    most 500 characters; social only facebook, instagram, whatsapp, telegram.
  - Nobody may delete any settings document, an admin neither.
  - settings/locations and any other settings document: no writes from an app.
  - The limits live in a constants file that a unit test compares with the
    rules, as for cars and bookings.
  - The emulator case "admin refused: write settings" stays refused: it adds
    an unknown field (ruleCheck) to settings/extras. Step 6.2 only renamed it
    to "admin refused: settings/extras with an unknown field (ruleCheck)".
    Accepted cases are added for valid admin writes, and refused cases for
    settings/locations, an unknown settings document, every delete, the
    public, and invalid shapes.
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

Not planned since 2026-10-20; see Section 15 ('Not planned').

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
  and booking_firestore_mapping_test.dart (the update of an edit). Step 3.9b
  adds admin_booking_edit_screen_test.dart (the form with the real router: fields,
  the total, saving, changed elsewhere, leaving, the route) and
  admin_price_card_test.dart, and more tests for the detail (the Edit icon, the
  stored-format message, "Saved" after an edit). Step 3.10a adds
  admin_booking_new_test.dart (pure: the draft, validation, the total and its
  texts, the booking that is created, the failures),
  admin_booking_new_provider_test.dart (the notifier: the ID made once, the two
  stages, "no answer" and "Check again"; no widgets), and more tests in
  booking_firestore_mapping_test.dart, booking_rules_limits_test.dart and
  admin_booking_write_errors_test.dart. Step 3.10b adds
  admin_booking_new_screen_test.dart (the form with the real router: fields,
  status, "no e-mail", the total, saving, "no answer", leaving, a second form,
  the route) and admin_created_booking_provider_test.dart (the one-time "Saved"
  marker and the detail), and more tests for the list (the button and the room
  below) and the detail ("No e-mail"). Step 3.11 adds
  admin_booking_delete_test.dart (pure: the stronger warning, the status check,
  the failures, the outcome when the live read is faster, the texts) and
  admin_booking_delete_screen_test.dart (the button, the question, "only Delete
  deletes", the race, the notice on the list; with the real router), and more
  tests in admin_booking_detail_provider_test.dart (the delete of the notifier)
  and admin_booking_write_errors_test.dart.
- Packages installed: firebase_core 4.15.0, flutter_riverpod 3.4.3, go_router 18.0.2,
  flutter_localizations (Flutter SDK), intl 0.20.2, cloud_firestore 6.10.0,
  firebase_app_check 0.4.8 (added in step 2.9a), firebase_auth 6.7.0 (added in step
  3.4), url_launcher 6.3.3 (added in step 6b.8, with pubspec.lock).
- Package approved for Phase 1: cloud_firestore.
- Packages approved for later: shared_preferences, image_picker (Phase 4);
  url_launcher was added in step 6b.8. Other Firebase packages are added in
  the phase that first uses them, with approval.
- Not added for now: cached_network_image, flutter_launcher_icons.

## 11. Phased delivery plan

0. Setup: Firebase project, project skeleton, CLAUDE.md, localization scaffolding
   — DONE (Section 14).
1. Public catalog (read-only) + filters + localization + empty states + purple theme +
   app name. Basic Firestore rules start here (public read of active cars).
   Demo cars are entered by hand in the Firebase console. — DONE (Section 16).
2. Booking form + price calculation + confirmation screen + Firestore rules +
   App Check. Extras prices and the location list are seeded by hand in the Firebase
   console, because the admin screens for them come in Phase 6. — DONE (Section 17;
   App Check step 2.9b moved to Phase 7).
3. Admin auth (custom claim script) + bookings list and editing — DONE (Section 18).
4. Fleet management — DONE (Section 19). The photo upload moved to Phase 7
   (Section 15).
5. Calendar + conflict warning — DONE (Section 20).
6. Settings screens (Extras & Prices, Company Info) + About Us page — DONE
   (Sections 21 and 22). Phase 6b, a redesign of the public app (Home, Cars,
   About/Contact, FAQ), was part of it: Section 22.
7. Release on the free plan: polish, the Privacy Policy, the live link (Flutter
   web on Firebase Hosting) and an Android APK from a GitHub Release, then the
   final README — open (the decisions of 2026-10-20 and the steps 7.1 to 7.12
   are in Section 23; 7.1 to 7.11 are done, 7.3b is skipped; only 7.12,
   the final README, and the final clean-up remain). No paid services: the
   Blaze plan, Cloud Functions, e-mail, TTL, the photo upload and Analytics
   are not planned (Section 15).
   README: the live link, the APK link, screenshots and GIFs (the admin panel
   is shown this way, never opened to visitors); an honest "how I worked"
   paragraph (architecture and business rules are the owner's decisions,
   Claude Code writes the code under supervision, the owner reviews and
   approves every change); a note that iOS could not be tested on Windows;
   "possible future work".

## 12. Cloud Functions — LAST PHASE ONLY

Not planned since 2026-10-20; see Section 15 ('Not planned').

The app must be fully functional without the Blaze plan until the last phase. In the
last phase:
1. onCreate trigger on `bookings` -> writes to the `mail` collection (Trigger Email
   extension, needs an SMTP provider such as a free-tier SendGrid account).
2. The same (or a second) function sets `expireAt` = createdAt + 12 months.

Before this phase starts, remind me about the Blaze plan requirement and to set a
Google Cloud budget alert.

Also: verify whether Cloud Storage for Firebase (photo upload, Phase 4) currently
requires the Blaze plan for new projects, and tell me BEFORE Phase 4 what my options
are. DONE on 13 Oct 2026: it does; see the Phase 4 decisions in Section 3.3.

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

- CLOSED in step 6b.9: the cars that needed repair. The owner repaired the old
  cars in the admin app; no car shows "Needs repair". Car photos still need
  the Storage upload of Phase 7 (below).
- CLOSED before step 4.1: the Cloud Storage question. It needs the Blaze plan, so
  Phase 4 has no upload; photos are https addresses (Section 3.3, Phase 4 decisions).
- Not planned (free plan decision, 2026-10-20). The project stays on the Spark
  plan; the Blaze plan is not planned. The README lists these items as
  "possible future work":
  - Cloud Functions and e-mail on a new booking (Section 12).
  - expireAt with a TTL policy, or any automatic deletion (Sections 4 and 9);
    the Privacy Policy says the data is kept until the owner deletes it. If
    expireAt is ever added, the admin update rule must also allow an
    unchanged expireAt, because an update is checked on the merged document.
  - The car photo upload to Cloud Storage: car photos stay https addresses.
    It would need Blaze, the packages firebase_storage and a picker, a
    storage.rules file with emulator tests and a deploy, and a bucket in
    US-CENTRAL1, US-EAST1 or US-WEST1 for the no-cost level.
  - Analytics, and with it the consent banner (Section 9): no Analytics and no
    advertising, so no consent banner is needed.
  - App Check enforcement (step 2.9b, below): App Check stays monitoring only,
    for the web and for the sideloaded APK.
  - If this ever changes: Blaze first, with a Google Cloud budget alert (it
    only warns and does not stop spending); Cloud Functions on Node 22.
- CLOSED in step 6b.9: a centered maximum width for the public pages. Home,
  FAQ and Contact are centered at 720 px; the catalog has its own widths; the
  owner checked a wide window.
- For Phase 7 (from Phase 6b):
  - A live link (6b.2): the Flutter web build on Firebase Hosting. Every
    firebase command needs its own approval; App Check for the hosted domain;
    the domain added to the authorized domains of Authentication.
  - An Android APK (6b.2): the release keystore is never committed and
    key.properties is git-ignored; the SHA fingerprints go into the Firebase
    Android app; a launcher icon; a test on a real phone. App Check is not
    enforced for a sideloaded APK.
  - The README with the live link, the APK and screenshots (6b.2); a short
    interim README exists since step 6b.9.
  - An unknown address such as /#/zzz shows go_router's own error page; it is
    replaced by a public "not found" page (6b.2).
  - The licence of the Home photos (6b.6): settled in step 7.10a (Section
    23): the owner accepts the photos as they are.
  - After the booking form, Back goes to the catalog, not to Home: the car
    page opens the form with context.go (known, unchanged; 6b.6).
  - A Home visit opens the active-cars listener: it reads every active car
    document even if Cars is never opened (6b.6).
  - GoRouter.optionURLReflectsImperativeAPIs = true was set for the push from
    Home to a car, so the browser address and Back follow it (6b.6).
  - ExpansionTile gives screen readers only the hint Collapsed or Expanded in
    this Flutter version; check the FAQ on a real phone with TalkBack (6b.7).
  - Test the phone and e-mail links on a real Android phone. On the web a
    failed tel: or mailto: cannot be detected; the copy button is the
    fallback (6b.8).
  - The Contact tab shows the live values of settings/company, which anyone
    can read; the Privacy Policy should mention the contact details shown
    (6b.8).
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
  - Web: done in step 7.6 (Section 23): reCAPTCHA Enterprise in the release
    build, the web debug provider under flutter run, monitoring only. The
    key was made with no billing account (the classic v3 registration is no
    longer offered); 10,000 assessments a month at no cost, nothing above
    it enabled. The public site key is committed; no localhost on the key
    (never add it). The web debug token was not registered. "Verified" web
    requests are expected only on the live domain after step 7.7.
  - Android release: the app will NOT be published on Google Play (portfolio project),
    so Play Integrity is not planned. A sideloaded APK then cannot get a real App
    Check token. The debug provider must never be shipped in a build for users.
  - iOS: no App Check setup (it cannot be set up or tested on Windows); note it in the
    README.
  - LOCK-OUT RISK: enforcing App Check for Firestore while Android users have a
    sideloaded APK would lock that app out completely (no catalog, no booking).
  - DECIDED for step 2.9b (2026-10-20): no enforcement at all, never Enforce; the
    rules stay the only protection. The web gets reCAPTCHA in monitoring only
    (step 7.6); the sideloaded APK has no App Check provider. The two items
    below apply only if this decision ever changes.
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
    provider for the admin web build as well (not needed: nothing is enforced).
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
- Privacy Policy and the booking form: the form has no consent line yet (decided in
  step 2.7). Step 7.4 adds the page /privacy, linked from the booking form next
  to the Send button and from the Contact tab; whether a consent line is needed
  is decided in step 7.4.
- Public demo: DECIDED (2026-10-20): both, a live link (Flutter web on Firebase
  Hosting) and an Android APK from a GitHub Release; no store. No demo notice on
  Home or the booking form.
- Web URLs: DECIDED (2026-10-20): the hash URLs (/#/...) stay; no clean URLs and
  no Hosting rewrite rule.
- Georgian font: not bundled. Checked in Phase 2 on the emulator with the full
  booking flow in Georgian: it looks fine.
- Offline behaviour (since step 3.12b; it replaces what was noted in step 2.10).
  Checked by hand on the Android emulator, including a start without a connection.
  In Chrome only a running session was checked by hand (the open admin list with
  the network set to Offline keeps its rows and says "Offline: showing saved
  data"); a start without a connection on the web was NOT checked by hand, it is
  covered by tests only:
  - Nothing the app reads is kept on the device after the app is closed (Android and
    iOS; a browser never kept it). So a start without a connection has nothing to
    show.
  - Start without a connection, public app: the catalog shows the spinner and after 3
    seconds "Could not load the cars. Please try again later." with "Try again". It
    never says "No cars available yet": that text needs the answer of the server. The
    booking form does the same with its own text. No technical text is shown.
  - Start without a connection, admin (Android): the session is kept, the list shows
    the spinner and after 3 seconds "No connection. The bookings could not be
    loaded." with "Try again". It never says "No bookings yet." without the answer of
    the server. "New booking" stays.
  - Recovery: when the connection is back, the cars, the form and the bookings appear
    by themselves within a few seconds; "Try again" asks at once.
  - A running session that loses the connection keeps what is on the screen. The
    admin list then says "Offline: showing saved data" after 3 seconds; "saved" means
    held in memory until the app is closed.
  - Sending a booking without a connection fails with the "check your internet
    connection" error and sends nothing; nothing is queued. The same goes for every
    change in the admin area.
  - Car photos without a connection: a grey placeholder with a car icon (noted in
    step 2.10; not looked at again in 3.12b).
  - The copy an earlier version left on the device is removed at the first start
    after the update. The file is dropped, not shredded (not overwritten securely).
  - Leaving a screen and coming back without a connection shows the load error, not
    the earlier data: memory holds only what a screen is showing.
  - The admin detail and edit pages give up after 3 seconds and then need "Try
    again"; they do not recover by themselves.
  - "Load more" without a connection brings its button back after 3 seconds, without
    a message.
  - iOS has the same code but cannot be tested on Windows.
  - The admin area is web-first; Android admin is secondary and was checked less.
- Russian and Georgian texts: I have not yet read the ru and ka texts of the booking
  form and the thank-you summary (65 keys). Check them before Phase 7.
- The Phase 6 company data (settings/company) is public by design: anyone can read
  it. Real company values are typed only by the owner in the admin app, never
  into a file, a test or a commit.
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
- README is written in the last phase (step 7.12): screenshots, an honest "how I
  worked" paragraph (architecture and business rules are my decisions; Claude Code
  writes the code under my supervision; I review and approve every change), and a
  note that iOS could not be tested on Windows. The admin panel is not opened to
  visitors (no shared password); the README shows it with screenshots and GIFs.
- OPEN QUESTION, not a decision: Navigation between screens is not decided. Proposal to
  decide later: the public app uses plain back navigation for the booking flow and a
  small app bar menu for the About Us and Privacy Policy pages (decide in Phase 6); the
  admin panel uses a responsive shell (a bottom navigation bar on phones, a side
  navigation rail on wide screens) with go_router's ShellRoute. The admin part is
  DECIDED before step 4.1: the responsive shell, built in step 4.4a (Section 3.3,
  Phase 4 decisions). The public part is DECIDED in Phase 6b (Section 22): a
  bottom navigation with four tabs at every width (Home, Cars, About/Contact,
  FAQ); the info icon planned in step 6.1 is dropped. The Privacy Policy is
  the page /privacy, linked from the booking form and the Contact tab (step
  7.4).
- App bar on other screens: the car detail screen reuses AppBarLogo next to the back
  arrow, with the same toolbar height (decided in step 2.4); the booking form and the
  thank-you screen do the same (step 2.7). Decide again for each new screen.
- lib/firebase_options.dart has one import split over two lines. The file is
  generated, so leave it alone.
- The import cycle between app_router and the screens is accepted: the router imports
  the screens, and the screens import the router for the route names. It is the one
  exception to "lib/core does not import lib/features".
- Admin data on the device: CLOSED in step 3.12b. Firestore keeps no copy on disk on
  Android and iOS any more, and the old copy is removed at the first start after the
  update (see "Decisions of step 3.12b" in Section 3 and "Offline behaviour" above).
- createdBy is not tied to who created a booking: the rules let an admin add or
  change it on any booking. A known simplification.
- Web sign-in, not verified: the app asks Firebase to keep the admin sign-in for the
  browser session only, but that closing the browser really signs out was NOT verified
  on a normal Chrome profile. "flutter run -d chrome" opens a fresh temporary profile
  each time, so being signed out after reopening proves nothing. Check it on the
  hosted web build (step 7.7), or with a normal Chrome and a local web server.
- Web admin without a connection, not verified by hand: a START without a
  connection on the web was not tested by hand in step 3.12b. Changed in step
  7.5: a reload while offline cannot work at all, because Flutter 3.44 web
  builds have no offline service worker (the page itself cannot load). The
  check is now "offline WITHOUT a reload", still open: as admin on Bookings,
  set the browser offline without reloading and see "Offline: showing saved
  data" or "No connection", never "No bookings yet."; go online again and see
  the bookings appear by themselves. Tests cover the logic.
- For Phase 7 (polish): offline car writes on the web. In Chrome without a
  connection a car transaction fails with a raw JavaScript error (NativeError),
  not a FirebaseException, so the forms take the safe "may or may not be saved"
  path instead of "No connection" (step 4.6b). Decide whether and how to read
  only the "code" of such an error safely on the web. Caution: "unavailable" on
  a transaction commit may also mean that the write arrived, so a create may
  need to stay "may or may not be saved".
- Android system Back of the admin navigation, not verified on a device (for Phase
  7): in step 4.4a the emulator did not boot, so Back on Cars (to Bookings, then to
  the catalog) is covered by a widget test only. Check it once on a healthy
  emulator or a phone: sign in as admin, open Cars, press Back twice.
  The car screens of steps 4.4b to 4.6 (the list, the edit form, the new-car
  form, hide and show) were checked in Chrome only; check them once on Android
  too.
- CLOSED in step 3.6: an unknown address under /admin shows the admin "not
  found" page (outside the navigation shell since step 4.4a).
- App Check state after step 3.5: Monitoring only, for Authentication and for
  Firestore (Authentication about 44% verified requests, Firestore about 68%; web
  requests carry no token). Enforcement, if ever, is the Phase 7 decision 2.9b, and
  then the admin web build needs a provider too. Never press Enforce before that.
- Notes after step 3.6:
  - CLOSED in step 3.12b: the cache question (on Android the bookings an admin had
    read remained in Firestore's local copy).
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

- Known limits of the admin area after Phase 3 (one list, gathered in step 3.12c;
  the step in brackets has the details in Section 3 or in this section):
  - Sign-in and session
    - One shared admin account with a long random password; there is no password
      reset in the app and no second role (Phase 3 decisions).
    - A claim removed with the script takes effect in the app within about an hour;
      the rules refuse as soon as the old token has expired (3.4).
    - An admin who loses the connection while the session is being read may see the
      login page (3.4).
    - On web the sign-in is meant to last for the browser session only; that closing
      the browser really signs out is not verified on a normal Chrome profile (3.5).
      On Android the sign-in stays on the device between app starts.
    - The public app has no visible way into the admin area: a long press on the
      logo on Android, a typed address on web (Phase 3 decisions).
  - The bookings list
    - The status counts, the search and the order cover only the loaded bookings, at
      first the newest 50; the screen says so in one line (3.7).
    - A booking without createdAt (possible only when made by hand in the console)
      is not listed and not counted as unreadable (3.6).
    - A booking that cannot be read is skipped; the list shows only how many (3.6).
    - A direct link to one booking on web also starts the list: up to 50 extra
      reads (3.8).
  - One booking: status, edit, create, delete
    - No conflict warning yet: an admin can confirm two bookings of one car for the
      same days without any warning. It comes in Phase 5 (Phase 3 decisions).
      Done in step 5.3 (Section 3.4).
    - Who changed a booking and when is not stored; the rules have no field for it
      (3.8). createdBy is the fixed word "admin" and the rules do not tie it to who
      created the booking (3.10a).
    - "No answer from the server" does not mean "not saved": the change may still
      have arrived, and only the live read tells. These paths cannot be forced by
      hand and are covered by tests only (3.8, 3.9, 3.10b, 3.11).
    - A document changed by hand in the console can be readable and still refused by
      the rules on every update (an unknown field, no createdAt, a value with spaces
      around it). The app names the reason; it is corrected in the form or in the
      console (3.8, 3.9a).
    - A customer or place map with an extra key written by hand is reported as a
      conflict of that part, not as an unknown field (3.9a).
    - A booking that is deleted while it is being edited replaces the form with
      "does not exist"; the typed values are lost (3.9a).
    - A session that ends while a form is open closes it; the typed values are lost
      (3.9b, 3.10b).
    - On web the browser's Back button, a typed address and closing the tab leave a
      form WITHOUT the discard question; only the arrow of the app bar and the
      system Back of Android ask (3.9b, 3.10b).
    - The calendar and clock dialogs are in the language of the app, not always
      English (3.9b).
    - A customer without an e-mail is stored with a placeholder address that can
      never exist; anything that sends mail later must skip it (3.10a).
    - A delete cannot be undone and there is no archive (3.11).
    - A booking that cannot be read has no delete button; such a document is removed
      in the Firebase console (3.11).
  - Without a connection (3.12b; these hold for the public app too)
    - Nothing is kept on the device after the app is closed, so a start without a
      connection shows the load or connection text with "Try again", never data.
    - The admin detail and edit pages give up after 3 seconds and then need "Try
      again"; they do not recover by themselves. The list, the catalog and the
      booking form do.
    - "Load more" without a connection brings its button back after 3 seconds,
      without a message.
    - Leaving a screen and coming back without a connection shows the load error,
      not the earlier data: memory holds only what a screen is showing.
    - The 3 seconds are a guess: on a very slow connection the error can show for a
      moment before the data arrives by itself.
    - The first start after the update removes the old copy from the device: the
      file is dropped, not shredded.
    - Car photos without a connection were not checked again.
    - A start without a connection on the web was not tested by hand (see the
      reminder for Phase 7 above).
  - Platforms and tools
    - The admin area is web-first; Android is secondary for it and was checked less.
    - The Android system Back of the admin navigation (Cars to Bookings to the
      catalog, step 4.4a) was not checked on a device, only by a widget test: the
      emulator did not boot. See the reminder for Phase 7.
    - iOS has the same code but cannot be tested on Windows.
    - App Check is not enforced (monitoring only); enforcement is the Phase 7
      decision 2.9b.
    - The secrets scan reads files, not the git history, and knows a fixed list of
      shapes; it does not replace reading a change before it is committed (3.12a).
    - The optional local file tool/private_denylist.txt exists on the owner's
      machine. git ignores it; it is never printed, pasted, read aloud or committed,
      and the scan never shows its content (3.12a).

- Known limits of fleet management after Phase 4 (gathered in step 4.8; the step
  in brackets has the details in Section 19):
  - Photos are https addresses typed by hand; there is no upload and no preview
    in the form, and nothing checks that an address really leads to an image
    (Phase 4 decisions; upload: Phase 7).
  - Hiding a car with confirmed future bookings gives no warning yet (Phase 5).
    Done in step 5.4.
  - A car is never deleted from the app; a document is removed only in the
    Firebase console (Phase 4 decisions).
  - A car document that the app cannot read is shown by its short ID only; it
    cannot be opened, hidden or shown in the app and is repaired in the console
    (4.4b, 4.5).
  - A save of the edit form replaces the whole car: fields the app does not know
    are dropped. This repairs old cars on purpose (4.1, 4.5).
  - After "No answer" the car forms lock their fields; "Save again" or "Check
    again" never writes twice, and "changed elsewhere" reloads only on request
    (4.5, 4.6).
  - Offline on the web a car write shows "may or may not be saved", not "No
    connection" (4.6b; Phase 7).
  - On the web the browser's Back, a typed address and closing the tab leave a
    car form without the discard question, as for the booking forms (4.5, 4.6).
  - The newest allowed year comes from the device clock; the rules use the
    server's clock. This matters only around New Year (4.5).
  - The car transactions were tested against the live database only by hand;
    there is no Firestore fake (4.3).
  - The diagnosis line of an unknown car write error appears only in debug
    builds (4.6b).

- Known limits of the calendar and the conflict warnings after Phase 5
  (gathered in step 5.6; the step in brackets has the details in Section 20):
  - Known limit of the calendar (5.5b): it listens to every confirmed booking
    of all time (status == confirmed, no date filter) and cuts the 14 days in
    Dart, so it needs no composite index. Each opening reads all of them once.
    Fine up to about 1,000 confirmed bookings (about 1,000 reads and 1-2 MB
    per opening; the free level allows 50,000 reads a day). Before that,
    switch to a query on status and dropoff with a composite index in
    firestore.indexes.json, deployed with approval.
  - Two admins confirming at the same moment can both pass the check: it runs
    before the write, not inside it (Phase 5 decisions, Section 3.4).
  - Offline, the conflict check says "Conflicts could not be checked". After
    "Continue anyway" the write fails with the old generic text "Not saved.
    Please try again." (5.3; Phase 7).
  - Hiding a car offline fails with the old text (5.4).
  - "Check again" on the new-booking form re-sends the same booking and runs
    no conflict check, by decision (5.3).
  - The calendar shows confirmed bookings only. Offline on its first opening
    it says "No connection", even when memory holds some bookings (5.5b).
  - The days of the calendar and "today" come from the device clock (5.5b).
  - The Phase 5 screens were checked in Chrome only, not on Android. Android's
    system Back on Calendar is covered by tests only (5.5a).

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
- 3.9 Edit all fields; the recomputed total next to the stored one — DONE.
  - 3.9a (logic, repository and notifier): done. The draft of the form, its
    validation, what changed and the update map, the stored total next to the new
    one with an explicit choice, the conflict check, and updateBooking in a
    transaction with one attempt and a 20 second limit.
  - 3.9b (the edit screen, its route, the Edit icon on the detail): done.
  - 1115 tests pass and analyze is clean. The rules emulator script passes (104
    public, 210 admin and signed-in); the rules were not changed.
  - I verified by eye, on the Android emulator and in Chrome, all 42 steps of the
    checklist: the first real updateBooking transactions against the deployed
    rules (customer and notes; dates with "Keep the stored total" and with "Use
    the new total"; a pickup in the past; a hidden car); airplane mode with
    nothing queued; "Discard your changes?" on the arrow and on the system Back;
    the changed-elsewhere banner and the refusal message with both buttons; a
    total conflict that names the car; the zzTest check (the status change and
    the edit both show the unknown-field sentence).
  - Verified known limit: in Chrome the browser's Back button leaves the edit
    screen without the discard question.
  - The three test bookings were restored to their original values.
- 3.10 Create a booking by hand (status confirmed, createdBy) — DONE.
  - 3.10a (logic, mapping, repository and notifier): done. The draft of the form,
    its validation, the total from today's prices, createdBy "admin", the
    placeholder for a customer without e-mail, and createBooking in a transaction
    with one attempt and a 20 second limit that never creates a second booking.
  - 3.10b (the form screen, its route, the "New booking" button, "No e-mail" in
    the detail): done.
  - 1255 tests pass and analyze is clean. The rules emulator script passes (104
    public, 233 admin and signed-in); the rules were not changed.
  - I verified by eye, on the Android emulator and in Chrome: the first real
    createBooking against the deployed rules (13 fields, createdBy "admin",
    createdAt from the server, status Confirmed, the stored total and the dates
    as shown); a booking with "no e-mail"; a pickup in the past; a hidden car;
    airplane mode with nothing created later; Back asking; a fast double tap
    making one document; an empty second form; the form opened directly in Chrome
    and after F5; /new/edit as "not found"; a booking created in Chrome appearing
    on the emulator by itself; and the short re-check of the edit screen.
  - Covered by tests only: the "no answer from the server" path.
  - The "Create Test" bookings were deleted in the console; the original three
    test bookings stay.
- 3.11 Delete a booking, with a confirmation — DONE.
  - 1339 tests pass and analyze is clean. The rules emulator script passes (104
    public, 244 admin and signed-in); the rules were not changed.
  - I verified by eye, on the Android emulator and in Chrome, with two throw-away
    bookings: the content of the question; "Keep", a tap outside and the system
    Back delete nothing; airplane mode ("Not deleted. No connection."); a fast
    double tap (the list with "Booking deleted.", no flash of "does not exist");
    the x on the notice; and a confirmed booking deleted in Chrome while its detail
    was open on the emulator, which then showed "This booking does not exist."
  - Covered by tests only: the "no answer from the server" path.
  - The two throw-away bookings are gone; the original three test bookings stay.
- 3.12 Verify Phase 3 and close it — DONE (3.12a, 3.12b and 3.12c).
  - 3.12a (the secrets scan, tool/check_secrets.mjs): done. Its 47 tests pass; the
    scan of the repository ends with 0 errors and 6 warnings (the intentionally
    invalid phone values of validation tests); 1339 Flutter tests pass. I checked
    it by hand on Windows: the three commands, a made-up password line and the
    local deny list, each found and never printed.
  - 3.12b (no data copy on the device; offline is told from empty): done. 1408
    Flutter tests pass; the secrets scan ends with 0 errors and 6 warnings. I
    checked it by hand on the Android emulator: the old copy was gone after the
    first start and none came back; a start without a connection shows the spinner
    and then the load or connection text with "Try again" in the catalog, the
    booking form and the admin list, never "No cars available yet" or "No bookings
    yet."; all three recover by themselves; no technical text is shown. In Chrome I
    checked a running session only (the open admin list with the network set to
    Offline keeps its rows and shows the "Offline" note); a start without a
    connection on the web is covered by tests only.
  - 3.12c (closing Phase 3 in the documents): done. Documents only, no app code.
    The checks ran once more: 1408 Flutter tests, 47 tests of the secrets scan,
    the rules emulator script (104 public, 244 admin and signed-in), analyze
    clean, the secrets scan with 0 errors. The results are in "Phase 3 totals"
    below.

Phase 3 totals (written in step 3.12c):
- Steps 3.1 to 3.12 are done. The admin area has: sign-in with the admin claim, the
  redirect and the "no admin access" page; the live bookings list with filter,
  search, sort and "Load more"; the booking detail with the status change; editing
  every field; creating a booking by hand; deleting a booking; honest screens
  without a connection; no data left on the device.
- Tests: 1408 Flutter tests pass and "flutter analyze" is clean. The tests of the
  secrets scan: 47 pass. (After step 3.4 there were 522 Flutter tests.)
- Rules: the emulator script passes with 104 of 104 public checks and 244 of 244
  admin and signed-in checks.
- The rules are unchanged since the deploy of step 3.3:
  - git: firestore.rules was last changed in commit 0a7eb27 (step 3.1, 9 Oct 2026
    16:22 Tbilisi time). "git diff 0a7eb27 HEAD" is empty for firestore.rules and
    for firestore.indexes.json.
  - Firebase console, Rules tab, read by the owner on 13 Oct 2026: the last publish
    is 9 Oct 2026, 5:34 PM (Asia/Tbilisi). That is after commit 0a7eb27 (16:22) and
    before the commit "Mark step 3.3 as done" (18:09 the same day), so it is the
    deploy of step 3.3 and nothing was published since. No firebase command was run
    against the real project for this check.
- Secrets scan of the repository: 0 errors, 6 warnings (the intentionally invalid
  phone values of validation tests).
- By the git history: the last package was added in step 3.4 (firebase_auth); the
  ARB files are unchanged since step 2.8; the rules since step 3.1; the indexes
  file since Phase 0.
- Checked by hand by the owner, step by step: 3.5 to 3.12b on the Android emulator
  and in Chrome. No separate regression pass was made at the end of the phase.
- The known limits are in one list in Section 15, "Known limits of the admin area
  after Phase 3". Still open for later phases (Section 15): the conflict warning
  (Phase 5; done in step 5.3); the App Check decision, the web sign-in check on a
  normal Chrome profile, the web start without a connection, the ru and ka text
  review and the README (Phase 7); the navigation shell (Phase 4).

## 19. Phase 4 status

Phase 4: fleet management (Section 11). The decisions are in Section 3.3. Every step
has a tier, which sets how much is tested by hand: Tier 1 (writes, deletes, rules,
sign-in, offline and network signals, money): full tests and a manual checklist of at
most 12 steps. Tier 2 (new screens and forms): tests and at most 8 steps, only what
the tests cannot see. Tier 3 (documents, scripts, tests, refactors without a change
of behaviour): tests and one short look, no emulator checklist.

- 4.1 Cars rules in the local file and the cars cases of the emulator script; the
  limits as Dart constants with a comparing test. No deploy. Tier 1 — DONE. Commit
  4e5fb1d. Results:
  - The rules are NOT deployed yet: the project still runs the rules of step 3.3
    (commit 0a7eb27), in which nobody can write a car. The deploy is step 4.2.
  - The emulator run passed: 104 of 104 public checks (unchanged) and 396 of 396
    admin and signed-in checks, 152 of them new car cases.
  - 1417 Flutter tests pass and analyze is clean; the 47 tests of the secrets scan
    pass; the scan ends with 0 errors and 6 warnings (the old ones).
  - 6 active cars were read once with the public query (read-only): 1 passes the
    new rules, 5 fail: missing descriptions, one also missing photos. All six stay
    readable, and all can be hidden and shown; the five need their descriptions
    before any other change is saved.
  - No manual check was possible: nothing is deployed and no screen writes a car.
- 4.2 Deploy the cars rules with my approval; compare the console text with the
  file; a short live check. Tier 1 — DONE. The deployed rules are those of commit
  4e5fb1d.
  - Deployed with "firebase deploy --only firestore:rules --project
    tbilisi-car-rental", run once by Claude Code in PowerShell in the project
    folder after my approval, on 13 Oct 2026 at 19:21:11 Tbilisi time. The file
    compiled and only the rules were released; no error and no warning. The
    console's Rules tab shows the publish time 13 Oct 2026, 7:21 PM.
  - The deployed file is firestore.rules of commit 4e5fb1d (13000 characters,
    303 lines). Before the deploy: the working tree was clean, git diff against
    4e5fb1d was empty, and the emulator script passed (104 of 104 public, 396 of
    396 admin and signed-in).
  - Anonymous read-only checks one minute later, all as expected: active cars with
    the filter 200 (6 cars); all cars without the filter 403; settings/extras and
    settings/locations 200; bookings get and list 403.
  - One anonymous refused write: an incomplete car for a made-up ID, with the
    precondition "the document exists", so nothing could be stored either way.
    Answer 403. No other write was sent to the live database.
  - I copied the live rules text from the console into a file outside the
    repository; it equals firestore.rules at HEAD (line endings and spaces at the
    ends of lines ignored; the file was UTF-8 without a byte order mark).
  - Checked by me in Chrome: the catalog shows the six active cars; five with a
    photo, one with the placeholder (it has no photos field).
  - The cars in the collection, checked against the new rules (counts only): 7
    cars, 6 active and 1 hidden. 1 passes; 6 fail, all six because they have no
    description, two of them also no photos field. They stay as they are until
    step 4.5: they can be read, hidden and shown, and are repaired by one save
    of the edit form.
  - The new rules cannot be used from the app yet: there is no screen that writes
    a car. Their first real use is step 4.5.
- 4.3 The car draft, its validation, the mapping and the repository writes (pure
  Dart and data layer, with tests; no screen). Tier 1 — DONE. Commit e629b1b.
  - 1493 Flutter tests pass and analyze is clean; the rules emulator script passes
    with 104 of 104 public and 398 of 398 admin and signed-in checks (two new: an
    admin may read a car that does not exist, as the create transaction does; the
    public may not); the 47 tests of the secrets scan pass.
  - The transactions are NOT tested against a real database: there is no Firestore
    fake, and none was added. What they decide is in tested pure functions. Their
    first real run is step 4.5.
  - The draft (lib/features/fleet/domain/car_draft.dart) keeps numbers as typed
    text; the validation (car_validation.dart) uses the limits of car_limits.dart
    and the same photo pattern as the rules; car_input.dart reads and formats the
    price and the engine size (at most two decimals, a comma allowed); car_write.dart
    holds the results, the failures and the decisions of the transactions.
  - FleetRepository (lib/features/fleet/data) writes cars: create with an ID made
    on the device, replace, and hide or show. Each is a transaction with one
    attempt and a 20 second limit; nothing is queued offline; "Saved" only after
    the server's answer; "No answer" is not "not saved".
  - Requirement from step 4.1: the year and the seats must be SENT as whole numbers
    (integers), on Android too. The rules refuse a year or a seat count stored as a
    decimal such as 2019.0. The price and the engine size may be whole or decimal.
  - Requirement from step 4.1: a save of the edit form replaces the whole car
    document, so that an old incomplete car is repaired in one save and an unknown
    field is dropped.
- 4.4a The admin navigation shell (bottom bar on phones, side rail on wide screens)
  with the entries Bookings and Cars; the redirect tests proved again. Tier 1, at
  most 8 manual steps — DONE. Commit b3698e6.
  - 1532 Flutter tests pass and analyze is clean; the 34 navigation tests pass
    unchanged; the 47 tests of the secrets scan pass.
  - Checked by hand in Chrome (wide and narrow). The Android system Back (Cars to
    Bookings to the catalog) was NOT checked on a device: the emulator did not
    boot. It is covered by a widget test. Check it once on a healthy emulator or a
    phone in Phase 7.
  - go_router's StatefulShellRoute.indexedStack with two branches: Bookings stays
    at /admin (with new, detail and edit below it), Cars is /admin/cars and shows
    "Cars: coming soon" until 4.4b. Each branch keeps its pages while the other is
    shown, so the bookings list keeps its filter, search and listener.
  - The gate pages (login, no access, checking) and the admin "not found" page are
    outside the shell: no navigation for a visitor who is not an admin. The
    redirect is unchanged; /admin/cars is admin content like every other address.
  - The rail from 600 pixels wide (labels always shown), the bottom bar below.
    FORMS NEVER SHOW THE NAVIGATION, on any width (new booking, edit booking, and
    later the car forms): a click on it is not a Back, so it would not ask
    "Discard your changes?". The rail shows on the list, a booking detail and
    Cars; the bottom bar only on the list and Cars.
  - Android's system Back on Cars goes to Bookings, then to the catalog. On the
    web nothing is intercepted: the browser's Back follows its history.
  - Sign out is one shared button in the app bar of each section. It closes the
    bookings listener first when the list is alive, and never starts it.
- 4.4b The fleet list: every car, hidden ones marked, read only. Tier 2 — DONE.
  Commit d2623a4.
  - 1586 Flutter tests pass and analyze is clean; the 47 tests of the secrets scan
    pass.
  - Checked by hand in Chrome: 7 cars, 6 visible and 1 hidden, 6 need repair, the
    one complete car without the badge; wide and narrow window.
  - The Cars section reads every car, also the hidden ones, live, the same way as
    the bookings list: an empty answer that did not come from the server is not
    "No cars yet."; after 3 seconds "No connection. The cars could not be loaded."
    with Try again, and the cars appear by themselves when the server answers.
    Nothing is written.
  - One centred column of white cards: the first photo or the placeholder,
    "Brand Model", the year, the price per day as in the catalog, and the badges
    Visible or Hidden and "Needs repair". Order: visible cars, then hidden ones,
    by brand, model and year; unreadable documents last. A count line above the
    list. A tap does nothing yet; there is no "Add car" button yet.
  - "Needs repair" means: the next full save would be refused by the rules or
    would change the stored document (a missing description, a missing photos
    field, an unknown field, a year stored as a decimal, a text with a space at
    an end). The same comparison as the "already saved" check of a replace. A car
    without photos (an empty list) does not need repair.
  - A document that the app cannot read at all shows "Unreadable car" and its
    shortened document ID, nothing else.
- 4.5 Edit a car, and hide or show it. Tier 1 — DONE. Commit 0219f3d.
  - 1670 Flutter tests pass and analyze is clean; the 47 tests of the secrets scan
    pass.
  - Checked by hand in Chrome by the owner, with real writes on the hidden car:
    the repair save, a price change and its undo, an offline save and its retry,
    a change in a second tab ("changed elsewhere"), show and hide from the list,
    and the hide question of the form's switch (cancelled). All passed.
  - FOLLOW-UP (polish, later): with the browser offline, saving a car showed the
    generic "Not saved. Something went wrong. Try again." instead of "No
    connection" or "No answer". Nothing was saved and no data was lost.
  - The form is at /admin/cars/<id>/edit, below the list; a tap on a readable card
    opens it. No navigation on it (a form). It reads the car live, like the
    booking edit, and saves the WHOLE car with replaceCar after the server's
    answer only; nothing is queued offline. A successful save returns to the list
    with "Saved".
  - Save is disabled while nothing changed, EXCEPT for a car that needs repair: a
    save of such a car as it is repairs it. A car that needs repair opens with a
    note and its field errors shown at once; other errors appear after Save.
  - "No answer": the fields are locked; "Save again" (a retry finds the car already
    saved and writes nothing twice) or "Load the current car". When the server
    then shows the car exactly as written, it counts as saved at once.
  - "Changed elsewhere": the form reloads only through "Load the current car".
  - Hide or show: a button on each readable card (setCarActive, works for every
    stored car, also one that needs repair); hiding asks "Hide this car?" first.
    The Visible switch of the form is saved with the whole car and asks the same
    question at Save. The Phase 5 warning about future bookings is not here
    (added in step 5.4).
  - "Discard your changes?" on the back arrow and the Android Back, as on the
    booking edit page.
  - An unreadable car has no button and cannot be opened; it is repaired in the
    console if it ever happens.
  - The photo addresses (4.7) are part of this form: add, remove, move up and
    down, at most 10, each checked with the rules' pattern. No previews.
- 4.6 Add a car (saved hidden by default). Tier 1 — DONE. Commit 00f637a.
  - 1714 Flutter tests pass and analyze is clean; the 47 tests of the secrets scan
    pass.
  - Checked by hand in Chrome by the owner with a real create of a made-up demo
    car: saved hidden, not in the public catalog; an offline attempt locked the
    form with "Check again", which saved it once back online; after a reload the
    list showed one new car, not two. The owner then deleted the demo document in
    the Firebase console.
  - FINDING: the Stage A log line (developer.log) does not appear in the browser
    console on the web, so the error type of the offline case is still unknown.
    Planned follow-up 4.6b: make the diagnosis visible, then map the error.
  - "Add a car" on the Cars list opens /admin/cars/new: the same fields as the
    edit form (the shared AdminCarFields), empty, the car hidden unless the
    switch is turned on. Save is enabled on the empty form; it shows every error.
  - The ID is made on the device once, when the form opens, and used for every
    attempt; createCar reads the document first, so a retry never creates a
    second car. Back to the list with "Saved" after the server's answer.
  - "No answer" AND an unknown error may have created the car: the fields are
    locked and only "Check again" sends the same car with the same ID again.
    Only "no connection" and "refused" are certain; then the form stays editable.
  - Diagnosis for the offline follow-up of 4.5: a car write that fails with an
    error type the app does not know logs only that type ("An unexpected error
    type in a car write: <type>"); codes with the web prefix "firestore/" are
    read like the plain codes. No other mapping yet.
- 4.6b Make the offline diagnosis visible. Tier 1 — DONE. Commit 88d3f87.
  - 1719 Flutter tests pass and analyze is clean; the 47 tests of the secrets scan
    pass.
  - FINDING (owner, Chrome debug build, one offline save on the new-car form, no
    database writes): "An unexpected error in a car write: CarWriteException
    (unknown) from NativeError". Offline in Chrome the transaction fails with a
    raw JavaScript error (NativeError), not a FirebaseException. Nothing is mapped
    by that type: a mapping by NativeError would be too broad. Stage B is NOT
    done. The form keeps its safe behaviour: fields locked, "may or may not be
    saved", "Check again", and the retry never creates a second car.
  - FOR THE PHASE 7 POLISH LIST: decide whether and how to read only the "code"
    of such a JavaScript error safely on the web, so that offline can show "No
    connection". Caution: "unavailable" on a transaction commit may also mean that
    the write arrived, so a create may need to stay "may or may not be saved".
  - Every car write error that ends as "unknown" prints one line in debug builds
    with debugPrint (shown in the browser console; never in a release build):
    "An unexpected error in a car write: CarWriteException(unknown) from <type>",
    for a FirebaseException only its code. Never a message or a value. Used by
    mapCarWriteError and by the catch-all of the three notifiers that write cars.
  - Replaces the Stage A developer.log line, which the web console does not show.
- 4.7 The photo addresses of a car in the form (add, remove, order). Tier 2 —
  folded into 4.5 (the edit form); 4.6 reuses the same form.
- 4.8 Verify Phase 4 and close it. Tier 3 — DONE (in the commit "Close Phase
  4"). Only this file changed; nothing in the app, tool/, the rules, the ARB
  files, the packages or the indexes. The results are in "Phase 4 totals".

Phase 4 totals (written in step 4.8):
- Steps 4.1 to 4.6b are done; 4.7 (the photo addresses) was folded into 4.5 and
  4.6. The admin area now has: the cars rules, deployed in step 4.2; the
  navigation shell with Bookings and Cars (a rail on wide screens, a bottom bar
  on phones); the live fleet list with every car, the badges Visible, Hidden and
  "Needs repair", and unreadable documents shown by their short ID only; the
  edit form, which repairs an old car in one save; hide and show from the list;
  the photo addresses (add, remove, order, at most 10); the "new car" form,
  saved hidden by default; a debug-only diagnosis line for car write errors.
- Tests: 1719 Flutter tests pass and "flutter analyze" is clean. The tests of the
  secrets scan: 47 pass. (At the end of Phase 3 there were 1408 Flutter tests.)
- Rules: run again in step 4.8 on the local emulator (project
  demo-tbilisi-car-rental; Java from "Android Studio1\jbr", set for that one
  command only): 104 of 104 public checks and 398 of 398 admin and signed-in
  checks. firestore.rules was last changed in commit 4e5fb1d (step 4.1) and
  deployed in step 4.2; "git diff 4e5fb1d" is empty for it. No firebase command
  was run against the real project in step 4.8.
- By the git history of Phase 4 (the 16 commits after 4e68af0): no package was
  added (pubspec.yaml and pubspec.lock last changed in step 3.4); the ARB files
  are unchanged since step 2.8; firestore.indexes.json since Phase 0.
- Secrets scan of the repository: 0 errors, 6 warnings, all intentionally
  invalid phone values in tests (booking_form_validation_test.dart and
  tool/check_booking_rules.mjs): two made-up 555 numbers that start with "+0",
  and four counting sequences that test the length limits.
- The Phase 4 history: every file version changed in the 16 commits and every
  commit message, read with the scan's own code by a temporary helper outside
  the repository (deleted afterwards; no snapshot files): 0 errors, 6 warnings
  (the same three lines of check_booking_rules.mjs, in two commits). An extra
  search of the added lines found no e-mail address other than @example.com
  and the Co-Authored-By address, and nothing shaped like a JWT token.
- Checked by hand by the owner, step by step, in Chrome: 4.4a to 4.6b, with real
  writes in 4.5 (the hidden car repaired) and 4.6 (a made-up demo car, deleted
  by the owner in the console afterwards). The car screens were NOT checked on
  Android: the emulator could not be used in Phase 4. No separate regression
  pass was made at the end of the phase.
- The live data at the end of Phase 4 (counts only, read by the owner in the
  admin app): 7 cars, 7 visible, 0 hidden; 5 still need repair (see the first
  item of Section 15).
- Moved on: Phase 5: the conflict warning, and a warning when a car with
  confirmed future bookings is hidden. Phase 6: nothing from Phase 4. Phase 7:
  the photo upload (Blaze), the offline error of car writes on the web, the
  Android check of the admin navigation and the car screens, App Check
  enforcement (decision 2.9b). Both Phase 5 items were done in Phase 5 (steps
  5.3 and 5.4).
- The known limits are in Section 15, "Known limits of fleet management after
  Phase 4".

Phase 4 is complete.

## 20. Phase 5 status

Phase 5: the calendar and the conflict warnings (Section 11). The decisions are
in Section 3.4. The tiers are those of Section 19.

- 5.1 The conflict logic: pure Dart and unit tests, no screen. Tier 3 — DONE.
  Commit ec126a4.
  - 1749 Flutter tests pass (30 new) and analyze is clean; the 47 tests of the
    secrets scan pass.
  - lib/features/admin/domain/booking_conflicts.dart: conflictBuffer (5 hours),
    bookingsConflict, findConflicts, needsConflictCheck and futureConfirmed, on
    UTC moments only; a time that is not UTC throws an ArgumentError.
- 5.2 Read the confirmed bookings of one car from the server only (10 second
  limit, error mapping); one new emulator case. Tier 1 — DONE. Commit 23bd801.
  - 1768 Flutter tests pass (19 new) and analyze is clean; the 47 tests of the
    secrets scan pass; the emulator script passes with 104 of 104 public and
    400 of 400 admin and signed-in checks.
  - readConfirmedBookingsOfCar never throws: a server answer is "checked" (the
    readable confirmed bookings of the car, and how many documents could not be
    read); no connection, an answer from memory, the 10 second limit, a refusal
    and any other error are "could not be checked". Equality filters only (carId
    and status), so no composite index. Only the failure kind and the error type
    or Firestore code are printed, in debug builds.
  - The car ID guard accepts exactly the IDs the cars rules allow.
  - The emulator script has two new signed-in cases (an admin may run the query,
    a request without sign-in may not): 104 of 104 public, 400 of 400 admin and
    signed-in. firestore.rules is unchanged.
  - No manual steps: nothing calls it from a screen yet. Its first live run is
    step 1 of the 5.3 checklist.
- 5.3 The conflict warning in the status change, the edit form and the new
  booking ("Checking…", "Continue anyway", "could not be checked"). Tier 1 —
  DONE. Commit e6fa3d0.
  - 1828 Flutter tests pass (60 new) and analyze is clean; the 47 tests of the
    secrets scan pass. No existing test changed.
  - Checked by hand in Chrome by the owner, 10 steps, all passed: the first live
    run of the query (online, no dialog, no index request, no Console line), the
    dialogs with times only, Cancel and "Continue anyway", and offline "Conflicts
    could not be checked".
  - After "Continue anyway" offline, the write fails with the old generic text
    ("Not saved. Please try again."); nothing is written. The mapping of the
    Chrome offline error stays a Phase 7 item.
  - "Check again" on the new-booking form re-sends the same booking with the
    same ID and runs no conflict check, by decision.
  - In Chrome debug, a car photo from an external image host is blocked by CORS
    and shows two Console errors; photos move to Storage in Phase 7.
- 5.4 The future confirmed bookings in the "Hide this car?" dialog (card and
  form switch). Tier 1 — DONE. Commit 2be161d.
  - 1873 Flutter tests pass (45 new) and analyze is clean; the 47 tests of the
    secrets scan pass. No existing expectation changed; two test setups got the
    fake bookings repository (harness only).
  - Checked by hand in Chrome by the owner, 8 steps, all passed: the dialog
    listed a rental in progress and a future booking in Tbilisi time and skipped
    a finished and a pending one, no names; Cancel, Hide and Show; the form path;
    the old dialog for a car with nothing ahead; offline the "could not be read"
    line with Hide still possible. The test bookings were cancelled and deleted.
  - The new files (hide_warning.dart, hide_check.dart) are in the admin feature.
    Fleet presentation already imported admin; no import from fleet domain or
    fleet data into admin was added.
  - In the car edit form, showErrors is now set only once the save really
    writes, so Cancel leaves the form as it was.
  - setActive(active: false) stays for its existing tests; the card hides with
    hide().
  - Hiding offline fails with the old text, as before.
- 5.5a The Calendar entry of the navigation, with an empty page. Tier 1 — DONE.
  Commit b4ca321.
  - 1892 Flutter tests pass (19 new) and analyze is clean; the 47 tests of the
    secrets scan pass.
  - Checked by hand in Chrome by the owner, 7 steps, all passed: the order
    Bookings, Calendar, Cars with the right entry selected; the Calendar page;
    reload; signed out, /admin/calendar went to the login page and back to
    Calendar after sign-in; the bottom bar when narrow; /admin/calendar/x showed
    the admin "not found" page without the navigation.
  - Three existing expectations changed, only because of the new branch: the
    list of AdminSection values, and Cars at index 2 instead of 1 (two lines in
    admin_shell_test.dart).
  - Phase 7 reminder: an unknown public address (for example /zzz, or one with
    a double slash) shows go_router's raw "Page Not Found / GoException" page.
    It needs a public "not found" page and an errorBuilder.
  - Android's system Back on Calendar (to Bookings) is covered by tests only, as
    for the other sections.
- 5.5b The calendar grid. Tier 2 — DONE. Commit 71ed42e.
  - 2001 Flutter tests pass (113 new) and analyze is clean; the 47 tests of the
    secrets scan pass; the emulator script passes with 104 of 104 public and
    402 of 402 admin and signed-in checks (two new cases: an admin may read the
    confirmed bookings of all cars, a request without sign-in may not).
    firestore.rules is unchanged.
  - Checked by hand in Chrome by the owner, all passed: the wide window, the
    narrow window, hiding and showing a car, offline on the first visit and
    offline with the grid shown, with four made-up test bookings.
  - 14 days per car in Tbilisi time, Previous and Next by 7 days, Today; hidden
    cars with a booking in the window and unknown car IDs get marked rows; a
    warning icon marks a booking too close to another of the same car; a tap
    opens the booking detail. Bars show times only, never a customer detail.
  - The grid is drawn only after the server has answered both reads; before
    that, "loading", and "No connection" when the server has not answered 3
    seconds (serverAnswerWait) after the first answer from memory; never "no
    bookings".
  - The old 5.5a screen test was replaced; no other existing test changed.
  - The query limit is in Section 15, "Known limit of the calendar (5.5b)".
- 5.6 Verify Phase 5 and close it. Tier 3 — DONE (in the commit "Close Phase
  5"). Only this file changed; nothing in the app, tool/, the rules, the ARB
  files, the packages or the indexes. The results are in "Phase 5 totals".

Phase 5 totals (written in step 5.6):
- Steps 5.1 to 5.5b are done, in the 12 commits after 7022099 ("Close Phase
  4"). The admin area now has: the pure conflict rules (5-hour buffer); a
  server-only read of the confirmed bookings of one car; the conflict warning
  in the status change, the edit form and the new booking ("Checking…",
  "Continue anyway", "could not be checked"); the confirmed bookings ahead in
  the "Hide this car?" dialog; the Calendar entry of the navigation (Bookings,
  Calendar, Cars) and the 14-day calendar of confirmed bookings in Tbilisi
  time.
- Tests: 2001 Flutter tests pass and "flutter analyze" is clean. The tests of the
  secrets scan: 47 pass. (At the end of Phase 4 there were 1719 Flutter tests.)
- Rules: run again in step 5.6 on the local emulator (project
  demo-tbilisi-car-rental; Java from "Android Studio1\jbr", set for that one
  command only): 104 of 104 public checks and 402 of 402 admin and signed-in
  checks (398 at the end of Phase 4; two new cases in 5.2 and two in 5.5b).
  firestore.rules was last changed in commit 4e5fb1d (step 4.1) and deployed in
  step 4.2; "git diff 4e5fb1d" is empty for it. No firebase command was run
  against the real project in step 5.6.
- By the git history of Phase 5 (the 12 commits after 7022099): no package was
  added (pubspec.yaml and pubspec.lock last changed in step 3.4); the ARB files
  are unchanged since step 2.8; firestore.indexes.json since Phase 0.
- Secrets scan of the repository: 0 errors, 6 warnings, all intentionally
  invalid phone values in tests (booking_form_validation_test.dart and
  tool/check_booking_rules.mjs), the same as at the end of Phase 4.
- The Phase 5 history: every file version changed in the 12 commits (74
  versions) and every commit message, read with the scan's own code by a
  temporary helper outside the repository (deleted afterwards; no snapshot
  files): 0 errors, 6 warnings (the same three lines of check_booking_rules.mjs,
  in two commits). An extra search of the added lines found no e-mail address
  other than @example.com and the Co-Authored-By address, and nothing shaped
  like a JWT token.
- Checked by hand by the owner, step by step, in Chrome: 5.3 to 5.5b (5.1 and
  5.2 have no screen), with four made-up test bookings in 5.5b, deleted
  afterwards. The Phase 5 screens were NOT checked on Android. No separate
  regression pass was made at the end of the phase.
- The live data at the end of Phase 5 (counts only, read by the owner in the
  admin app): 7 cars, 7 visible, 0 hidden; 4 still need repair (see the first
  item of Section 15).
- Moved on to Phase 7: a public "not found" page for unknown addresses
  (go_router's raw error page, 5.5a); the offline error texts of the booking
  and hide writes (5.3, 5.4); the Android check of the admin screens, Calendar
  included; car photos from external hosts blocked by CORS in Chrome debug,
  which goes away with Storage (5.3).
- The known limits are in Section 15, "Known limits of the calendar and the
  conflict warnings after Phase 5".

Phase 5 is complete.

## 21. Phase 6 status

Phase 6: the settings screens (Extras & Prices, Company Info) and the About Us
page (Section 11). The decisions are in Sections 2.5, 3.5, 3.6, 4, 5 and 8. The
tiers are those of Section 19. A change of firestore.rules, the ARB files, the
packages or the indexes needs the owner's separate approval; such steps say so.

- 6.1 The Phase 6 decisions in this file. Tier 3 — DONE (in the commit "Record
  the Phase 6 decisions"). Only this file changed.
- 6.2 The settings rules in the local file, the limits constants file with its
  unit test, and the emulator cases. Tier 1 — DONE. Commit f32d9bb.
  - 2011 Flutter tests pass (10 new) and analyze is clean; the 47 tests of the
    secrets scan pass; the emulator script passes with 104 of 104 public and
    491 of 491 admin and signed-in checks (402 + 89 new).
  - The rules are in the local file only; the live rules are unchanged until
    step 6.3.
  - New files: lib/features/settings/domain/settings_limits.dart and
    test/rules/settings_rules_limits_test.dart. The test also checks that the
    company phone and e-mail patterns are the same text as the booking ones,
    and that 365 × (2000 + 4 × 100) stays within the total limit.
  - The parameter of isValidCompanySettings is "company", not "c", so that the
    existing booking limits test still finds the customer's "c.keys()".
  - The secrets scan has 7 warnings now: the new one is the intentionally
    invalid phone of an emulator case, a made-up phone that starts with +0.
- 6.3 Deploy the rules, with the check of the live text as in step 4.2. Tier 1 —
  DONE. The deployed file is firestore.rules of commit f32d9bb (426 lines).
  - Deployed with "firebase deploy --only firestore:rules --project
    tbilisi-car-rental", run once by Claude Code after my approval, on
    2026-10-19 at about 09:14 Tbilisi time. The file compiled and only the
    rules were released; no error and no warning. The console's Rules tab
    shows the publish time Oct 19, 2026, about 9:14 AM.
  - Before the deploy: the working tree was clean, HEAD equalled origin/main
    (3c40b5a), "git diff f32d9bb" was empty for firestore.rules, the rules tests
    passed, and the emulator script passed (104 of 104 public, 491 of 491 admin
    and signed-in). The CLI listed tbilisi-car-rental; no account was printed.
  - Backup: firestore.rules of f32d9bb^ (54b80c7) was saved outside the
    repository; it equals that of 4e5fb1d (303 lines). I copied the live text
    from the console before the deploy into a file outside the repository; it
    equals 4e5fb1d (publish time Oct 13, 2026, 7:21 PM, the step 4.2 deploy).
  - After the deploy I copied the live text again; it equals firestore.rules at
    HEAD (426 lines). Both comparisons ignore line endings and spaces at the
    ends of lines.
  - Anonymous checks about two and a half minutes later, no sign-in, all as
    expected: settings/extras 200, settings/locations 200, settings/company 404
    (it does not exist yet; the read is allowed), active cars with the filter
    200 (7 cars), all cars without the filter 403, a booking get 403.
  - Two anonymous refused writes, each with the precondition "the document
    exists", so nothing could be stored either way: settings/company with a
    made-up body 403, settings/ruleCheck63 403. No other write.
  - Checked by me in Chrome on the live app: the catalog loads, and a car's
    booking form shows the extras with their prices.
  - No live data written; App Check untouched. No admin write was made on the
    live project: the admin write path is proven by hand in steps 6.6 and 6.7.
- 6.4 The company model and parser, and the write methods of the settings
  repository (extras prices, company) with error mapping and "no answer". No
  screen. Tier 1 — DONE. Commit d3269f0.
  - 2167 Flutter tests pass (156 new) and analyze is clean; the 47 tests of the
    secrets scan pass. The scan has 0 errors and 11 warnings: the four new ones
    are the intentionally invalid made-up phone that starts with +0, in four
    test files; this file has none.
  - No change to the rules, the ARB files, the packages, the indexes or
    ExtrasPrices (it already compares by value). No screen yet.
  - The settings domain files import the booking and fleet domain (the phone
    and e-mail validators and the decimal parser); no existing file moved.
  - The 100 USD limit of an extra is enforced by the rules and by the form
    validator, not by the ExtrasPrices reader. So a stored value above 100 (a
    console edit) cannot break the public booking form, and the admin form
    reports it as too high.
  - The save transaction is tested through its pure decision
    (decideSettingsSave) and the error mapping; the real save is proven by
    hand in steps 6.6 and 6.7, as for the car writes.
  - test/rules/settings_values_rules_test.dart ties the Dart checks of the
    company fields to the answers of the emulator in step 6.2 (the same
    sample values); they agree on every sample.
- 6.5 The Settings entry of the admin navigation, with a page of two links.
  Tier 1 — DONE. Commit 8d7d2cd.
  - 2193 Flutter tests pass (26 new) and analyze is clean; the scan has 0
    errors and 11 warnings, as before. No firebase command; no change to the
    rules, the ARB files or the packages.
  - Settings is the fourth admin section (AdminSection.settings, index 3),
    with the pages /admin/settings, /admin/settings/extras and
    /admin/settings/company. The two pages below Settings are placeholders
    that read and write nothing (filled in steps 6.6 and 6.7) and show no
    navigation, as forms do. An unknown page below Settings is the admin
    "not found" page.
  - Android's system Back on the first page of Settings goes to Bookings, as
    for Calendar and Cars; on a page below Settings it returns to Settings.
  - One existing expectation changed: the list of AdminSection values.
  - Checked by me in Chrome. The first check found white text on the white
    cards: the two new widgets read the text style outside the card, from the
    purple page. Fixed as in the car cards (the text style is read inside the
    card); a contrast test now checks every text on those cards.
- 6.6 The Extras & Prices screen. Tier 1 (money) — DONE. Commit 03a79b6.
  - 2247 Flutter tests pass and analyze is clean; the scan has 0 errors and 11
    warnings, as before. No firebase command; no change to the rules, the ARB
    files or the packages.
  - The Extras & Prices page is now the real form: the four prices in USD per
    day, 0 to 100 with at most two decimals; the names and age ranges are
    read-only (a test compares the ages with app_en.arb). It is built like
    the car edit form: Save, "Saved" and back to Settings; the discard
    question; after "No answer" the fields are locked and "Save again" is
    offered; the changed-elsewhere banner and refusal; the load-failure and
    unreadable states.
  - The form opens from memory when it already holds the prices, as the car
    form does; only when memory has nothing it waits 3 seconds and shows "No
    connection" with "Try again". A stale form cannot overwrite anything: the
    save transaction reads the server copy and refuses with "changed
    elsewhere". The wording of Section 3.5 was corrected to say so.
  - Checked by me in Chrome with real writes through the app, the first live
    writes of settings/extras: a save, changed elsewhere in two tabs, an
    offline save and an offline open. The original prices were restored at
    the end.
  - For Phase 7: in Chrome an offline save shows the generic "Something went
    wrong" notice (the raw NativeError is not mapped); the error for a
    negative or malformed price says "at most two decimals" and should be
    worded better together with the helper texts.
- 6.7 The Company Info screen. Tier 1 (writes) — DONE. Commit 8ca9a5d.
  - 2301 Flutter tests pass and analyze is clean; the scan has 0 errors and 11
    warnings, as before. No firebase command against the real project; no
    change to the rules, the ARB files or the packages.
  - The Company Info page is now the real form, in six cards: name, phone,
    e-mail, address and working hours in ka, ru and en, a map link and four
    social links. An empty field leaves its key out; a translated text is all
    three languages or none. A note says that everything typed is public.
  - It is built like the Extras & Prices form: the same states and notices,
    the lock after "No answer", the changed-elsewhere banner and refusal, the
    discard question, and it opens from memory when memory holds the
    document. The first save creates settings/company and expects "does not
    exist"; the empty first-time form opens only after the server confirmed
    that the document does not exist.
  - The placeholder widget of step 6.5 and its text were removed.
  - Two emulator cases were added (an address of exactly 300 Georgian letters
    accepted, 301 refused: the rules count characters, not bytes): 104 of 104
    public and 493 of 493 admin and signed-in checks. No rules change.
  - Checked by me in Chrome with real writes through the app, the first live
    writes of settings/company, with made-up demo values only: a save, a
    reopen, absent keys, a Georgian text of 301 letters refused, changed
    elsewhere in two tabs, an offline save and an offline open. The company
    document now exists on the live project with made-up values; the values
    themselves are not written in any file.
  - For Phase 7: in Chrome an offline save shows the generic "Something went
    wrong" notice, as for 6.6.
- 6.8 The public About Us page. Replaced by step 6b.8 (Section 22): the
  About/Contact tab of the new public shell.
- 6.9 Tappable contacts with url_launcher. Replaced by step 6b.8 (Section 22).
- 6.10 Verify Phase 6 and close it. Moved after Phase 6b: it is step 6b.9,
  which closes Phase 6 and Phase 6b together (Section 22).

## 22. Phase 6b status

Phase 6b: a redesign of the public app, decided by the owner after step 6.7.
It is part of Phase 6 (Section 11) and replaces steps 6.8 to 6.10. The tiers
are those of Section 19. A change of firestore.rules, the ARB files, the
packages, pubspec.yaml (also the assets) or the indexes needs the owner's
separate approval; such steps say so.

Phase 6b decisions (the owner's, made before step 6b.1):
- The public app is mobile-first (Android phones). The web is used only for
  the admin area. Public screens are checked in Chrome with a narrow window as
  a stand-in for a phone.
- Public shell: a bottom navigation with four tabs at every width, never a
  rail: Home (/), Cars (/cars), About/Contact (/about) and FAQ (/faq).
  - The catalog (search and filter, unchanged) moves from / to /cars.
  - The car page /cars/:carId and the booking routes keep their addresses.
  - Every place that returns to the catalog (after a booking, Back from a
    car) goes to /cars; addresses come from the AppRoutes constants.
  - The language menu stays in the app bar; there is no info icon.
- Home, from top to bottom:
  - a hero with a background photo, the title and the subtitle; a tap
    anywhere on the title opens /cars;
  - "Popular cars": up to 3 cards that show the car photo only; a tap opens
    the car page; the block is hidden when no visible car is marked;
  - the booking steps, one step per page, swiped sideways, with tappable dots;
  - the conditions and benefits cards (for example the minimum age, the
    deposit, 24/7 service, the insurance, the quality of the cars), swiped in
    the same way;
  - the traffic rules in Georgia, as cards, swiped in the same way.
  Swiping works on every width; for the check in Chrome the swipe areas also
  accept a mouse drag, and the dots can be tapped.
- Popular cars, variant A:
  - A new optional boolean field "popular" on a car; absent means false.
  - The admin car form gets a "Popular" checkbox and says that Home shows at
    most 3 cars.
  - Home shows up to 3 visible cars that are marked, in a stable order.
  - This needs a change of firestore.rules (the allowed fields of a car),
    emulator cases and a deploy, each with its own approval as in steps 6.2
    and 6.3. No index is expected (equality filters only); if one turns out
    to be needed, it needs its own approval.
  - Variant B, an automatic count of the most booked cars, is for Phase 7
    with Cloud Functions on Blaze: the public app cannot read bookings.
- Texts: all texts of Home, FAQ and About/Contact are static and live in the
  ARB files (ka, ru, en).
  - The owner supplies them in one UTF-8 file, C:\temp\home_texts.txt, with a
    bracketed key and a ka, ru and en line per key. Claude Code reads that
    file and never invents or translates a text. The texts are not repeated
    in this file.
  - The ARB change needs its own approval at the step that makes it.
  - The FAQ is an expandable list: a tap opens the answer.
  - About/Contact is one screen: a static about text, the company data from
    settings/company (Section 2.5) and tappable contacts (url_launcher needs
    its own package approval).
- Images: the owner's own photos.
  - JPG for photos, PNG only for logos and icons; about 1200 to 1600 pixels
    wide and at most about 400 KB each; file names in lower-case ASCII.
  - Delivered in C:\temp\home_images and bundled as assets (for example
    assets/images/home/). Declaring them in pubspec.yaml needs its own
    approval at that step.
  - The owner confirmed that the photos and the texts are his own.
- Phase 7 keeps the automatic popularity (variant B) and the earlier
  reminders.

Steps:
- 6b.1 The Phase 6b decisions in this file. Tier 3 — DONE (in the commit
  "Record the Phase 6b decisions in the plan"). Only this file changed.
- 6b.2 The public shell (bottom navigation, four tabs) and the catalog moved to
  /cars, with placeholder pages for About/Contact and FAQ. Tier 1: the routes
  around the booking flow change — DONE (in the commit "Add the public bottom
  navigation and move the catalog to /cars").
  - 2338 Flutter tests pass and analyze is clean; the scan has 0 errors and 11
    warnings. ARB: the 7 approved keys in en, ka and ru (the owner's texts).
  - The public shell is a StatefulShellRoute with four branches. The car
    page, the booking form, the thank-you page and the admin area lie on the
    root navigator, so the bottom bar is hidden there.
  - Android Back on Cars, Contact and FAQ goes to Home; on Home it leaves the
    app; on the thank-you page it goes to /cars.
  - The web hash addresses (/#/cars) are kept.
  - The third tab is called Contact (key tabContact); its address is /about.
  - Checked by the owner in Chrome with a narrow window, 11 steps, all passed.
  - Noted for Phase 7: see "For Phase 7 (noted in step 6b.2)" in Section 15.
- 6b.3 The Popular flag: the rules in the local file and the emulator cases.
  Tier 1 — DONE (in the commit "Allow the optional popular flag on a car in
  the rules").
  - The rules allow an optional field "popular" on a car, only as a bool;
    absent means false. It is in the hasOnly list of isValidCar but not in
    hasAll. The "at most 3" limit cannot be enforced by the rules (they would
    have to count other cars); it lives in the text of the admin form and in
    Home, which shows at most 3.
  - 25 new emulator cases (section I.12): 104 of 104 public and 518 of 518
    admin and signed-in checks (was 493).
  - 2338 Flutter tests pass and analyze is clean; the scan has 0 errors and 11
    warnings. One Dart test expectation changed: the rules-text test now
    expects [...carFields, 'popular']; popular joins carFields in step 6b.5.
  - Decided: the app writes popular only as true, when a car is marked, and
    leaves the key absent when it is not marked. Hiding and showing keep
    popular unchanged.
  - An old incomplete car cannot be marked popular until it is repaired by
    one save of the edit form.
  - The local firestore.rules was ahead of the live rules until step 6b.4,
    which deployed it.
- 6b.4 Deploy the rules, with the check of the live text as in step 6.3.
  Tier 1 — DONE (no code change; this file only). The deployed file is
  firestore.rules of commit 2c7e2a9 (431 lines).
  - Deployed with "firebase deploy --only firestore:rules --project
    tbilisi-car-rental", run once by Claude Code after my approval, on
    2026-10-19 at about 17:43 Tbilisi time; exit code 0, no warning. The
    console's Rules history shows the new version at 5:43 PM above the 6.3
    one (9:14 AM).
  - Before the deploy: the working tree was clean, HEAD equalled origin/main
    (e88bb86), the rules tests passed (106), and the emulator script passed
    (104 of 104 public, 518 of 518 admin and signed-in).
  - I copied the live text from the console before the deploy into a file
    outside the repository: it was identical to f32d9bb, and its only
    difference from the local file was the 6b.3 change. After the deploy I
    copied it again: it is identical to firestore.rules at HEAD. Both
    comparisons ignore line endings and spaces at the ends of lines.
  - Anonymous checks about two minutes after the release, no sign-in, all as
    expected: settings/extras read 200, the active-cars query 200, all cars
    without the filter 403, a booking get 403. One anonymous refused write: a
    PATCH of a made-up car document with popular: true and the precondition
    "the document exists" gave 403; nothing was stored.
  - Checked by me in Chrome on the live app: the public catalog and a car
    page; in the admin area a price +1 and back on one valid car (a full
    replacement checked by isValidCar), all passed.
  - No live data written by Claude Code; no other service touched (no
    indexes, hosting, functions, storage or auth); App Check untouched.
- 6b.5 The car model and the "Popular" checkbox of the admin car form.
  Tier 1 — DONE (in the commit "Add the Popular mark to cars and the admin
  car form").
  - The model and the draft carry popular. Both car forms have the checkbox
    "Popular (shown on Home)" in the Visibility card, with a note; the admin
    list shows a "Popular" badge.
  - A soft warning, never blocking, appears when the box is ticked and 3
    other visible cars are already marked. It is counted from the admin list
    in memory: no query and no index. It does not show when the edit address
    is opened directly without the list.
  - The app writes popular only as true; an unmarked car has no key.
  - A stored false is valid and is no repair reason (the next save drops the
    key). A value that is not a bool reads as false and is a repair reason
    ("popular is not true or false").
  - homePopularMax = 3 (in car_limits.dart; the app only).
  - 2371 Flutter tests pass (was 2338) and analyze is clean; the scan has 0
    errors and 11 warnings.
  - Changed existing tests: the rules-text expectation is back to carFields,
    the sample car has popular, and the carDocument test sets it.
  - Contrast fix: the small notes of the car form (price, photos, visibility,
    too many photos) read their style outside the card and were white on
    white (the 6.5 bug class). Found by the new contrast test.
  - Checked by me in Chrome on the live app, all passed; every car was
    restored to unmarked.
  - No live data written by Claude Code; no rules, ARB, package or index
    change.
- 6b.6 The Home screen. Tier 2 (large) — DONE (in the commit "Build the
  public Home screen with popular cars and info blocks").
  - Home blocks: the hero, the popular cars, the process, the benefits, the
    conditions and the traffic rules; the block titles are centered.
  - The photos are bundled in assets/images/home/ without EXIF and XMP; the
    texts are in the 3 ARB files (33 keys; homeTerms* for the conditions).
  - 2414 Flutter tests pass and analyze is clean; the scan has 0 errors and 11
    warnings.
- 6b.7 The FAQ screen. Tier 2 — DONE (in the commit "Add the public FAQ
  screen with expandable questions").
  - The FAQ page: a heading and 10 expandable questions (several can be
    open), content at most 720 px wide; the texts are in the 3 ARB files
    (21 keys: faqPageHeading, faq1Question to faq10Answer).
  - SectionTitle moved to lib/core/widgets (shared by Home and FAQ).
  - 2426 Flutter tests pass and analyze is clean; the scan has 0 errors and 11
    warnings.
- 6b.8 About/Contact: the about text, the company data and tappable contacts.
  Tier 2 — DONE (in the commit "Add the Contact tab with the about text and
  company contacts").
  - The Contact tab: the about text from the ARB files and a contacts card
    from settings/company (name, phone, e-mail, address, working hours, map
    link, social links); a tap calls, writes or opens; copy buttons; loading,
    error and empty states.
  - The package url_launcher 6.3.3, the first new package since step 3.4;
    pubspec.lock was committed with it. No platform file changed.
  - 15 ARB keys. 2460 Flutter tests pass and analyze is clean; the scan has 0
    errors and 11 warnings.
- 6b.9 Verify Phase 6 and Phase 6b and close them (replaces step 6.10). Tier 3
  — DONE (in the commits "Remove the unused placeholder page and texts" and
  "Close Phase 6 and Phase 6b").
  - The unused PublicPlaceholder widget and the keys pageComingSoon and
    faqTitle were removed (ARB approval), with the tests that checked them.
  - The results are in "Phase 6 and 6b totals"; Section 15 was refreshed and
    a short interim README replaced Flutter's template.

Phase 6 and 6b totals (written in step 6b.9):
- Steps 6.1 to 6.7 (6.8 to 6.10 were replaced by 6b.8 and 6b.9) and 6b.1 to
  6b.8 are done, in the 26 commits after a34b588 ("Close Phase 5"); step
  6b.9 added the cleanup commit and this one. The app now has: the Settings
  entry of the admin area with the Extras & Prices and Company Info forms;
  the Popular mark of a car; the public shell with four tabs; Home, FAQ and
  the Contact tab with tappable contacts.
- Tests: 2459 Flutter tests pass and "flutter analyze" is clean. The tests of
  the secrets scan: 47 of 47 pass. (At the end of Phase 5 there were 2001
  Flutter tests.)
- Secrets scan of the repository: 0 errors, 11 warnings, all intentional
  made-up phone shapes in tests and in tool/check_booking_rules.mjs.
- Rules: the emulator script, run again in step 6b.9 on the local emulator
  (project demo-tbilisi-car-rental; Java from "Android Studio1\jbr", set for
  that one command only): 104 of 104 public checks and 518 of 518 admin and
  signed-in checks (402 at the end of Phase 5). No firebase command was run
  against the real project in step 6b.9.
- By the git history of the 26 commits: firestore.rules changed in 2 commits
  (the last is 2c7e2a9, deployed in step 6b.4; the live rules equal HEAD);
  firestore.indexes.json is unchanged since Phase 0; pubspec.yaml changed in
  6b.6 (the assets) and 6b.8 (url_launcher 6.3.3, with pubspec.lock). The
  ARB files have 173 keys, none unused. The 3 Home photos are bundled
  without metadata.
- The history of the 26 commits: every commit message (26) and every file
  version changed (170; 20 binary or skipped), read with the scan's own code
  by a temporary helper outside the repository (deleted afterwards): 0
  errors, 17 warnings, all made-up phone shapes. An extra search of the
  added lines found no e-mail address other than the allowed ones and
  nothing shaped like a token.
- Checked by hand by the owner: the extras prices are the original ones; the
  live catalog has 7 cars, 7 visible, 0 hidden, 0 marked Popular, and no car
  shows "Needs repair"; settings/company holds only the owner's chosen demo
  values; the full Chrome check (Home, Cars, the booking form, Contact, FAQ,
  the languages, a wide window, the admin area) passed.
- Moved on to Phase 7: see Section 15, "For Phase 7 (from Phase 6b)" and the
  other Phase 7 items there.

Phase 6 is complete. Phase 6b is complete.

## 23. Phase 7 status

Phase 7: the release on the free plan (Section 11). The tiers are those of
Section 19. A change of firestore.rules, firebase.json, the ARB files, the
packages, pubspec.yaml (also the assets), the Android platform files or the
indexes needs the owner's separate approval, and so does every firebase
command and every release build; such steps say so.

Phase 7 decisions (the owner's, 2026-10-20):
- Goal: a portfolio app. No Google Play and no other store. Deliverables: a
  live link (Flutter web on Firebase Hosting, Spark plan, free) and an
  Android APK shared from a GitHub Release. iOS is not possible on Windows.
- No paid services: the Blaze plan is not planned, so no Cloud Functions, no
  e-mail sending, no TTL or automatic deletion, no Cloud Storage photo
  upload (car photos stay https addresses) and no Analytics. The README lists
  them as "possible future work" (Section 15, "Not planned"). No consent
  banner is needed: there is no Analytics and no advertising.
- No demo notice on Home or the booking form.
- App Check for the web: a reCAPTCHA key (free), monitoring only. Never
  Enforce, also not for the sideloaded APK.
- A Privacy Policy page /privacy with the owner's texts (6 sections, ka, ru
  and en), linked from the booking form and the Contact tab. It says that
  the data is kept until the owner deletes it (no automatic deletion). Its
  sentence about Google reCAPTCHA stays only once the App Check web step is
  done.
- The hash URLs (/#/...) stay; no clean URLs.
- The admin panel is not opened to visitors (no shared password); the README
  shows it with screenshots and GIFs.
- Order: 7.1 to 7.12 as listed. The first four steps change no Firebase
  setting. Changed on 2026-10-21: the first deploy 7.7 comes before the
  icon 7.8.

- 7.1 The Phase 7 decisions in this file. Tier 3 — DONE (in the commit
  "Record the Phase 7 decisions in the plan").
- 7.2 A public "not found" page for unknown addresses such as /#/zzz,
  instead of go_router's own error page. Tier 2 — DONE (in the commit "Add
  the public not-found page for unknown addresses").
  - The page is the last top-level catch-all route, plus errorBuilder for
    router errors; Android's system Back goes to Home. 3 ARB keys. 2492
    Flutter tests pass; the scan has 0 errors and 11 warnings.
- 7.3a The public texts. Tier 2 — DONE (in the commit "Polish the public
  texts and let booking field errors wrap").
  - One term each: ka pick-up "მიღება" (also in FAQ 3), en "Pick-up" and
    "Return"; ka "ელფოსტა" and "საბავშვო სავარძელი"; the ru load errors
    say "Попробуйте позже"; the car page button is "Request a booking".
  - errorMaxLines 6 on the booking form fields (the phone error needs 5
    lines at 360 px and text size 1.3); a layout test (the form and the
    filter sheet, ka, ru, en) and a terms test. 2506 Flutter tests pass.
- 7.3b The admin texts (English only). Tier 3 — SKIPPED by the owner,
  listed as future work in the README: the offline notice of the settings
  forms, the wording for a negative price, helper texts, "Pickup" ->
  "Pick-up" in the admin texts, and optionally a shorter phone error with
  the example only in the hint.
  - Reason: these texts are only in the admin panel, which visitors do not
    see, and any text change would need a new web deploy and a new APK and
    release so that the live site and the APK keep matching.
  - Small tidy-ups: replace the sample car name in
    booking_form_screen_test.dart by a made-up one (a separate Tier 3
    commit).
- 7.4 The Privacy Policy page /privacy and its links from the booking form
  (next to Send) and from the Contact tab; the texts come from the owner's
  file in ka, ru and en. Tier 2 — DONE (in the commit "Add the Privacy
  Policy page with links from the booking form and the Contact tab").
  - The page /privacy is a top-level route above the catch-all, always
    opened with push, so Back returns to the form (its values kept) or to
    the Contact tab. A shared PrivacyLink sits under Send, after a consent
    line, and at the end of the Contact tab; a button opens the Contact tab.
  - 15 ARB keys. No reCAPTCHA mention yet: it is added in step 7.6. 2529
    Flutter tests pass; the scan has 0 errors and 11 warnings.
- 7.5 The web release build, a hosting block in firebase.json and a local
  check. Tier 1 — DONE (in the commits "Add the Hosting configuration and
  web metadata" and "Add a check that the web release build has its
  plugins").
  - firebase.json: a hosting block (build/web, every address rewritten to
    index.html, no-cache for HTML/JS/JSON, one day for images and fonts);
    the other blocks unchanged. web/index.html: lang="en", the theme colour,
    a longer description, og:title, og:description, og:type (no og:image
    yet); the manifest uses #673AB7 and has no fixed orientation.
  - The Flutter 3.44.8 web build: the default JavaScript/CanvasKit build
    (no --wasm, the CanvasKit CDN), 43 MB in build/web, main.dart.js about
    4 MB, no source maps.
  - Checked locally on the Hosting emulator with a demo project: the
    rewrite works (/cars without # opens the app). The emulator does not
    apply the cache headers (even a "**" rule adds none); they are checked
    on the live domain in step 7.7.
  - Finding: the release web build used a stale web_plugin_registrant.dart
    (a Flutter tool step that is cached) without firebase_auth_web and
    url_launcher_web, so the admin sign-in failed with channel-error and
    the Contact links could not open; debug (flutter run) was not
    affected. Fixed by flutter clean and guarded by tool/check_web_build.mjs.
    Verified by the owner on the emulator: the sign-in works, the session
    ends when the browser closes, and the Contact links open.
  - Release procedure, for every web build and before every deploy:
    flutter clean, flutter build web --release, node
    tool/check_web_build.mjs (it must pass).
  - Notes: test a local build only on http://localhost:5000 (127.0.0.1 is
    not an authorized domain of Authentication, so the sign-in fails
    there). The favicon and the web icons are still Flutter's; step 7.8
    replaces them after the first deploy (order changed in 7.7). A report of the
    caching gap to Flutter is possible (Phase 7, optional).
- 7.6 App Check for the web, monitoring only. Tier 1 — DONE (in the commit
  "Turn on App Check monitoring for the web build").
  - The provider is reCAPTCHA Enterprise (Fraud Defense): the classic
    reCAPTCHA v3 registration is no longer possible in the Firebase
    console. The key was made with no billing account and no payment
    method; the project stays on Spark. The localhost domain is not on it.
  - The public site key is a committed constant (appCheckWebSiteKey in
    lib/core/config/app_check_config.dart). flutter run uses the web debug
    provider, the release build reCAPTCHA Enterprise; nothing activates
    when the key is empty. Android is unchanged (debug provider in debug
    builds only).
  - Monitoring only: Cloud Firestore and Authentication stay "Monitoring";
    never press Enforce.
  - Privacy section 5 (ka, ru, en) mentions Google reCAPTCHA.
    tool/check_web_build.mjs also checks that the site key is in the build
    (it never prints the key). 2536 Flutter tests and 59 Node tests pass.
  - The web debug token was not registered (optional). flutter run -d
    chrome starts a fresh browser profile, so it makes a new debug token
    on every run. "Verified" requests are expected only on the live domain
    after step 7.7: check the App Check metrics there.
  - The reCAPTCHA Enterprise free quota is 10,000 assessments a month;
    nothing above it is enabled (no billing).
  - The old classic reCAPTCHA key in the other Google project is unused
    and may be deleted.
- 7.7 The first Hosting deploy. Tier 1 — DONE (deployed 2026-10-21, after
  the owner's GO, with firebase deploy --only hosting --project
  tbilisi-car-rental, message "Step 7.7: first deploy"; 43 files, no
  prompts; rules and indexes not deployed).
  - --non-interactive was added to the deploy command (not in the approved
    text; it only makes a prompt fail instead of wait).
  - The pre-flight passed on c975f04: analyze, 2536 Flutter tests, 59 Node
    tests, the scan 0 errors / 11 warnings, flutter clean, the release
    build, check_web_build (5 plugins and the site key), 43 MB, no .map
    files, the noindex tag in the build.
  - Live: https://tbilisi-car-rental.web.app and
    https://tbilisi-car-rental.firebaseapp.com (both 200, both with the
    noindex tag); /cars without # serves the app.
  - Headers (curl -I): no-cache for /index.html, the JS files and
    version.json; max-age=86400 for the images; main.dart.js is served
    with br or gzip. / and /cars get Hosting's default max-age=3600 (the
    header rules match the requested path): step 7.7a.
  - The owner's smoke test on https://tbilisi-car-rental.web.app passed:
    the public tabs and the language switch, the unknown address (the
    not-found page), /cars without # opens the app, the admin sign-in
    works on the live domain, the bookings list loads, and after closing
    all Chrome windows the admin panel asks for the sign-in again. The
    browser console showed only the known CORS error of one outside car
    photo (step 7.7b).
  - App Check on the live site (CLOSED in step 7.8a, the owner's check):
    "Verified" requests now appear for Cloud Firestore and Authentication;
    both stay on Monitoring. The other categories are old traffic and
    local tests.
  - ORDER CHANGED (the owner, 2026-10-21): 7.7 (the first deploy) comes
    BEFORE 7.8 (the icon). The link is not public until the README, so
    nobody sees the default icon; the deploy shows early whether the live
    domain, the sign-in and App Check work. The icon goes out with a
    second deploy in 7.8.
  - Before GO, the owner checked in the console: the Hosting site
    (the default site tbilisi-car-rental), the authorized domains of
    Authentication (localhost and both Hosting domains), the browser API
    key (application restrictions "None"), the reCAPTCHA key (both Hosting
    domains), App Check on Monitoring, the Spark plan.
  - Pre-flight for every deploy: a clean tree on main equal to
    origin/main; flutter analyze; flutter test; the Node tests in tool/;
    the secrets scan; flutter clean; flutter build web --release; node
    tool/check_web_build.mjs; build/web about 43 MB, no .map files; the
    built index.html has the noindex tag.
  - Search engines: web/index.html has <meta name="robots"
    content="noindex, nofollow"> (the company is fictional). There is no
    robots.txt that blocks crawling, so the tag can be read.
  - Rollback: the console's Hosting release history (Rollback). Firebase
    CLI 15.30.1 has no hosting:rollback command.
  - Release retention in the Hosting settings: not set now.
  - The three old test bookings stay (made-up names and numbers).
- 7.7a The cache headers of / and /cars. Tier 1 — DONE (in the commit
  "Send the start page with no-cache on every path"; deployed 2026-10-21
  after the owner's GO with firebase deploy --only hosting --project
  tbilisi-car-rental, message "Step 7.7a: no-cache for the start page";
  no prompts, 1 new file of 43).
  - The deploy command was run without extra flags; the only extra was the
    shell redirect < /dev/null (it makes a prompt fail instead of wait).
  - firebase.json: the first header rule's source is now "**" (no-cache);
    the image and font rule stays last (max-age=86400).
    tool/hosting_config.test.mjs guards the two rules, their order, the
    rewrite, the public folder and the Firestore block (JSON only). 2536
    Flutter tests and 65 Node tests pass.
  - Precedence, checked live: Hosting applies every matching header rule
    in order and the LAST one wins for the same header (not documented).
    A rule that must win goes after the general "**" rule.
  - curl -I on the live domain (all 200): no-cache for /, /cars,
    /index.html, main.dart.js, flutter_bootstrap.js, version.json,
    canvaskit.wasm and assets/NOTICES; max-age=86400 for hero.jpg, the
    MaterialIcons font, favicon.png and Icon-192.png; main.dart.js is
    served with br or gzip. firebaseapp.com answers 200; the noindex tag
    is served on both domains.
  - The owner's check in Chrome: the start page first came from the
    browser's disk cache with the OLD max-age=3600 (a copy stored before
    the fix, from the first deploy). After a hard reload (Ctrl+Shift+R) it
    came from the network with Cache-Control: no-cache and the
    Last-Modified time of the second deploy. The images, fonts and icons
    came from the disk cache. The old copy stays in a browser for up to
    one hour, and only for visitors who opened the site before the fix.
  - App Check on the live site: closed in step 7.8a (see 7.7).
- 7.7b The photos and the company values on the live site. Tier 2 — DONE
  (no code change).
  - The owner checked the live site in an Incognito window: the catalog
    shows every photo that exists, and the cars with several photos show
    all of them on the car page. Two cars have no photo and show the grey
    placeholder icon, the designed fallback. The About page shows the
    company values correctly.
  - The owner accepts the photos as they are (see 7.10a); no licence work.
- 7.8 The launcher icon and the app name. Tier 2 — DONE (in the commit
  "Add the launcher and web icons from the owner's logo"). Not deployed
  yet: step 7.8a.
  - The source: the owner's own logo (made in CorelDRAW, no third-party
    mark), an ellipse of 1025 x 689 px, 8-bit RGBA. The repo copy
    tool/icon_source/logo.png is re-encoded without metadata (no colour
    profile, no text chunks).
  - tool/make_icons.mjs makes the 15 icons with Node's own zlib, no
    package (pubspec unchanged). It centres the ellipse on a square
    canvas without stretching it, never scales up, averages with
    premultiplied alpha and writes PNGs without metadata.
    tool/make_icons.test.mjs (28 tests) checks the sizes, the missing
    metadata, the safe zones and that the committed icons are what the
    script makes. Rerun after a logo change: node tool/make_icons.mjs
    --import <logo.png>, then node tool/make_icons.mjs, then the tests.
  - Android: 5 legacy ic_launcher icons (the ellipse at 94 % on
    transparency), 5 adaptive foregrounds (66 %; the car stays inside the
    safe circle of 66 of 108 dp) and mipmap-anydpi-v26/ic_launcher.xml
    on values/colors.xml.
  - Web: favicon.png (32 px), Icon-192 and Icon-512 (94 % on
    transparency), Icon-maskable-192 and -512 (80 % on the fill colour;
    the car inside the 40 % circle).
  - The adaptive background and the maskable icons use the logo's fill
    colour #623CA5, not the theme colour #673AB7: on #673AB7 the ellipse
    edge shows as a faint oval. LOGO_FILL in the script and colors.xml
    have the same value.
  - The Android label and the web short_name are "Tbilisi Car"; the web
    title, the web name, the ARB appTitle and iOS keep "Tbilisi Car
    Rental". The Apple touch icon points at Icon-maskable-192.png (iOS
    fills transparency with black).
  - iOS skipped: for the README, "iOS icon: Flutter default, not tested".
  - Checked: 2536 Flutter tests and 93 Node tests pass; the scan has 0
    errors. The owner's checks: the web build on the local Hosting
    emulator (localhost:5000) in Incognito: the favicon, Icon-192,
    Icon-512, the maskable icons and DevTools > Application > Manifest;
    the Android emulator: the icon in the launcher, the app and recent
    apps.
  - The label "Tbilisi Car" is set in AndroidManifest.xml; the owner saw
    it in the app drawer with the release APK on the emulator (7.10) and
    on a real phone (7.11).
  - Note: a normal Chrome profile may show the old favicon from its cache
    until the site data is cleared.
- 7.8a The third Hosting deploy with the new web icons. Tier 1 — DONE
  (deployed 2026-10-21 after the owner's GO with firebase deploy --only
  hosting --project tbilisi-car-rental, message "Step 7.8a: new web
  icons"; no extra flags, no prompts; 8 new files of 43). The APK with
  the new icon comes with 7.9 and 7.10.
  - The pre-flight passed on c9b90a1: analyze, 2536 Flutter tests, 93
    Node tests, the scan 0 errors / 11 warnings, flutter clean, the
    release build, check_web_build, 43 MB, no .map files, the noindex
    tag; the five icons in build/web identical to web/.
  - curl -I on the live domain (all 200): no-cache for /, /index.html,
    /manifest.json and main.dart.js; max-age=86400 for favicon.png
    (1013 bytes), Icon-192 (8558), Icon-512 (27951), Icon-maskable-192
    (5036) and Icon-maskable-512 (16252), each length equal to the local
    file. firebaseapp.com answers 200; the noindex tag, short_name
    "Tbilisi Car" and the touch icon Icon-maskable-192.png are served.
  - App Check: the open item of 7.7 is closed (see 7.7).
  - The owner's check in Incognito on https://tbilisi-car-rental.web.app
    passed: the favicon, Icon-512, Icon-maskable-512, the manifest (short
    name "Tbilisi Car", name "Tbilisi Car Rental", four icons loaded),
    Home and a car page, and the release history showing "Step 7.8a: new
    web icons".
  - A normal Chrome profile may keep the old icons for up to one day
    (max-age=86400).
- 7.9 The release signing. Tier 1 — DONE (in the commit "Sign the Android
  release build with the owner's key").
  - android/app/build.gradle.kts: a release signing config that reads
    android/key.properties (storeFile, storePassword, keyAlias,
    keyPassword). The owner made the file himself; git ignores it and no
    tool of this project opens it. The release build no longer uses the
    debug key.
  - A release build without key.properties, with a missing value or with
    a missing keystore stops with a clear error that names no value.
    Debug builds, flutter analyze and flutter test do not need the file.
  - The keystore was made by the owner with keytool and lives outside the
    repository, with the owner's own backup: alias release, RSA 4096,
    PKCS12, valid for 10000 days, one password for store and key. With no
    Google Play there is no Play App Signing: this key is the app's only
    signing key, and every later APK must be signed with it.
  - tool/signing_files.test.mjs (5 tests) checks that git ignores and does
    not track key.properties and keystores, and that the build file reads
    the four values only from key.properties. 2536 Flutter tests and 98
    Node tests pass; the scan has 0 errors; a debug APK still builds.
  - The release APK (1.0.0+1, 59.3 MB) is signed with the owner's key:
    apksigner verifies it (v2 scheme), the signer is the owner's
    certificate (not Android Debug), and its SHA-256 and SHA-1 equal the
    keystore's (compared by the owner).
  - The SHA fingerprints are NOT added to the Firebase Android app:
    nothing in the app uses them (no Google Sign-In, no phone sign-in, no
    Play Integrity; the admin signs in with e-mail and password). So 7.10
    skips that.
- 7.10a Make the repository public. Tier 1 — DONE (the audit in the
  commit "Record the history audit before the repository goes public";
  the repository made public by the owner on 2026-10-21).
  - The history audit covered all 146 commits of the 3 refs (no stash, no
    tags): 1,099 blobs, 530 paths ever, 65 of them deleted, every commit
    message and every author and committer field.
  - Method: a one-off script run once, reusing the functions of
    tool/check_secrets.mjs; proved first on a throwaway repo with made-up
    planted values (also in deleted files and in UTF-16 binaries).
  - Result: the deny list (2 entries) had 0 matches in files, binaries,
    commit messages and author fields. No key, token, service account,
    keystore or reCAPTCHA secret. Author and committer addresses are
    GitHub noreply addresses only.
  - 3 errors, judged harmless and left (option iii): the Windows
    manifest's public OS GUIDs (old Windows template), npm's public
    deprecation text in tool/admin/package-lock.json, and a made-up
    address in an old version of a booking validation test (looked at by
    the owner). 58 phone-number warnings, all made-up test data or format
    cases (looked at by the owner), left as well. No history rewrite, no
    new repository, no force push.
  - Limits: the audit is only as complete as the 2-entry deny list, and
    the case folding in binary files covers ASCII letters only.
  - Photos: the owner accepts all photos as they are.
  - Licence of the repository: none for now (all rights reserved); look
    again in 7.12.
  - Done by the owner by hand on GitHub, after the audit: the About
    description, the website and the topics; Wiki, Issues, Projects and
    Discussions off (Sponsorships stay off); one person has access; no
    Actions and no secrets. Then, as the last click, Settings > General >
    Change visibility > Make public (2026-10-21). The release page opens
    in an Incognito window.
- 7.10 The release APK on a GitHub Release. Tier 1 — DONE (in the commit
  "Add a check that a release APK holds no secret"; the tag v1.0.0).
  It came after 7.10a: a release in a private repository cannot be
  downloaded by visitors. No SHA fingerprints in the Firebase console (see
  7.9).
  - Commit 0c2fc4e: tool/check_apk.mjs with 16 tests. It reads the APK as
    a zip with Node's zlib and checks every entry: forbidden file names,
    every deny-list text (ASCII case-folded, UTF-8 and UTF-16LE at any
    offset), the secret shapes (private key, service-account key, App
    Check debug token outside images, a reCAPTCHA secret other than the
    public site key), and e-mail addresses only in libapp.so (Dart
    private names like _name@<digits>.member are not addresses). It
    prints entry names, rule names and counts only, and fails without a
    usable deny list. Found in review before the commit: the deny-list
    texts must be case-folded like the bytes; fixed and tested.
  - The build: flutter clean, flutter build apk --release from 0c2fc4e;
    2536 Flutter tests, 114 Node tests, analyze and the secrets scan
    passed; pubspec.lock unchanged. check_apk: 198 entries, 0 findings.
    apksigner verified it (v2); the signer certificate equals that of 7.9
    (the keystore's). The APK is 62,223,547 bytes (59.3 MB), SHA-256
    e936940b95fdb6afaaadbdc21b668644c10806545896bacd218e46a24ba67007.
  - The release: the annotated tag v1.0.0 on 0c2fc4e and the GitHub
    Release "Tbilisi Car Rental 1.0.0 (Android APK)", created with gh
    after the owner's separate "GO", with the assets
    tbilisi-car-rental-1.0.0.apk and tbilisi-car-rental-1.0.0.apk.sha256.
    The notes (demo, Android 7.0+, install steps, the Play Protect note,
    the hashes, the privacy link) are on the release page only; the APK
    and the release folder never entered the repository.
  - Checked after publishing: the download URL answers 200; a fresh
    download has the same SHA-256 as the local file and the .sha256 file,
    and passes check_apk. The owner installed the same APK on
    emulator-5554 (after uninstalling the debug app) and checked the icon
    and the label "Tbilisi Car", Home, the catalog, a car page, the
    booking form (no booking sent), Privacy, Back, the language switch
    and the FAQ: all fine.
  - App Check: this APK has no App Check provider, so its requests show
    as "Unverified: outdated client". Expected; nothing is enforced.
- 7.11 Checks on a real Android phone by the owner. Tier 3 — DONE.
  - The owner downloaded the APK from the release page v1.0.0 in the
    phone's browser and installed it; the "install from this source"
    prompt and the Google Play Protect warning appeared as the release
    notes say.
  - Checked, all fine: the icon and the label "Tbilisi Car"; the four
    public tabs, with the photos; the phone and e-mail links on the About
    page (the dialer and the mail app open; nothing was called or sent);
    Android Back through the catalog, a car page and the form to Home and
    out of the app; the language switch ka, ru, en; offline with airplane
    mode (a clear message, no crash, and the catalog loads again when the
    network is back); the admin screens on the phone.
  - NOT tested: TalkBack on the FAQ (skipped by the owner; to be named in
    the README). No booking was sent (no write to the live database).
- 7.12 The final README: the live link, the APK link, screenshots, GIFs, an
  honest "how I worked" paragraph, "iOS not tested on Windows" and "possible
  future work". Tier 3 — not started.
  - The README links the release page
    https://github.com/LukaMeletidi/tbilisi-car-rental/releases/tag/v1.0.0
    and the live site. The repository licence is decided there (none for
    now, all rights reserved).
