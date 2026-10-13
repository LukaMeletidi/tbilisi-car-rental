import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/data/firestore_disk_copy.dart';

void main() {
  bool off(TargetPlatform platform, {bool isWeb = false}) =>
      turnsFirestoreDiskCopyOff(isWeb: isWeb, platform: platform);

  test('Android: the disk copy is switched off', () {
    expect(off(TargetPlatform.android), true);
  });

  test('iOS: the disk copy is switched off', () {
    expect(off(TargetPlatform.iOS), true);
  });

  test('web is not touched, whatever device the browser runs on', () {
    for (final platform in TargetPlatform.values) {
      expect(off(platform, isWeb: true), false, reason: platform.name);
    }
  });

  test('the other platforms are not touched', () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      expect(off(platform), false, reason: platform.name);
    }
  });

  test('only Android and iOS are switched off', () {
    final switchedOff = {
      for (final platform in TargetPlatform.values)
        if (off(platform)) platform,
    };
    expect(switchedOff, {TargetPlatform.android, TargetPlatform.iOS});
  });
}
