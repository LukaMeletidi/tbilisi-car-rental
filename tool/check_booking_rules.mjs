// Checks the Firestore rules against the LOCAL emulator: the public cases
// for "bookings" (no sign-in), and the admin and signed-in cases of Phase 3.
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

function encode(value) {
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
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

// F. Admin and the other collections: nothing may be written, and "mail"
// may not even be read.
const mark = { body: { fields: encodeFields({ ruleCheck: true }) } };
signedIn('admin refused: write settings', 403, () =>
  send(
    'PATCH',
    `${DOCUMENTS}/settings/extras?updateMask.fieldPaths=ruleCheck`,
    { ...mark, headers: ADMIN },
  ),
);
signedIn('admin refused: create a car', 403, () =>
  send('PATCH', `${DOCUMENTS}/cars/newCar`, {
    body: { fields: encodeFields({ brand: 'Kia', active: true }) },
    headers: ADMIN,
  }),
);
signedIn('admin refused: change a car', 403, () =>
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
