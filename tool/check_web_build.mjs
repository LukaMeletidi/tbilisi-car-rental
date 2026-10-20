// Checks a release web build: every plugin with a web implementation must be
// compiled into build/web/main.dart.js.
//
// Why: Flutter 3.44 caches the step that writes web_plugin_registrant.dart
// (its only input is a Flutter tool file), so a plugin added after the
// first release build may be left out. The app then falls back to the
// method channel on the web; in step 7.5 the admin sign-in failed with
// "channel-error". Run this after every `flutter build web --release` and
// before every deploy; `flutter clean` before the build fixes a stale cache.
//
// Read-only. It prints no file contents: only plugin names and yes/no.
//
// Usage: node tool/check_web_build.mjs [--root <project dir>]
// Exit code: 0 when every web plugin is found; 1 otherwise, or when a file
// is missing or cannot be read.

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

/// A text that only the plugin's web registration brings into main.dart.js.
/// The FlutterFire plugins register their library name; url_launcher_web
/// registers its link view type. A new web plugin needs a marker here.
export const WEB_PLUGIN_MARKERS = {
  cloud_firestore_web: 'flutter-fire-fst',
  firebase_app_check_web: 'flutter-fire-app-check',
  firebase_auth_web: 'flutter-fire-auth',
  firebase_core_web: 'flutter-fire-core',
  url_launcher_web: '__url_launcher::link',
};

/// Checks the build under [root]. Returns { ok, rows, error }.
export function checkWebBuild(root) {
  const depsPath = path.join(root, '.flutter-plugins-dependencies');
  const jsPath = path.join(root, 'build', 'web', 'main.dart.js');
  if (!fs.existsSync(depsPath)) {
    return {
      ok: false,
      rows: [],
      error: 'No .flutter-plugins-dependencies: run "flutter pub get".',
    };
  }
  if (!fs.existsSync(jsPath)) {
    return {
      ok: false,
      rows: [],
      error:
        'No build/web/main.dart.js: run "flutter build web --release" first.',
    };
  }

  let plugins;
  let js;
  try {
    const deps = JSON.parse(fs.readFileSync(depsPath, 'utf8'));
    plugins = (deps.plugins?.web ?? []).map((plugin) => plugin.name);
    js = fs.readFileSync(jsPath, 'utf8');
  } catch (error) {
    return {
      ok: false,
      rows: [],
      error: `A file could not be read (${error.name}).`,
    };
  }

  const rows = plugins.map((name) => {
    const marker = WEB_PLUGIN_MARKERS[name];
    if (marker === undefined) return { name, found: 'no marker known' };
    return { name, found: js.includes(marker) ? 'yes' : 'no' };
  });
  return { ok: rows.every((row) => row.found === 'yes'), rows, error: null };
}

function main(argv) {
  const at = argv.indexOf('--root');
  const root = at >= 0 ? argv[at + 1] : process.cwd();
  const result = checkWebBuild(root);
  if (result.error) {
    console.log(`ERROR  ${result.error}`);
    return 1;
  }
  for (const row of result.rows) {
    console.log(`${row.name.padEnd(26)} ${row.found}`);
  }
  console.log(
    result.ok
      ? 'OK: every web plugin is in the build.'
      : 'MISSING: run "flutter clean", then build again.',
  );
  return result.ok ? 0 : 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  process.exit(main(process.argv.slice(2)));
}
