import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/glass_widgets.dart';
import '../application/session_controller.dart';

/// Shown instead of a sign-in when a biometric-enabled session reopens
/// (cold start, or back from the background -- see AppLockController). One
/// fingerprint/face check unlocks both the app and the vault key.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_unlock);
  }

  Future<void> _unlock() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final ok = await ref.read(vaultKeyControllerProvider.notifier).unlockWithBiometrics();
      if (!mounted) return;
      if (ok) {
        // The router redirect takes it from here.
        ref.read(appLockProvider.notifier).unlock();
        return;
      }
      if (!await ref.read(biometricServiceProvider).isEnabled()) {
        // Stored key was stale (vault password changed elsewhere): fall back
        // to the normal unlocked app, where the vault asks for its password.
        ref.read(appLockProvider.notifier).unlock();
        return;
      }
      setState(() => _error = 'Not recognised. Try again, or sign out and sign in with your password.');
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final client = session is SessionAuthenticated ? session.client : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CrystalIcon(icon: Icons.fingerprint, size: 96),
                const SizedBox(height: 16),
                HoloText('PassVault is locked', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (client != null) ...[
                  const SizedBox(height: 4),
                  Text(client.name ?? client.email),
                ],
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: 240,
                  child: HoloButton(onPressed: _checking ? null : _unlock, icon: Icons.fingerprint, child: const Text('Unlock')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _checking ? null : () => ref.read(sessionControllerProvider.notifier).logout(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
