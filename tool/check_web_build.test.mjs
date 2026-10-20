// Tests of tool/check_web_build.mjs with made-up project folders.
// Run: node --test tool/check_web_build.test.mjs

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { WEB_PLUGIN_MARKERS, checkWebBuild } from './check_web_build.mjs';

const script = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'check_web_build.mjs',
);

/// A made-up project folder with the given web plugins and main.dart.js.
function project({ plugins, js, withBuild = true, deps }) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'web-build-test-'));
  const content =
    deps ??
    JSON.stringify({ plugins: { web: plugins.map((name) => ({ name })) } });
  fs.writeFileSync(path.join(root, '.flutter-plugins-dependencies'), content);
  if (withBuild) {
    fs.mkdirSync(path.join(root, 'build', 'web'), { recursive: true });
    fs.writeFileSync(path.join(root, 'build', 'web', 'main.dart.js'), js);
  }
  return root;
}

function run(root) {
  return spawnSync(process.execPath, [script, '--root', root], {
    encoding: 'utf8',
  });
}

const allPlugins = Object.keys(WEB_PLUGIN_MARKERS);
const allMarkers = Object.values(WEB_PLUGIN_MARKERS).join(' ');

test('every web plugin in the build: passes with exit code 0', () => {
  const root = project({ plugins: allPlugins, js: `x ${allMarkers} y` });
  assert.equal(checkWebBuild(root).ok, true);
  const result = run(root);
  assert.equal(result.status, 0);
  assert.match(result.stdout, /OK: every web plugin is in the build/);
  assert.match(result.stdout, /firebase_auth_web\s+yes/);
});

test('flutter-fire-auth missing: fails with exit code 1', () => {
  const js = allMarkers.replace('flutter-fire-auth', '');
  const root = project({ plugins: allPlugins, js });
  const check = checkWebBuild(root);
  assert.equal(check.ok, false);
  assert.deepEqual(
    check.rows.find((row) => row.name === 'firebase_auth_web'),
    { name: 'firebase_auth_web', found: 'no' },
  );
  const result = run(root);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /firebase_auth_web\s+no/);
  assert.match(result.stdout, /MISSING/);
});

test('no build: fails with a clear message', () => {
  const root = project({ plugins: allPlugins, js: '', withBuild: false });
  const result = run(root);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /No build\/web\/main\.dart\.js/);
});

test('no .flutter-plugins-dependencies: fails with a clear message', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'web-build-test-'));
  const result = run(root);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /run "flutter pub get"/);
});

test('an unreadable plugin list: fails without printing it', () => {
  const root = project({ plugins: [], js: '', deps: '{ not json SECRET' });
  const result = run(root);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /could not be read/);
  assert.doesNotMatch(result.stdout, /SECRET/);
});

test('a web plugin without a known marker: fails', () => {
  const root = project({
    plugins: [...allPlugins, 'new_plugin_web'],
    js: allMarkers,
  });
  const result = run(root);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /new_plugin_web\s+no marker known/);
});

test('the output never contains the build file', () => {
  const root = project({ plugins: allPlugins, js: `${allMarkers} TOKEN-123` });
  assert.doesNotMatch(run(root).stdout, /TOKEN-123/);
});
