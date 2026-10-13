import 'dart:developer' as developer;

/// Notes for the developer that [what] could not be loaded. Only the TYPE
/// of the error is written: its text could hold details that must not end
/// up in a log, and it is never shown on a screen.
void logLoadError(String what, Object error) {
  developer.log(
    '$what could not be loaded: ${error.runtimeType}',
    name: 'load',
    level: 900, // warning
  );
}
