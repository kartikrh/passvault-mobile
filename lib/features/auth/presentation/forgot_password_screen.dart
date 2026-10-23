import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import 'auth_scaffold.dart';

/// POST /vault/auth/forgotPassword. The emailed link opens PassVault's web
/// reset page (the server builds it from VAULTCLIENTAPPURL), where the new
/// password is chosen; the user then signs in here with it.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter the email address you signed up with');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).forgotPassword(email);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset your password',
      children: _sent
          ? [
              const Icon(Icons.mark_email_read_outlined, size: 48),
              const SizedBox(height: 16),
              const Text(
                'If an account exists for that email, we\'ve sent a reset link. Open it to choose a new '
                'password, then sign in here with it.\n\nThis resets your sign-in password only -- '
                'your vault password can\'t be reset.',
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to sign in')),
            ]
          : [
              const Text('Enter your email and we\'ll send you a link to reset your sign-in password.'),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send reset link'),
              ),
            ],
    );
  }
}
