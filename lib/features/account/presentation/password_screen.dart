import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../vault_data/presentation/password_strength_meter.dart';
import 'account_widgets.dart';
import 'profile_screen.dart';

/// Account (sign-in) password -- change it, or set one for an account that
/// signed up with Google and never had one. Not the vault password: that
/// one can't be changed or recovered by the server.
class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key});

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _hasPassword {
    final session = ref.read(sessionControllerProvider);
    return session is SessionAuthenticated && session.client.hasPassword;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(accountRepositoryProvider);
      if (_hasPassword) {
        await repo.changePassword(currentPassword: _current.text, newPassword: _next.text);
      } else {
        await repo.setPassword(_next.text);
        await ref.read(sessionControllerProvider.notifier).refreshProfile();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password saved')));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPassword = _hasPassword;
    return Scaffold(
      appBar: AppBar(title: Text(hasPassword ? 'Change password' : 'Set password')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              hasPassword
                  ? 'Your sign-in password. This is not your vault password.'
                  : 'Add a password so you can also sign in without Google.',
            ),
            const SizedBox(height: 16),
            if (hasPassword) ...[
              TextFormField(
                controller: _current,
                decoration: const InputDecoration(labelText: 'Current password'),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _next,
              decoration: const InputDecoration(labelText: 'New password'),
              obscureText: true,
              onChanged: (_) => setState(() {}),
              validator: validateAccountPassword,
            ),
            PasswordStrengthMeter(password: _next.text),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
              obscureText: true,
              validator: (v) => v != _next.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 16),
            ErrorText(_error),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save password'),
            ),
          ],
        ),
      ),
    );
  }
}
