import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gives the current moment in UTC.
///
/// Code that needs "now" reads it from here instead of calling
/// DateTime.now(), so tests can replace it with a fixed moment. The result
/// does not depend on the time zone of the device.
final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);
