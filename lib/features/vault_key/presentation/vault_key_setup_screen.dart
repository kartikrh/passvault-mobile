import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/auth_scaffold.dart';

/// One-time action -- the vault key is derived from a password the user
/// chooses here (never generated for them), then escrowed via
/// POST /vault/key/setup. Every later device/session recovers the same key
/// via /vault/key/recover (see VaultKeyController.checkStatus) instead of
/// re-deriving it, so this screen only ever runs once per account.
class VaultKeySetupScreen extends ConsumerStatefulWidget {
  const VaultKeySetupScreen({super.key});

  @override
  ConsumerState<VaultKeySetupScreen> createState() => _VaultKeySetupScreenState();
}

class _VaultKeySetupScreenState extends ConsumerState<VaultKeySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(vaultKeyControllerProvider.notifier).setup(_passwordController.text);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Set up your vault',
      children: [
        const Text(
          'Choose a vault password. It encrypts everything you save -- PassVault never sees it, '
          'and there is no way to recover your vault if you forget it.',
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Vault password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration: const InputDecoration(labelText: 'Confirm vault password'),
                obscureText: true,
                validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
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
                    : const Text('Set up vault'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
