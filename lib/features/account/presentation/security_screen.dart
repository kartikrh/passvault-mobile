import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_outcome.dart';
import '../../auth/domain/client.dart';
import '../../vault_key/application/vault_key_controller.dart';
import '../../../core/theme/glass_widgets.dart';
import 'account_widgets.dart';

/// Two-factor authentication (set up / reset Google Authenticator),
/// fingerprint/Face ID unlock, and the danger zone (suspend / delete) --
/// passvault-client's TwoFactorSettings + AccountDangerZone.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _busy = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadBiometricState);
  }

  Future<void> _loadBiometricState() async {
    final biometrics = ref.read(biometricServiceProvider);
    final available = await biometrics.isAvailable();
    final enabled = await biometrics.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setUpAuthenticator() => _run(() async {
        final challenge = await ref.read(accountRepositoryProvider).beginTwoFactorSetup();
        if (mounted) context.push('/two-factor', extra: challenge);
      });

  Future<void> _resetAuthenticator() async {
    final ok = await showConfirm(
      context,
      title: 'Reset authenticator?',
      message: 'Your current authenticator codes stop working immediately and you\'ll scan a new QR code now. '
          'We\'ll email you that 2FA was reset.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!ok) return;
    await _run(() async {
      final repo = ref.read(accountRepositoryProvider);
      await repo.resetTwoFactor();
      await ref.read(sessionControllerProvider.notifier).refreshProfile();
      final challenge = await repo.beginTwoFactorSetup();
      if (mounted) context.push('/two-factor', extra: challenge);
    });
  }

  Future<void> _toggleBiometrics(bool enable) async {
    final controller = ref.read(vaultKeyControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    if (!enable) {
      await controller.disableBiometrics();
    } else if (ref.read(vaultKeyControllerProvider) is! VaultKeyReady) {
      // The stored copy is the in-memory vault key, so it must be unlocked first.
      messenger.showSnackBar(const SnackBar(content: Text('Unlock your vault with its password first.')));
      return;
    } else if (await ref.read(biometricServiceProvider).authenticate('Confirm to turn on biometric unlock')) {
      await controller.enableBiometrics();
    }
    await _loadBiometricState();
  }

  Future<String?> _codeIfNeeded(Client client, String message) async {
    if (!client.otpEnabled) return '';
    return showCodePrompt(context, title: 'Verify it\'s you', message: message);
  }

  Future<void> _suspend(Client client) async {
    final ok = await showConfirm(
      context,
      title: 'Suspend your account?',
      message: 'You\'ll be signed out everywhere and can\'t sign in until support reactivates the account. '
          'Your saved data stays in your Google Drive.',
      confirmLabel: 'Suspend',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final code = await _codeIfNeeded(client, 'Enter the 6-digit code to suspend your account.');
    if (code == null) return;
    await _run(() async {
      await ref.read(accountRepositoryProvider).suspendAccount(code: code.isEmpty ? null : code);
      await ref.read(sessionControllerProvider.notifier).logout(reason: 'Your account has been suspended.');
    });
  }

  Future<void> _delete(Client client) async {
    final reason = await _askDeleteReason();
    if (reason == null || !mounted) return;
    final code = await _codeIfNeeded(client, 'Enter the 6-digit code to permanently delete your account.');
    if (code == null) return;
    await _run(() async {
      await ref.read(accountRepositoryProvider).deleteAccount(code: code.isEmpty ? null : code, reason: reason);
      await ref.read(sessionControllerProvider.notifier).logout(reason: 'Your account has been deleted.');
    });
  }

  Future<String?> _askDeleteReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete your account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This permanently deletes your PassVault account. This can\'t be undone. '
                'Please tell us why you\'re leaving.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Reason'),
                maxLines: 3,
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: controller.text.trim().isEmpty ? null : () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final client = session is SessionAuthenticated ? session.client : null;
    if (client == null) return const Scaffold(body: SizedBox.shrink());
    final isAuthenticator = client.otpType == OtpType.googleAuthenticator;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: ErrorText(_error)),
            if (_busy) const LinearProgressIndicator(),
            SectionCard(
              title: 'Two-factor authentication',
              subtitle: !client.otpEnabled
                  ? 'Off for this account.'
                  : isAuthenticator
                      ? (client.hasOtpSecret ? 'Google Authenticator is set up.' : 'Google Authenticator is not set up yet.')
                      : 'Codes are sent to your email.',
              children: [
                if (client.otpEnabled && isAuthenticator)
                  client.hasOtpSecret
                      ? OutlinedButton.icon(
                          onPressed: _resetAuthenticator,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset authenticator'),
                        )
                      : FilledButton.icon(
                          onPressed: _setUpAuthenticator,
                          icon: const Icon(Icons.qr_code),
                          label: const Text('Set up authenticator'),
                        ),
              ],
            ),
            if (_biometricAvailable)
              SectionCard(
                title: 'Fingerprint / Face ID',
                subtitle: 'Unlock the app and your vault, and show saved passwords, without typing.',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Use biometrics'),
                    value: _biometricEnabled,
                    onChanged: _toggleBiometrics,
                  ),
                ],
              ),
            const SectionCard(
              title: 'Appearance',
              subtitle: 'Choose a colour palette. It\'s remembered on this device.',
              children: [PalettePicker()],
            ),
            SectionCard(
              title: 'Danger zone',
              children: [
                OutlinedButton(
                  onPressed: () => _suspend(client),
                  child: const Text('Suspend account'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError),
                  onPressed: () => _delete(client),
                  child: const Text('Delete account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
