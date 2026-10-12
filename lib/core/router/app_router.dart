import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/auth_outcome.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/two_factor_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/vault_data/presentation/drive_connect_screen.dart';
import '../../features/vault_data/presentation/vault_screen.dart';
import '../../features/vault_key/presentation/vault_key_setup_screen.dart';

/// Refreshes the router's redirect decision whenever SessionController's
/// state changes (e.g. logout from any screen) -- GoRouter otherwise only
/// re-evaluates `redirect` on navigation, not on external state changes.
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _SessionRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final isAuthRoute = state.matchedLocation != '/home';
      final isSplash = state.matchedLocation == '/';

      if (session is SessionUnknown) {
        return isSplash ? null : '/';
      }
      if (session is SessionUnauthenticated) {
        return isAuthRoute && !isSplash ? null : '/login';
      }
      // SessionAuthenticated.
      if (isSplash || state.matchedLocation == '/login') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/two-factor',
        builder: (context, state) => TwoFactorScreen(challenge: state.extra as TwoFactorRequired),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/vault-key-setup', builder: (context, state) => const VaultKeySetupScreen()),
      GoRoute(path: '/drive-connect', builder: (context, state) => const DriveConnectScreen()),
      GoRoute(path: '/vault', builder: (context, state) => const VaultScreen()),
    ],
  );
});
