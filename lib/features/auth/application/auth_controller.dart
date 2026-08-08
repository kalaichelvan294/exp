import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_status.dart';

/// Holds the current admin session status and drives elevation.
///
/// Ports the renderer helpers (`admin-auth.js` + the role logic in
/// `topbar.js`): it reads the authoritative status from the bridge and exposes
/// elevate / logout / configure-PIN / set-timeout. Privileged actions the UI
/// wants to trigger surface exceptions to callers so dialogs can show the
/// bridge's message (incorrect PIN, lockout, etc.).
class AuthController extends Notifier<AuthStatus> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthStatus build() {
    Future.microtask(refresh);
    return const AuthStatus();
  }

  /// Re-reads the authoritative session status. Failures fall back to the
  /// default (sales) role so the UI never gets stuck showing admin surfaces.
  Future<void> refresh() async {
    try {
      state = await _repo.status();
    } catch (_) {
      state = const AuthStatus();
    }
  }

  Future<void> elevate(String pin) async {
    await _repo.elevate(pin);
    await refresh();
  }

  Future<void> configurePin({String? currentPin, required String newPin}) async {
    await _repo.configurePin(currentPin: currentPin, newPin: newPin);
    await refresh();
  }

  Future<void> logout() async {
    await _repo.logout();
    await refresh();
  }

  Future<void> setSessionTimeout(Duration timeout) async {
    await _repo.setTimeout(timeout);
    await refresh();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);
