import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/glass_widgets.dart';
import '../../auth/presentation/auth_scaffold.dart';
import '../data/vault_key_repository.dart';

/// Unlocks the vault for this app session: vault password (derived +
/// checked on the device), or fingerprint/Face ID when enabled. After a
/// successful password unlock it offers to turn biometric unlock on.
class VaultUnlockScreen extends ConsumerStatefulWidget {
  const VaultUnlockScreen({super.key});

  @override
  ConsumerState<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends ConsumerState<VaultUnlockScreen> {
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _biometricEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final enabled = await ref.read(biometricServiceProvider).isEnabled();
      if (!mounted) return;
      setState(() => _biometricEnabled = enabled);
      if (enabled) _unlockWithBiometrics();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _openVault() => context.pushReplacement('/vault');

  Future<void> _unlockWithBiometrics() async {
    setState(() => _error = null);
    try {
      final ok = await ref.read(vaultKeyControllerProvider.notifier).unlockWithBiometrics();
      if (!mounted) return;
      if (ok) {
        _openVault();
      } else {
        final stillEnabled = await ref.read(biometricServiceProvider).isEnabled();
        if (mounted) setState(() => _biometricEnabled = stillEnabled);
      }
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.toApiException(e).message);
    }
  }

  Future<void> _unlockWithPassword() async {
    if (_passwordController.text.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(vaultKeyControllerProvider.notifier).unlockWithPassword(_passwordController.text);
      _passwordController.clear();
      if (!mounted) return;
      await _offerBiometrics();
      if (mounted) _openVault();
    } on IncorrectVaultPasswordException {
      setState(() => _error = 'Incorrect vault password');
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _offerBiometrics() async {
    final biometrics = ref.read(biometricServiceProvider);
    if (_biometricEnabled || !await biometrics.isAvailable() || !mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use fingerprint or Face ID?'),
        content: const Text(
          'Unlock PassVault and show saved passwords with your fingerprint or face instead of typing '
          'your vault password or a 2FA code. You can turn this off on the home screen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Turn on')),
        ],
      ),
    );
    if (accept != true) return;
    // Confirm the biometric works before relying on it.
    if (await biometrics.authenticate('Confirm to turn on biometric unlock')) {
      await ref.read(vaultKeyControllerProvider.notifier).enableBiometrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Unlock your vault',
      icon: Icons.lock_open,
      children: [
        const Text('Enter your vault password. It never leaves this device -- PassVault can\'t see or reset it.'),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Vault password'),
          obscureText: true,
          autofocus: !_biometricEnabled,
          onSubmitted: (_) => _unlockWithPassword(),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
        ],
        HoloButton(
          onPressed: _submitting ? null : _unlockWithPassword,
          child: _submitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Unlock'),
        ),
        if (_biometricEnabled) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _unlockWithBiometrics,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Use fingerprint / Face ID'),
          ),
        ],
      ],
    );
  }
}
