// Tests for tool/check_secrets.mjs. Run them with:
//
//   node --test tool/check_secrets.test.mjs
//
// Every sample is made up, and is put together at run time from pieces, so
// that this file itself holds nothing the scan would report. The tests of
// the staged mode work in a temporary git repository outside this one.

import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  unlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  DENYLIST_PATH,
  forbiddenFileRule,
  isAllowedEmail,
  isBinary,
  isSkippedPath,
  listFiles,
  loadDenylist,
  mask,
  report,
  scanRepo,
  scanText,
} from './check_secrets.mjs';

// ---- Made-up samples, assembled from pieces -------------------------------

const at = '@';
const quote = '"';
const dashes = '-'.repeat(5);
const letters = (count, letter = 'a') => letter.repeat(count);

const privateKeyLine = `${dashes}BEGIN ${'PRIVATE'} KEY${dashes}`;
const rsaKeyLine = `${dashes}BEGIN RSA ${'PRIVATE'} KEY${dashes}`;
const serviceAccountType = [
  `${quote}type${quote}`,
  `${quote}service_${'account'}${quote}`,
].join(': ');
const privateKeyField = `${quote}private${'_'}key${quote}: ${quote}x${quote}`;
const privateKeyIdField = `${quote}private${'_'}key_id${quote}: ${quote}x${quote}`;
const apiKey = `${'AI'}za${letters(35, 'B')}`;
const passwordLine = (value) => `pass${'word'} = '${value}'`;
// The API key as the Firebase configuration files have it, and as a
// constant in some other file.
const apiKeyField = [['api', 'Key'].join(''), `'${apiKey}',`].join(': ');
const keyConstant = [['const', 'key'].join(' '), `'${apiKey}';`].join(' = ');
const uuid = [8, 4, 4, 4, 12].map((n) => letters(n, 'a')).join('-');
// Not at a reserved domain, so the scan must report it.
const otherAddress = `someone${at}mail.${'company'}.org`;
const exampleAddress = `someone${at}example.com`;
const placeholderAddress = `none${at}no-email.invalid`;
const trailerAddress = `noreply${at}anthropic.com`;
const fakePhone = `+995 ${'555'} 12 34 56`;
const otherPhone = `+995 ${'577'} 12 34 56`;
const idOf = (length) => `'${('aB3' + letters(length)).slice(0, length)}'`;

const rules = (findings) => findings.map((f) => `${f.level}:${f.rule}`);
const scan = (text, path = 'lib/sample.dart') => scanText(path, text);

// ---- Errors ----------------------------------------------------------------

test('a private key block is an error', () => {
  assert.deepEqual(rules(scan(privateKeyLine)), ['error:private-key']);
  assert.deepEqual(rules(scan(rsaKeyLine)), ['error:private-key']);
});

test('the marks of a service account key file are errors', () => {
  assert.deepEqual(rules(scan(serviceAccountType)), [
    'error:service-account-key',
  ]);
  assert.deepEqual(rules(scan(privateKeyField)), ['error:service-account-key']);
  assert.deepEqual(rules(scan(privateKeyIdField)), [
    'error:service-account-key',
  ]);
});

test('a Google API key is an error outside the two allowed files', () => {
  const line = `const key = ${apiKey};`;
  assert.deepEqual(rules(scan(line)), ['error:google-api-key']);
  assert.deepEqual(rules(scan(line, 'web/index.html')), [
    'error:google-api-key',
  ]);
});

test('a Google API key is allowed in the two Firebase config files', () => {
  const line = apiKeyField;
  assert.deepEqual(scan(line, 'lib/firebase_options.dart'), []);
  assert.deepEqual(scan(line, 'android/app/google-services.json'), []);
  // Also when the path arrives with Windows separators.
  assert.deepEqual(scan(line, 'lib\\firebase_options.dart'), []);
  // But not in a file that only has a similar name.
  assert.deepEqual(rules(scan(line, 'lib/other/firebase_options.dart')), [
    'error:google-api-key',
    'error:secret-value',
  ]);
});

test('in the two config files ONLY the API key is let through', () => {
  for (const path of [
    'lib/firebase_options.dart',
    'android/app/google-services.json',
  ]) {
    // Another password-like value in the same file is still an error...
    assert.deepEqual(rules(scan(passwordLine('hunter2hunter2'), path)), [
      'error:secret-value',
    ]);
    const other = [['api', 'Key'].join(''), "'hunter2hunter2',"].join(': ');
    assert.deepEqual(rules(scan(other, path)), ['error:secret-value']);
    // ...and so is everything else.
    assert.deepEqual(rules(scan(privateKeyLine, path)), ['error:private-key']);
    assert.deepEqual(rules(scan(otherAddress, path)), ['error:email-address']);
    // The API key itself is not, next to such a line or alone.
    assert.deepEqual(
      rules(scan([apiKeyField, passwordLine('hunter2hunter2')].join('\n'), path)),
      ['error:secret-value'],
    );
    assert.deepEqual(scan(apiKeyField, path), []);
  }
});

test('a password, token or secret written as a value is an error', () => {
  const names = [
    'password', 'passwd', 'pwd', 'secret', 'token', 'apiKey', 'api_key',
    'API-KEY',
  ];
  for (const name of names) {
    for (const line of [
      `${name} = 'hunter2hunter2'`,
      `${name}: "hunter2hunter2"`,
      `"${name}": "hunter2hunter2"`,
    ]) {
      assert.deepEqual(rules(scan(line)), ['error:secret-value'], line);
    }
  }
});

test('a made-up value, a short value and a plain word are no secret', () => {
  for (const line of [
    passwordLine('made-up-password-123'),
    passwordLine('fake-key-for-tests'),
    passwordLine('example-value'),
    passwordLine('abc'),
    'final password = passwordController.text;',
    "const adminPasswordLabel = 'Password';",
    "const adminShowPassword = 'Show the password';",
    'token: token,',
  ]) {
    assert.deepEqual(scan(line), [], line);
  }
});

test('something shaped like an App Check debug token is an error', () => {
  assert.deepEqual(rules(scan(`token ${uuid}`)), ['error:debug-token-shape']);
  assert.deepEqual(rules(scan(uuid.toUpperCase())), ['error:debug-token-shape']);
});

test('an e-mail address outside the allow list is an error', () => {
  const georgian = `n.b+cars${at}mail.${'example'}.ge`;
  for (const address of [
    `someone${at}mail.${'company'}.org`,
    georgian,
    `someone${at}${'gmail'}.com`,
  ]) {
    assert.deepEqual(rules(scan(`to: ${address}`)), ['error:email-address']);
    assert.equal(isAllowedEmail(address), false);
  }
});

test('a look-alike of a reserved domain is still an error', () => {
  for (const address of [
    // A reserved name in the middle is worth nothing: the END counts.
    `someone${at}example.com.evil.org`,
    `someone${at}example.org.evil.com`,
    `someone${at}test.evil.org`,
    `someone${at}invalid.evil.org`,
    // Not the reserved name, only something that contains it.
    `someone${at}notexample.org`,
    `someone${at}myexample.com`,
    `someone${at}example.co`,
    `someone${at}example.com.ge`,
    `someone${at}mail.examples`,
    // The two exact addresses, with something added.
    `none${at}no-email.invalid.org`,
    `x${trailerAddress}.org`,
    `other${at}anthropic.com`,
  ]) {
    assert.equal(isAllowedEmail(address), false, 'look-alike');
    assert.deepEqual(rules(scan(address)), ['error:email-address'], 'look-alike');
  }
});

test('addresses at the reserved example domains are not reported', () => {
  for (const address of [
    exampleAddress,
    `Nino.Beridze+cars${at}example.com`,
    `someone${at}example.net`,
    `someone${at}example.org`,
    // Sub-domains of them.
    `n.b+cars${at}mail.example.com`,
    `someone${at}a.b.example.org`,
    `someone${at}MAIL.Example.NET`,
  ]) {
    assert.equal(isAllowedEmail(address), true, 'reserved domain');
    assert.deepEqual(scan(`<${address}>`), [], 'reserved domain');
  }
});

test('addresses that end in a reserved label are not reported', () => {
  for (const address of [
    `fake${at}project.iam.example`,
    `someone${at}company.example`,
    `someone${at}nothing.invalid`,
    `someone${at}my.test`,
    `someone${at}mail.localhost`,
    `someone${at}Company.EXAMPLE`,
  ]) {
    assert.equal(isAllowedEmail(address), true, 'reserved ending');
    assert.deepEqual(scan(`<${address}>`), [], 'reserved ending');
  }
});

test('the placeholder and the trailer address are not reported', () => {
  for (const address of [placeholderAddress, trailerAddress]) {
    assert.equal(isAllowedEmail(address), true);
    assert.deepEqual(scan(`<${address}>`), []);
  }
});

test('an image name such as icon@2x.png is not an address', () => {
  assert.deepEqual(scan(`"filename": "Icon-App-20x20${at}2x.png"`), []);
  assert.deepEqual(scan(`LaunchImage${at}3x.png`), []);
});

// ---- Warnings --------------------------------------------------------------

test('a phone number that is not a made-up 555 number is a warning', () => {
  assert.deepEqual(rules(scan(`phone: '${otherPhone}'`)), [
    'warning:phone-number',
  ]);
  const american = ['+1', '(202)', '303-4040'].join(' ');
  assert.deepEqual(rules(scan(american)), ['warning:phone-number']);
});

test('the made-up 555 numbers are not reported', () => {
  for (const phone of [fakePhone, '+995555000000', '+995 (555) 00-00-01']) {
    assert.deepEqual(scan(`phone: '${phone}'`), [], 'a 555 number');
  }
});

test('a quoted text shaped like a document ID or a UID is a warning', () => {
  assert.deepEqual(rules(scan(`doc(${idOf(20)})`)), ['warning:id-shape']);
  assert.deepEqual(rules(scan(`uid = ${idOf(28)}`)), ['warning:id-shape']);
});

test('names of classes and other lengths are not ID-shaped', () => {
  for (const line of [
    "name: 'AdminBookingsNotifier'",
    "group('isPlausibleBookingId', () {",
    `doc(${idOf(19)})`,
    `doc(${idOf(21)})`,
    "'aaaaaaaaaaaaaaaaaaaa'",
    "'12345678901234567890'",
  ]) {
    assert.deepEqual(scan(line), [], line);
  }
});

test('warnings and errors are told apart', () => {
  const findings = scan([otherPhone, passwordLine('hunter2hunter2')].join('\n'));
  assert.deepEqual(rules(findings), ['warning:phone-number', 'error:secret-value']);
  assert.deepEqual(
    findings.map((f) => f.line),
    [1, 2],
  );
});

// ---- Lines, line endings, clean text ---------------------------------------

test('the line number is right with Windows and Unix line endings', () => {
  const lines = ['first', 'second', passwordLine('hunter2hunter2'), 'last'];
  for (const ending of ['\n', '\r\n']) {
    const [finding] = scan(lines.join(ending));
    assert.equal(finding.line, 3);
    // The carriage return is not counted as part of the value.
    assert.equal(finding.length, 'hunter2hunter2'.length);
  }
});

test('ordinary code and text give no findings', () => {
  const text = [
    "import 'package:flutter/material.dart';",
    '@override',
    'Widget build(BuildContext context) => const SizedBox();',
    '// See https://firebase.google.com/docs/firestore/security/get-started',
    "const adminTbilisiTimeNote = 'Tbilisi time (GMT+4)';",
    'final total = 5 * (45 + 4.5);',
  ].join('\n');
  assert.deepEqual(scan(text), []);
});

// ---- Masking ---------------------------------------------------------------

test('a finding never holds the found value, only its length', () => {
  const typed = 'hunter2hunter2';
  const findings = scan(
    [passwordLine(typed), otherAddress, apiKey, uuid, otherPhone].join('\n'),
  );
  assert.equal(findings.length, 5);
  for (const finding of findings) {
    assert.deepEqual(Object.keys(finding).sort(), [
      'length',
      'level',
      'line',
      'rule',
    ]);
    assert.equal(typeof finding.length, 'number');
  }
  const text = JSON.stringify(findings);
  for (const value of [typed, otherAddress, apiKey, uuid, otherPhone]) {
    assert.equal(text.includes(value), false);
  }
});

test('the printed report shows no value, not even a part of it', () => {
  const typed = 'Zx9hunter2Qw7';
  const findings = [
    ...scan(passwordLine(typed)),
    ...scan(otherAddress),
    ...scan(otherPhone),
  ].map((f) => ({ path: 'lib/sample.dart', ...f }));
  const { lines, errors, warnings } = report(
    { findings, checked: 1, skipped: 0, missing: 0 },
    { staged: false },
  );
  const text = lines.join('\n');

  assert.equal(errors, 2);
  assert.equal(warnings, 1);
  assert.match(text, /ERROR {4}lib\/sample\.dart:1 {2}secret-value/);
  assert.match(text, /WARNING {2}lib\/sample\.dart:1 {2}phone-number/);
  assert.ok(text.includes(mask(typed.length)));
  assert.match(text, /FAILED/);
  for (const piece of [typed, typed.slice(0, 4), 'someone', 'company', '577']) {
    assert.equal(text.includes(piece), false, 'a part of a value was printed');
  }
});

test('mask says only the length', () => {
  assert.equal(mask(14), '<masked, 14 characters>');
});

test('a report without errors says OK, with warnings too', () => {
  const clean = report(
    { findings: [], checked: 3, skipped: 1, missing: 0 },
    { staged: true },
  );
  assert.equal(clean.errors, 0);
  assert.match(clean.lines.join('\n'), /Checked 3 files \(staged content\)/);
  assert.match(clean.lines.join('\n'), /OK: no errors/);

  const warned = report(
    {
      findings: [
        {
          path: 'a.dart',
          level: 'warning',
          rule: 'phone-number',
          line: 2,
          length: 13,
        },
      ],
      checked: 1,
      skipped: 0,
      missing: 2,
    },
    { staged: false },
  );
  assert.equal(warned.errors, 0);
  assert.equal(warned.warnings, 1);
  assert.match(warned.lines.join('\n'), /2 listed but missing/);
  assert.match(warned.lines.join('\n'), /OK: no errors/);
});

// ---- Skipped paths, binary files, forbidden names --------------------------

test('built, downloaded and generated files are skipped', () => {
  for (const path of [
    'build/app/outputs/flutter-apk/app-debug.apk',
    '.dart_tool/package_config.json',
    'tool/admin/node_modules/firebase-admin/package.json',
    'tool\\admin\\node_modules\\x\\index.js',
    'android/.gradle/8.0/fileHashes.bin',
    'ios/Pods/Firebase/README.md',
    'lib/l10n/generated/app_localizations_en.dart',
    'tool/admin/package-lock.json',
    'pubspec.lock',
    'assets/images/logo.PNG',
    'web/favicon.png',
    'android/gradle/wrapper/gradle-wrapper.jar',
  ]) {
    assert.equal(isSkippedPath(path), true, path);
  }
});

test('hand-written files are not skipped', () => {
  for (const path of [
    'lib/main.dart',
    'lib/l10n/app_en.arb',
    'firestore.rules',
    'docs/PLAN.md',
    'tool/check_secrets.mjs',
    'tool/check_secrets.test.mjs',
    'android/app/google-services.json',
    'android/app/build.gradle.kts',
    'pubspec.yaml',
    'README.md',
  ]) {
    assert.equal(isSkippedPath(path), false, path);
  }
});

test('a file with a zero byte counts as binary', () => {
  assert.equal(isBinary(Buffer.from([0x89, 0x50, 0x00, 0x47])), true);
  assert.equal(isBinary(Buffer.from('plain text\r\n', 'utf8')), false);
  assert.equal(isBinary(Buffer.alloc(0)), false);
});

test('files that must not be in the repository are found by their name', () => {
  for (const path of [
    '.env',
    'config/.env.production',
    'android/key.properties',
    'android/app/upload.jks',
    'release.keystore',
    'certs/key.pem',
    'serviceAccount.json',
    'tool/admin/service-account-key.json',
    'tool\\admin\\service_account.json',
    'x-firebase-adminsdk-abc12-def.json',
  ]) {
    assert.equal(forbiddenFileRule(path), 'forbidden-file', path);
  }
  for (const path of [
    'lib/core/environment.dart',
    'android/gradle.properties',
    'android/app/google-services.json',
    'docs/service_account_notes.md',
    'tool/admin/set_admin_claim.mjs',
  ]) {
    assert.equal(forbiddenFileRule(path), null, path);
  }
});

// ---- A real, temporary git repository --------------------------------------

function tempRepo() {
  const dir = mkdtempSync(join(tmpdir(), 'check-secrets-test-'));
  const git = (...args) =>
    execFileSync('git', args, { cwd: dir, windowsHide: true, stdio: 'pipe' });
  git('init', '--quiet');
  // No line-ending conversion: the files are read back exactly as written.
  git('config', 'core.autocrlf', 'false');
  const write = (path, content) => {
    mkdirSync(dirname(join(dir, path)), { recursive: true });
    writeFileSync(join(dir, path), content);
  };
  const remove = () => rmSync(dir, { recursive: true, force: true });
  return { dir, git, write, remove };
}

test('normal mode checks tracked files and new files, not ignored ones', () => {
  const repo = tempRepo();
  try {
    repo.write('.gitignore', 'ignored/\n');
    repo.write('tracked.txt', `${passwordLine('hunter2hunter2')}\n`);
    repo.write('new.txt', `${otherAddress}\n`);
    repo.write('ignored/typed.txt', `${privateKeyLine}\n`);
    repo.write('clean.txt', 'nothing here\n');
    repo.git('add', '.gitignore', 'tracked.txt', 'clean.txt');

    assert.deepEqual(listFiles({ staged: false, cwd: repo.dir }), [
      '.gitignore',
      'clean.txt',
      'new.txt',
      'tracked.txt',
    ]);
    const result = scanRepo({ staged: false, cwd: repo.dir });
    assert.deepEqual(
      result.findings.map((f) => `${f.path}:${f.rule}`).sort(),
      ['new.txt:email-address', 'tracked.txt:secret-value'],
    );
    assert.equal(result.checked, 4);
  } finally {
    repo.remove();
  }
});

test('staged mode reads the STAGED content, not the working copy', () => {
  const repo = tempRepo();
  try {
    // Staged with a secret, then cleaned up in the working copy only.
    repo.write('a.txt', `${passwordLine('hunter2hunter2')}\n`);
    repo.git('add', 'a.txt');
    repo.write('a.txt', 'clean now\n');
    // Staged clean, then a secret typed into the working copy only.
    repo.write('b.txt', 'clean\n');
    repo.git('add', 'b.txt');
    repo.write('b.txt', `${privateKeyLine}\n`);
    // Never staged.
    repo.write('c.txt', `${otherAddress}\n`);

    const staged = scanRepo({ staged: true, cwd: repo.dir });
    assert.deepEqual(listFiles({ staged: true, cwd: repo.dir }), ['a.txt', 'b.txt']);
    assert.deepEqual(
      staged.findings.map((f) => `${f.path}:${f.rule}`),
      ['a.txt:secret-value'],
    );

    const working = scanRepo({ staged: false, cwd: repo.dir });
    assert.deepEqual(
      working.findings.map((f) => `${f.path}:${f.rule}`).sort(),
      ['b.txt:private-key', 'c.txt:email-address'],
    );
  } finally {
    repo.remove();
  }
});

test('a staged deletion is not checked, and nothing staged is no error', () => {
  const repo = tempRepo();
  try {
    assert.deepEqual(scanRepo({ staged: true, cwd: repo.dir }).findings, []);

    repo.write('gone.txt', `${passwordLine('hunter2hunter2')}\n`);
    repo.git('add', 'gone.txt');
    repo.git(
      '-c', 'user.name=Test', '-c', `user.email=${exampleAddress}`,
      'commit', '--quiet', '-m', 'add',
    );
    repo.git('rm', '--quiet', 'gone.txt');

    const result = scanRepo({ staged: true, cwd: repo.dir });
    assert.deepEqual(listFiles({ staged: true, cwd: repo.dir }), []);
    assert.deepEqual(result.findings, []);
  } finally {
    repo.remove();
  }
});

test('a file git lists that is missing on disk is counted, not fatal', () => {
  const repo = tempRepo();
  try {
    repo.write('kept.txt', 'kept\n');
    repo.write('deleted.txt', `${passwordLine('hunter2hunter2')}\n`);
    repo.git('add', 'kept.txt', 'deleted.txt');
    unlinkSync(join(repo.dir, 'deleted.txt'));

    const result = scanRepo({ staged: false, cwd: repo.dir });
    assert.equal(result.missing, 1);
    assert.equal(result.checked, 1);
    assert.deepEqual(result.findings, []);
  } finally {
    repo.remove();
  }
});

test('a forbidden file name is an error also for a binary or empty file', () => {
  const repo = tempRepo();
  try {
    repo.write('android/upload.jks', Buffer.from([0, 1, 2, 3]));
    repo.write('.env', '');
    repo.write('deep/folder/photo.png', Buffer.from([0x89, 0x50, 0, 0]));
    repo.write('lib/firebase_options.dart', `${apiKeyField}\n`);
    repo.write('web/config.js', `${keyConstant}\n`);

    const result = scanRepo({ staged: false, cwd: repo.dir });
    assert.deepEqual(
      result.findings.map((f) => `${f.path}:${f.rule}`).sort(),
      [
        '.env:forbidden-file',
        'android/upload.jks:forbidden-file',
        'web/config.js:google-api-key',
      ],
    );
    assert.ok(result.skipped >= 2);
  } finally {
    repo.remove();
  }
});

// ---- The optional local deny list -------------------------------------------

// Invented words, put together at run time.
const denyWord = ['Zeb', 'raQuartz', '77'].join('');
const otherDenyWord = ['Mar', 'bleFalcon', '31'].join('');

/** A temporary repository whose .gitignore covers the deny list. */
function repoWithDenylist(lines, { ignored = true } = {}) {
  const repo = tempRepo();
  if (ignored) repo.write('.gitignore', `${DENYLIST_PATH}\n`);
  if (lines !== null) repo.write(DENYLIST_PATH, lines.join('\n'));
  return repo;
}

const found = (result) =>
  result.findings.map((f) => `${f.path}:${f.line}:${f.level}:${f.rule}`).sort();

test('no deny list: no effect', () => {
  const repo = repoWithDenylist(null);
  try {
    repo.write('notes.txt', `about ${denyWord}\n`);

    assert.deepEqual(loadDenylist(repo.dir), { entries: [], findings: [] });
    assert.deepEqual(scanRepo({ cwd: repo.dir }).findings, []);
  } finally {
    repo.remove();
  }
});

test('an ignored deny list and a match: an error, masked', () => {
  const repo = repoWithDenylist(['# what must never appear', '', denyWord]);
  try {
    repo.write('lib/notes.txt', `first\r\nabout ${denyWord} here\r\n`);
    repo.write('clean.txt', 'nothing\n');

    const result = scanRepo({ cwd: repo.dir });
    assert.deepEqual(found(result), ['lib/notes.txt:2:error:denylist-match']);
    assert.equal(result.findings[0].length, denyWord.length);

    const { lines, errors } = report(result, { staged: false });
    assert.equal(errors, 1);
    const text = lines.join('\n');
    assert.match(text, /lib\/notes\.txt:2 {2}denylist-match/);
    assert.ok(text.includes(mask(denyWord.length)));
    assert.equal(text.includes(denyWord), false);
    assert.equal(text.toLowerCase().includes(denyWord.toLowerCase()), false);
  } finally {
    repo.remove();
  }
});

test('the deny list is compared without regard to the case of letters', () => {
  const repo = repoWithDenylist([denyWord.toLowerCase()]);
  try {
    repo.write('a.txt', `${denyWord.toUpperCase()}\n`);
    repo.write('b.txt', `x${denyWord}y\n`);

    assert.deepEqual(found(scanRepo({ cwd: repo.dir })), [
      'a.txt:1:error:denylist-match',
      'b.txt:1:error:denylist-match',
    ]);
  } finally {
    repo.remove();
  }
});

test('an ignored deny list without a match: nothing', () => {
  const repo = repoWithDenylist([denyWord, otherDenyWord]);
  try {
    repo.write('notes.txt', 'nothing of that kind\n');

    assert.deepEqual(scanRepo({ cwd: repo.dir }).findings, []);
  } finally {
    repo.remove();
  }
});

test('several entries: each match is its own error; a line is an exact text', () => {
  const repo = repoWithDenylist([denyWord, `  ${otherDenyWord} street  `]);
  try {
    repo.write('a.txt', `${denyWord} and ${otherDenyWord} street\n`);
    // Only a part of the second entry: no match.
    repo.write('b.txt', `${otherDenyWord}\n`);

    assert.deepEqual(found(scanRepo({ cwd: repo.dir })), [
      'a.txt:1:error:denylist-match',
      'a.txt:1:error:denylist-match',
    ]);
  } finally {
    repo.remove();
  }
});

test('a deny list that git does not ignore is an error and is not used', () => {
  const repo = repoWithDenylist([denyWord], { ignored: false });
  try {
    repo.write('notes.txt', `about ${denyWord}\n`);

    const result = scanRepo({ cwd: repo.dir });
    // Not used: no match is reported. And the list itself is not scanned.
    assert.deepEqual(found(result), [
      `${DENYLIST_PATH}:0:error:denylist-not-ignored`,
    ]);
    const text = report(result, { staged: false }).lines.join('\n');
    assert.match(text, /denylist-not-ignored/);
    assert.equal(text.includes(denyWord), false);
  } finally {
    repo.remove();
  }
});

test('a tracked deny list is an error, also with an ignore rule', () => {
  const repo = repoWithDenylist([denyWord]);
  try {
    repo.git('add', '--force', DENYLIST_PATH);
    repo.write('notes.txt', `about ${denyWord}\n`);

    for (const staged of [false, true]) {
      const result = scanRepo({ staged, cwd: repo.dir });
      assert.deepEqual(found(result), [
        `${DENYLIST_PATH}:0:error:denylist-not-ignored`,
      ]);
      const text = report(result, { staged }).lines.join('\n');
      assert.equal(text.includes(denyWord), false);
    }
  } finally {
    repo.remove();
  }
});

test('a line shorter than 4 characters: a warning, line number only', () => {
  const short = ['Q', 'z', '7'].join('');
  const repo = repoWithDenylist(['# comment', short, '', denyWord, 'ab']);
  try {
    repo.write('notes.txt', `${short} and ab are everywhere\n`);

    const result = scanRepo({ cwd: repo.dir });
    assert.deepEqual(found(result), [
      `${DENYLIST_PATH}:2:warning:denylist-line-too-short`,
      `${DENYLIST_PATH}:5:warning:denylist-line-too-short`,
    ]);
    assert.deepEqual(
      result.findings.map((f) => f.length),
      [0, 0],
    );
    const { lines, errors, warnings } = report(result, { staged: false });
    assert.equal(errors, 0);
    assert.equal(warnings, 2);
    const text = lines.join('\n');
    assert.match(text, /private_denylist\.txt:2 {2}denylist-line-too-short/);
    assert.equal(text.includes(short), false);
    assert.equal(text.includes('masked'), false);
  } finally {
    repo.remove();
  }
});

test('staged mode compares the deny list with the STAGED content', () => {
  const repo = repoWithDenylist([denyWord]);
  try {
    // Staged with the word, then cleaned up in the working copy only.
    repo.write('a.txt', `about ${denyWord}\n`);
    repo.git('add', 'a.txt');
    repo.write('a.txt', 'clean now\n');
    // Staged clean, then the word typed into the working copy only.
    repo.write('b.txt', 'clean\n');
    repo.git('add', 'b.txt');
    repo.write('b.txt', `about ${denyWord}\n`);

    assert.deepEqual(found(scanRepo({ staged: true, cwd: repo.dir })), [
      'a.txt:1:error:denylist-match',
    ]);
    assert.deepEqual(found(scanRepo({ staged: false, cwd: repo.dir })), [
      'b.txt:1:error:denylist-match',
    ]);
  } finally {
    repo.remove();
  }
});

test('no content of the deny list ever appears in the output', () => {
  const short = ['Q', 'z', '7'].join('');
  const comment = ['# the', 'owner', 'wrote', 'this'].join(' ');
  const repo = repoWithDenylist([comment, denyWord, otherDenyWord, short]);
  try {
    repo.write('a.txt', `${denyWord} ${otherDenyWord} ${short}\n`);
    const script = join(
      dirname(fileURLToPath(import.meta.url)),
      'check_secrets.mjs',
    );
    let out;
    try {
      out = execFileSync(process.execPath, [script], {
        cwd: repo.dir,
        stdio: 'pipe',
        windowsHide: true,
      }).toString('utf8');
      assert.fail('the scan should have failed');
    } catch (error) {
      assert.equal(error.status, 1);
      out = [error.stdout, error.stderr]
        .map((part) => part?.toString('utf8') ?? '')
        .join('');
    }
    assert.match(out, /denylist-match/);
    assert.match(out, /denylist-line-too-short/);
    const lower = out.toLowerCase();
    for (const piece of [denyWord, otherDenyWord, short, 'owner', 'wrote']) {
      assert.equal(lower.includes(piece.toLowerCase()), false, 'leaked');
    }
  } finally {
    repo.remove();
  }
});

test('the deny list of this repository, if any, is ignored by git', () => {
  const root = join(dirname(fileURLToPath(import.meta.url)), '..');
  const { findings } = loadDenylist(root);
  assert.deepEqual(
    findings.filter((f) => f.rule === 'denylist-not-ignored'),
    [],
  );
});

// ---- The script and this file themselves -----------------------------------

test('the script and its tests hold nothing the scan reports', () => {
  const here = dirname(fileURLToPath(import.meta.url));
  for (const name of ['check_secrets.mjs', 'check_secrets.test.mjs']) {
    const text = readFileSync(join(here, name), 'utf8');
    const findings = scanText(`tool/${name}`, text);
    assert.deepEqual(
      findings.filter((f) => f.level === 'error'),
      [],
      `${name} trips the scan`,
    );
  }
});

test('the command line: exit code 0, 1 and 2', () => {
  const script = join(dirname(fileURLToPath(import.meta.url)), 'check_secrets.mjs');
  const run = (cwd, ...args) => {
    try {
      const out = execFileSync(process.execPath, [script, ...args], {
        cwd,
        stdio: 'pipe',
        windowsHide: true,
      });
      return { code: 0, out: out.toString('utf8') };
    } catch (error) {
      return {
        code: error.status,
        out: [error.stdout, error.stderr]
          .map((part) => part?.toString('utf8') ?? '')
          .join(''),
      };
    }
  };
  const repo = tempRepo();
  try {
    repo.write('clean.txt', `phone ${otherPhone}\n`);
    const clean = run(repo.dir);
    assert.equal(clean.code, 0);
    assert.match(clean.out, /Errors: 0\. Warnings: 1\./);

    const typed = 'Zx9hunter2Qw7';
    repo.write('bad.txt', `${passwordLine(typed)}\n`);
    const bad = run(repo.dir);
    assert.equal(bad.code, 1);
    assert.match(bad.out, /ERROR {4}bad\.txt:1 {2}secret-value/);
    assert.equal(bad.out.includes(typed), false);

    // Nothing is staged, so the staged mode has nothing to complain about.
    assert.equal(run(repo.dir, '--staged').code, 0);
    assert.equal(run(repo.dir, '--everything').code, 2);
  } finally {
    repo.remove();
  }
});
