import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/web_auth.dart';

void main() {
  final pinHash = hashPin('1234', random: Random(1));
  final operatorHash = hashPin('9876', random: Random(2));

  group('PIN hashing', () {
    test('verifies the right PIN only', () {
      expect(verifyPin('1234', pinHash), isTrue);
      expect(verifyPin('1235', pinHash), isFalse);
      expect(verifyPin('', pinHash), isFalse);
    });

    test('salts every hash', () {
      expect(hashPin('1234'), isNot(hashPin('1234')));
      expect(hashPin('1234'), isNot(contains('1234')));
    });
  });

  group('WebAuth', () {
    late DateTime now;
    late List<(String, Duration)> lockouts;
    late WebAuth auth;

    setUp(() {
      now = DateTime(2026, 9, 29, 12);
      lockouts = [];
      auth = WebAuth(
        clock: () => now,
        onLockout: (ip, d) => lockouts.add((ip, d)),
      );
    });

    LoginResult login(
      String pin, {
      String ip = '10.0.0.5',
      bool controlAllowed = true,
    }) => auth.login(
      ip: ip,
      pin: pin,
      viewerPinHash: pinHash,
      operatorPinHash: controlAllowed ? operatorHash : null,
    );

    test('the right PIN opens a viewer session', () {
      final result = login('1234');
      expect(result, isA<LoginOk>());
      final session = (result as LoginOk).session;
      expect(session.role, WebRole.viewer);
      expect(session.ip, '10.0.0.5');
      expect(session.token.length, greaterThanOrEqualTo(40));
      expect(auth.touch(session.token), same(session));
    });

    test('unknown or missing tokens have no session', () {
      expect(auth.touch(null), isNull);
      expect(auth.touch('nope'), isNull);
    });

    test('5 wrong PINs lock the IP out, then the lockout doubles', () {
      for (var i = 0; i < 4; i++) {
        expect(login('0000'), isA<LoginInvalidPin>());
      }
      final first = login('0000');
      expect((first as LoginLockedOut).retryAfter, const Duration(seconds: 60));
      expect(lockouts, [('10.0.0.5', const Duration(seconds: 60))]);

      // Even the right PIN is refused while locked, and other IPs aren't.
      now = now.add(const Duration(seconds: 30));
      expect(
        (login('1234') as LoginLockedOut).retryAfter,
        const Duration(seconds: 30),
      );
      expect(login('1234', ip: '10.0.0.6'), isA<LoginOk>());

      now = now.add(const Duration(seconds: 31));
      for (var i = 0; i < 4; i++) {
        expect(login('0000'), isA<LoginInvalidPin>());
      }
      expect(
        (login('0000') as LoginLockedOut).retryAfter,
        const Duration(seconds: 120),
      );
    });

    test('lockouts stop doubling at an hour', () {
      for (var round = 0; round < 10; round++) {
        for (var i = 0; i < WebAuth.maxFailures; i++) {
          login('0000');
        }
        now = now.add(const Duration(hours: 2));
      }
      expect(lockouts.last.$2, WebAuth.maxLockout);
    });

    test('a successful login clears the failure count', () {
      for (var i = 0; i < 4; i++) {
        login('0000');
      }
      expect(login('1234'), isA<LoginOk>());
      for (var i = 0; i < 4; i++) {
        expect(login('0000'), isA<LoginInvalidPin>());
      }
    });

    test('sessions expire after 12 h idle; use keeps them alive', () {
      final token = (login('1234') as LoginOk).session.token;
      now = now.add(const Duration(hours: 11));
      expect(auth.touch(token), isNotNull);
      now = now.add(const Duration(hours: 11));
      expect(auth.touch(token), isNotNull);
      now = now.add(const Duration(hours: 12, seconds: 1));
      expect(auth.touch(token), isNull);
      expect(auth.sessions, isEmpty);
    });

    test('logout and revokeAll end sessions', () {
      final a = (login('1234') as LoginOk).session.token;
      final b = (login('1234') as LoginOk).session.token;
      auth.logout(a);
      expect(auth.touch(a), isNull);
      expect(auth.touch(b), isNotNull);
      auth.revokeAll();
      expect(auth.touch(b), isNull);
    });

    test('onChange fires when sessions start, end or change role', () {
      var changes = 0;
      auth = WebAuth(clock: () => now, onChange: () => changes++);
      final session = (login('1234') as LoginOk).session;
      expect(changes, 1);
      login('0000');
      auth.touch(session.token);
      expect(changes, 1, reason: 'wrong PINs and plain use change nothing');
      auth.unlock(session, '9876', operatorHash);
      auth.lock(session);
      expect(changes, 3);
      auth.logout(session.token);
      auth.logout(session.token);
      expect(changes, 4, reason: 'an unknown token changes nothing');
      login('1234');
      auth.revokeAll();
      auth.revokeAll();
      expect(changes, 6);
    });

    group('operator', () {
      test('the Operator PIN logs in as operator, only while allowed', () {
        final ok = login('9876') as LoginOk;
        expect(ok.session.role, WebRole.operator);
        expect(login('9876', controlAllowed: false), isA<LoginInvalidPin>());
        expect(
          (login('1234') as LoginOk).session.role,
          WebRole.viewer,
          reason: 'the Viewer PIN still gives a viewer',
        );
      });

      test('unlock upgrades the same session; lock drops it back', () {
        final session = (login('1234') as LoginOk).session;
        expect(
          auth.unlock(session, '1234', operatorHash),
          isA<LoginInvalidPin>(),
        );
        expect(session.role, WebRole.viewer);

        expect(auth.unlock(session, '9876', operatorHash), isA<LoginOk>());
        expect(session.role, WebRole.operator);
        expect(auth.touch(session.token)?.role, WebRole.operator);

        auth.lock(session);
        expect(session.role, WebRole.viewer);
      });

      test('wrong unlock PINs count towards the IP lockout', () {
        final session = (login('1234') as LoginOk).session;
        for (var i = 0; i < 3; i++) {
          auth.unlock(session, '0000', operatorHash);
        }
        login('0000');
        expect(
          auth.unlock(session, '0000', operatorHash),
          isA<LoginLockedOut>(),
        );
        expect(
          auth.unlock(session, '9876', operatorHash),
          isA<LoginLockedOut>(),
        );
        expect(session.role, WebRole.viewer);
      });

      test('demoteOperators drops every operator to viewer', () {
        final op = (login('9876') as LoginOk).session;
        final viewer = (login('1234') as LoginOk).session;
        expect(auth.demoteOperators(), [op]);
        expect(op.role, WebRole.viewer);
        expect(viewer.role, WebRole.viewer);
        expect(auth.touch(op.token), isNotNull, reason: 'still signed in');
      });
    });
  });
}
