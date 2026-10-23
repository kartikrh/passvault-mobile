import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_outcome.dart';
import '../../auth/domain/client.dart';
import '../../auth/presentation/auth_scaffold.dart';
import '../../vault_data/presentation/password_strength_meter.dart';
import 'account_widgets.dart';
import 'profile_screen.dart';

/// Account steps every signed-in client must finish before using the app --
/// the same PROFILE and OTP_SETUP gates as passvault-client's
/// useOnboardingStatus / OnboardingWizardModal. (Vault key and Drive are
/// handled when the vault is first opened.) The router sends any session
/// that [needsOnboarding] here.
bool needsProfileStep(Client c) => (c.username ?? '').isEmpty || !c.hasPassword;

bool needsOtpStep(Client c) => c.otpEnabled && c.otpType == OtpType.googleAuthenticator && !c.hasOtpSecret;

bool needsOnboarding(Client c) => needsProfileStep(c) || needsOtpStep(c);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final client = _client;
    _name.text = client?.name ?? '';
    _username.text = client?.username ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _username, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Client? get _client {
    final session = ref.read(sessionControllerProvider);
    return session is SessionAuthenticated ? session.client : null;
  }

  Future<void> _saveProfile(Client client) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(accountRepositoryProvider);
      if ((client.username ?? '').isEmpty) {
        await repo.updateProfile(name: _name.text.trim(), username: _username.text.trim());
      }
      if (!client.hasPassword) {
        await repo.setPassword(_password.text);
      }
      // The router re-evaluates on the new profile: next step, or /home.
      await ref.read(sessionControllerProvider.notifier).refreshProfile();
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startOtpSetup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await ref.read(accountRepositoryProvider).beginTwoFactorSetup();
      if (!mounted) return;
      // TwoFactorScreen confirms the code via /vault/auth/verifyOtp and
      // signs the refreshed session in (hasOtpSecret: true).
      context.push('/two-factor', extra: challenge);
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final client = session is SessionAuthenticated ? session.client : null;
    if (client == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final profileStep = needsProfileStep(client);
    final busyIndicator = const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));

    return PopScope(
      canPop: false,
      child: AuthScaffold(
        title: profileStep ? 'Finish setting up your account' : 'Protect your account',
        children: [
          Text('Step ${profileStep ? 1 : 2} of 2', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          if (profileStep)
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((client.username ?? '').isEmpty) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'Username', helperText: 'Can\'t be changed later'),
                      validator: validateUsername,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!client.hasPassword) ...[
                    const Text('Set a sign-in password, so you can also sign in without Google.'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                      validator: validateAccountPassword,
                    ),
                    PasswordStrengthMeter(password: _password.text),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      decoration: const InputDecoration(labelText: 'Confirm password'),
                      obscureText: true,
                      validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  ErrorText(_error),
                  FilledButton(
                    onPressed: _busy ? null : () => _saveProfile(client),
                    child: _busy ? busyIndicator : const Text('Continue'),
                  ),
                ],
              ),
            )
          else ...[
            const Text(
              'Two-factor authentication is required. Scan a QR code with Google Authenticator '
              '(or any authenticator app) and enter the code it shows.',
            ),
            const SizedBox(height: 16),
            ErrorText(_error),
            FilledButton.icon(
              onPressed: _busy ? null : _startOtpSetup,
              icon: const Icon(Icons.qr_code),
              label: _busy ? busyIndicator : const Text('Set up authenticator'),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
