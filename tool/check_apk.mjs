// Checks that a release APK holds no secret of this project (step 7.10).
//
//   node tool/check_apk.mjs <file.apk>
//
// An APK is a zip file. Every entry is read with Node's own zlib (no
// package) and checked:
// - its name, with forbiddenFileRule of tool/check_secrets.mjs
//   (key.properties, keystores, .env, service-account JSON);
// - its bytes, for every text of the local deny list (loadDenylist), as
//   UTF-8 and as UTF-16LE at any offset; the ASCII letters of both the
//   bytes and the texts are case-folded;
// - its bytes read as Latin-1, for the secret shapes: a private key, a
//   service-account key, an App Check debug token and a reCAPTCHA secret
//   (6L + 38 characters other than the committed public site key);
// - e-mail addresses: see EMAIL_ENTRY below.
//
// It prints only entry names, rule names and counts, never a found value
// and never a line of the deny list. Without a usable deny list it fails:
// it never reports "clean" without it.
//
// Exit code: 0 clean, 1 a finding or an error.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import zlib from 'node:zlib';

import {
  forbiddenFileRule,
  isAllowedEmail,
  loadDenylist,
} from './check_secrets.mjs';

export const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const SITE_KEY_FILE = 'lib/core/config/app_check_config.dart';

// ---- The zip file ---------------------------------------------------------

const EOCD = 0x06054b50;
const ZIP64_LOCATOR = 0x07064b50;
const CENTRAL = 0x02014b50;
const LOCAL = 0x04034b50;

/// The entries of the zip [buffer]: { name, data } with the uncompressed
/// bytes. Stored (0) and deflated (8) entries only; zip64 and encrypted
/// entries throw a clear error.
export function readZip(buffer) {
  const from = Math.max(0, buffer.length - 22 - 0xffff);
  let end = -1;
  for (let at = buffer.length - 22; at >= from; at--) {
    if (buffer.readUInt32LE(at) === EOCD) {
      end = at;
      break;
    }
  }
  if (end < 0) throw new Error('Not a zip file: no end of central directory.');
  if (end >= 20 && buffer.readUInt32LE(end - 20) === ZIP64_LOCATOR) {
    throw new Error('A zip64 archive is not supported.');
  }
  const count = buffer.readUInt16LE(end + 10);
  const size = buffer.readUInt32LE(end + 12);
  const start = buffer.readUInt32LE(end + 16);
  if (count === 0xffff || size === 0xffffffff || start === 0xffffffff) {
    throw new Error('A zip64 archive is not supported.');
  }

  const entries = [];
  let at = start;
  for (let i = 0; i < count; i++) {
    if (buffer.readUInt32LE(at) !== CENTRAL) {
      throw new Error(`Broken central directory at entry ${i}.`);
    }
    const flags = buffer.readUInt16LE(at + 8);
    const method = buffer.readUInt16LE(at + 10);
    const compressed = buffer.readUInt32LE(at + 20);
    const plain = buffer.readUInt32LE(at + 24);
    const nameLength = buffer.readUInt16LE(at + 28);
    const extraLength = buffer.readUInt16LE(at + 30);
    const commentLength = buffer.readUInt16LE(at + 32);
    const local = buffer.readUInt32LE(at + 42);
    const name = buffer.toString('utf8', at + 46, at + 46 + nameLength);
    at += 46 + nameLength + extraLength + commentLength;

    if (flags & 1) throw new Error(`An encrypted entry: ${name}`);
    if ([compressed, plain, local].includes(0xffffffff)) {
      throw new Error('A zip64 archive is not supported.');
    }
    if (buffer.readUInt32LE(local) !== LOCAL) {
      throw new Error(`Broken local header: ${name}`);
    }
    const dataStart =
      local + 30 + buffer.readUInt16LE(local + 26) + buffer.readUInt16LE(local + 28);
    const raw = buffer.subarray(dataStart, dataStart + compressed);
    let data;
    if (method === 0) data = raw;
    else if (method === 8) data = zlib.inflateRawSync(raw);
    else throw new Error(`Compression method ${method} is not supported: ${name}`);
    if (data.length !== plain) throw new Error(`Wrong size after reading: ${name}`);
    entries.push({ name, data });
  }
  return entries;
}

// ---- The rules ------------------------------------------------------------

/// The committed public App Check site key (allowed in the APK), or null.
export function readSiteKey(root = ROOT) {
  const file = path.join(root, ...SITE_KEY_FILE.split('/'));
  if (!fs.existsSync(file)) return null;
  const match = fs
    .readFileSync(file, 'utf8')
    .match(/const appCheckWebSiteKey\s*=\s*'([^']+)';/);
  return match ? match[1] : null;
}

/// A copy of [data] with the ASCII letters A-Z turned into a-z.
export function foldAscii(data) {
  const folded = Buffer.from(data);
  for (let i = 0; i < folded.length; i++) {
    if (folded[i] >= 0x41 && folded[i] <= 0x5a) folded[i] += 0x20;
  }
  return folded;
}

/// The byte patterns of the deny-list [texts], made once per text: each
/// text folded with the same ASCII-only rule as foldAscii (non-ASCII
/// letters stay as they are), as UTF-8 and as UTF-16LE.
export function denyPatterns(texts) {
  return texts.map((text) => {
    const folded = text.replace(/[A-Z]/g, (letter) =>
      String.fromCharCode(letter.charCodeAt(0) + 0x20),
    );
    return {
      utf8: Buffer.from(folded, 'utf8'),
      utf16: Buffer.from(folded, 'utf16le'),
    };
  });
}

/// Whether [pattern] (see denyPatterns) is in [folded] (see foldAscii), at
/// any offset. Both sides are folded the same way. A byte search only:
/// decoding an odd-aligned UTF-16 text and lowercasing it crashed Node 24
/// on Windows.
export function containsText(folded, pattern) {
  return folded.indexOf(pattern.utf8) >= 0 || folded.indexOf(pattern.utf16) >= 0;
}

const SHAPES = [
  ['private-key', /-----BEGIN [A-Z ]*PRIVATE KEY-----/g],
  [
    'service-account-key',
    /"type"\s*:\s*"service_account"|"private_key(?:_id)?"\s*:/g,
  ],
  [
    'debug-token-shape',
    /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi,
  ],
];
const RECAPTCHA = /(?<![A-Za-z0-9_-])6L[A-Za-z0-9_-]{38}(?![A-Za-z0-9_-])/g;
const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g;

/// The entries that hold this project's own code and texts. An e-mail
/// address outside the allow list is a finding only there: the other
/// entries are the Flutter engine, the Firebase and AndroidX libraries and
/// their licence texts (calibrated on the first release APK, step 7.10).
export const EMAIL_ENTRY = /^lib\/[^/]+\/libapp\.so$/;

/// Dart's private names in compiled code: "_name@<library number>.member".
/// They have the shape of an e-mail address but are not one.
const DART_PRIVATE_NAME = /@\d+\./;

/// Image entries. A UUID inside an image is its editor's metadata (XMP
/// instance ids), not an App Check debug token.
const IMAGE_ENTRY = /\.(png|jpe?g|webp|gif)$/i;

/// Every finding of one entry: { entry, rule, count }. Never a value.
/// [patterns] come from denyPatterns.
export function scanEntry(name, data, { patterns, siteKey }) {
  const findings = [];
  const add = (rule, count = 1) => findings.push({ entry: name, rule, count });

  const forbidden = forbiddenFileRule(name);
  if (forbidden) add(forbidden);

  const folded = foldAscii(data);
  for (const pattern of patterns) {
    if (containsText(folded, pattern)) add('denylist-match');
  }

  const text = data.toString('latin1');
  for (const [rule, pattern] of SHAPES) {
    if (rule === 'debug-token-shape' && IMAGE_ENTRY.test(name)) continue;
    const count = [...text.matchAll(pattern)].length;
    if (count > 0) add(rule, count);
  }
  const secrets = [...text.matchAll(RECAPTCHA)].filter((m) => m[0] !== siteKey);
  if (secrets.length > 0) add('recaptcha-secret-shape', secrets.length);

  if (EMAIL_ENTRY.test(name)) {
    const emails = [...text.matchAll(EMAIL)].filter(
      (m) =>
        !DART_PRIVATE_NAME.test(m[0]) &&
        !/@[0-9]+x\./i.test(m[0]) &&
        !isAllowedEmail(m[0]),
    );
    if (emails.length > 0) add('email-address', emails.length);
  }
  return findings;
}

/// Checks the APK [file]. Returns { entries, findings }; throws when the
/// deny list cannot be used.
export function checkApk(file, { denylist, siteKey }) {
  if (!denylist || denylist.length === 0) {
    throw new Error('No deny-list entries: the APK cannot be called clean.');
  }
  const patterns = denyPatterns(denylist);
  const entries = readZip(fs.readFileSync(file));
  const findings = entries.flatMap((e) =>
    scanEntry(e.name, e.data, { patterns, siteKey }),
  );
  return { entries: entries.length, findings };
}

function main(argv) {
  const file = argv[0];
  if (!file || !fs.existsSync(file)) {
    console.log('ERROR  Usage: node tool/check_apk.mjs <file.apk>');
    return 1;
  }
  const loaded = loadDenylist(ROOT);
  if (loaded.findings.some((f) => f.level === 'error')) {
    console.log('ERROR  The deny list is not usable (it must be git-ignored).');
    return 1;
  }
  let result;
  try {
    result = checkApk(file, { denylist: loaded.entries, siteKey: readSiteKey() });
  } catch (error) {
    console.log(`ERROR  ${error.message}`);
    return 1;
  }
  for (const f of result.findings) {
    console.log(`${f.rule.padEnd(24)} ${f.entry}  (${f.count})`);
  }
  console.log(
    `Checked ${result.entries} entries with ${loaded.entries.length} ` +
      `deny-list entries. Findings: ${result.findings.length}.`,
  );
  return result.findings.length > 0 ? 1 : 0;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  process.exit(main(process.argv.slice(2)));
}
