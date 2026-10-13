// Checks the Firestore rules against the LOCAL emulator: the public cases
// for "bookings" (no sign-in), the admin and signed-in cases of Phase 3, and
// the cars cases of step 4.1 (an admin adds, changes, hides and shows cars).
//
// It never talks to the real database: it refuses to start unless
// FIRESTORE_EMULATOR_HOST points to this computer, and it uses a "demo-"
// project id, which exists only inside the emulator.
//
// Run it through the emulator (needs Java; no login, no packages):
//
//   firebase emulators:exec --only firestore
//     --project demo-tbilisi-car-rental "node tool/check_booking_rules.mjs"
//
// (one line). The emulator loads firestore.rules, sets
// FIRESTORE_EMULATOR_HOST for the script and stops when the script ends.
//
// Output: one line per case (PASS or FAIL) and a summary of two lines, the
// public checks and the admin and signed-in checks. Exit code 1 when any case
// fails or when the number of public checks changed, 2 when the script
// refuses to start.

// Exists only inside the emulator. Never the id of the real project.
const PROJECT = 'demo-tbilisi-car-rental';

// ---- Safety guard --------------------------------------------------------

function refuse(message) {
  console.error(`REFUSED TO RUN: ${message}`);
  console.error('This script only works against the local Firestore');
  console.error('emulator. See the comment at the top of the file.');
  process.exit(2);
}

function emulatorHost() {
  const value = process.env.FIRESTORE_EMULATOR_HOST;
  if (!value) {
    refuse('FIRESTORE_EMULATOR_HOST is not set.');
  }
  let parsed;
  try {
    parsed = new URL(`http://${value}`);
  } catch {
    refuse(`FIRESTORE_EMULATOR_HOST is not a host and port: "${value}".`);
  }
  const localNames = ['localhost', '127.0.0.1', '[::1]'];
  if (!localNames.includes(parsed.hostname) || parsed.port === '') {
    refuse(`FIRESTORE_EMULATOR_HOST is not on this computer: "${value}".`);
  }
  if (!PROJECT.startsWith('demo-')) {
    refuse(`the project id "${PROJECT}" does not start with "demo-".`);
  }
  return parsed.host;
}

const HOST = emulatorHost();

// Every request URL is built here: always http, always the local emulator.
function url(path) {
  return `http://${HOST}${path}`;
}

const DATABASE = `projects/${PROJECT}/databases/(default)`;
const DOCUMENTS = `/v1/${DATABASE}/documents`;

// The emulator's admin bypass: skips the rules. Used only to prepare data.
const OWNER = { Authorization: 'Bearer owner' };

// The real service does not answer on this address with "Ok"; the Firestore
// emulator does.
async function requireEmulator() {
  let text = '';
  try {
    text = (await (await fetch(url('/'))).text()).trim();
  } catch (error) {
    refuse(`nothing answers on ${HOST} (${error.message}).`);
  }
  if (text !== 'Ok') {
    refuse(`${HOST} does not answer like the Firestore emulator.`);
  }
}

// ---- Firestore REST helpers ----------------------------------------------

// A number that is sent as a decimal even when it is whole: Android sends
// the Dart double 45.0 this way, while the web sends it as the integer 45.
class DoubleNumber {
  constructor(value) {
    this.value = value;
  }
}
const AS_DOUBLE = (value) => new DoubleNumber(value);

function encode(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (value instanceof DoubleNumber) return { doubleValue: value.value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encode) } };
  }
  return { mapValue: { fields: encodeFields(value) } };
}

function encodeFields(map) {
  const fields = {};
  for (const [key, value] of Object.entries(map)) {
    fields[key] = encode(value);
  }
  return fields;
}

async function send(method, path, { body, headers } = {}) {
  const response = await fetch(url(path), {
    method,
    headers: { 'Content-Type': 'application/json', ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, text: await response.text() };
}

// Writes a document with the admin bypass (the rules are skipped).
async function seed(path, data) {
  const result = await send('PATCH', `${DOCUMENTS}/${path}`, {
    body: { fields: encodeFields(data) },
    headers: OWNER,
  });
  if (result.status !== 200) {
    throw new Error(`Seeding ${path} failed: ${result.status} ${result.text}`);
  }
}

let nextId = 0;

// Creates a booking the way the app does: one write, createdAt set by the
// server. Without [headers] there is no sign-in. Returns the HTTP status and
// the document id.
async function create(data, { serverCreatedAt = true, headers } = {}) {
  nextId += 1;
  const id = `case${nextId}`;
  const write = {
    update: {
      name: `${DATABASE}/documents/bookings/${id}`,
      fields: encodeFields(data),
    },
  };
  if (serverCreatedAt) {
    write.updateTransforms = [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
    ];
  }
  const result = await send('POST', `${DOCUMENTS}:commit`, {
    body: { writes: [write] },
    headers,
  });
  return { ...result, id };
}

// ---- Test data -----------------------------------------------------------

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

const now = Date.now();
const pickup = new Date(Math.floor(now / MINUTE) * MINUTE + 7 * DAY);
const after = (date, milliseconds) => new Date(date.getTime() + milliseconds);

const ACTIVE_CAR = 'activeCar';
const INACTIVE_CAR = 'inactiveCar';

// A booking that the rules must accept. Without createdAt: the server adds
// it. Every case below changes ONE thing in a fresh copy.
function validBooking() {
  return {
    customer: {
      fullName: 'Nino Beridze',
      phone: '+995555123456',
      whatsapp: true,
      telegram: false,
      email: 'nino@example.com',
    },
    carId: ACTIVE_CAR,
    pickupDateTime: pickup,
    dropoffDateTime: after(pickup, 5 * DAY),
    pickupLocation: { id: 'tbilisiAirport' },
    dropoffLocation: { id: 'tbilisiOffice' },
    extras: ['childSeat'],
    notes: 'Late arrival',
    totalPrice: 272.5,
    language: 'ru',
    status: 'new',
  };
}

function booking(change) {
  const data = validBooking();
  change(data);
  return data;
}

const letters = (count) => 'a'.repeat(count);
const emailOfLength = (count) =>
  `${letters(count - '@example.com'.length)}@example.com`;

// ---- Cases ---------------------------------------------------------------

const cases = [];

// Each case runs without sign-in. It can be run again with the headers of a
// signed-in user; the expected answer stays the same.
function accepted(name, change = () => {}) {
  cases.push({
    name,
    expected: 200,
    run: (headers) => create(booking(change), { headers }),
  });
}

function refused(name, change, options) {
  cases.push({
    name,
    expected: 403,
    run: (headers) => create(booking(change), { ...options, headers }),
  });
}

// 1. Valid bookings: these must be ACCEPTED, or the refusals prove nothing.
accepted('valid: the base booking');
accepted('valid: no extras', (b) => (b.extras = []));
accepted(
  'valid: all four extras',
  (b) => (b.extras = ['snowChains', 'childSeat', 'infantSeat', 'boosterSeat']),
);
accepted('valid: "other" pickup and dropoff locations', (b) => {
  b.pickupLocation = { id: 'other', text: 'Hotel in Batumi' };
  b.dropoffLocation = { id: 'other', text: 'Gudauri, hotel Alpina' };
});
accepted(
  'valid: "other" text of 200 characters',
  (b) => (b.pickupLocation = { id: 'other', text: letters(200) }),
);
accepted('valid: empty notes', (b) => (b.notes = ''));
accepted('valid: notes of 500 characters', (b) => (b.notes = letters(500)));
accepted(
  'valid: exactly 365 days',
  (b) => (b.dropoffDateTime = after(pickup, 365 * DAY)),
);
accepted('valid: a whole-number total', (b) => (b.totalPrice = 225));
accepted('valid: a total of 0', (b) => (b.totalPrice = 0));
accepted('valid: a total of 1,000,000', (b) => (b.totalPrice = 1000000));
accepted('valid: name of 2 characters', (b) => (b.customer.fullName = 'Li'));
accepted(
  'valid: name of 100 characters',
  (b) => (b.customer.fullName = letters(100)),
);
accepted('valid: phone of 8 digits', (b) => (b.customer.phone = '+12345678'));
accepted(
  'valid: phone of 15 digits',
  (b) => (b.customer.phone = '+123456789012345'),
);
accepted(
  'valid: e-mail of 254 characters',
  (b) => (b.customer.email = emailOfLength(254)),
);
accepted('valid: language ka', (b) => (b.language = 'ka'));
accepted('valid: language en', (b) => (b.language = 'en'));

// 2. Keys.
refused('keys: an extra top-level key', (b) => (b.discount = 10));
refused('keys: createdBy present', (b) => (b.createdBy = 'Giorgi'));
refused(
  'keys: expireAt present',
  (b) => (b.expireAt = after(pickup, 400 * DAY)),
);
for (const key of Object.keys(validBooking())) {
  refused(`keys: "${key}" missing`, (b) => delete b[key]);
}
refused('keys: an extra key inside customer', (b) => (b.customer.age = 30));
refused(
  'keys: an extra key inside a fixed location',
  (b) => (b.pickupLocation = { id: 'tbilisiAirport', note: 'gate 2' }),
);
refused(
  'keys: an extra key inside an "other" location',
  (b) => (b.pickupLocation = { id: 'other', text: 'Hotel', note: 'x' }),
);
for (const key of Object.keys(validBooking().customer)) {
  refused(`keys: customer "${key}" missing`, (b) => delete b.customer[key]);
}

// 3. Status and createdAt.
refused('status: "pending"', (b) => (b.status = 'pending'));
refused('status: "confirmed"', (b) => (b.status = 'confirmed'));
refused(
  'createdAt: a fixed date instead of the server time',
  (b) => (b.createdAt = new Date('2020-01-01T00:00:00Z')),
  { serverCreatedAt: false },
);
refused(
  'createdAt: the time of the device (a moment ago)',
  (b) => (b.createdAt = new Date(now)),
  { serverCreatedAt: false },
);
refused('createdAt: missing', () => {}, { serverCreatedAt: false });

// 4. Dates.
refused(
  'dates: pickup in the past',
  (b) => (b.pickupDateTime = new Date(now - HOUR)),
);
refused(
  'dates: dropoff equal to pickup',
  (b) => (b.dropoffDateTime = pickup),
);
refused(
  'dates: dropoff before pickup',
  (b) => (b.dropoffDateTime = after(pickup, -HOUR)),
);
refused(
  'dates: 365 days and one minute',
  (b) => (b.dropoffDateTime = after(pickup, 365 * DAY + MINUTE)),
);
refused(
  'dates: pickup is a text',
  (b) => (b.pickupDateTime = pickup.toISOString()),
);
refused(
  'dates: dropoff is a text',
  (b) => (b.dropoffDateTime = after(pickup, 5 * DAY).toISOString()),
);

// 5. Customer.
refused('name: 1 character', (b) => (b.customer.fullName = 'L'));
refused('name: 101 characters', (b) => (b.customer.fullName = letters(101)));
refused('name: a leading space', (b) => (b.customer.fullName = ' Nino'));
refused('name: a trailing space', (b) => (b.customer.fullName = 'Nino '));
refused('name: a number', (b) => (b.customer.fullName = 12345));
refused('phone: no "+"', (b) => (b.customer.phone = '995555123456'));
refused('phone: letters', (b) => (b.customer.phone = '+99555512345a'));
refused('phone: a space', (b) => (b.customer.phone = '+995 555123456'));
refused('phone: starts with 0', (b) => (b.customer.phone = '+0995551234'));
refused('phone: 7 digits', (b) => (b.customer.phone = '+1234567'));
refused('phone: 16 digits', (b) => (b.customer.phone = '+1234567890123456'));
refused('whatsapp: a text', (b) => (b.customer.whatsapp = 'yes'));
refused('telegram: a number', (b) => (b.customer.telegram = 1));
refused('email: empty', (b) => (b.customer.email = ''));
refused('email: no "@"', (b) => (b.customer.email = 'nino.example.com'));
refused('email: two "@"', (b) => (b.customer.email = 'ni@no@example.com'));
refused(
  'email: no dot in the domain',
  (b) => (b.customer.email = 'nino@example'),
);
refused('email: a space', (b) => (b.customer.email = 'ni no@example.com'));
refused(
  'email: 255 characters',
  (b) => (b.customer.email = emailOfLength(255)),
);
refused('customer: a text instead of a map', (b) => (b.customer = 'Nino'));

// 6. Notes, extras, language, total.
refused('notes: 501 characters', (b) => (b.notes = letters(501)));
refused('notes: a number', (b) => (b.notes = 5));
refused('extras: an unknown name', (b) => (b.extras = ['roofBox']));
refused(
  'extras: the same name twice',
  (b) => (b.extras = ['childSeat', 'childSeat']),
);
// Five items always repeat a name or use an unknown one; here: a repeat.
refused(
  'extras: five items',
  (b) =>
    (b.extras = [
      'snowChains',
      'childSeat',
      'infantSeat',
      'boosterSeat',
      'snowChains',
    ]),
);
refused('extras: a text instead of a list', (b) => (b.extras = 'childSeat'));
refused('language: "de"', (b) => (b.language = 'de'));
refused('language: a number', (b) => (b.language = 1));
refused('total: negative', (b) => (b.totalPrice = -1));
refused('total: above the maximum', (b) => (b.totalPrice = 1000000.01));
refused('total: a text', (b) => (b.totalPrice = '272.50'));

// 7. Locations.
refused(
  'location: "other" without text',
  (b) => (b.pickupLocation = { id: 'other' }),
);
refused(
  'location: "other" with an empty text',
  (b) => (b.pickupLocation = { id: 'other', text: '' }),
);
refused(
  'location: "other" with a text of only spaces',
  (b) => (b.pickupLocation = { id: 'other', text: '   ' }),
);
refused(
  'location: "other" with 201 characters',
  (b) => (b.dropoffLocation = { id: 'other', text: letters(201) }),
);
refused(
  'location: a fixed id with a text',
  (b) => (b.pickupLocation = { id: 'tbilisiAirport', text: 'Gate 2' }),
);
refused(
  'location: an id with a space',
  (b) => (b.dropoffLocation = { id: 'tbilisi airport' }),
);
refused(
  'location: an id that starts with a digit',
  (b) => (b.pickupLocation = { id: '1airport' }),
);
refused(
  'location: an id of 65 characters',
  (b) => (b.pickupLocation = { id: letters(65) }),
);
refused('location: no id', (b) => (b.pickupLocation = {}));
refused(
  'location: a text instead of a map',
  (b) => (b.dropoffLocation = 'tbilisiAirport'),
);

// 8. Car.
refused('car: an id that does not exist', (b) => (b.carId = 'noSuchCar'));
refused('car: a car that is not active', (b) => (b.carId = INACTIVE_CAR));
refused('car: an id with a slash', (b) => (b.carId = 'cars/activeCar'));
refused('car: an empty id', (b) => (b.carId = ''));
refused('car: a number', (b) => (b.carId = 7));

// 9. Reading, changing and deleting an existing booking, without sign-in.
const EXISTING = 'bookings/existingBooking';

cases.push({
  name: 'read: get one booking',
  expected: 403,
  run: (headers) => send('GET', `${DOCUMENTS}/${EXISTING}`, { headers }),
});
cases.push({
  name: 'read: list the bookings',
  expected: 403,
  run: (headers) => send('GET', `${DOCUMENTS}/bookings`, { headers }),
});
cases.push({
  name: 'update: change the status of a booking',
  expected: 403,
  run: (headers) =>
    send('PATCH', `${DOCUMENTS}/${EXISTING}?updateMask.fieldPaths=status`, {
      body: { fields: encodeFields({ status: 'confirmed' }) },
      headers,
    }),
});
cases.push({
  name: 'update: send a complete valid booking over an existing one',
  expected: 403,
  run: (headers) =>
    send('POST', `${DOCUMENTS}:commit`, {
      body: {
        writes: [
          {
            update: {
              name: `${DATABASE}/documents/${EXISTING}`,
              fields: encodeFields(validBooking()),
            },
            updateTransforms: [
              { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
            ],
          },
        ],
      },
      headers,
    }),
});
cases.push({
  name: 'delete: delete a booking',
  expected: 403,
  run: (headers) => send('DELETE', `${DOCUMENTS}/${EXISTING}`, { headers }),
});

// ---- Guard for the public cases ------------------------------------------
//
// Everything above is the public part: requests without sign-in. It must
// never shrink. The script stops when the number of cases changed, so a
// case cannot drop out unnoticed. Together with the two "stored" checks in
// main() these are the 104 public checks.
const PUBLIC_REQUEST_CASES = 102;
const PUBLIC_STORED_CHECKS = 2;
const PUBLIC_CHECKS = PUBLIC_REQUEST_CASES + PUBLIC_STORED_CHECKS;

if (cases.length !== PUBLIC_REQUEST_CASES) {
  console.error(
    `The public cases changed: expected ${PUBLIC_REQUEST_CASES} request ` +
      `cases, got ${cases.length}.`,
  );
  process.exit(1);
}

// ---- Signed-in requests (Phase 3) -----------------------------------------
//
// The Firestore emulator accepts a sign-in token without a signature. The
// tokens below are made here, for made-up users; no real account and no
// Firebase Auth is involved. They are worthless outside the emulator.

function testToken(uid, claims = {}) {
  const part = (value) =>
    Buffer.from(JSON.stringify(value)).toString('base64url');
  const seconds = Math.floor(now / 1000);
  const header = { alg: 'none', typ: 'JWT' };
  const payload = {
    iss: `https://securetoken.google.com/${PROJECT}`,
    aud: PROJECT,
    sub: uid,
    user_id: uid,
    auth_time: seconds,
    iat: seconds,
    exp: seconds + 3600,
    firebase: { sign_in_provider: 'password', identities: {} },
    ...claims,
  };
  return { Authorization: `Bearer ${part(header)}.${part(payload)}.` };
}

// The admin: signed in, with the custom claim admin: true.
const ADMIN = testToken('admin-user', { admin: true });

// Signed in, but without the claim. Must be treated like the public.
const NO_CLAIM = testToken('other-user');

const HIDDEN_CAR_PATH = `cars/${INACTIVE_CAR}`;

// A car document without the "active" field. Reading ".data.active" of it
// is an error in the rules, which the admin create path must survive.
const CAR_WITHOUT_ACTIVE = 'carWithoutActive';

// When the seeded bookings were "created". An update must keep it.
const SEEDED_AT = new Date(now);

let nextSeed = 0;

// Puts a booking into the emulator with the admin bypass and returns its id.
async function seedBooking(change = () => {}) {
  nextSeed += 1;
  const id = `seeded${nextSeed}`;
  await seed(`bookings/${id}`, { ...booking(change), createdAt: SEEDED_AT });
  return id;
}

// A PARTIAL update: only the named fields are sent, with an update mask, and
// the emulator merges them into the stored document. This is how the app's
// update() call works.
function updatePartial(id, values, headers) {
  const mask = Object.keys(values)
    .map((key) => `updateMask.fieldPaths=${encodeURIComponent(key)}`)
    .join('&');
  return send('PATCH', `${DOCUMENTS}/bookings/${id}?${mask}`, {
    body: { fields: encodeFields(values) },
    headers,
  });
}

// A FULL replacement: the whole document is sent and replaces the stored one
// (like set() without merge). createdAt is sent with its stored value.
function updateFull(id, change, headers) {
  const data = { ...validBooking(), createdAt: SEEDED_AT };
  change(data);
  return send('POST', `${DOCUMENTS}:commit`, {
    body: {
      writes: [
        {
          update: {
            name: `${DATABASE}/documents/bookings/${id}`,
            fields: encodeFields(data),
          },
        },
      ],
    },
    headers,
  });
}

// The stored fields of a booking, read with the admin bypass; null when the
// document does not exist.
async function storedBooking(id) {
  const result = await send('GET', `${DOCUMENTS}/bookings/${id}`, {
    headers: OWNER,
  });
  return result.status === 200 ? JSON.parse(result.text).fields : null;
}

// Turns an accepted request into a failure when the stored document is not
// what it should be.
async function andStored(result, id, isRight) {
  if (result.status !== 200) return result;
  const fields = await storedBooking(id);
  if (fields !== null && isRight(fields)) return result;
  return { status: 0, text: 'accepted, but the stored document is wrong' };
}

// An admin booking made by hand: confirmed, with the staff name.
function adminBooking(change = () => {}) {
  return booking((b) => {
    b.status = 'confirmed';
    b.createdBy = 'Giorgi';
    change(b);
  });
}

const signedInCases = [];

function signedIn(name, expected, run) {
  signedInCases.push({ name, expected, run });
}

// A. Admin reads.
signedIn('admin read: get one booking', 200, () =>
  send('GET', `${DOCUMENTS}/${EXISTING}`, { headers: ADMIN }),
);
signedIn('admin read: list all bookings', 200, () =>
  send('GET', `${DOCUMENTS}/bookings`, { headers: ADMIN }),
);
signedIn('admin read: a booking that does not exist is "not found"', 404, () =>
  send('GET', `${DOCUMENTS}/bookings/noSuchBooking`, { headers: ADMIN }),
);
signedIn('admin read: get a hidden car', 200, () =>
  send('GET', `${DOCUMENTS}/${HIDDEN_CAR_PATH}`, { headers: ADMIN }),
);
signedIn('admin read: list all cars without a filter', 200, () =>
  send('GET', `${DOCUMENTS}/cars`, { headers: ADMIN }),
);

// B. Admin updates that must be accepted, sent both ways.
for (const status of ['pending', 'confirmed', 'cancelled', 'new']) {
  const before = status === 'new' ? 'confirmed' : 'new';
  signedIn(`admin update, partial: status to "${status}"`, 200, async () => {
    const id = await seedBooking((b) => (b.status = before));
    const result = await updatePartial(id, { status }, ADMIN);
    // Only the status changed; the other 11 fields were kept.
    return andStored(
      result,
      id,
      (fields) =>
        fields.status.stringValue === status &&
        Object.keys(fields).length === 12 &&
        fields.notes.stringValue === 'Late arrival',
    );
  });
  signedIn(`admin update, full: status to "${status}"`, 200, async () => {
    const id = await seedBooking((b) => (b.status = before));
    const result = await updateFull(id, (b) => (b.status = status), ADMIN);
    return andStored(
      result,
      id,
      (fields) => fields.status.stringValue === status,
    );
  });
}
signedIn(
  'admin update, full: customer and dates, pickup in the past',
  200,
  async () => {
    const id = await seedBooking();
    return updateFull(
      id,
      (b) => {
        b.customer.fullName = 'Giorgi Maisuradze';
        b.pickupDateTime = new Date(now - 10 * DAY);
        b.dropoffDateTime = new Date(now - 5 * DAY);
      },
      ADMIN,
    );
  },
);
signedIn('admin update, partial: createdBy added', 200, async () => {
  const id = await seedBooking();
  const result = await updatePartial(id, { createdBy: 'Giorgi' }, ADMIN);
  return andStored(
    result,
    id,
    (fields) =>
      fields.createdBy.stringValue === 'Giorgi' &&
      Object.keys(fields).length === 13,
  );
});
signedIn('admin update, partial: the car changed to a hidden car', 200, async () => {
  const id = await seedBooking();
  return updatePartial(id, { carId: INACTIVE_CAR }, ADMIN);
});

// C. Admin updates that must be refused; each has one thing wrong.
function refusedPartial(name, values) {
  signedIn(`admin update refused, partial: ${name}`, 403, async () => {
    const id = await seedBooking();
    return updatePartial(id, values, ADMIN);
  });
}

function refusedFull(name, change) {
  signedIn(`admin update refused, full: ${name}`, 403, async () => {
    const id = await seedBooking();
    return updateFull(id, change, ADMIN);
  });
}

refusedPartial('status "completed"', { status: 'completed' });
refusedPartial('createdAt changed', { createdAt: new Date(now - HOUR) });
refusedPartial('expireAt', { expireAt: after(pickup, 400 * DAY) });
refusedPartial('an unknown key', { discount: 10 });
refusedFull('status "completed"', (b) => (b.status = 'completed'));
refusedFull('createdAt changed', (b) => (b.createdAt = new Date(now - HOUR)));
refusedFull('a key missing', (b) => delete b.notes);
refusedFull('phone without "+"', (b) => (b.customer.phone = '995555123456'));
refusedFull(
  'a place id with a space',
  (b) => (b.pickupLocation = { id: 'tbilisi airport' }),
);
refusedFull(
  'dropoff before pickup',
  (b) => (b.dropoffDateTime = after(pickup, -HOUR)),
);
refusedFull(
  '365 days and one minute',
  (b) => (b.dropoffDateTime = after(pickup, 365 * DAY + MINUTE)),
);
refusedFull('an unknown extra', (b) => (b.extras = ['roofBox']));
refusedFull('notes of 501 characters', (b) => (b.notes = letters(501)));
refusedFull('total negative', (b) => (b.totalPrice = -1));
refusedFull('total above the maximum', (b) => (b.totalPrice = 1000000.01));
refusedFull('language "de"', (b) => (b.language = 'de'));
refusedFull('a car that does not exist', (b) => (b.carId = 'noSuchCar'));
refusedFull('createdBy empty', (b) => (b.createdBy = ''));
refusedFull('createdBy of 101 characters', (b) => (b.createdBy = letters(101)));
refusedFull('createdBy a number', (b) => (b.createdBy = 7));

// C2. The updates the app's edit form sends (step 3.9). They mirror
// AdminBookingChanges in lib/features/admin/domain/admin_booking_edit.dart:
// a PARTIAL update with only the changed top-level fields; a nested map
// (customer, a place) and the list of extras are always sent whole; status,
// createdAt and createdBy are never sent.

// Puts a document into the emulator exactly as given (admin bypass).
async function seedRaw(data) {
  nextSeed += 1;
  const id = `seeded${nextSeed}`;
  await seed(`bookings/${id}`, data);
  return id;
}

const sameCreatedAt = (fields) =>
  new Date(fields.createdAt.timestampValue).getTime() === SEEDED_AT.getTime();

// Accepted, and afterwards the stored document still has its 12 fields,
// its createdAt and its status, and [isRight] holds.
function acceptedEdit(name, values, isRight = () => true, options = {}) {
  const status = options.status ?? 'new';
  signedIn(`admin edit: ${name}`, 200, async () => {
    const id = await seedBooking((b) => {
      b.status = status;
      options.change?.(b);
    });
    const result = await updatePartial(id, values, ADMIN);
    return andStored(
      result,
      id,
      (fields) =>
        Object.keys(fields).length === 12 &&
        sameCreatedAt(fields) &&
        fields.status.stringValue === status &&
        isRight(fields),
    );
  });
}

function refusedEdit(name, values, change = () => {}, headers = ADMIN) {
  signedIn(`admin edit refused: ${name}`, 403, async () => {
    const id = await seedBooking(change);
    return updatePartial(id, values, headers);
  });
}

const editedCustomer = {
  fullName: 'Giorgi Maisuradze',
  phone: '+995555654321',
  whatsapp: false,
  telegram: true,
  email: 'giorgi@example.com',
};
const mapOf = (field) => field.mapValue.fields;

acceptedEdit(
  'the customer, sent whole',
  { customer: editedCustomer },
  (f) =>
    mapOf(f.customer).fullName.stringValue === 'Giorgi Maisuradze' &&
    mapOf(f.customer).telegram.booleanValue === true &&
    Object.keys(mapOf(f.customer)).length === 5,
);
acceptedEdit(
  'the pickup place, a fixed place replaced by a free text',
  { pickupLocation: { id: 'other', text: 'Hotel in Batumi' } },
  (f) => mapOf(f.pickupLocation).text.stringValue === 'Hotel in Batumi',
);
acceptedEdit(
  'the drop-off place, a free text replaced by a fixed place',
  { dropoffLocation: { id: 'tbilisiAirport' } },
  (f) =>
    mapOf(f.dropoffLocation).id.stringValue === 'tbilisiAirport' &&
    Object.keys(mapOf(f.dropoffLocation)).length === 1,
  { change: (b) => (b.dropoffLocation = { id: 'other', text: 'A hotel' }) },
);
acceptedEdit(
  'the extras, sent as the whole list',
  { extras: ['snowChains', 'boosterSeat'] },
  (f) => f.extras.arrayValue.values.length === 2,
);
acceptedEdit(
  'the extras, emptied',
  { extras: [] },
  (f) => (f.extras.arrayValue.values ?? []).length === 0,
);
acceptedEdit(
  'the notes, emptied',
  { notes: '' },
  (f) => f.notes.stringValue === '',
);
acceptedEdit(
  'the language',
  { language: 'ka' },
  (f) => f.language.stringValue === 'ka',
);
acceptedEdit(
  'the car, changed to a hidden car',
  { carId: INACTIVE_CAR },
  (f) => f.carId.stringValue === INACTIVE_CAR,
);
acceptedEdit(
  'the car and the new total together',
  { carId: INACTIVE_CAR, totalPrice: 600 },
  (f) =>
    f.carId.stringValue === INACTIVE_CAR && f.totalPrice.integerValue === '600',
);
acceptedEdit(
  'the total alone, with cents',
  { totalPrice: 360.5 },
  (f) => f.totalPrice.doubleValue === 360.5,
);
acceptedEdit(
  'both dates, a pickup in the past',
  {
    pickupDateTime: new Date(now - 10 * DAY),
    dropoffDateTime: new Date(now - 5 * DAY),
  },
  (f) => new Date(f.pickupDateTime.timestampValue).getTime() < now,
);
acceptedEdit(
  'the drop-off alone, moved later',
  { dropoffDateTime: after(pickup, 9 * DAY) },
  (f) =>
    new Date(f.dropoffDateTime.timestampValue).getTime() ===
    after(pickup, 9 * DAY).getTime(),
);
acceptedEdit(
  'every field an edit can send, at once',
  {
    customer: editedCustomer,
    carId: INACTIVE_CAR,
    pickupDateTime: new Date(now - 3 * DAY),
    dropoffDateTime: new Date(now + 4 * DAY),
    pickupLocation: { id: 'other', text: 'Hotel in Batumi' },
    dropoffLocation: { id: 'tbilisiAirport' },
    extras: ['infantSeat'],
    notes: 'Changed by the admin',
    totalPrice: 840,
    language: 'en',
  },
  (f) =>
    f.notes.stringValue === 'Changed by the admin' &&
    f.language.stringValue === 'en',
);
acceptedEdit(
  'a confirmed booking: the status is not sent and stays',
  { notes: 'Changed by the admin' },
  (f) => f.notes.stringValue === 'Changed by the admin',
  { status: 'confirmed' },
);
acceptedEdit(
  'a cancelled booking can be edited too',
  { language: 'en' },
  () => true,
  { status: 'cancelled' },
);

// Refused. The first two are why the app checks the stored document before
// it writes: the rules look at the WHOLE document, so these refuse an edit
// that is itself fine.
refusedEdit(
  'the stored document has an unknown field, only the notes are sent',
  { notes: 'Changed by the admin' },
  (b) => (b.zzTest = true),
);
signedIn(
  'admin edit refused: the stored document has no createdAt',
  403,
  async () => {
    const id = await seedRaw(validBooking());
    return updatePartial(id, { notes: 'Changed by the admin' }, ADMIN);
  },
);
signedIn(
  'admin status change refused: the stored document has an unknown field',
  403,
  async () => {
    const id = await seedBooking((b) => (b.zzTest = true));
    return updatePartial(id, { status: 'confirmed' }, ADMIN);
  },
);
// A hand-made document (written in the console, not by the app) with a
// value that is not in the app's clean form, and an edit of ANOTHER part.
// The rules look at the whole document, so four of these refuse the edit;
// the app says so by name before it writes (storedFormatErrors in
// admin_booking_edit.dart). Notes are not checked for spaces by the rules.
refusedEdit(
  'hand-made: the stored phone has spaces, only the language is sent',
  { language: 'en' },
  (b) => (b.customer.phone = '+995 555 12-34-56'),
);
refusedEdit(
  'hand-made: the stored name ends with a space, only the language is sent',
  { language: 'en' },
  (b) => (b.customer.fullName = 'Nino Beridze '),
);
refusedEdit(
  'hand-made: the stored e-mail ends with a space, only the language is sent',
  { language: 'en' },
  (b) => (b.customer.email = 'nino@example.com '),
);
refusedEdit(
  'hand-made: a stored place text ends with a space, only the language is sent',
  { language: 'en' },
  (b) => (b.pickupLocation = { id: 'other', text: 'Hotel in Batumi ' }),
);
acceptedEdit(
  'hand-made: the stored notes end with a space, only the language is sent',
  { language: 'en' },
  (f) => f.notes.stringValue === 'Late arrival ',
  { change: (b) => (b.notes = 'Late arrival ') },
);
signedIn(
  'admin status change refused: hand-made: the stored phone has spaces',
  403,
  async () => {
    const id = await seedBooking(
      (b) => (b.customer.phone = '+995 555 12-34-56'),
    );
    return updatePartial(id, { status: 'confirmed' }, ADMIN);
  },
);
refusedEdit('a car that does not exist', { carId: 'noSuchCar' });
refusedEdit('createdAt sent along and changed', {
  notes: 'Changed by the admin',
  createdAt: new Date(now - HOUR),
});
refusedEdit('an unknown field sent along', {
  notes: 'Changed by the admin',
  updatedAt: new Date(now),
});
refusedEdit('the customer sent without the e-mail', {
  customer: {
    fullName: 'Giorgi Maisuradze',
    phone: '+995555654321',
    whatsapp: false,
    telegram: true,
  },
});
refusedEdit('a fixed place sent with a text', {
  pickupLocation: { id: 'tbilisiAirport', text: 'Arrivals' },
});
refusedEdit('the drop-off alone, moved before the stored pickup', {
  dropoffDateTime: after(pickup, -HOUR),
});
refusedEdit('the drop-off alone, 365 days and one minute', {
  dropoffDateTime: after(pickup, 365 * DAY + MINUTE),
});
refusedEdit('the same extra twice', { extras: ['childSeat', 'childSeat'] });
refusedEdit('a total above the maximum', { totalPrice: 1000000.01 });
refusedEdit('a negative total', { totalPrice: -0.01 });
refusedEdit('notes of 501 characters', { notes: letters(501) });
refusedEdit(
  'signed in without the claim',
  { notes: 'Changed' },
  () => {},
  NO_CLAIM,
);
refusedEdit('no sign-in', { notes: 'Changed' }, () => {}, {});

// D. Admin creates.
for (const status of ['new', 'pending', 'confirmed', 'cancelled']) {
  signedIn(`admin create: status "${status}" with createdBy`, 200, () =>
    create(adminBooking((b) => (b.status = status)), { headers: ADMIN }),
  );
}
signedIn('admin create: confirmed, without createdBy', 200, () =>
  create(adminBooking((b) => delete b.createdBy), { headers: ADMIN }),
);
signedIn('admin create: a pickup in the past', 200, () =>
  create(
    adminBooking((b) => {
      b.pickupDateTime = new Date(now - 10 * DAY);
      b.dropoffDateTime = new Date(now - 5 * DAY);
    }),
    { headers: ADMIN },
  ),
);
// The public check gives "no" here (the car is hidden); the admin check
// must still decide.
signedIn('admin create: a hidden car', 200, () =>
  create(adminBooking((b) => (b.carId = INACTIVE_CAR)), { headers: ADMIN }),
);
// The public check stops with an ERROR here (the car has no "active" field
// and there is no createdBy to refuse it earlier); the admin check must
// still decide. This is the proof for "A || B" in the create rule.
signedIn(
  'admin create: the public check errors, the admin check still decides',
  200,
  () =>
    create(
      adminBooking((b) => {
        delete b.createdBy;
        b.carId = CAR_WITHOUT_ACTIVE;
      }),
      { headers: ADMIN },
    ),
);
signedIn('admin create refused: createdAt a fixed date', 403, () =>
  create(
    adminBooking((b) => (b.createdAt = new Date('2020-01-01T00:00:00Z'))),
    { headers: ADMIN, serverCreatedAt: false },
  ),
);
signedIn('admin create refused: createdAt missing', 403, () =>
  create(adminBooking(), { headers: ADMIN, serverCreatedAt: false }),
);
signedIn('admin create refused: createdBy with a leading space', 403, () =>
  create(adminBooking((b) => (b.createdBy = ' Giorgi')), { headers: ADMIN }),
);
signedIn('admin create refused: an unknown key', 403, () =>
  create(adminBooking((b) => (b.discount = 10)), { headers: ADMIN }),
);
signedIn('admin create refused: a car that does not exist', 403, () =>
  create(adminBooking((b) => (b.carId = 'noSuchCar')), { headers: ADMIN }),
);
signedIn('admin create refused: status missing', 403, () =>
  create(adminBooking((b) => delete b.status), { headers: ADMIN }),
);

// D2. The document the "new booking" form creates (step 3.10). It mirrors
// adminNewBookingDocument and createBooking of the app: a chosen document
// ID, a write that only succeeds while the document does not exist, the 13
// fields (createdBy is the fixed word "admin"), and createdAt set by the
// server.
let nextNew = 0;

function appBooking(change = () => {}) {
  return booking((b) => {
    b.status = 'confirmed';
    b.createdBy = 'admin';
    b.language = 'en';
    change(b);
  });
}

// Creates [data] as the document [id] the way the app's transaction does.
function createWithId(id, data, { headers = ADMIN, serverCreatedAt = true } = {}) {
  const write = {
    update: {
      name: `${DATABASE}/documents/bookings/${id}`,
      fields: encodeFields(data),
    },
    currentDocument: { exists: false },
  };
  if (serverCreatedAt) {
    write.updateTransforms = [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
    ];
  }
  return send('POST', `${DOCUMENTS}:commit`, {
    body: { writes: [write] },
    headers,
  });
}

function acceptedNew(name, change = () => {}, isRight = () => true) {
  signedIn(`admin new booking: ${name}`, 200, async () => {
    nextNew += 1;
    const id = `newBooking${nextNew}`;
    const result = await createWithId(id, appBooking(change));
    return andStored(
      result,
      id,
      (f) =>
        Object.keys(f).length === 13 &&
        f.createdAt.timestampValue !== undefined &&
        f.createdBy.stringValue === 'admin' &&
        isRight(f),
    );
  });
}

function refusedNew(name, change, options) {
  signedIn(`admin new booking refused: ${name}`, 403, () => {
    nextNew += 1;
    return createWithId(`newBooking${nextNew}`, appBooking(change), options);
  });
}

for (const status of ['confirmed', 'new', 'pending', 'cancelled']) {
  acceptedNew(
    `status "${status}", createdBy "admin"`,
    (b) => (b.status = status),
    (f) => f.status.stringValue === status,
  );
}
acceptedNew(
  'the placeholder for a customer without e-mail',
  (b) => (b.customer.email = 'none@no-email.invalid'),
  (f) => mapOf(f.customer).email.stringValue === 'none@no-email.invalid',
);
acceptedNew('a hidden car', (b) => (b.carId = INACTIVE_CAR));
acceptedNew('a pickup in the past', (b) => {
  b.pickupDateTime = new Date(now - 10 * DAY);
  b.dropoffDateTime = new Date(now - 5 * DAY);
});
acceptedNew(
  'no extras, empty notes, another place as a text',
  (b) => {
    b.extras = [];
    b.notes = '';
    b.dropoffLocation = { id: 'other', text: 'Hotel in Batumi' };
  },
  (f) => (f.extras.arrayValue.values ?? []).length === 0,
);
acceptedNew('all four extras and a total with cents', (b) => {
  b.extras = ['snowChains', 'childSeat', 'infantSeat', 'boosterSeat'];
  b.totalPrice = 307.5;
});

// A second create with the same ID must not replace the first booking. The
// app never sends one (its transaction reads first); this is the server's
// own answer to it, which is not "accepted".
signedIn(
  'admin new booking: a second create with the same ID changes nothing',
  200,
  async () => {
    const id = 'newBookingTwice';
    const first = await createWithId(id, appBooking());
    if (first.status !== 200) return first;
    const second = await createWithId(
      id,
      appBooking((b) => (b.notes = 'A second booking')),
    );
    if (second.status === 200) {
      return { status: 0, text: 'the second create was accepted' };
    }
    return andStored(
      first,
      id,
      (f) => f.notes.stringValue === 'Late arrival',
    );
  },
);

refusedNew('createdAt not set by the server', () => {}, {
  serverCreatedAt: false,
});
refusedNew(
  'createdAt a fixed date',
  (b) => (b.createdAt = new Date('2020-01-01T00:00:00Z')),
  { serverCreatedAt: false },
);
refusedNew('a car that does not exist', (b) => (b.carId = 'noSuchCar'));
refusedNew('createdBy empty', (b) => (b.createdBy = ''));
refusedNew('createdBy of 101 characters', (b) => (b.createdBy = letters(101)));
refusedNew('createdBy with a space at the end', (b) => (b.createdBy = 'admin '));
refusedNew('an unknown field', (b) => (b.updatedAt = new Date(now)));
refusedNew('an empty e-mail', (b) => (b.customer.email = ''));
refusedNew('no e-mail field', (b) => delete b.customer.email);
refusedNew('a total above the maximum', (b) => (b.totalPrice = 1000000.01));
refusedNew('a phone with spaces', (b) => (b.customer.phone = '+995 555 123456'));
refusedNew('signed in without the claim', () => {}, { headers: NO_CLAIM });
refusedNew('no sign-in', () => {}, { headers: {} });

// E. Admin delete.
let deletedId;
signedIn('admin delete: delete a booking', 200, async () => {
  deletedId = await seedBooking();
  return send('DELETE', `${DOCUMENTS}/bookings/${deletedId}`, {
    headers: ADMIN,
  });
});
signedIn('admin delete: the booking is really gone', 404, () =>
  send('GET', `${DOCUMENTS}/bookings/${deletedId}`, { headers: OWNER }),
);

// E2. Deleting a booking (step 3.11). The rule is "delete: if isAdmin()":
// an admin may delete any booking, and the stored document is NOT checked,
// unlike on an update. Everybody else is refused, and then the booking is
// still there.
function deleteBookingAs(id, headers) {
  return send('DELETE', `${DOCUMENTS}/bookings/${id}`, { headers });
}

// Accepted, and afterwards the document is really gone.
function deletedByAdmin(name, change) {
  signedIn(`admin delete: ${name}`, 200, async () => {
    const id = await seedBooking(change);
    const result = await deleteBookingAs(id, ADMIN);
    if (result.status !== 200) return result;
    return (await storedBooking(id)) === null
      ? result
      : { status: 0, text: 'accepted, but the booking is still there' };
  });
}

// Refused, and afterwards the document is still there, unchanged.
function deleteRefused(name, headers) {
  signedIn(`delete refused: ${name}`, 403, async () => {
    const id = await seedBooking((b) => (b.status = 'confirmed'));
    const result = await deleteBookingAs(id, headers);
    if (result.status !== 403) return result;
    const fields = await storedBooking(id);
    return fields !== null &&
      fields.status.stringValue === 'confirmed' &&
      Object.keys(fields).length === 12
      ? result
      : { status: 0, text: 'refused, but the booking is gone or changed' };
  });
}

for (const status of ['new', 'pending', 'confirmed', 'cancelled']) {
  deletedByAdmin(`a booking with the status "${status}"`, (b) => {
    b.status = status;
  });
}
deletedByAdmin('a booking made by an admin (with createdBy)', (b) => {
  b.createdBy = 'admin';
});
// The app could not UPDATE these two (the rules check the whole document
// on an update), but it can delete them: that is the way to remove a
// broken document.
deletedByAdmin('a hand-made document with an unknown field', (b) => {
  b.zzTest = true;
});
deletedByAdmin('a hand-made document with a phone the rules refuse', (b) => {
  b.customer.phone = '+995 555 12-34-56';
});
signedIn('admin delete: a document without createdAt', 200, async () => {
  const id = await seedRaw(validBooking());
  const result = await deleteBookingAs(id, ADMIN);
  if (result.status !== 200) return result;
  return (await storedBooking(id)) === null
    ? result
    : { status: 0, text: 'accepted, but the booking is still there' };
});
// Deleting what is not there is not an error for the server. The app does
// not rely on this: its transaction reads first and says "already
// deleted".
signedIn('admin delete: a booking that does not exist (no error)', 200, () =>
  deleteBookingAs('noSuchBookingToDelete', ADMIN),
);
deleteRefused('signed in without the claim', NO_CLAIM);
deleteRefused('no sign-in', {});

// F. Admin and the other collections: settings and unknown collections may
// not be written, a car may not be deleted, and "mail" may not even be read.
// (Since step 4.1 an admin may add and change cars; see section I.)
const mark = { body: { fields: encodeFields({ ruleCheck: true }) } };
signedIn('admin refused: write settings', 403, () =>
  send(
    'PATCH',
    `${DOCUMENTS}/settings/extras?updateMask.fieldPaths=ruleCheck`,
    { ...mark, headers: ADMIN },
  ),
);
signedIn('admin refused: create a car with only two fields', 403, () =>
  send('PATCH', `${DOCUMENTS}/cars/newCar`, {
    body: { fields: encodeFields({ brand: 'Kia', active: true }) },
    headers: ADMIN,
  }),
);
signedIn('admin refused: add an unknown field to a car', 403, () =>
  send(
    'PATCH',
    `${DOCUMENTS}/cars/${ACTIVE_CAR}?updateMask.fieldPaths=ruleCheck`,
    { ...mark, headers: ADMIN },
  ),
);
signedIn('admin refused: delete a car', 403, () =>
  send('DELETE', `${DOCUMENTS}/cars/${ACTIVE_CAR}`, { headers: ADMIN }),
);
signedIn('admin refused: read "mail"', 403, () =>
  send('GET', `${DOCUMENTS}/mail/anyMail`, { headers: ADMIN }),
);
signedIn('admin refused: write "mail"', 403, () =>
  send('PATCH', `${DOCUMENTS}/mail/anyMail`, { ...mark, headers: ADMIN }),
);
signedIn('admin refused: write an unknown collection', 403, () =>
  send('PATCH', `${DOCUMENTS}/other/anyDocument`, { ...mark, headers: ADMIN }),
);

// G. Signed in WITHOUT the claim: exactly like the public. Every public
// request case runs again with such a token and must give the same answer.
for (const publicCase of cases) {
  signedIn(`no claim, as public: ${publicCase.name}`, publicCase.expected, () =>
    publicCase.run(NO_CLAIM),
  );
}
signedIn('no claim: get a hidden car', 403, () =>
  send('GET', `${DOCUMENTS}/${HIDDEN_CAR_PATH}`, { headers: NO_CLAIM }),
);
signedIn('no claim: list cars without a filter', 403, () =>
  send('GET', `${DOCUMENTS}/cars`, { headers: NO_CLAIM }),
);
const wrongClaims = { 'false': false, 'the text "true"': 'true', 'the number 1': 1 };
for (const [label, value] of Object.entries(wrongClaims)) {
  signedIn(`wrong claim (admin is ${label}): get a booking`, 403, () =>
    send('GET', `${DOCUMENTS}/${EXISTING}`, {
      headers: testToken('wrong-claim-user', { admin: value }),
    }),
  );
}
signedIn('no claim: an admin-style create (confirmed, createdBy)', 403, () =>
  create(adminBooking(), { headers: NO_CLAIM }),
);

// H. Public, cars and settings: the rules that existed before bookings.
const activeCarsQuery = {
  structuredQuery: {
    from: [{ collectionId: 'cars' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'active' },
        op: 'EQUAL',
        value: { booleanValue: true },
      },
    },
  },
};
signedIn('public: get an active car', 200, () =>
  send('GET', `${DOCUMENTS}/cars/${ACTIVE_CAR}`),
);
signedIn('public: query the cars with the active filter', 200, () =>
  send('POST', `${DOCUMENTS}:runQuery`, { body: activeCarsQuery }),
);
signedIn('public: get a hidden car', 403, () =>
  send('GET', `${DOCUMENTS}/${HIDDEN_CAR_PATH}`),
);
signedIn('public: list cars without a filter', 403, () =>
  send('GET', `${DOCUMENTS}/cars`),
);
signedIn('public: read settings', 200, () =>
  send('GET', `${DOCUMENTS}/settings/extras`),
);
signedIn('public: write settings', 403, () =>
  send(
    'PATCH',
    `${DOCUMENTS}/settings/extras?updateMask.fieldPaths=ruleCheck`,
    mark,
  ),
);

// I. Cars (step 4.1): an admin may add and change a car, the whole document
// is checked on every write, nobody may delete one, and hiding or showing
// (only "active" changes) works for every stored car.

const THIS_YEAR = new Date(now).getUTCFullYear();
const photoAddress = (n) => `https://photos.example.com/car-${n}.jpg`;

// A car that the rules must accept. Every case changes ONE thing in a fresh
// copy. All values are made up.
function validCar(change = () => {}) {
  const car = {
    brand: 'Honda',
    model: 'Civic',
    year: 2019,
    drivetrain: 'fwd',
    transmission: 'automatic',
    fuelType: 'hybrid',
    seats: 5,
    engineSize: 1.8,
    pricePerDay: 45,
    description: {
      ka: 'ეკონომიური ჰიბრიდი',
      ru: 'Экономичный гибрид',
      en: 'An economical hybrid',
    },
    photos: [photoAddress(1), photoAddress(2)],
    active: true,
  };
  change(car);
  return car;
}

// Cars put into the emulator with the admin bypass, as if they had been made
// by hand in the console before these rules existed.
const OLD_CAR = 'oldCar'; // only two fields
const OLD_CAR_TO_REPAIR = 'oldCarToRepair'; // only two fields
const OLD_CAR_TO_RENAME = 'oldCarToRename'; // only two fields
const OLD_CAR_WITH_EXTRA = 'oldCarWithExtra'; // valid, plus an unknown field
const STORED_CAR = 'storedCar'; // valid
const STORED_HIDDEN_CAR = 'storedHiddenCar'; // valid, hidden
const CAR_FOR_OTHERS = 'carForOthers'; // valid; nobody else may touch it

async function seedCars() {
  for (const id of [OLD_CAR, OLD_CAR_TO_REPAIR, OLD_CAR_TO_RENAME]) {
    await seed(`cars/${id}`, { brand: 'Lada', active: true });
  }
  await seed(`cars/${OLD_CAR_WITH_EXTRA}`, { ...validCar(), note: 'old' });
  await seed(`cars/${STORED_CAR}`, validCar());
  await seed(
    `cars/${STORED_HIDDEN_CAR}`,
    validCar((c) => (c.active = false)),
  );
  await seed(`cars/${CAR_FOR_OTHERS}`, validCar());
}

let nextCar = 0;

// Creates the car [id] the way the app will: one write that must not find
// the document. Without [headers] there is no sign-in.
function createCar(id, data, headers) {
  return send('POST', `${DOCUMENTS}:commit`, {
    body: {
      writes: [
        {
          update: {
            name: `${DATABASE}/documents/cars/${id}`,
            fields: encodeFields(data),
          },
          currentDocument: { exists: false },
        },
      ],
    },
    headers,
  });
}

// A FULL replacement of an existing car (like set() without merge).
function replaceCar(id, data, headers) {
  return send('POST', `${DOCUMENTS}:commit`, {
    body: {
      writes: [
        {
          update: {
            name: `${DATABASE}/documents/cars/${id}`,
            fields: encodeFields(data),
          },
          currentDocument: { exists: true },
        },
      ],
    },
    headers,
  });
}

// A PARTIAL update of a car: only the named fields are sent, with an update
// mask. A field in [remove] is in the mask without a value, which deletes it.
function updateCar(id, values, headers, remove = []) {
  const mask = [...Object.keys(values), ...remove]
    .map((key) => `updateMask.fieldPaths=${encodeURIComponent(key)}`)
    .join('&');
  return send('PATCH', `${DOCUMENTS}/cars/${id}?${mask}`, {
    body: { fields: encodeFields(values) },
    headers,
  });
}

// The stored fields of a car, read with the admin bypass.
async function storedCar(id) {
  const result = await send('GET', `${DOCUMENTS}/cars/${id}`, {
    headers: OWNER,
  });
  return result.status === 200 ? JSON.parse(result.text).fields : null;
}

async function andStoredCar(result, id, isRight) {
  if (result.status !== 200) return result;
  const fields = await storedCar(id);
  if (fields !== null && isRight(fields)) return result;
  return { status: 0, text: 'accepted, but the stored car is wrong' };
}

function carAccepted(name, change = () => {}) {
  nextCar += 1;
  const id = `car${nextCar}`;
  signedIn(`car, admin create: ${name}`, 200, () =>
    createCar(id, validCar(change), ADMIN),
  );
}

function carRefused(name, change) {
  nextCar += 1;
  const id = `car${nextCar}`;
  signedIn(`car, admin create refused: ${name}`, 403, () =>
    createCar(id, validCar(change), ADMIN),
  );
}

// I.1 Admin allowed: create.
const ADMIN_MADE_ACTIVE = 'adminMadeActive';
const ADMIN_MADE_HIDDEN = 'adminMadeHidden';
signedIn('car, admin create: a full car, stored with its 12 fields', 200, () =>
  createCar(ADMIN_MADE_ACTIVE, validCar(), ADMIN).then((result) =>
    andStoredCar(
      result,
      ADMIN_MADE_ACTIVE,
      (f) =>
        Object.keys(f).length === 12 &&
        f.active.booleanValue === true &&
        f.photos.arrayValue.values.length === 2,
    ),
  ),
);
signedIn('car, admin create: a hidden car', 200, () =>
  createCar(ADMIN_MADE_HIDDEN, validCar((c) => (c.active = false)), ADMIN),
);
carAccepted('without engineSize', (c) => delete c.engineSize);
carAccepted('no photos', (c) => (c.photos = []));
carAccepted('10 photos, every field at its longest', (c) => {
  c.brand = letters(40);
  c.model = letters(40);
  c.description = {
    ka: letters(1000),
    ru: letters(1000),
    en: letters(1000),
  };
  c.photos = Array.from(
    { length: 10 },
    (_, n) => `https://photos.example.com/${n}/${letters(460)}.jpg`,
  );
});
carAccepted('a photo address of exactly 500 characters', (c) => {
  c.photos = [`https://a.example/${letters(500 - 'https://a.example/'.length)}`];
});
carAccepted('a price with decimals', (c) => (c.pricePerDay = 45.5));
carAccepted('a price sent as a decimal number 45.0', (c) => {
  // Android sends a whole price as a double; see encodeDouble below.
  c.pricePerDay = AS_DOUBLE(45);
});
carAccepted('the highest price, 2000', (c) => (c.pricePerDay = 2000));
carAccepted('engineSize as a whole number', (c) => (c.engineSize = 2));
carAccepted('the largest engineSize, 8', (c) => (c.engineSize = 8));
carAccepted('year 1990', (c) => (c.year = 1990));
carAccepted('year: this year plus one', (c) => (c.year = THIS_YEAR + 1));
carAccepted('1 seat', (c) => (c.seats = 1));
carAccepted('9 seats', (c) => (c.seats = 9));
carAccepted('a brand of one character', (c) => (c.brand = 'X'));
// The length is counted in characters, not in bytes: a Georgian letter
// takes three bytes.
carAccepted('a Georgian description of exactly 1000 letters', (c) => {
  c.description.ka = 'ა'.repeat(1000);
});
carRefused('description: a Georgian text of 1001 letters', (c) => {
  c.description.ka = 'ა'.repeat(1001);
});
carAccepted('a description with a line break inside', (c) => {
  c.description.en = 'First line\nSecond line';
});
for (const value of ['fwd', 'rwd', 'awd']) {
  carAccepted(`drivetrain ${value}`, (c) => (c.drivetrain = value));
}
for (const value of ['automatic', 'manual']) {
  carAccepted(`transmission ${value}`, (c) => (c.transmission = value));
}
for (const value of ['petrol', 'diesel', 'hybrid', 'electric']) {
  carAccepted(`fuelType ${value}`, (c) => (c.fuelType = value));
}
carAccepted('an electric car with an engineSize (not forbidden)', (c) => {
  c.fuelType = 'electric';
});

// I.2 Admin allowed: update.
signedIn('car, admin update: change the price (partial)', 200, () =>
  updateCar(STORED_CAR, { pricePerDay: 60 }, ADMIN).then((result) =>
    andStoredCar(
      result,
      STORED_CAR,
      (f) => f.pricePerDay.integerValue === '60' && f.brand !== undefined,
    ),
  ),
);
signedIn('car, admin update: hide a valid car', 200, () =>
  updateCar(STORED_CAR, { active: false }, ADMIN).then((result) =>
    andStoredCar(result, STORED_CAR, (f) => f.active.booleanValue === false),
  ),
);
signedIn('car, admin update: show it again', 200, () =>
  updateCar(STORED_CAR, { active: true }, ADMIN).then((result) =>
    andStoredCar(result, STORED_CAR, (f) => f.active.booleanValue === true),
  ),
);
signedIn('car, admin update: replace every field', 200, () =>
  replaceCar(
    STORED_CAR,
    validCar((c) => {
      c.brand = 'Kia';
      c.model = 'Sportage';
      c.year = 2021;
      c.drivetrain = 'awd';
      c.transmission = 'manual';
      c.fuelType = 'diesel';
      c.seats = 7;
      c.engineSize = 2;
      c.pricePerDay = 70;
      c.description = { ka: 'ქართული', ru: 'Русский', en: 'English' };
      c.photos = [photoAddress(9)];
      c.active = false;
    }),
    ADMIN,
  ).then((result) =>
    andStoredCar(
      result,
      STORED_CAR,
      (f) => f.brand.stringValue === 'Kia' && Object.keys(f).length === 12,
    ),
  ),
);
signedIn('car, admin update: remove engineSize', 200, () =>
  updateCar(STORED_CAR, {}, ADMIN, ['engineSize']).then((result) =>
    andStoredCar(
      result,
      STORED_CAR,
      (f) => f.engineSize === undefined && Object.keys(f).length === 11,
    ),
  ),
);
signedIn('car, admin update: an old incomplete car is repaired by a full '
  + 'replacement', 200, () =>
  replaceCar(OLD_CAR_TO_REPAIR, validCar(), ADMIN).then((result) =>
    andStoredCar(
      result,
      OLD_CAR_TO_REPAIR,
      (f) => Object.keys(f).length === 12,
    ),
  ),
);
signedIn('car, admin update: a full replacement drops an unknown field of an '
  + 'old car', 200, () =>
  replaceCar(OLD_CAR_WITH_EXTRA, validCar(), ADMIN).then((result) =>
    andStoredCar(
      result,
      OLD_CAR_WITH_EXTRA,
      (f) => f.note === undefined,
    ),
  ),
);

// I.3 Admin refused, field by field (create).
for (const field of ['brand', 'model']) {
  carRefused(`${field}: missing`, (c) => delete c[field]);
  carRefused(`${field}: empty`, (c) => (c[field] = ''));
  carRefused(`${field}: 41 characters`, (c) => (c[field] = letters(41)));
  carRefused(`${field}: a space in front`, (c) => (c[field] = ' Kia'));
  carRefused(`${field}: a space at the end`, (c) => (c[field] = 'Kia '));
  carRefused(`${field}: a number`, (c) => (c[field] = 5));
}
carRefused('year: missing', (c) => delete c.year);
carRefused('year: 1989', (c) => (c.year = 1989));
carRefused('year: this year plus two', (c) => (c.year = THIS_YEAR + 2));
carRefused('year: 2019.5', (c) => (c.year = 2019.5));
carRefused('year: sent as the decimal number 2019.0', (c) => {
  c.year = AS_DOUBLE(2019);
});
carRefused('year: the text "2019"', (c) => (c.year = '2019'));
carRefused('drivetrain: missing', (c) => delete c.drivetrain);
carRefused('drivetrain: "4wd"', (c) => (c.drivetrain = '4wd'));
carRefused('drivetrain: "FWD"', (c) => (c.drivetrain = 'FWD'));
carRefused('drivetrain: a number', (c) => (c.drivetrain = 4));
carRefused('transmission: missing', (c) => delete c.transmission);
carRefused('transmission: "auto"', (c) => (c.transmission = 'auto'));
carRefused('transmission: "Automatic"', (c) => (c.transmission = 'Automatic'));
carRefused('fuelType: missing', (c) => delete c.fuelType);
carRefused('fuelType: "gas"', (c) => (c.fuelType = 'gas'));
carRefused('fuelType: "Petrol"', (c) => (c.fuelType = 'Petrol'));
carRefused('seats: missing', (c) => delete c.seats);
carRefused('seats: 0', (c) => (c.seats = 0));
carRefused('seats: 10', (c) => (c.seats = 10));
carRefused('seats: 4.5', (c) => (c.seats = 4.5));
carRefused('seats: the text "5"', (c) => (c.seats = '5'));
carRefused('engineSize: 0', (c) => (c.engineSize = 0));
carRefused('engineSize: negative', (c) => (c.engineSize = -1.6));
carRefused('engineSize: 8.1', (c) => (c.engineSize = 8.1));
carRefused('engineSize: the text "1.8"', (c) => (c.engineSize = '1.8'));
carRefused('engineSize: null', (c) => (c.engineSize = null));
carRefused('pricePerDay: missing', (c) => delete c.pricePerDay);
carRefused('pricePerDay: 0', (c) => (c.pricePerDay = 0));
carRefused('pricePerDay: negative', (c) => (c.pricePerDay = -45));
carRefused('pricePerDay: 2000.01', (c) => (c.pricePerDay = 2000.01));
carRefused('pricePerDay: the text "45"', (c) => (c.pricePerDay = '45'));
carRefused('description: missing', (c) => delete c.description);
carRefused('description: a text instead of a map', (c) => {
  c.description = 'An economical hybrid';
});
for (const language of ['ka', 'ru', 'en']) {
  carRefused(`description: without ${language}`, (c) => {
    delete c.description[language];
  });
}
carRefused('description: an empty en', (c) => (c.description.en = ''));
carRefused('description: en of 1001 characters', (c) => {
  c.description.en = letters(1001);
});
carRefused('description: a space at the end of ru', (c) => {
  c.description.ru = 'Экономичный гибрид ';
});
carRefused('description: a line break at the end of ka', (c) => {
  c.description.ka = 'ეკონომიური ჰიბრიდი\n';
});
carRefused('description: an extra language "de"', (c) => {
  c.description.de = 'Ein sparsamer Hybrid';
});
carRefused('description: a number as a text', (c) => (c.description.en = 5));
carRefused('photos: missing', (c) => delete c.photos);
carRefused('photos: a text instead of a list', (c) => {
  c.photos = photoAddress(1);
});
carRefused('photos: 11 addresses', (c) => {
  c.photos = Array.from({ length: 11 }, (_, n) => photoAddress(n));
});
carRefused('photos: an http address', (c) => {
  c.photos = ['http://photos.example.com/car.jpg'];
});
carRefused('photos: an address without a dot', (c) => {
  c.photos = ['https://localhost/car'];
});
carRefused('photos: a space inside the address', (c) => {
  c.photos = ['https://photos.example.com/my car.jpg'];
});
carRefused('photos: an address of 501 characters', (c) => {
  c.photos = [`https://a.example/${letters(501 - 'https://a.example/'.length)}`];
});
carRefused('photos: a number in the list', (c) => {
  c.photos = [photoAddress(1), 5];
});
carRefused('photos: the same address twice', (c) => {
  c.photos = [photoAddress(1), photoAddress(1)];
});
carRefused('photos: a bad address in the tenth place', (c) => {
  c.photos = Array.from({ length: 10 }, (_, n) => photoAddress(n));
  c.photos[9] = 'http://photos.example.com/last.jpg';
});
carRefused('photos: an empty text', (c) => (c.photos = ['']));
carRefused('photos: "https://" alone', (c) => (c.photos = ['https://']));
carRefused('active: missing', (c) => delete c.active);
carRefused('active: the text "true"', (c) => (c.active = 'true'));
carRefused('active: null', (c) => (c.active = null));

// I.4 Unknown fields. (An update that adds one to an old car is in section F:
// "admin refused: add an unknown field to a car".)
carRefused('an unknown field', (c) => (c.createdAt = new Date(now)));
signedIn('car, admin update refused: add an unknown field to a valid car',
  403, () => updateCar(CAR_FOR_OTHERS, { note: 'x' }, ADMIN));
signedIn('car, admin update refused: a full replacement with an unknown '
  + 'field', 403, () =>
  replaceCar(CAR_FOR_OTHERS, validCar((c) => (c.note = 'x')), ADMIN));

// I.5 Updates that are judged by the whole document.
signedIn('car, admin update refused: a valid car gets the price 0', 403, () =>
  updateCar(CAR_FOR_OTHERS, { pricePerDay: 0 }, ADMIN),
);
signedIn('car, admin update refused: an old incomplete car gets only a new '
  + 'brand', 403, () => updateCar(OLD_CAR_TO_RENAME, { brand: 'Kia' }, ADMIN));
signedIn('car, admin update refused: a required field is removed', 403, () =>
  updateCar(CAR_FOR_OTHERS, {}, ADMIN, ['model']),
);

// I.6 The ID of a new car.
signedIn('car, admin create refused: an ID with a dot', 403, () =>
  createCar('bad.id', validCar(), ADMIN),
);
signedIn('car, admin create refused: an ID of 129 characters', 403, () =>
  createCar(letters(129), validCar(), ADMIN),
);
signedIn('car, admin create: an ID of 128 characters', 200, () =>
  createCar(letters(128), validCar(), ADMIN),
);

// I.7 Hiding and showing always works: only "active" changes.
signedIn('car, hide: an old incomplete car', 200, () =>
  updateCar(OLD_CAR, { active: false }, ADMIN).then((result) =>
    andStoredCar(
      result,
      OLD_CAR,
      (f) => f.active.booleanValue === false && Object.keys(f).length === 2,
    ),
  ),
);
signedIn('car, show: the old incomplete car again', 200, () =>
  updateCar(OLD_CAR, { active: true }, ADMIN).then((result) =>
    andStoredCar(result, OLD_CAR, (f) => f.active.booleanValue === true),
  ),
);
signedIn('car, hide: an old car that has no "active" field yet', 200, () =>
  updateCar(CAR_WITHOUT_ACTIVE, { active: false }, ADMIN),
);
signedIn('car, hide refused: an old incomplete car, "active" and the brand '
  + 'together', 403, () =>
  updateCar(OLD_CAR, { active: false, brand: 'Kia' }, ADMIN));
signedIn('car, hide refused: "active" as the text "false"', 403, () =>
  updateCar(OLD_CAR, { active: 'false' }, ADMIN),
);
signedIn('car, hide refused: "active" as null', 403, () =>
  updateCar(OLD_CAR, { active: null }, ADMIN),
);
signedIn('car, hide refused: "active" removed', 403, () =>
  updateCar(OLD_CAR, {}, ADMIN, ['active']),
);
signedIn('car, hide refused: a valid car, "active" as a text', 403, () =>
  updateCar(CAR_FOR_OTHERS, { active: 'false' }, ADMIN),
);
signedIn('car, hide with another field on a valid car: judged as a whole and '
  + 'accepted', 200, () =>
  updateCar(ADMIN_MADE_HIDDEN, { active: false, pricePerDay: 50 }, ADMIN));
signedIn('car, hide with another field on a valid car: judged as a whole and '
  + 'refused', 403, () =>
  updateCar(CAR_FOR_OTHERS, { active: false, pricePerDay: 0 }, ADMIN));
signedIn('car, hide refused: the public', 403, () =>
  updateCar(OLD_CAR, { active: false }),
);
signedIn('car, hide refused: signed in without the claim', 403, () =>
  updateCar(OLD_CAR, { active: false }, NO_CLAIM),
);
for (const [label, value] of Object.entries(wrongClaims)) {
  signedIn(`car, hide refused: wrong claim (admin is ${label})`, 403, () =>
    updateCar(
      OLD_CAR,
      { active: false },
      testToken('wrong-claim-user', { admin: value }),
    ),
  );
}
signedIn('car, stored: the old car is still shown after the refused requests',
  200, () =>
  andStoredCar({ status: 200, text: '' }, OLD_CAR, (f) =>
    f.active.booleanValue === true && f.brand.stringValue === 'Lada'));

// I.8 Nobody deletes a car. (An active one: section F.)
signedIn('car, admin refused: delete a hidden car', 403, () =>
  send('DELETE', `${DOCUMENTS}/cars/${STORED_HIDDEN_CAR}`, { headers: ADMIN }),
);
signedIn('car, admin refused: delete a car the admin created', 403, () =>
  send('DELETE', `${DOCUMENTS}/cars/${ADMIN_MADE_ACTIVE}`, { headers: ADMIN }),
);

// I.9 Everybody else: no create, no update, no delete.
const others = {
  'the public': undefined,
  'signed in without the claim': NO_CLAIM,
  'wrong claim (admin is the text "true")': testToken('wrong-claim-user', {
    admin: 'true',
  }),
};
for (const [who, headers] of Object.entries(others)) {
  nextCar += 1;
  const id = `car${nextCar}`;
  signedIn(`car, refused for ${who}: create a valid car`, 403, () =>
    createCar(id, validCar(), headers),
  );
  signedIn(`car, refused for ${who}: change the price`, 403, () =>
    updateCar(CAR_FOR_OTHERS, { pricePerDay: 1 }, headers),
  );
  signedIn(`car, refused for ${who}: replace a car`, 403, () =>
    replaceCar(CAR_FOR_OTHERS, validCar(), headers),
  );
  signedIn(`car, refused for ${who}: delete a car`, 403, () =>
    send('DELETE', `${DOCUMENTS}/cars/${CAR_FOR_OTHERS}`, { headers }),
  );
}
signedIn('car, stored: the car is unchanged after the refused requests', 200,
  () =>
  andStoredCar({ status: 200, text: '' }, CAR_FOR_OTHERS, (f) =>
    f.pricePerDay.integerValue === '45' && Object.keys(f).length === 12));

// I.10 Reading is as before, also for cars an admin created.
signedIn('car, public read: an active car the admin created', 200, () =>
  send('GET', `${DOCUMENTS}/cars/${ADMIN_MADE_ACTIVE}`),
);
signedIn('car, public read refused: a hidden car the admin created', 403, () =>
  send('GET', `${DOCUMENTS}/cars/${ADMIN_MADE_HIDDEN}`),
);
signedIn('car, public query with the active filter: holds the active car and '
  + 'not the hidden one', 200, async () => {
  const result = await send('POST', `${DOCUMENTS}:runQuery`, {
    body: activeCarsQuery,
  });
  if (result.status !== 200) return result;
  const names = JSON.parse(result.text)
    .map((row) => row.document?.name ?? '')
    .map((name) => name.split('/').pop());
  const right =
    names.includes(ADMIN_MADE_ACTIVE) && !names.includes(ADMIN_MADE_HIDDEN);
  return right ? result : { status: 0, text: 'the wrong cars came back' };
});
signedIn('car, public read refused: list cars without a filter', 403, () =>
  send('GET', `${DOCUMENTS}/cars`),
);
signedIn('car, admin read: a hidden car the admin created', 200, () =>
  send('GET', `${DOCUMENTS}/cars/${ADMIN_MADE_HIDDEN}`, { headers: ADMIN }),
);

// I.11 A booking still follows the car.
signedIn('car, public booking: accepted for an active car the admin created',
  200, () => create(booking((b) => (b.carId = ADMIN_MADE_ACTIVE))));
signedIn('car, public booking: refused for a hidden car the admin created',
  403, () => create(booking((b) => (b.carId = ADMIN_MADE_HIDDEN))));

// ---- Run -----------------------------------------------------------------

async function prepare() {
  // Empty the emulator's database, then add what the rules look up.
  const cleared = await send(
    'DELETE',
    `/emulator/v1/${DATABASE}/documents`,
    { headers: OWNER },
  );
  if (cleared.status !== 200) {
    throw new Error(`Clearing the emulator failed: ${cleared.status}`);
  }
  await seed(`cars/${ACTIVE_CAR}`, { brand: 'Toyota', active: true });
  await seed(`cars/${INACTIVE_CAR}`, { brand: 'Honda', active: false });
  await seed(`cars/${CAR_WITHOUT_ACTIVE}`, { brand: 'Mazda' });
  await seedCars();
  await seed('settings/extras', {
    pricesPerDay: {
      snowChains: 5,
      childSeat: 5,
      infantSeat: 5,
      boosterSeat: 5,
    },
  });
  await seed('settings/locations', {
    items: [
      { id: 'tbilisiAirport', name: { en: 'Tbilisi Airport' } },
      { id: 'tbilisiOffice', name: { en: 'Tbilisi Office' } },
    ],
  });
  await seed(EXISTING, {
    ...validBooking(),
    createdAt: new Date(now),
  });
}

function report(passed, name, detail = '') {
  console.log(`${passed ? 'PASS' : 'FAIL'}  ${name}${detail}`);
  return passed ? 0 : 1;
}

const words = { 200: 'accepted', 403: 'refused', 404: 'not found' };

// Runs one request case and prints its line. Returns 1 for a failure.
async function runCase(testCase, headers) {
  const result = await testCase.run(headers);
  const passed = result.status === testCase.expected;
  const detail = passed
    ? ` (${words[testCase.expected]})`
    : ` (expected ${testCase.expected}, got ${result.status}: ` +
      `${result.text.replace(/\s+/g, ' ').slice(0, 200)})`;
  return { failed: report(passed, testCase.name, detail), result };
}

async function main() {
  await requireEmulator();
  console.log(`Firestore emulator at ${HOST}, project ${PROJECT}`);
  await prepare();

  // ---- The public checks: no sign-in.
  let publicFailures = 0;
  let publicRun = 0;
  let firstAcceptedId;

  for (const testCase of cases) {
    const { failed, result } = await runCase(testCase);
    publicFailures += failed;
    publicRun += 1;
    if (!failed && testCase.expected === 200 && result.id) {
      firstAcceptedId ??= result.id;
    }
  }

  // An accepted booking is really stored, with the server's createdAt.
  let stored = { status: 0, text: '' };
  if (firstAcceptedId) {
    stored = await send('GET', `${DOCUMENTS}/bookings/${firstAcceptedId}`, {
      headers: OWNER,
    });
  }
  const fields = stored.status === 200 ? JSON.parse(stored.text).fields : {};
  publicFailures += report(
    Object.keys(fields).length === 12 &&
      fields.createdAt?.timestampValue !== undefined,
    'stored: an accepted booking has 12 fields and a server createdAt',
  );
  publicRun += 1;

  // The refused update and delete changed nothing.
  const existing = await send('GET', `${DOCUMENTS}/${EXISTING}`, {
    headers: OWNER,
  });
  publicFailures += report(
    existing.status === 200 &&
      JSON.parse(existing.text).fields.status.stringValue === 'new',
    'stored: the existing booking is unchanged after the refused requests',
  );
  publicRun += 1;

  // ---- Admin, signed in without the claim, and the older public rules.
  let signedInFailures = 0;
  for (const testCase of signedInCases) {
    signedInFailures += (await runCase(testCase)).failed;
  }

  const publicPassed = publicRun - publicFailures;
  const signedInTotal = signedInCases.length;
  console.log('');
  console.log(
    `Public (unchanged): ${publicPassed} of ${publicRun}` +
      (publicRun === PUBLIC_CHECKS ? '' : ` (EXPECTED ${PUBLIC_CHECKS})`),
  );
  console.log(
    `Admin and signed-in: ${signedInTotal - signedInFailures} of ` +
      `${signedInTotal}`,
  );

  if (publicRun !== PUBLIC_CHECKS) {
    console.error(
      `The public cases changed: expected ${PUBLIC_CHECKS}, got ${publicRun}.`,
    );
    process.exit(1);
  }
  process.exit(publicFailures + signedInFailures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error(`ERROR: ${error.stack ?? error}`);
  process.exit(1);
});
