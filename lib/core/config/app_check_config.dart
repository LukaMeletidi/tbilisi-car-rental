import 'package:firebase_app_check/firebase_app_check.dart';

/// The site key of the web app's reCAPTCHA Enterprise key for App Check
/// (step 7.6). It is public by design: the browser sends it to reCAPTCHA,
/// and the Firebase documentation passes it in the app's code. Enterprise
/// has no second, private key, and a debug token is never written into
/// this project.
const appCheckWebSiteKey = '6LfTdvgtAAAAAKnWYcLtyDq-uhBp4cvTWjVh-Eon';

/// The App Check provider of the web app, or null when there is none.
///
/// - [debug] (flutter run): the debug provider. The Firebase JS SDK makes a
///   debug token and prints it in the browser console; the owner registers
///   it in the Firebase console. It is never passed in from the code.
/// - Otherwise reCAPTCHA Enterprise with [siteKey]; an empty key means no
///   App Check on the web at all, and the app works as before.
///
/// App Check is monitoring only: nothing is enforced, so requests without a
/// valid token are still accepted.
WebProvider? appCheckWebProvider({
  required bool debug,
  required String siteKey,
}) {
  if (debug) return WebDebugProvider();
  final key = siteKey.trim();
  if (key.isEmpty) return null;
  return ReCaptchaEnterpriseProvider(key);
}
