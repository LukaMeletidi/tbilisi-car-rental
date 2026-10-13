import 'package:flutter/foundation.dart';

/// Whether the app switches off the copy of its data that Firestore keeps
/// ON DISK, and removes an old one, on this platform.
///
/// - Android and iOS: yes. By default Firestore keeps everything the app
///   has read in a file on the device, also after the app is closed and
///   after Sign out. An admin reads bookings with names, phone numbers and
///   e-mail addresses; they must not stay on the device.
/// - Web: no change. A browser keeps nothing on disk unless the app asks
///   for it, and this app does not; the setting is not touched at all.
/// - Every other platform (the unused desktop folders): no change.
///
/// What Firestore keeps in memory while the app runs is not affected.
bool turnsFirestoreDiskCopyOff({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return false;
  switch (platform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return false;
  }
}
