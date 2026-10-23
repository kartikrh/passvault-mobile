import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/glass_widgets.dart';
import 'core/providers.dart';
import 'features/auth/application/session_controller.dart';

/// Locked (biometrics on) or signed out (biometrics off) once the app has
/// been in the background this long.
const _autoLockAfter = Duration(minutes: 5);

/// Same cadence as passvault-client's useVpnGuard: sign-in already blocks a
/// VPN; this catches one switched on mid-session.
const _vpnCheckInterval = Duration(minutes: 4);

void main() {
  // A release build must never talk to the API over plain HTTP (the default
  // base URL is the emulator's http://10.0.2.2) -- pass
  // --dart-define=API_BASE_URL=https://... for release builds.
  if (kReleaseMode && !apiBaseUrl.startsWith('https://')) {
    throw StateError('Release builds require an https:// API_BASE_URL (got $apiBaseUrl)');
  }
  runApp(const ProviderScope(child: PassVaultApp()));
}

class PassVaultApp extends ConsumerStatefulWidget {
  const PassVaultApp({super.key});

  @override
  ConsumerState<PassVaultApp> createState() => _PassVaultAppState();
}

class _PassVaultAppState extends ConsumerState<PassVaultApp> {
  late final AppLifecycleListener _lifecycle;
  late final Timer _vpnTimer;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    _vpnTimer = Timer.periodic(_vpnCheckInterval, (_) => _checkVpn());
    _lifecycle = AppLifecycleListener(
      onHide: () => _backgroundedAt = DateTime.now(),
      onShow: () {
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null &&
            DateTime.now().difference(since) >= _autoLockAfter &&
            ref.read(sessionControllerProvider) is SessionAuthenticated) {
          _lockOrSignOut();
        }
      },
    );
  }

  Future<void> _checkVpn() async {
    if (ref.read(sessionControllerProvider) is! SessionAuthenticated) return;
    try {
      if (await ref.read(accountRepositoryProvider).vpnDetected()) {
        await ref
            .read(sessionControllerProvider.notifier)
            .logout(reason: 'You were signed out because a VPN or proxy was detected. Turn it off and sign in again.');
      }
    } catch (_) {
      // Network hiccup -- the next tick tries again.
    }
  }

  Future<void> _lockOrSignOut() async {
    // Drop the in-memory vault key either way; with biometrics on, the lock
    // screen brings it back with one fingerprint/face check.
    ref.read(vaultKeyControllerProvider.notifier).clear();
    final locked = await ref.read(appLockProvider.notifier).lock();
    if (!locked) await ref.read(sessionControllerProvider.notifier).logout();
  }

  @override
  void dispose() {
    _vpnTimer.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final palette = ref.watch(paletteProvider);
    return MaterialApp.router(
      title: 'PassVault',
      // The palette decides light vs dark (Amethyst is dark glass), so one
      // theme is used regardless of the OS setting.
      theme: buildAppTheme(palette),
      routerConfig: router,
      builder: (context, child) => PrismBackground(child: child ?? const SizedBox.shrink()),
    );
  }
}
