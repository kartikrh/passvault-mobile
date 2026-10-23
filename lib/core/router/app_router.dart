import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/activity_screen.dart';
import '../../features/account/presentation/onboarding_screen.dart';
import '../../features/account/presentation/pages_screen.dart';
import '../../features/account/presentation/password_screen.dart';
import '../../features/account/presentation/profile_screen.dart';
import '../../features/account/presentation/security_screen.dart';
import '../../features/account/presentation/upgrade_plan_screen.dart';
import '../../features/auth/application/app_lock_controller.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/auth_outcome.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/lock_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/two_factor_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/vault_data/presentation/drive_connect_screen.dart';
import '../../features/vault_data/presentation/vault_screen.dart';
import '../../features/vault_key/presentation/vault_key_setup_screen.dart';
import '../../features/vault_key/presentation/vault_unlock_screen.dart';
import '../providers.dart';

/// Refreshes the router's redirect decision whenever SessionController's
/// state changes (e.g. logout from any screen) -- GoRouter otherwise only
/// re-evaluates `redirect` on navigation, not on external state changes.
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
    ref.listen(appLockProvider, (_, _) => notifyListeners());
  }
}

const _publicRoutes = {'/', '/login', '/two-factor', '/forgot-password', '/pages'};

/// Reachable while onboarding is unfinished (the 2FA enrollment step uses
/// /two-factor; Help & legal stays readable).
const _onboardingRoutes = {'/onboarding', '/two-factor', '/pages'};

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _SessionRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      // Reachable while signed out. Everything else (home, vault, key setup,
      // Drive connect) requires a session -- the old check treated every
      // route except /home as public.
      final isAuthRoute = _publicRoutes.contains(state.matchedLocation);
      final isSplash = state.matchedLocation == '/';

      if (session is SessionUnknown) {
        return isSplash ? null : '/';
      }
      if (session is SessionUnauthenticated) {
        return isAuthRoute && !isSplash ? null : '/login';
      }
      // SessionAuthenticated -- but a biometric-enabled session stays behind
      // the lock screen until the fingerprint/face check passes.
      final lock = ref.read(appLockProvider);
      if (lock == AppLockState.unknown) {
        return isSplash ? null : '/';
      }
      if (lock == AppLockState.locked) {
        return state.matchedLocation == '/lock' ? null : '/lock';
      }
      // Unfinished account setup (username/password, authenticator) blocks
      // everything else -- same gate as passvault-client's onboarding wizard.
      final location = state.matchedLocation;
      final onboarding = needsOnboarding((session as SessionAuthenticated).client);
      if (onboarding) {
        return _onboardingRoutes.contains(location) ? null : '/onboarding';
      }
      if (isSplash || location == '/login' || location == '/lock' || location == '/onboarding') {
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
      GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
      GoRoute(path: '/vault-key-setup', builder: (context, state) => const VaultKeySetupScreen()),
      GoRoute(path: '/vault-unlock', builder: (context, state) => const VaultUnlockScreen()),
      GoRoute(path: '/drive-connect', builder: (context, state) => const DriveConnectScreen()),
      GoRoute(path: '/vault', builder: (context, state) => const VaultScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/pages', builder: (context, state) => const PagesScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/security', builder: (context, state) => const SecurityScreen()),
      GoRoute(path: '/password', builder: (context, state) => const PasswordScreen()),
      GoRoute(path: '/activity', builder: (context, state) => const ActivityScreen()),
      GoRoute(path: '/upgrade', builder: (context, state) => const UpgradePlanScreen()),
    ],
  );
});
