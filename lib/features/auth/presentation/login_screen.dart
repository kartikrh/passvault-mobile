import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/location/location_service.dart';
import '../../../core/providers.dart';
import '../application/session_controller.dart';
import '../data/google_auth_service.dart';
import '../domain/auth_outcome.dart';
import 'auth_scaffold.dart';

/// Email/username + password login (matching passvault-client's LoginForm),
/// with Google sign-in offered below it whenever this White Label has
/// isGoogleLoginMobile/googleKeyMobile configured.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleOutcome(AuthOutcome outcome) {
    switch (outcome) {
      case AuthSuccess(:final client):
        ref.read(sessionControllerProvider.notifier).setAuthenticated(client);
        context.go('/home');
      case TwoFactorRequired():
        context.push('/two-factor', extra: outcome);
    }
  }

  Future<void> _login() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email/username and password');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final outcome = await ref.read(authRepositoryProvider).login(identifier: identifier, password: password);
      if (!mounted) return;
      _handleOutcome(outcome);
    } on LocationRequiredException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _continueWithGoogle(String googleClientId) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final idToken = await GoogleAuthService(googleClientId).signInAndGetIdToken();
      final outcome = await ref.read(authRepositoryProvider).googleSignIn(idToken);
      if (!mounted) return;
      _handleOutcome(outcome);
    } on LocationRequiredException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final whitelabel = ref.watch(whitelabelProvider);

    return AuthScaffold(
      title: 'Welcome to PassVault',
      children: [
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _identifierController,
          decoration: const InputDecoration(labelText: 'Email or Username'),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !_submitting,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
          textInputAction: TextInputAction.done,
          enabled: !_submitting,
          onSubmitted: (_) => _submitting ? null : _login(),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submitting ? null : _login,
          child: _submitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Log In'),
        ),
        // Google is an independent, additive sign-in path -- its own load/
        // error state (missing config, fetch failure) must never block the
        // password form above, which needs nothing from whitelabelProvider.
        whitelabel.when(
          data: (config) {
            if (config.googleClientId == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : () => _continueWithGoogle(config.googleClientId!),
                  icon: const Icon(Icons.g_mobiledata),
                  label: const Text('Continue with Google'),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              'Could not load sign-in configuration: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
}
