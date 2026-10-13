import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:tbilisi_car_rental/core/data/firestore_disk_copy.dart';

/// How long the start of the app waits for the old disk copy to be removed.
const firestoreClearTimeout = Duration(seconds: 5);

/// Sets Firestore up before anything uses it. Call it ONCE, right after
/// Firebase.initializeApp and before runApp.
///
/// On Android and iOS (see [turnsFirestoreDiskCopyOff]) it does two things:
///
/// 1. It tells Firestore not to keep a copy of the data on disk. From then
///    on what the app reads lives in memory only, until the app is closed.
/// 2. It removes the copy an earlier version of the app left on the
///    device.
///
/// The order matters and is NOT "remove, then switch off". The plugin
/// creates the real Firestore object, with the settings it has at that
/// moment, on the first call that reaches it, and keeps that object for
/// as long as the app runs. Removing the old copy is such a call. So the
/// setting is given first (that only stores a value on the Dart side), and
/// the removal second: it then creates the object already without a disk
/// copy. The plugin's documentation allows exactly this: clearPersistence
/// "must be called before other methods (other than settings)".
///
/// Web and every other platform are not touched at all.
///
/// It never stops the app from starting. A failure is logged with the type
/// of the error only; the app then starts as before. If only the removal
/// fails, the old file stays on the device until the app's data is
/// cleared, but nothing new is written to it.
///
/// Note of the plugin: the removal drops the old data but does not
/// overwrite it securely.
Future<void> setUpFirestore() async {
  final disk = turnsFirestoreDiskCopyOff(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );
  if (!disk) return;

  final firestore = FirebaseFirestore.instance;

  // 1. No copy on disk any more. Nothing is sent to the plugin yet.
  try {
    firestore.settings = const Settings(persistenceEnabled: false);
  } catch (error) {
    _logFailure('switching the disk copy off', error);
    // Without the setting the removal would create Firestore WITH a disk
    // copy, which is the old behaviour anyway; nothing more to do here.
    return;
  }

  // 2. Remove what an earlier version left behind. Firestore allows this
  //    only now, before its first real use.
  try {
    await firestore.clearPersistence().timeout(firestoreClearTimeout);
  } catch (error) {
    _logFailure('removing the old disk copy', error);
  }
}

void _logFailure(String what, Object error) {
  // The type only: an error text could hold a path or other details.
  developer.log(
    'Firestore start-up: $what failed with ${error.runtimeType}',
    name: 'setUpFirestore',
    level: 900, // warning
  );
}
