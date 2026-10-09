/// What the app knows about who is signed in to the admin area.
enum AdminSession {
  /// Not known yet: the app has just started and Firebase has not answered.
  /// Nothing of the admin area may be shown, and nobody is sent to the login
  /// page yet.
  unknown,

  /// Nobody is signed in.
  signedOut,

  /// An account is signed in, but its sign-in token has no admin claim.
  noAccess,

  /// The signed-in account has the claim admin: true.
  admin,
}

/// The session for an answer from Firebase Auth.
///
/// [signedIn] says whether an account is signed in; [claims] are the claims
/// of its sign-in token. The account is an admin only when the claim "admin"
/// is exactly the boolean true: a missing claim, false, the text "true" and
/// the number 1 are all "no access". The Firestore rules decide the same
/// way; this value only chooses which page is shown.
AdminSession adminSessionFromClaims({
  required bool signedIn,
  Map<String, Object?>? claims,
}) {
  if (!signedIn) return AdminSession.signedOut;
  final isAdmin = claims != null && claims['admin'] == true;
  return isAdmin ? AdminSession.admin : AdminSession.noAccess;
}
