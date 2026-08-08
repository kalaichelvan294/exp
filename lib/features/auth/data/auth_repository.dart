// ignore_for_file: prefer_initializing_formals
//
// Named parameters cannot be private (`this._field`), so initializing formals
// cannot be used for the private hasher/clock fields.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_role.dart';
import '../domain/auth_status.dart';
import 'auth_settings_store.dart';
import 'pin_hasher.dart';

/// Admin privilege separation backed **directly by Postgres** (parity with the
/// Electron `auth.js`, which held session state in the main process and stored
/// the PIN hash/salt/timeout in the `settings` table).
///
/// The PIN hash, salt, and session timeout are persisted; the live session
/// (role, expiry, failed attempts, lockout) is held in memory for the app run.
/// The renderer is not the trust boundary — verification happens here against
/// the stored scrypt hash.
class AuthRepository {
  AuthRepository(
    this._store, {
    PinHasher hasher = const PinHasher(),
    DateTime Function()? clock,
  })  : _hasher = hasher,
        _now = clock ?? DateTime.now;

  final AuthSettingsStore _store;
  final PinHasher _hasher;
  final DateTime Function() _now;

  // settings keys (parity with auth.js)
  static const _hashKey = 'adminPinHash';
  static const _saltKey = 'adminPinSalt';
  static const _timeoutKey = 'adminSessionTimeoutMs';

  static const _defaultTimeout = Duration(minutes: 5);
  static const _minTimeout = Duration(seconds: 30);
  static const _maxAttempts = 5;
  static const _lockout = Duration(minutes: 30);
  static final _pinFormat = RegExp(r'^[0-9]{4,12}$');

  // In-memory session state.
  AuthRole _role = AuthRole.sales;
  DateTime? _expiresAt;
  Duration? _timeoutCache;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  bool get _elevated =>
      _role == AuthRole.admin &&
      _expiresAt != null &&
      _expiresAt!.isAfter(_now());

  void _dropIfExpired() {
    if (_role == AuthRole.admin &&
        (_expiresAt == null || !_expiresAt!.isAfter(_now()))) {
      _role = AuthRole.sales;
      _expiresAt = null;
    }
  }

  Future<Duration> _timeout() async {
    final cached = _timeoutCache;
    if (cached != null) return cached;
    final ms = await _store.getNumber(_timeoutKey);
    final resolved = (ms != null && ms >= _minTimeout.inMilliseconds)
        ? Duration(milliseconds: ms)
        : _defaultTimeout;
    _timeoutCache = resolved;
    return resolved;
  }

  Future<bool> _pinConfigured() async {
    final hash = await _store.getText(_hashKey);
    final salt = await _store.getText(_saltKey);
    return hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty;
  }

  Future<AuthStatus> status() async {
    _dropIfExpired();
    final timeout = await _timeout();
    final elevated = _elevated;
    return AuthStatus(
      role: elevated ? AuthRole.admin : AuthRole.sales,
      pinConfigured: await _pinConfigured(),
      expiresAt: elevated ? _expiresAt : null,
      timeout: timeout,
    );
  }

  Future<AuthStatus> elevate(String pin) async {
    final now = _now();
    final lockedUntil = _lockoutUntil;
    if (lockedUntil != null && lockedUntil.isAfter(now)) {
      final minutes =
          (lockedUntil.difference(now).inMilliseconds / 60000).ceil();
      final safe = minutes < 1 ? 1 : minutes;
      throw AuthException(
        'Too many incorrect PIN attempts. Admin access is locked for '
        'about $safe more minute${safe == 1 ? '' : 's'}.',
      );
    }

    if (!await _pinConfigured()) {
      throw AuthException(
        'Admin PIN is not set. Set a PIN to enable admin access.',
      );
    }

    final salt = await _store.getText(_saltKey);
    final hash = await _store.getText(_hashKey);
    final ok =
        salt != null && hash != null && _hasher.verify(pin, salt, hash);
    if (!ok) {
      _failedAttempts += 1;
      if (_failedAttempts >= _maxAttempts) {
        _lockoutUntil = now.add(_lockout);
        _failedAttempts = 0;
      }
      throw AuthException('Incorrect PIN.');
    }

    _failedAttempts = 0;
    _lockoutUntil = null;
    _role = AuthRole.admin;
    _expiresAt = now.add(await _timeout());
    return status();
  }

  Future<void> logout() async {
    _role = AuthRole.sales;
    _expiresAt = null;
  }

  /// First-run sets the PIN with no [currentPin]; changing an existing PIN
  /// requires the current one (parity with `auth.js#configurePin`).
  Future<void> configurePin({String? currentPin, required String newPin}) async {
    if (await _pinConfigured()) {
      final salt = await _store.getText(_saltKey);
      final hash = await _store.getText(_hashKey);
      final ok = currentPin != null &&
          salt != null &&
          hash != null &&
          _hasher.verify(currentPin, salt, hash);
      if (!ok) {
        throw AuthException('Current PIN is incorrect.');
      }
    }
    await _setPin(newPin);
  }

  Future<void> _setPin(String newPin) async {
    if (!_pinFormat.hasMatch(newPin)) {
      throw AuthException('PIN must be 4 to 12 digits.');
    }
    final saltHex = _hasher.newSaltHex();
    final hashHex = _hasher.hash(newPin, saltHex);
    await _store.setText(_saltKey, saltHex);
    await _store.setText(_hashKey, hashHex);
  }

  Future<void> setTimeout(Duration timeout) async {
    if (timeout < _minTimeout) {
      throw AuthException('Session timeout must be at least 30 seconds.');
    }
    _timeoutCache = timeout;
    await _store.setNumber(_timeoutKey, timeout.inMilliseconds);
    if (_elevated) {
      _expiresAt = _now().add(timeout);
    }
  }
}

/// Custom exception for authentication errors.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(authSettingsStoreProvider)),
);
