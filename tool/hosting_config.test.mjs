// Guards the Hosting part of firebase.json (step 7.7a). It reads the file
// as JSON only and does not imitate how Hosting matches paths: the proof
// that the headers work is the curl -I check on the live domain.
//
// Hosting matches header rules against the requested path, before any
// rewrite, and applies every matching rule in order; for the same header
// the last rule wins (not documented; checked live in step 7.7a). So the
// "**" no-cache rule comes first and the image and font rule last.
//
// Run: node --test tool/hosting_config.test.mjs

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const config = JSON.parse(
  fs.readFileSync(
    path.join(
      path.dirname(fileURLToPath(import.meta.url)),
      '..',
      'firebase.json',
    ),
    'utf8',
  ),
);
const hosting = config.hosting;
const rules = hosting.headers;

const imageSource = '**/*.@(png|jpg|svg|otf|ttf|woff|woff2)';

/// Every Cache-Control value of [rule], whatever the case of the key.
function cacheControl(rule) {
  return rule.headers
    .filter((header) => header.key.toLowerCase() === 'cache-control')
    .map((header) => header.value);
}

test('exactly two header rules', () => {
  assert.equal(rules.length, 2);
});

test('the first rule: every path gets no-cache, and nothing else', () => {
  assert.equal(rules[0].source, '**');
  assert.deepEqual(rules[0].headers, [
    { key: 'Cache-Control', value: 'no-cache' },
  ]);
});

test('the last rule: images and fonts are kept for one day', () => {
  const last = rules.at(-1);
  assert.equal(last.source, imageSource);
  assert.deepEqual(last.headers, [
    { key: 'Cache-Control', value: 'max-age=86400' },
  ]);
});

test('no other rule sets Cache-Control', () => {
  const setting = rules.filter((rule) => cacheControl(rule).length > 0);
  assert.deepEqual(
    setting.map((rule) => rule.source),
    ['**', imageSource],
  );
});

test('every address is rewritten to index.html, from build/web', () => {
  assert.equal(hosting.public, 'build/web');
  assert.deepEqual(hosting.rewrites, [
    { source: '**', destination: '/index.html' },
  ]);
});

test('the Firestore block still names the rules and the indexes', () => {
  assert.deepEqual(config.firestore, {
    rules: 'firestore.rules',
    indexes: 'firestore.indexes.json',
  });
});
