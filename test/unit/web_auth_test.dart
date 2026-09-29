import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/web_auth.dart';

void main() {
  final pinHash = hashPin('1234', random: Random(1));

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

    LoginResult login(String pin, {String ip = '10.0.0.5'}) =>
        auth.login(ip: ip, pin: pin, viewerPinHash: pinHash);

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
  });
}
