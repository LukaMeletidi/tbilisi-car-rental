// Checks the Firestore rules for "bookings" against the LOCAL emulator.
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
// Output: one line per case (PASS or FAIL) and a summary. Exit code 1 when
// any case fails, 2 when the script refuses to start.

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

// Creates a booking the way the app does: no sign-in, one write, createdAt
// set by the server. Returns the HTTP status and the document id.
async function create(data, { serverCreatedAt = true } = {}) {
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

function accepted(name, change = () => {}) {
  cases.push({ name, expected: 200, run: () => create(booking(change)) });
}

function refused(name, change, options) {
  cases.push({
    name,
    expected: 403,
    run: () => create(booking(change), options),
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
  run: () => send('GET', `${DOCUMENTS}/${EXISTING}`),
});
cases.push({
  name: 'read: list the bookings',
  expected: 403,
  run: () => send('GET', `${DOCUMENTS}/bookings`),
});
cases.push({
  name: 'update: change the status of a booking',
  expected: 403,
  run: () =>
    send('PATCH', `${DOCUMENTS}/${EXISTING}?updateMask.fieldPaths=status`, {
      body: { fields: encodeFields({ status: 'confirmed' }) },
    }),
});
cases.push({
  name: 'update: send a complete valid booking over an existing one',
  expected: 403,
  run: () =>
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
    }),
});
cases.push({
  name: 'delete: delete a booking',
  expected: 403,
  run: () => send('DELETE', `${DOCUMENTS}/${EXISTING}`),
});

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

async function main() {
  await requireEmulator();
  console.log(`Firestore emulator at ${HOST}, project ${PROJECT}`);
  await prepare();

  let failures = 0;
  let firstAcceptedId;

  for (const testCase of cases) {
    const result = await testCase.run();
    const passed = result.status === testCase.expected;
    const word = testCase.expected === 200 ? 'accepted' : 'refused';
    const detail = passed
      ? ` (${word})`
      : ` (expected ${testCase.expected}, got ${result.status}: ` +
        `${result.text.replace(/\s+/g, ' ').slice(0, 200)})`;
    failures += report(passed, testCase.name, detail);
    if (passed && testCase.expected === 200 && result.id) {
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
  failures += report(
    Object.keys(fields).length === 12 &&
      fields.createdAt?.timestampValue !== undefined,
    'stored: an accepted booking has 12 fields and a server createdAt',
  );

  // The refused update and delete changed nothing.
  const existing = await send('GET', `${DOCUMENTS}/${EXISTING}`, {
    headers: OWNER,
  });
  failures += report(
    existing.status === 200 &&
      JSON.parse(existing.text).fields.status.stringValue === 'new',
    'stored: the existing booking is unchanged after the refused requests',
  );

  const total = cases.length + 2;
  console.log('');
  console.log(`${total - failures} of ${total} passed, ${failures} failed.`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error(`ERROR: ${error.stack ?? error}`);
  process.exit(1);
});
