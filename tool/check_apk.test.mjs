// Tests of tool/check_apk.mjs with made-up zip files.
// Run: node --test tool/check_apk.test.mjs

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import zlib from 'node:zlib';

import { checkApk, denyPatterns, readZip, scanEntry } from './check_apk.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, 'check_apk.mjs');
const denylistFile = path.join(here, 'private_denylist.txt');

// Made-up values only, assembled from pieces so that the secrets scan of
// the repository does not take them for real ones.
const at = '@';
const dashes = '-'.repeat(5);
const privateKeyLine = `${dashes}BEGIN ${'PRIVATE'} KEY${dashes}`;
const madeUpAddress = `made-up${at}madeup-domain.net`;
const uuid = ['01234567', '89ab', 'cdef', '0123', '456789abcdef'].join('-');
const siteKey = `6L${'madeUpPublicSiteKeyForTheTests00000000'}`;
const secretShape = `6L${'madeUpSecretShapeForTheTests1111111111'}`;
const denyWord = 'zebraquartz';
const options = { denylist: [denyWord], siteKey };

/// A zip file of [files] ({ name: Buffer | string }); every second entry is
/// deflated, the others are stored.
function zip(files) {
  const locals = [];
  const centrals = [];
  let offset = 0;
  Object.entries(files).forEach(([name, content], index) => {
    const data = Buffer.from(content);
    const deflate = index % 2 === 1;
    const body = deflate ? zlib.deflateRawSync(data) : data;
    const nameBytes = Buffer.from(name, 'utf8');
    const crc = zlib.crc32(data);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(deflate ? 8 : 0, 8);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(body.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(nameBytes.length, 26);
    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(deflate ? 8 : 0, 10);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(body.length, 20);
    central.writeUInt32LE(data.length, 24);
    central.writeUInt16LE(nameBytes.length, 28);
    central.writeUInt32LE(offset, 42);
    locals.push(local, nameBytes, body);
    centrals.push(central, nameBytes);
    offset += 30 + nameBytes.length + body.length;
  });
  const directory = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(Object.keys(files).length, 8);
  end.writeUInt16LE(Object.keys(files).length, 10);
  end.writeUInt32LE(directory.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, directory, end]);
}

function writeTemp(buffer) {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'check-apk-test-'));
  const file = path.join(folder, 'app.apk');
  fs.writeFileSync(file, buffer);
  return file;
}

const clean = {
  'AndroidManifest.xml': 'made-up manifest',
  'lib/arm64-v8a/libapp.so':
    `code _name${at}123456.member ${siteKey} a${at}example.com`,
  'assets/flutter_assets/logo.png': Buffer.from([0, 1, 2, 3]),
  'classes.dex': `library text with someone${at}library.org`,
};

const rules = (files) => {
  const file = writeTemp(zip(files));
  return checkApk(file, options).findings.map((f) => `${f.rule} ${f.entry}`);
};

test('readZip reads stored and deflated entries', () => {
  const entries = readZip(zip({ 'a.txt': 'stored', 'b.txt': 'deflated' }));
  assert.deepEqual(
    entries.map((e) => [e.name, e.data.toString()]),
    [['a.txt', 'stored'], ['b.txt', 'deflated']],
  );
});

test('readZip refuses a zip64 archive and a file that is not a zip', () => {
  const buffer = zip({ 'a.txt': 'x' });
  buffer.writeUInt16LE(0xffff, buffer.length - 22 + 10);
  assert.throws(() => readZip(buffer), /zip64/);
  assert.throws(() => readZip(Buffer.from('not a zip at all')), /Not a zip/);
});

test('a clean APK has no findings', () => {
  assert.deepEqual(rules(clean), []);
});

test('a forbidden entry name is found', () => {
  assert.deepEqual(rules({ ...clean, 'assets/key.properties': 'x' }), [
    'forbidden-file assets/key.properties',
  ]);
});

test('a private key header is found', () => {
  assert.deepEqual(rules({ ...clean, 'res/raw/a.txt': privateKeyLine }), [
    'private-key res/raw/a.txt',
  ]);
});

test('a reCAPTCHA-secret shape other than the site key is found', () => {
  assert.deepEqual(rules({ ...clean, 'res/raw/b.txt': `k ${secretShape} k` }), [
    'recaptcha-secret-shape res/raw/b.txt',
  ]);
});

test('a deny-list text is found as UTF-8, any case', () => {
  assert.deepEqual(rules({ ...clean, 'res/raw/c.txt': 'ZebraQuartz' }), [
    'denylist-match res/raw/c.txt',
  ]);
});

test('a deny-list text is found as odd-aligned UTF-16LE', () => {
  const odd = Buffer.concat([
    Buffer.from([0, 7, 0]),
    Buffer.from('ZEBRAQUARTZ', 'utf16le'),
    Buffer.from([0]),
  ]);
  assert.deepEqual(rules({ ...clean, 'res/raw/d.bin': odd }), [
    'denylist-match res/raw/d.bin',
  ]);
});

test('a mixed-case deny-list entry is found in any case and as UTF-16LE', () => {
  const mixed = { denylist: ['ZebraQuartz-X9'], siteKey };
  const found = (content) => {
    const file = writeTemp(zip({ ...clean, 'res/raw/m.bin': content }));
    return checkApk(file, mixed).findings.map((f) => f.rule);
  };
  assert.deepEqual(found('a zebraquartz-x9 b'), ['denylist-match'], 'lower');
  assert.deepEqual(found('a ZEBRAQUARTZ-X9 b'), ['denylist-match'], 'upper');
  assert.deepEqual(found('a zEbRaQuArTz-x9 b'), ['denylist-match'], 'mixed');
  const odd = Buffer.concat([
    Buffer.from([0, 7, 0]),
    Buffer.from('zebraQUARTZ-x9', 'utf16le'),
    Buffer.from([0]),
  ]);
  assert.deepEqual(found(odd), ['denylist-match'], 'UTF-16LE');
});

test('an e-mail address in our compiled code is found; library text not', () => {
  const found = rules({ ...clean, 'lib/x86_64/libapp.so': `code ${madeUpAddress}` });
  assert.deepEqual(found, ['email-address lib/x86_64/libapp.so']);
});

test('a debug-token shape is found, but not inside an image', () => {
  assert.deepEqual(
    rules({ ...clean, 'res/raw/e.txt': uuid, 'res/f.png': `xmp ${uuid}` }),
    ['debug-token-shape res/raw/e.txt'],
  );
});

test('an empty deny list fails instead of calling the APK clean', () => {
  const file = writeTemp(zip(clean));
  assert.throws(
    () => checkApk(file, { denylist: [], siteKey }),
    /No deny-list entries/,
  );
});

test('scanEntry returns rule names and counts only', () => {
  const findings = scanEntry('res/raw/g.txt', Buffer.from(denyWord), {
    patterns: denyPatterns([denyWord]),
    siteKey,
  });
  assert.deepEqual(findings, [
    { entry: 'res/raw/g.txt', rule: 'denylist-match', count: 1 },
  ]);
});

test('the command line prints no planted value', () => {
  const file = writeTemp(
    zip({
      ...clean,
      'res/raw/h.txt': `${privateKeyLine} ${secretShape}`,
      'lib/x86_64/libapp.so': madeUpAddress,
    }),
  );
  const result = spawnSync(process.execPath, [script, file], {
    encoding: 'utf8',
  });
  assert.equal(result.status, 1);
  // With a deny list on this computer the findings are listed; without
  // one the tool stops first with the message of the next test.
  if (fs.existsSync(denylistFile)) {
    assert.match(result.stdout, /private-key\s+res\/raw\/h\.txt/);
  } else {
    assert.equal(
      result.stdout.trim(),
      'ERROR  No deny-list entries: the APK cannot be called clean.',
    );
  }
  assert.doesNotMatch(result.stdout, /madeup-domain|6Lmade|BEGIN PRIVATE/);
});

test('the command line fails without a deny list, with a clear message', () => {
  // A copy of the two tools in an empty folder: there is no deny list there,
  // whatever this computer has. The real list is never opened.
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'check-apk-nolist-'));
  fs.mkdirSync(path.join(folder, 'tool'));
  for (const name of ['check_apk.mjs', 'check_secrets.mjs']) {
    fs.copyFileSync(path.join(here, name), path.join(folder, 'tool', name));
  }
  const file = path.join(folder, 'app.apk');
  fs.writeFileSync(file, zip(clean));
  const result = spawnSync(
    process.execPath,
    [path.join(folder, 'tool', 'check_apk.mjs'), file],
    { cwd: folder, encoding: 'utf8' },
  );
  assert.equal(result.status, 1);
  assert.equal(
    result.stdout.trim(),
    'ERROR  No deny-list entries: the APK cannot be called clean.',
  );
});

test('the command line fails without a file', () => {
  const result = spawnSync(process.execPath, [script], { encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.match(result.stdout, /Usage/);
});
