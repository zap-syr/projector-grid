import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

enum WebRole { viewer, operator }

/// Salted PBKDF2-HMAC-SHA256 of [pin], stored as
/// `pbkdf2-sha256$<iterations>$<salt>$<hash>` (base64). A 4–8 digit PIN is
/// brute-forceable offline whatever the hash; this only keeps the PIN itself
/// out of the settings file.
String hashPin(String pin, {Random? random}) {
  final rnd = random ?? Random.secure();
  final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
  const iterations = 10000;
  final hash = _pbkdf2(utf8.encode(pin), salt, iterations);
  return 'pbkdf2-sha256\$$iterations\$${base64.encode(salt)}\$${base64.encode(hash)}';
}

bool verifyPin(String pin, String stored) {
  final parts = stored.split(r'$');
  final iterations = int.parse(parts[1]);
  final salt = base64.decode(parts[2]);
  final expected = base64.decode(parts[3]);
  final actual = _pbkdf2(utf8.encode(pin), salt, iterations);
  var diff = 0;
  for (var i = 0; i < expected.length; i++) {
    diff |= expected[i] ^ actual[i];
  }
  return diff == 0;
}

/// One 32-byte block, which is all SHA-256 output needs.
List<int> _pbkdf2(List<int> password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, password);
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final out = List<int>.of(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < out.length; j++) {
      out[j] ^= u[j];
    }
  }
  return out;
}

class WebSession {
  final String token;

  /// Viewer, or operator after an operator-PIN login or *Unlock control*.
  WebRole role;
  final String ip;
  DateTime lastSeen;

  WebSession(this.token, this.role, this.ip, this.lastSeen);
}

sealed class LoginResult {}

class LoginOk extends LoginResult {
  final WebSession session;
  LoginOk(this.session);
}

class LoginInvalidPin extends LoginResult {}

class LoginLockedOut extends LoginResult {
  final Duration retryAfter;
  LoginLockedOut(this.retryAfter);
}

class _Attempts {
  int failures = 0;
  int lockouts = 0;
  DateTime? lockedUntil;
}

/// Web Access sessions and PIN brute-force protection. In memory only: an
/// app restart signs every client out, which a phone recovers from with one
/// PIN entry.
class WebAuth {
  WebAuth({DateTime Function()? clock, this.onLockout})
    : _now = clock ?? DateTime.now;

  static const idleTimeout = Duration(hours: 12);
  static const maxFailures = 5;
  static const baseLockout = Duration(seconds: 60);

  /// Doubling stops here so a forgotten phone retrying all night doesn't
  /// lock its IP out for days.
  static const maxLockout = Duration(hours: 1);

  final DateTime Function() _now;
  final void Function(String ip, Duration lockout)? onLockout;
  final _sessions = <String, WebSession>{};
  final _attempts = <String, _Attempts>{};
  final _random = Random.secure();

  /// The role follows from which PIN matches; [operatorPinHash] is null
  /// while *Allow control* is off, so only the Viewer PIN works then.
  LoginResult login({
    required String ip,
    required String pin,
    required String viewerPinHash,
    required String? operatorPinHash,
  }) => _attempt(ip, () {
    final WebRole role;
    if (operatorPinHash != null && verifyPin(pin, operatorPinHash)) {
      role = WebRole.operator;
    } else if (verifyPin(pin, viewerPinHash)) {
      role = WebRole.viewer;
    } else {
      return null;
    }
    final token = base64Url
        .encode(List<int>.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    return _sessions[token] = WebSession(token, role, ip, _now());
  });

  /// *Unlock control*: upgrades [session] to operator with the Operator PIN.
  /// Wrong PINs count towards the same per-IP lockout as logins.
  LoginResult unlock(WebSession session, String pin, String operatorPinHash) =>
      _attempt(session.ip, () {
        if (!verifyPin(pin, operatorPinHash)) return null;
        session.role = WebRole.operator;
        return session;
      });

  /// *Lock*: back to viewer, same session.
  void lock(WebSession session) => session.role = WebRole.viewer;

  /// *Allow control* turned off: every operator drops to viewer. Returns the
  /// sessions that changed.
  List<WebSession> demoteOperators() => [
    for (final s in _sessions.values)
      if (s.role == WebRole.operator) s..role = WebRole.viewer,
  ];

  /// Runs [check] unless [ip] is locked out; a null result is a wrong PIN.
  LoginResult _attempt(String ip, WebSession? Function() check) {
    final now = _now();
    final attempts = _attempts.putIfAbsent(ip, _Attempts.new);
    final lockedUntil = attempts.lockedUntil;
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      return LoginLockedOut(lockedUntil.difference(now));
    }

    final session = check();
    if (session != null) {
      _attempts.remove(ip);
      return LoginOk(session);
    }

    attempts.failures++;
    if (attempts.failures < maxFailures) return LoginInvalidPin();
    attempts
      ..failures = 0
      ..lockouts += 1;
    final factor = 1 << min(attempts.lockouts - 1, 6);
    final lockout = baseLockout * factor > maxLockout
        ? maxLockout
        : baseLockout * factor;
    attempts.lockedUntil = now.add(lockout);
    onLockout?.call(ip, lockout);
    return LoginLockedOut(lockout);
  }

  /// The live session for [token], marked as seen now; null when unknown or
  /// idle past [idleTimeout].
  WebSession? touch(String? token) {
    if (token == null) return null;
    final session = _sessions[token];
    if (session == null) return null;
    final now = _now();
    if (now.difference(session.lastSeen) > idleTimeout) {
      _sessions.remove(token);
      return null;
    }
    session.lastSeen = now;
    return session;
  }

  void logout(String token) => _sessions.remove(token);

  void revokeAll() => _sessions.clear();

  /// Sessions not yet idle past [idleTimeout].
  List<WebSession> get sessions {
    final now = _now();
    _sessions.removeWhere((_, s) => now.difference(s.lastSeen) > idleTimeout);
    return List.unmodifiable(_sessions.values);
  }
}
