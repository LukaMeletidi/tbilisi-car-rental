// tool/admin/guards.test.mjs
//
// Tests for the safety checks of set_admin_claim.mjs. They need no real key,
// no network, no Firebase and no installed package. Every "key" here is
// made up and useless. Run from the repository root:
//
//   node --test tool/admin/guards.test.mjs

import assert from 'node:assert/strict';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { after, describe, test } from 'node:test';

import {
  EXPECTED_PROJECT_ID,
  KEY_FILE_VARIABLE,
  Refusal,
  checkKeyLocation,
  claimsAfter,
  keyPathFromEnvironment,
  parseArguments,
  readKey,
  repositoryRootFrom,
  syncedFoldersFromEnvironment,
} from './guards.mjs';

// Obviously not a key. It must never look like a real one, or the secrets
// scan of the repository would give a false alarm.
const FAKE_SECRET = 'FAKE-KEY-FOR-TESTS';

// A sandbox in the system temp folder:
//   <sandbox>/repo      stands for the repository
//   <sandbox>/synced    stands for a OneDrive folder
//   <sandbox>/outside   a normal folder
const sandbox = mkdtempSync(path.join(os.tmpdir(), 'admin-guards-'));
const repo = path.join(sandbox, 'repo');
const synced = path.join(sandbox, 'synced');
const outside = path.join(sandbox, 'outside');
for (const folder of [repo, synced, outside]) {
  mkdirSync(folder, { recursive: true });
}
mkdirSync(path.join(repo, 'secrets'));
after(() => rmSync(sandbox, { recursive: true, force: true }));

const places = { repositoryRoot: repo, syncedFolders: [synced] };

function fakeKey(changes = {}) {
  const key = {
    type: 'service_account',
    project_id: EXPECTED_PROJECT_ID,
    client_email: 'fake@tbilisi-car-rental.iam.example',
    private_key: FAKE_SECRET,
    ...changes,
  };
  for (const [name, value] of Object.entries(changes)) {
    if (value === undefined) delete key[name];
  }
  return key;
}

let nextFile = 0;

// Writes [content] (an object, or a raw text) into [folder]; returns the path.
function writeKey(folder, content = fakeKey()) {
  nextFile += 1;
  const file = path.join(folder, `key${nextFile}.json`);
  const text = typeof content === 'string' ? content : JSON.stringify(content);
  writeFileSync(file, text);
  return file;
}

function refusal(action, pattern) {
  assert.throws(action, (error) => {
    assert.ok(error instanceof Refusal, `not a Refusal: ${error}`);
    assert.match(error.message, pattern);
    assert.ok(
      !error.message.includes(FAKE_SECRET),
      'the message shows the secret of the key',
    );
    return true;
  });
}

describe('arguments', () => {
  test('without a mode the account is only shown', () => {
    assert.deepEqual(parseArguments(['abc123']), {
      mode: 'show',
      uid: 'abc123',
    });
  });

  test('"show", "set" and "remove" are read', () => {
    for (const mode of ['show', 'set', 'remove']) {
      assert.deepEqual(parseArguments([mode, 'abc123']), {
        mode,
        uid: 'abc123',
      });
    }
  });

  test('an unknown mode is refused', () => {
    refusal(() => parseArguments(['grant', 'abc123']), /Unknown mode/);
    refusal(() => parseArguments(['SET', 'abc123']), /Unknown mode/);
  });

  test('a mode without a UID is refused, never read as a UID', () => {
    refusal(() => parseArguments(['set']), /UID is missing/);
    refusal(() => parseArguments(['remove']), /UID is missing/);
  });

  test('no arguments and too many arguments are refused', () => {
    refusal(() => parseArguments([]), /Usage/);
    refusal(() => parseArguments(['set', 'abc123', 'extra']), /Usage/);
  });

  test('an e-mail instead of a UID is refused', () => {
    refusal(() => parseArguments(['set', 'a@example.com']), /e-mail/);
  });

  test('a UID with spaces or other signs is refused', () => {
    refusal(() => parseArguments(['abc 123']), /unexpected form/);
    refusal(() => parseArguments(['set', 'abc/123']), /unexpected form/);
    refusal(() => parseArguments(['']), /unexpected form/);
  });
});

describe('the environment variable', () => {
  test('missing or empty is refused', () => {
    refusal(() => keyPathFromEnvironment({}), /is not set/);
    refusal(
      () => keyPathFromEnvironment({ [KEY_FILE_VARIABLE]: '   ' }),
      /is not set/,
    );
  });

  test('its value is returned as it is', () => {
    const file = path.join(outside, 'key.json');
    assert.equal(keyPathFromEnvironment({ [KEY_FILE_VARIABLE]: file }), file);
  });

  test('the OneDrive folders are taken from the environment', () => {
    assert.deepEqual(
      syncedFoldersFromEnvironment({ OneDrive: synced, OneDriveConsumer: '' }),
      [synced],
    );
    assert.deepEqual(syncedFoldersFromEnvironment({}), []);
  });
});

describe('where the key file is', () => {
  test('a normal folder outside the repository is accepted', () => {
    const file = writeKey(outside);
    assert.equal(
      path.basename(checkKeyLocation(file, places)),
      path.basename(file),
    );
  });

  test('a relative path is refused', () => {
    refusal(() => checkKeyLocation('key.json', places), /full path/);
    refusal(
      () => checkKeyLocation(path.join('..', 'outside', 'key.json'), places),
      /full path/,
    );
  });

  test('a file that does not exist is refused', () => {
    refusal(
      () => checkKeyLocation(path.join(outside, 'missing.json'), places),
      /not found/,
    );
  });

  test('a key inside the repository is refused', () => {
    refusal(
      () => checkKeyLocation(writeKey(repo), places),
      /inside the repository/,
    );
    refusal(
      () => checkKeyLocation(writeKey(path.join(repo, 'secrets')), places),
      /inside the repository/,
    );
  });

  test('a path that leaves and re-enters the repository is refused', () => {
    const file = writeKey(repo);
    const tricky = path.join(outside, '..', 'repo', path.basename(file));
    refusal(() => checkKeyLocation(tricky, places), /inside the repository/);
  });

  test('a link outside that points into the repository is refused', (t) => {
    // A directory junction: Windows follows it like a link and, unlike a
    // real symlink, creating one needs no special rights.
    const file = writeKey(path.join(repo, 'secrets'));
    const link = path.join(outside, 'link-into-repo');
    try {
      symlinkSync(path.join(repo, 'secrets'), link, 'junction');
    } catch (error) {
      t.skip(`no link could be made on this computer (${error.code})`);
      return;
    }
    const throughLink = path.join(link, path.basename(file));
    refusal(
      () => checkKeyLocation(throughLink, places),
      /inside the repository/,
    );
  });

  test('a key inside a synced folder is refused', () => {
    refusal(() => checkKeyLocation(writeKey(synced), places), /synced folder/);
  });

  test('a synced folder that does not exist is ignored', () => {
    const file = writeKey(outside);
    checkKeyLocation(file, {
      repositoryRoot: repo,
      syncedFolders: [path.join(sandbox, 'no-such-folder')],
    });
  });

  test('the repository root is two folders above tool/admin', () => {
    const adminFolder = path.join(repo, 'tool', 'admin');
    assert.equal(repositoryRootFrom(adminFolder), repo);
    // The real root: this test file lies in <root>/tool/admin.
    const realRoot = repositoryRootFrom(import.meta.dirname);
    assert.equal(path.basename(path.join(realRoot, 'tool', 'admin')), 'admin');
    refusal(
      () =>
        checkKeyLocation(path.join(import.meta.dirname, 'guards.mjs'), {
          repositoryRoot: realRoot,
          syncedFolders: [],
        }),
      /inside the repository/,
    );
  });
});

describe('the contents of the key file', () => {
  test('a correct fake key is accepted', () => {
    const key = readKey(writeKey(outside));
    assert.equal(key.project_id, EXPECTED_PROJECT_ID);
    assert.equal(key.client_email, 'fake@tbilisi-car-rental.iam.example');
  });

  test('malformed JSON is refused, without showing the text', () => {
    // A complete fake key with its last brace cut off.
    const cutOff = JSON.stringify(fakeKey()).slice(0, -1);
    assert.ok(cutOff.includes(FAKE_SECRET));
    refusal(() => readKey(writeKey(outside, cutOff)), /not valid JSON/);
  });

  test('JSON that is not an object is refused', () => {
    for (const text of ['[]', '"text"', '7', 'null']) {
      refusal(() => readKey(writeKey(outside, text)), /not a service account/);
    }
  });

  test('another kind of file is refused', () => {
    refusal(
      () => readKey(writeKey(outside, fakeKey({ type: 'authorized_user' }))),
      /not a service account/,
    );
    refusal(
      () => readKey(writeKey(outside, fakeKey({ type: undefined }))),
      /not a service account/,
    );
  });

  test('a key of another project is refused and the project is named', () => {
    refusal(
      () => readKey(writeKey(outside, fakeKey({ project_id: 'other-app' }))),
      /another project \("other-app"\)/,
    );
    // Close to the right name is still wrong.
    for (const projectId of [
      'tbilisi-car-rental-2',
      'Tbilisi-Car-Rental',
      ' tbilisi-car-rental',
      'demo-tbilisi-car-rental',
    ]) {
      refusal(
        () => readKey(writeKey(outside, fakeKey({ project_id: projectId }))),
        /another project/,
      );
    }
  });

  test('a key without a project id is refused', () => {
    refusal(
      () => readKey(writeKey(outside, fakeKey({ project_id: undefined }))),
      /another project \(none\)/,
    );
    refusal(
      () => readKey(writeKey(outside, fakeKey({ project_id: 7 }))),
      /another project \(none\)/,
    );
  });

  test('a key without client_email or private_key is refused', () => {
    refusal(
      () => readKey(writeKey(outside, fakeKey({ client_email: undefined }))),
      /no "client_email"/,
    );
    refusal(
      () => readKey(writeKey(outside, fakeKey({ private_key: '' }))),
      /no "private_key"/,
    );
  });

  test('a file that cannot be read is refused', () => {
    // A folder instead of a file.
    refusal(() => readKey(outside), /cannot be read/);
  });
});

describe('the claims after a change', () => {
  test('"set" adds admin and keeps every other claim', () => {
    assert.deepEqual(claimsAfter('set', undefined), { admin: true });
    assert.deepEqual(claimsAfter('set', {}), { admin: true });
    assert.deepEqual(claimsAfter('set', { team: 'a', admin: false }), {
      team: 'a',
      admin: true,
    });
  });

  test('"remove" drops only admin', () => {
    assert.deepEqual(claimsAfter('remove', { team: 'a', admin: true }), {
      team: 'a',
    });
  });

  test('when nothing is left the result is null', () => {
    assert.equal(claimsAfter('remove', { admin: true }), null);
    assert.equal(claimsAfter('remove', undefined), null);
  });

  test('"show" changes nothing', () => {
    assert.deepEqual(claimsAfter('show', { admin: true }), { admin: true });
  });

  test('the given claims are not changed in place', () => {
    const current = { team: 'a' };
    claimsAfter('set', current);
    assert.deepEqual(current, { team: 'a' });
  });
});

describe('this test file', () => {
  test('contains nothing that looks like a real key', () => {
    const own = readFileSync(import.meta.filename, 'utf8');
    // Built from parts, so that this line is not itself a match.
    const header = ['PRIVATE', 'KEY'].join(' ');
    assert.ok(!own.includes(header), `the file contains "${header}"`);
    assert.ok(!own.includes('-----' + 'BEGIN'), 'the file has a PEM header');
  });
});
