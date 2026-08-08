import 'package:flutter/foundation.dart';

import 'auth_role.dart';

/// Snapshot of the admin session, mirroring the `auth:status` contract from the
/// Electron main process (`auth.js#getStatus`).
///
/// The API bridge is the trust boundary; this model is a read-only view the
/// Flutter UI uses to gate admin navigation and drive the session countdown.
@immutable
class AuthStatus {
  const AuthStatus({
    this.role = AuthRole.sales,
    this.pinConfigured = false,
    this.expiresAt,
    this.timeout = defaultTimeout,
  });

  /// Default inactivity timeout (parity with `DEFAULT_TIMEOUT_MS`).
  static const Duration defaultTimeout = Duration(minutes: 5);

  /// Minimum inactivity timeout the bridge accepts (parity with `MIN_TIMEOUT_MS`).
  static const Duration minTimeout = Duration(seconds: 30);

  final AuthRole role;

  /// Whether an admin PIN has been set. When false, the PIN modal runs in
  /// first-run setup mode.
  final bool pinConfigured;

  /// Absolute expiry of the current admin session, or null when not elevated.
  final DateTime? expiresAt;

  /// Configured inactivity timeout for admin sessions.
  final Duration timeout;

  bool get isAdmin => role == AuthRole.admin;

  /// True while an admin session is active and not yet expired by the local
  /// clock. The bridge remains authoritative; this only drives UX.
  bool get isElevated =>
      isAdmin && expiresAt != null && expiresAt!.isAfter(DateTime.now());

  factory AuthStatus.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expiresAt'];
    final expiresMs = expiresRaw is num ? expiresRaw.toInt() : 0;
    final timeoutRaw = json['timeoutMs'];
    final timeoutMs = timeoutRaw is num ? timeoutRaw.toInt() : 0;
    return AuthStatus(
      role: AuthRole.fromWire(json['role']),
      pinConfigured: json['pinConfigured'] == true,
      expiresAt: expiresMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(expiresMs)
          : null,
      timeout: timeoutMs >= minTimeout.inMilliseconds
          ? Duration(milliseconds: timeoutMs)
          : defaultTimeout,
    );
  }

  AuthStatus copyWith({
    AuthRole? role,
    bool? pinConfigured,
    DateTime? expiresAt,
    Duration? timeout,
  }) {
    return AuthStatus(
      role: role ?? this.role,
      pinConfigured: pinConfigured ?? this.pinConfigured,
      expiresAt: expiresAt ?? this.expiresAt,
      timeout: timeout ?? this.timeout,
    );
  }
}
