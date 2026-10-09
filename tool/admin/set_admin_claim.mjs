// tool/admin/set_admin_claim.mjs
//
// Shows, sets or removes the custom claim admin: true of ONE Firebase Auth
// account of the project tbilisi-car-rental.
//
//   node set_admin_claim.mjs <UID>           show the account (the default)
//   node set_admin_claim.mjs set <UID>       give it admin: true
//   node set_admin_claim.mjs remove <UID>    take admin away
//
// It needs a service account key. The key file must be OUTSIDE the
// repository and outside any synced folder; its full path is given in the
// environment variable ADMIN_KEY_FILE for this one command. Delete the key
// in the Google Cloud console as soon as the work is done. See docs/PLAN.md.
//
// The script touches nothing else: no Firestore, no other account, no other
// claim. It never prints the key or the path of the key file.

import { createInterface } from 'node:readline/promises';

import {
  EXPECTED_PROJECT_ID,
  Refusal,
  checkKeyLocation,
  claimsAfter,
  keyPathFromEnvironment,
  parseArguments,
  readKey,
  repositoryRootFrom,
  syncedFoldersFromEnvironment,
} from './guards.mjs';

function describeClaims(claims) {
  const names = Object.keys(claims ?? {});
  return names.length === 0 ? '(none)' : JSON.stringify(claims);
}

function printAccount(title, user) {
  console.log(title);
  console.log(`  UID:      ${user.uid}`);
  console.log(`  E-mail:   ${user.email ?? '(none)'}`);
  console.log(`  Disabled: ${user.disabled ? 'yes' : 'no'}`);
  console.log(`  Claims:   ${describeClaims(user.customClaims)}`);
}

// A change must be confirmed by typing the e-mail of the account.
async function confirmByEmail(email) {
  if (!process.stdin.isTTY) {
    throw new Refusal(
      'A change must be confirmed by hand; run this in a terminal.',
    );
  }
  const terminal = createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  try {
    const answer = await terminal.question(
      'Type the e-mail of this account to confirm: ',
    );
    return answer.trim().toLowerCase() === email.toLowerCase();
  } finally {
    terminal.close();
  }
}

async function main() {
  const { mode, uid } = parseArguments(process.argv.slice(2));

  // Every check runs before the key is used and before any network call.
  const realKeyPath = checkKeyLocation(keyPathFromEnvironment(process.env), {
    repositoryRoot: repositoryRootFrom(import.meta.dirname),
    syncedFolders: syncedFoldersFromEnvironment(process.env),
  });
  const key = readKey(realKeyPath);

  console.log(`Project:         ${key.project_id}`);
  console.log(`Service account: ${key.client_email}`);
  console.log(`Mode:            ${mode}`);
  console.log('');

  // Loaded only now, so every refusal above works without the package.
  const { cert, initializeApp } = await import('firebase-admin/app');
  const { getAuth } = await import('firebase-admin/auth');
  const auth = getAuth(
    initializeApp({ credential: cert(key), projectId: EXPECTED_PROJECT_ID }),
  );

  let user;
  try {
    user = await auth.getUser(uid);
  } catch (error) {
    if (error?.code === 'auth/user-not-found') {
      throw new Refusal('There is no account with this UID.');
    }
    throw error;
  }
  printAccount('Account:', user);

  if (mode === 'show') {
    console.log('\nNothing was changed (mode "show").');
    return;
  }

  const isAdmin = user.customClaims?.admin === true;
  if (mode === 'set' && isAdmin) {
    console.log('\nThis account already has admin: true. Nothing to do.');
    return;
  }
  if (mode === 'remove' && user.customClaims?.admin === undefined) {
    console.log('\nThis account has no admin claim. Nothing to do.');
    return;
  }
  if (!user.email) {
    throw new Refusal('This account has no e-mail; it cannot be confirmed.');
  }

  console.log(
    mode === 'set'
      ? '\nThis will GIVE this account admin rights (admin: true).'
      : '\nThis will REMOVE the admin claim from this account.',
  );
  if (!(await confirmByEmail(user.email))) {
    throw new Refusal('The e-mail does not match. Nothing was changed.');
  }

  await auth.setCustomUserClaims(uid, claimsAfter(mode, user.customClaims));

  // Read it back from the server; do not trust the call alone.
  printAccount('\nAccount after the change:', await auth.getUser(uid));
  console.log(
    '\nThe app sees the change after the next sign-in (sign out, sign in).',
  );
  console.log(
    'Now delete the key in the Google Cloud console and the key file.',
  );
}

main().catch((error) => {
  if (error instanceof Refusal) {
    console.error(`REFUSED: ${error.message}`);
  } else {
    // Only the code and the message of the error; never the key.
    console.error(`ERROR: ${error?.code ?? ''} ${error?.message ?? error}`);
  }
  process.exit(1);
});
