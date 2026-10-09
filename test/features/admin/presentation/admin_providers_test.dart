import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_sign_in_failure.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_sign_in_provider.dart';

const testEmail = 'admin@example.com';
const testPassword = ' correct horse battery staple ';

/// Stands in for Firebase Auth. Records the calls and answers as the test
/// tells it to.
class FakeAdminAuthRepository implements AdminAuthRepository {
  final sessions = StreamController<AdminSession>();
  final signIns = <({String email, String password})>[];
  var signOuts = 0;

  /// When set, signIn waits for it.
  Completer<void>? pending;

  /// When set, signIn fails with it.
  Object? error;

  @override
  Stream<AdminSession> watchSession() => sessions.stream;

  @override
  Future<void> signIn({required String email, required String password}) {
    signIns.add((email: email, password: password));
    if (pending != null) return pending!.future;
    if (error != null) return Future.error(error!);
    return Future.value();
  }

  @override
  Future<void> signOut() async => signOuts += 1;
}

late FakeAdminAuthRepository repository;
late ProviderContainer container;

void main() {
  setUp(() {
    repository = FakeAdminAuthRepository();
    container = ProviderContainer(
      overrides: [adminAuthRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    // Not awaited: when nothing listened to the stream, the future of
    // close() never completes.
    addTearDown(() {
      unawaited(repository.sessions.close());
    });
  });

  group('adminSessionProvider', () {
    test('is unknown until Firebase gives its first answer', () async {
      expect(container.read(adminSessionProvider), AdminSession.unknown);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(adminSessionProvider), AdminSession.unknown);
    });

    test('follows the stream of the repository', () async {
      container.read(adminSessionProvider);
      for (final session in [
        AdminSession.signedOut,
        AdminSession.noAccess,
        AdminSession.admin,
        AdminSession.signedOut,
      ]) {
        repository.sessions.add(session);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(adminSessionProvider), session);
      }
    });

    test('an error of the stream becomes signedOut, never admin', () async {
      container.read(adminSessionProvider);
      repository.sessions.add(AdminSession.admin);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(adminSessionProvider), AdminSession.admin);

      repository.sessions.addError(StateError('no connection'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(adminSessionProvider), AdminSession.signedOut);
    });

    test('an error before any answer is signedOut too', () async {
      container.read(adminSessionProvider);
      repository.sessions.addError(StateError('broken'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(adminSessionProvider), AdminSession.signedOut);
    });

    test('a later answer after an error is followed again', () async {
      container.read(adminSessionProvider);
      repository.sessions.addError(StateError('no connection'));
      await Future<void>.delayed(Duration.zero);
      repository.sessions.add(AdminSession.admin);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(adminSessionProvider), AdminSession.admin);
    });
  });

  group('adminSignInProvider', () {
    late ProviderSubscription<AdminSignInState> subscription;

    AdminSignInNotifier notifier() =>
        container.read(adminSignInProvider.notifier);
    AdminSignInState state() => container.read(adminSignInProvider);

    setUp(() {
      // Keeps the auto-dispose provider alive during a test, as the login
      // page does.
      subscription = container.listen(adminSignInProvider, (_, _) {});
      addTearDown(subscription.close);
    });

    test('starts idle', () {
      expect(state().status, AdminSignInStatus.idle);
      expect(state().failure, isNull);
      expect(state().isWorking, false);
    });

    test('an empty e-mail or password fails with missingInput and calls '
        'nothing', () async {
      for (final (email, password) in [
        ('', testPassword),
        ('   ', testPassword),
        (testEmail, ''),
        ('', ''),
      ]) {
        expect(
          await notifier().signIn(email: email, password: password),
          false,
        );
        expect(state().status, AdminSignInStatus.failed);
        expect(state().failure, AdminSignInFailure.missingInput);
      }
      expect(repository.signIns, isEmpty);
    });

    test('a successful sign-in ends idle; the e-mail is trimmed and the '
        'password is sent unchanged', () async {
      expect(
        await notifier().signIn(email: '  $testEmail ', password: testPassword),
        true,
      );

      expect(state().status, AdminSignInStatus.idle);
      expect(state().failure, isNull);
      expect(repository.signIns, hasLength(1));
      expect(repository.signIns.single.email, testEmail);
      expect(repository.signIns.single.password, testPassword);
    });

    for (final failure in AdminSignInFailure.values) {
      test(
        '${failure.name} from the repository ends in the failed state',
        () async {
          repository.error = AdminSignInException(failure);

          expect(
            await notifier().signIn(email: testEmail, password: testPassword),
            false,
          );
          expect(state().status, AdminSignInStatus.failed);
          expect(state().failure, failure);
        },
      );
    }

    test('an unexpected error becomes the unknown failure', () async {
      repository.error = StateError('broken');

      expect(
        await notifier().signIn(email: testEmail, password: testPassword),
        false,
      );
      expect(state().failure, AdminSignInFailure.unknown);
    });

    test('a second press while working does nothing', () async {
      repository.pending = Completer<void>();

      final first = notifier().signIn(email: testEmail, password: testPassword);
      expect(state().status, AdminSignInStatus.working);
      expect(state().isWorking, true);

      expect(
        await notifier().signIn(email: testEmail, password: testPassword),
        false,
      );
      expect(repository.signIns, hasLength(1));

      repository.pending!.complete();
      expect(await first, true);
      expect(state().status, AdminSignInStatus.idle);
    });

    test('a new attempt after a failure starts clean', () async {
      repository.error = const AdminSignInException(
        AdminSignInFailure.wrongCredentials,
      );
      await notifier().signIn(email: testEmail, password: 'wrong');
      expect(state().failure, AdminSignInFailure.wrongCredentials);

      repository.error = null;
      expect(
        await notifier().signIn(email: testEmail, password: testPassword),
        true,
      );
      expect(state().status, AdminSignInStatus.idle);
      expect(state().failure, isNull);
      expect(repository.signIns, hasLength(2));
    });

    test('the state never contains the e-mail or the password', () async {
      final seen = <String>[];
      final watcher = container.listen(
        adminSignInProvider,
        (_, next) => seen.add('$next'),
        fireImmediately: true,
      );
      addTearDown(watcher.close);

      repository.error = const AdminSignInException(
        AdminSignInFailure.wrongCredentials,
      );
      await notifier().signIn(email: testEmail, password: testPassword);
      repository.error = null;
      await notifier().signIn(email: testEmail, password: testPassword);

      expect(seen.length, greaterThanOrEqualTo(4));
      for (final text in seen) {
        expect(text.contains(testEmail), false, reason: text);
        expect(text.contains('admin@'), false, reason: text);
        expect(text.contains(testPassword.trim()), false, reason: text);
        expect(text.contains('horse'), false, reason: text);
      }
      expect(seen.first, 'AdminSignInState(idle)');
      expect(seen, contains('AdminSignInState(working)'));
      expect(seen, contains('AdminSignInState(failed, wrongCredentials)'));
    });

    test('sign out calls the repository', () async {
      await notifier().signOut();
      expect(repository.signOuts, 1);
    });

    test(
      'a sign-in that finishes after the page is gone does not fail',
      () async {
        repository.pending = Completer<void>();
        final running = notifier().signIn(
          email: testEmail,
          password: testPassword,
        );

        subscription.close();
        await Future<void>.delayed(Duration.zero);

        repository.pending!.complete();
        expect(await running, true);
      },
    );
  });
}
