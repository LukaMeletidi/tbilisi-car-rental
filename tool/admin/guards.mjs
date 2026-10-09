// tool/admin/guards.mjs
//
// The safety checks of set_admin_claim.mjs. Nothing here talks to Firebase
// or to the network, so the checks can be tested without a real key.

import { readFileSync, realpathSync } from 'node:fs';
import path from 'node:path';

// The only project this tool may ever touch.
export const EXPECTED_PROJECT_ID = 'tbilisi-car-rental';

// The environment variable that holds the path of the key file.
export const KEY_FILE_VARIABLE = 'ADMIN_KEY_FILE';

export const MODES = ['show', 'set', 'remove'];

// A reason to stop. Its message is shown to the user; the exit code is 1.
export class Refusal extends Error {}

const USAGE =
  'Usage: node set_admin_claim.mjs [show|set|remove] <UID>\n' +
  'Without a mode the account is only shown; nothing is changed.';

// "show" is the default. A change must be asked for by name.
export function parseArguments(args) {
  if (args.length < 1 || args.length > 2) throw new Refusal(USAGE);
  const mode = args.length === 2 ? args[0] : 'show';
  const uid = args[args.length - 1];

  if (!MODES.includes(mode)) {
    throw new Refusal(`Unknown mode "${mode}".\n${USAGE}`);
  }
  if (args.length === 1 && MODES.includes(uid)) {
    throw new Refusal(`The UID is missing.\n${USAGE}`);
  }
  if (uid.includes('@')) {
    throw new Refusal(
      'This looks like an e-mail. Give the UID of the account instead ' +
        '(Firebase console > Authentication > Users > User UID).',
    );
  }
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid)) {
    throw new Refusal('The UID has an unexpected form.');
  }
  return { mode, uid };
}

export function keyPathFromEnvironment(env) {
  const value = env[KEY_FILE_VARIABLE];
  if (value === undefined || value.trim() === '') {
    throw new Refusal(
      `The environment variable ${KEY_FILE_VARIABLE} is not set. It must ` +
        'hold the full path of the service account key file.',
    );
  }
  return value;
}

// Folders that are copied to a cloud service on this computer.
export function syncedFoldersFromEnvironment(env) {
  return ['OneDrive', 'OneDriveConsumer', 'OneDriveCommercial']
    .map((name) => env[name])
    .filter((value) => typeof value === 'string' && value !== '');
}

// True when [child] is [parent] itself or lies somewhere below it.
function isInside(parent, child) {
  const relative = path.relative(parent, child);
  return (
    relative === '' ||
    (!relative.startsWith('..') && !path.isAbsolute(relative))
  );
}

// Checks where the key file really is and returns its real path.
//
// The real paths are compared (links and junctions are followed), so a link
// that only looks like it is outside the repository does not pass. A
// relative path is refused outright.
export function checkKeyLocation(keyPath, { repositoryRoot, syncedFolders }) {
  if (!path.isAbsolute(keyPath)) {
    throw new Refusal(
      `${KEY_FILE_VARIABLE} must be a full path, not a relative one.`,
    );
  }
  let realKey;
  try {
    realKey = realpathSync.native(keyPath);
  } catch {
    throw new Refusal('The key file was not found or cannot be opened.');
  }
  if (isInside(realpathSync.native(repositoryRoot), realKey)) {
    throw new Refusal(
      'The key file is inside the repository. Move it out of the project ' +
        'folder first; a key must never be where git can see it.',
    );
  }
  for (const folder of syncedFolders ?? []) {
    let realFolder;
    try {
      realFolder = realpathSync.native(folder);
    } catch {
      continue; // The folder does not exist on this computer.
    }
    if (isInside(realFolder, realKey)) {
      throw new Refusal(
        'The key file is inside a synced folder (OneDrive). Move it to a ' +
          'folder that is not copied to the cloud.',
      );
    }
  }
  return realKey;
}

// Reads and checks the key. The contents are never put into a message.
export function readKey(realKeyPath) {
  let text;
  try {
    text = readFileSync(realKeyPath, 'utf8');
  } catch {
    throw new Refusal('The key file cannot be read.');
  }
  let key;
  try {
    key = JSON.parse(text);
  } catch {
    throw new Refusal('The key file is not valid JSON.');
  }
  if (key === null || typeof key !== 'object' || Array.isArray(key)) {
    throw new Refusal('The key file is not a service account key.');
  }
  if (key.type !== 'service_account') {
    throw new Refusal('The key file is not a service account key.');
  }
  if (key.project_id !== EXPECTED_PROJECT_ID) {
    const found =
      typeof key.project_id === 'string' ? `"${key.project_id}"` : 'none';
    throw new Refusal(
      `The key belongs to another project (${found}). This tool only ` +
        `works with "${EXPECTED_PROJECT_ID}".`,
    );
  }
  for (const field of ['client_email', 'private_key']) {
    if (typeof key[field] !== 'string' || key[field] === '') {
      throw new Refusal(`The key file has no "${field}".`);
    }
  }
  return key;
}

// The claims of the account after the change. Every other claim is kept.
// Returns null when no claim is left.
export function claimsAfter(mode, currentClaims) {
  const claims = { ...(currentClaims ?? {}) };
  if (mode === 'set') claims.admin = true;
  if (mode === 'remove') delete claims.admin;
  return Object.keys(claims).length === 0 ? null : claims;
}

// The repository root, seen from the folder tool/admin.
export function repositoryRootFrom(adminToolFolder) {
  return path.resolve(adminToolFolder, '..', '..');
}
