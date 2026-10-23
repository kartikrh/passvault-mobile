import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';
import '../domain/client.dart';

sealed class SessionState {
  const SessionState();
}

/// Still checking for a stored token on app start -- the router keeps the
/// splash screen up while in this state.
class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

class SessionAuthenticated extends SessionState {
  final Client client;
  const SessionAuthenticated(this.client);
}

/// App-wide sign-in state. The JWT itself lives in [TokenStorage]
/// (written automatically by ApiClient's response interceptor whenever a
/// call returns `result.token`) -- this only tracks whether one is present
/// and, if so, the profile it belongs to.
class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref) : super(const SessionUnknown()) {
    bootstrap();
  }

  final Ref _ref;

  Future<void> bootstrap() async {
    final token = await _ref.read(tokenStorageProvider).read();
    if (token == null) {
      state = const SessionUnauthenticated();
      return;
    }
    try {
      final client = await _ref.read(authRepositoryProvider).fetchProfile();
      state = SessionAuthenticated(client);
    } catch (_) {
      // Stored token is expired/invalid -- same as never having signed in.
      await _ref.read(tokenStorageProvider).clear();
      state = const SessionUnauthenticated();
    }
  }

  /// A fresh password/Google sign-in -- that already proved who this is, so
  /// it also lifts the biometric app lock.
  void setAuthenticated(Client client) {
    _ref.read(appLockProvider.notifier).unlock();
    state = SessionAuthenticated(client);
  }

  /// Re-reads the profile after something changed it (username/password
  /// set, 2FA enrolled or reset) so every gate sees the new state.
  Future<void> refreshProfile() async {
    final client = await _ref.read(authRepositoryProvider).fetchProfile();
    if (state is SessionAuthenticated) state = SessionAuthenticated(client);
  }

  /// [reason] is shown on the login screen when the sign-out wasn't the
  /// user's own choice (VPN detected, account suspended/deleted).
  Future<void> logout({String? reason}) async {
    _ref.read(logoutReasonProvider.notifier).state = reason;
    try {
      await _ref.read(authRepositoryProvider).logout();
    } on ApiException {
      // Sessions are stateless JWTs (see logoutService) -- nothing server-side
      // to actually revoke, so a failed call here still clears the local token.
    } finally {
      await _ref.read(tokenStorageProvider).clear();
      // Vault key is per-session, in-memory only (see VaultKeyController) --
      // must be dropped on logout so the next sign-in (possibly a different
      // account on the same device) does a fresh recover rather than reusing
      // whatever was cached here.
      _ref.read(vaultKeyControllerProvider.notifier).clear();
      // Signing out ends biometric unlock too -- the next person to sign in
      // on this device must not inherit the stored vault key.
      await _ref.read(biometricServiceProvider).disable();
      _ref.read(appLockProvider.notifier).unlock();
      state = const SessionUnauthenticated();
    }
  }
}

final sessionControllerProvider = StateNotifierProvider<SessionController, SessionState>(
  (ref) => SessionController(ref),
);
