// Looks for secrets and personal data in the files git would commit.
//
//   node tool/check_secrets.mjs            every tracked file and every new
//                                          file that is not ignored
//   node tool/check_secrets.mjs --staged   only what is staged for the next
//                                          commit, read as it is staged
//
// It only reads. It never changes a file, never contacts a network and
// needs no packages. A found value is never printed, not even in part:
// the output has the file, the line, the rule and the length of the value.
//
// Optional: tool/private_denylist.txt, a local file that git ignores. Each
// of its lines is a text that must never appear in the repository (the
// admin's e-mail and UID, real names or numbers). The owner fills it by
// hand; its content is never printed and never committed.
//
// Exit code 1 when an ERROR was found, 0 otherwise (warnings do not fail).
//
// Known limit: it reads files, not the git history. A secret that was
// committed once and removed later is not found here.

import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { pathToFileURL } from 'node:url';

// ---- What is skipped ------------------------------------------------------

// Folders that hold built or downloaded files, never hand-written ones.
const SKIPPED_FOLDERS = [
  'build/',
  '.dart_tool/',
  'node_modules/',
  '.git/',
  '.gradle/',
  'Pods/',
  // Generated from the ARB files by "flutter gen-l10n".
  'lib/l10n/generated/',
];

// Lock files: long lists of package hashes, written by tools.
const SKIPPED_NAMES = ['package-lock.json', 'pubspec.lock', 'Podfile.lock'];

const BINARY_EXTENSIONS = [
  'png', 'jpg', 'jpeg', 'gif', 'webp', 'ico', 'icns', 'bmp', 'svgz',
  'ttf', 'otf', 'woff', 'woff2', 'jar', 'apk', 'aab', 'zip', 'gz', 'pdf',
  'so', 'dll', 'exe', 'bin', 'mp3', 'mp4',
];

/** Whether the content of [path] is not looked at. Paths use "/". */
export function isSkippedPath(path) {
  const normal = path.replaceAll('\\', '/');
  const inSkippedFolder = SKIPPED_FOLDERS.some(
    (folder) => normal.startsWith(folder) || normal.includes(`/${folder}`),
  );
  if (inSkippedFolder) return true;
  const name = basename(normal);
  if (SKIPPED_NAMES.includes(name)) return true;
  const extension = name.includes('.') ? name.split('.').pop() : '';
  return BINARY_EXTENSIONS.includes(extension.toLowerCase());
}

/** Whether [buffer] looks like a binary file: it has a zero byte early. */
export function isBinary(buffer) {
  return buffer.subarray(0, 8000).includes(0);
}

// ---- Files that must not be in the repository at all ----------------------

const FORBIDDEN_NAMES = [
  /^\.env(\..+)?$/i,
  /^key\.properties$/i,
  /\.(jks|keystore|p12|pfx|pem)$/i,
  /^service[-_]?account.*\.json$/i,
  /-firebase-adminsdk-.*\.json$/i,
];

/** The rule a file breaks by its NAME alone, or null. */
export function forbiddenFileRule(path) {
  const name = basename(path.replaceAll('\\', '/'));
  return FORBIDDEN_NAMES.some((pattern) => pattern.test(name))
    ? 'forbidden-file'
    : null;
}

// ---- The rules for the content --------------------------------------------

// The two Firebase client configuration files. Their API key is not a
// secret (it only names the project) and they are allowed in the
// repository; see docs/PLAN.md. ONLY the API key is exempt there: any
// other password-like value in these files is still an error.
const API_KEY_FILES = [
  'lib/firebase_options.dart',
  'android/app/google-services.json',
];
const API_KEY = /AIza[0-9A-Za-z_-]{35}/g;
const API_KEY_START = 'AIza';

// The e-mail addresses that may appear.
//
// 1. Addresses at the domains that are reserved for examples and can never
//    belong to anybody (RFC 2606 and RFC 6761): example.com, example.net
//    and example.org with their sub-domains, and every domain whose LAST
//    label is "example", "invalid", "test" or "localhost".
// 2. Two exact addresses: the placeholder for "the customer has no e-mail"
//    and the address of the commit trailer.
//
// The whole domain is looked at, from its end: "example.com.evil.org" and
// "notexample.org" are not allowed.
const RESERVED_DOMAINS = ['example.com', 'example.net', 'example.org'];
const RESERVED_LAST_LABELS = ['example', 'invalid', 'test', 'localhost'];
const EXACT_ADDRESSES = ['none@no-email.invalid', 'noreply@anthropic.com'];

/** Whether the e-mail [address] may appear in the repository. */
export function isAllowedEmail(address) {
  const lower = address.toLowerCase();
  if (EXACT_ADDRESSES.includes(lower)) return true;
  const domain = lower.slice(lower.lastIndexOf('@') + 1);
  const labels = domain.split('.');
  if (RESERVED_LAST_LABELS.includes(labels[labels.length - 1])) return true;
  return RESERVED_DOMAINS.some(
    (reserved) => domain === reserved || domain.endsWith(`.${reserved}`),
  );
}

// ---- The optional local deny list ------------------------------------------

/** Where the deny list is, relative to the root of the repository. */
export const DENYLIST_PATH = 'tool/private_denylist.txt';

// A shorter line would match far too much ("a", "the").
const DENYLIST_MIN_LENGTH = 4;

/**
 * Reads the deny list of the repository [cwd], when there is one.
 *
 * Returns { entries, findings }. [entries] are the texts to look for, in
 * lower case; [findings] are the problems of the list itself. A finding
 * never holds a text of the list, only the number of its line.
 *
 * The list is used only when git ignores it and does not track it. If it
 * could be committed, that is the error "denylist-not-ignored" and the
 * list is not used at all.
 */
export function loadDenylist(cwd) {
  const file = join(cwd, ...DENYLIST_PATH.split('/'));
  if (!existsSync(file)) return { entries: [], findings: [] };

  const run = (args) =>
    spawnSync('git', args, { cwd, windowsHide: true, stdio: 'pipe' }).status;
  // Exit code 0: git knows the file (it is tracked, or staged).
  const tracked = run(['ls-files', '--error-unmatch', DENYLIST_PATH]) === 0;
  // Exit code 0: an ignore rule covers the file.
  const ignored = run(['check-ignore', '-q', DENYLIST_PATH]) === 0;
  if (tracked || !ignored) {
    return {
      entries: [],
      findings: [
        {
          path: DENYLIST_PATH,
          level: 'error',
          rule: 'denylist-not-ignored',
          line: 0,
          length: 0,
        },
      ],
    };
  }

  const entries = [];
  const findings = [];
  readFileSync(file, 'utf8')
    .split(/\r?\n/)
    .forEach((raw, index) => {
      const text = raw.trim();
      if (text === '' || text.startsWith('#')) return;
      if (text.length < DENYLIST_MIN_LENGTH) {
        findings.push({
          path: DENYLIST_PATH,
          level: 'warning',
          rule: 'denylist-line-too-short',
          line: index + 1,
          length: 0,
        });
        return;
      }
      entries.push(text.toLowerCase());
    });
  return { entries: [...new Set(entries)], findings };
}

// A value that plainly says it is made up is not a secret.
const MADE_UP_VALUE = /^(made-up|fake|example|test|dummy|placeholder)/i;

const EMAIL =
  /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g;

// A word such as "password" or "token", then ":" or "=", then a quoted
// value of at least six characters without a space.
const SECRET_NAMES = '(password|passwd|pwd|secret|token|api[_-]?key)';
const SECRET_VALUE = new RegExp(
  `\\b${SECRET_NAMES}\\b["']?\\s*[:=]\\s*(["'\`])([^"'\`\\s]{6,})\\2`,
  'gi',
);
const PHONE = /\+\d[\d ().-]{7,}\d/g;

/**
 * Every finding in [text], the content of the file [path].
 * A finding is { level: 'error' | 'warning', rule, line, length }.
 * The found value itself is never part of a finding.
 *
 * [denylist] are the texts of the local deny list, in lower case; each is
 * looked for as it is, whatever the case of the letters in [text].
 */
export function scanText(path, text, denylist = []) {
  const normal = path.replaceAll('\\', '/');
  const isApiKeyFile = API_KEY_FILES.includes(normal);
  const findings = [];
  const add = (level, rule, line, value) =>
    findings.push({ level, rule, line, length: value.length });

  const lines = text.split(/\r?\n/);
  lines.forEach((content, index) => {
    const line = index + 1;

    // A private key, as PEM text.
    for (const m of content.matchAll(/-----BEGIN [A-Z ]*PRIVATE KEY-----/g)) {
      add('error', 'private-key', line, m[0]);
    }

    // The marks of a service account key file.
    for (const m of content.matchAll(/"private_key(?:_id)?"\s*:/g)) {
      add('error', 'service-account-key', line, m[0]);
    }
    for (const m of content.matchAll(/"type"\s*:\s*"service_account"/g)) {
      add('error', 'service-account-key', line, m[0]);
    }

    // A Google API key, outside the two allowed configuration files.
    if (!isApiKeyFile) {
      for (const m of content.matchAll(API_KEY)) {
        add('error', 'google-api-key', line, m[0]);
      }
    }

    // A password, token or secret written as a value. In the two allowed
    // configuration files only a value that IS the API key is let through
    // ("apiKey: '...'"); everything else is checked there as well.
    for (const m of content.matchAll(SECRET_VALUE)) {
      const value = m[3];
      if (MADE_UP_VALUE.test(value)) continue;
      if (isApiKeyFile && value.startsWith(API_KEY_START)) continue;
      add('error', 'secret-value', line, value);
    }

    // A text of the local deny list, in any case of the letters.
    if (denylist.length > 0) {
      const lower = content.toLowerCase();
      for (const entry of denylist) {
        if (lower.includes(entry)) {
          add('error', 'denylist-match', line, entry);
        }
      }
    }

    // Something shaped like an App Check debug token (a UUID).
    const uuid =
      /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi;
    for (const m of content.matchAll(uuid)) {
      add('error', 'debug-token-shape', line, m[0]);
    }

    // An e-mail address outside the allow list. "icon@2x.png" is the name
    // of an image, not an address.
    for (const m of content.matchAll(EMAIL)) {
      const address = m[0];
      if (/@[0-9]+x\./i.test(address)) continue;
      if (isAllowedEmail(address)) continue;
      add('error', 'email-address', line, address);
    }

    // WARNINGS: too many false alarms to stop a commit.

    // A phone number that is not one of the made-up 555 numbers.
    for (const m of content.matchAll(PHONE)) {
      const digits = m[0].replace(/\D/g, '');
      if (digits.startsWith('995555')) continue;
      add('warning', 'phone-number', line, m[0]);
    }

    // A quoted text shaped like a Firestore document ID (20 characters) or
    // an account UID (28): letters and digits mixed.
    const id = /(["'`/])([A-Za-z0-9]{28}|[A-Za-z0-9]{20})(["'`])/g;
    for (const m of content.matchAll(id)) {
      const value = m[2];
      if (/[0-9]/.test(value) && /[a-z]/.test(value) && /[A-Z]/.test(value)) {
        add('warning', 'id-shape', line, value);
      }
    }
  });
  return findings;
}

/** What is printed in place of a found value: its length only. */
export function mask(length) {
  return `<masked, ${length} characters>`;
}

// ---- Which files -----------------------------------------------------------

function git(args, cwd) {
  return execFileSync('git', args, {
    cwd,
    maxBuffer: 256 * 1024 * 1024,
    windowsHide: true,
  });
}

/**
 * The paths to check, relative to the repository [cwd], with "/".
 * Normal mode: tracked files and new files that are not ignored.
 * Staged mode: the files staged for the next commit (not the deleted ones).
 */
export function listFiles({ staged, cwd }) {
  const args = staged
    ? ['diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z']
    : ['ls-files', '--cached', '--others', '--exclude-standard', '-z'];
  const paths = git(args, cwd).toString('utf8').split('\0').filter(Boolean);
  return [...new Set(paths)].sort();
}

/**
 * The content of [path] as a buffer, or null when there is none.
 * Staged mode reads what is STAGED (the index), not the working copy.
 */
export function readContent(path, { staged, cwd }) {
  if (staged) {
    try {
      return git(['show', `:${path}`], cwd);
    } catch {
      return null;
    }
  }
  const file = join(cwd, ...path.split('/'));
  // Listed by git but deleted in the working copy.
  if (!existsSync(file)) return null;
  return readFileSync(file);
}

/**
 * Checks the repository [cwd]. Returns
 * { findings: [{ path, level, rule, line, length }], checked, skipped,
 *   missing }.
 */
export function scanRepo({ staged = false, cwd = process.cwd() } = {}) {
  // The deny list is always read from the disk: git ignores it, so it is
  // never staged. What it is compared WITH is the staged content in the
  // staged mode, like for every other rule.
  const denylist = loadDenylist(cwd);
  const findings = [...denylist.findings];
  let checked = 0;
  let skipped = 0;
  let missing = 0;

  for (const path of listFiles({ staged, cwd })) {
    // The deny list itself is never looked into, also when git does not
    // ignore it (that is reported above).
    if (path === DENYLIST_PATH) continue;
    // The name alone can be wrong, whatever is inside.
    const rule = forbiddenFileRule(path);
    if (rule !== null) {
      findings.push({ path, level: 'error', rule, line: 0, length: 0 });
    }
    if (isSkippedPath(path)) {
      skipped += 1;
      continue;
    }
    const buffer = readContent(path, { staged, cwd });
    if (buffer === null) {
      missing += 1;
      continue;
    }
    if (isBinary(buffer)) {
      skipped += 1;
      continue;
    }
    checked += 1;
    const text = buffer.toString('utf8');
    for (const finding of scanText(path, text, denylist.entries)) {
      findings.push({ path, ...finding });
    }
  }
  return { findings, checked, skipped, missing };
}

/** The lines the script prints for [result]; no found value is in them. */
export function report(result, { staged }) {
  const lines = [];
  const order = { error: 0, warning: 1 };
  const sorted = [...result.findings].sort(
    (a, b) =>
      order[a.level] - order[b.level] ||
      a.path.localeCompare(b.path) ||
      a.line - b.line,
  );
  for (const f of sorted) {
    const level = f.level === 'error' ? 'ERROR  ' : 'WARNING';
    const where = f.line > 0 ? `${f.path}:${f.line}` : f.path;
    const value = f.length > 0 ? `  ${mask(f.length)}` : '';
    lines.push(`${level}  ${where}  ${f.rule}${value}`);
  }
  const errors = sorted.filter((f) => f.level === 'error').length;
  const warnings = sorted.length - errors;
  if (sorted.length > 0) lines.push('');
  lines.push(
    `Checked ${result.checked} files ` +
      `(${staged ? 'staged content' : 'working copy'}); ` +
      `skipped ${result.skipped}` +
      (result.missing > 0 ? `; ${result.missing} listed but missing` : '') +
      '.',
  );
  lines.push(`Errors: ${errors}. Warnings: ${warnings}.`);
  lines.push(
    errors > 0
      ? 'FAILED: do not commit before every error is resolved.'
      : 'OK: no errors. Warnings do not stop a commit; look at them.',
  );
  return { lines, errors, warnings };
}

function main(argv) {
  const known = ['--staged'];
  const unknown = argv.filter((arg) => !known.includes(arg));
  if (unknown.length > 0) {
    console.error(`Unknown argument: ${unknown.join(' ')}`);
    console.error('Usage: node tool/check_secrets.mjs [--staged]');
    return 2;
  }
  const staged = argv.includes('--staged');
  let cwd;
  try {
    cwd = git(['rev-parse', '--show-toplevel'], process.cwd())
      .toString('utf8')
      .trim();
  } catch {
    console.error('This is not a git repository.');
    return 2;
  }
  const { lines, errors } = report(scanRepo({ staged, cwd }), { staged });
  for (const line of lines) console.log(line);
  return errors > 0 ? 1 : 0;
}

// Run only when started as a script, not when imported by the tests.
if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  process.exit(main(process.argv.slice(2)));
}
