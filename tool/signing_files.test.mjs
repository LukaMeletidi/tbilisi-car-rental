// Guards the Android release signing (step 7.9): the keystore and
// android/key.properties stay out of git, and the build file reads the
// signing values only from key.properties.
//
// It reads only android/app/build.gradle.kts and git's output. It never
// opens key.properties or a keystore, and creates no file: the paths
// given to git check-ignore are examples.
//
// Run: node --test tool/signing_files.test.mjs

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const buildFile = fs.readFileSync(
  path.join(root, 'android', 'app', 'build.gradle.kts'),
  'utf8',
);

function git(...args) {
  return spawnSync('git', args, { cwd: root, encoding: 'utf8' });
}

const examplePaths = [
  'android/key.properties',
  'android/app/x.jks',
  'android/x.keystore',
  'x.jks',
  'x.keystore',
];

test('git ignores key.properties and keystores (example paths)', () => {
  for (const example of examplePaths) {
    // Exit code 0: ignored; 1: not ignored.
    assert.equal(git('check-ignore', '-q', example).status, 0, example);
  }
});

test('git tracks no keystore and no key.properties', () => {
  const result = git('ls-files');
  assert.equal(result.status, 0);
  const tracked = result.stdout
    .split(/\r?\n/)
    .filter((file) => /(\.(jks|keystore|p12|pfx)|(^|\/)key\.properties)$/i
      .test(file));
  assert.deepEqual(tracked, []);
});

test('the release build is signed with the release config, not debug', () => {
  assert.match(
    buildFile,
    /signingConfig = signingConfigs\.findByName\("release"\)/,
  );
  assert.doesNotMatch(buildFile, /signingConfigs\.getByName\("debug"\)/);
});

test('the four signing values come only from key.properties', () => {
  for (const name of ['storePassword', 'keyPassword', 'keyAlias']) {
    assert.match(
      buildFile,
      new RegExp(`${name} = keystoreProperties\\.getProperty\\("${name}"\\)`),
      name,
    );
  }
  assert.match(
    buildFile,
    /storeFile = file\(keystoreProperties\.getProperty\("storeFile"\)\)/,
  );
  // No value written into the build file itself.
  assert.doesNotMatch(buildFile, /(store|key)Password\s*=\s*"/);
  assert.doesNotMatch(buildFile, /keyAlias\s*=\s*"/);
  assert.doesNotMatch(buildFile, /storeFile\s*=\s*file\("/);
});

test('a release build without key.properties stops with a clear error', () => {
  assert.match(buildFile, /rootProject\.file\("key\.properties"\)/);
  assert.match(buildFile, /android\/key\.properties is missing/);
  assert.match(buildFile, /android\/key\.properties lacks:/);
  assert.match(buildFile, /The keystore named in android\/key\.properties/);
});
