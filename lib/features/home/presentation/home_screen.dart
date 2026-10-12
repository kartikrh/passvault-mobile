import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../vault_key/application/vault_key_controller.dart';

/// Placeholder post-login screen -- proves the auth/session round-trip and
/// vault-key setup/recovery both work. The real vault UI (accounts/notes)
/// is Phase 3/4 of the build plan.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // Step 1 of the vault gate, matching passvault-client's useVault: check
    // whether a vault key is already escrowed for this client before
    // anything vault-related can be shown.
    Future.microtask(() async {
      try {
        await ref.read(vaultKeyControllerProvider.notifier).checkStatus();
      } catch (e) {
        if (mounted) setState(() => _error = ApiClient.toApiException(e).message);
      }
    });
  }

  Future<void> _openVault() async {
    setState(() => _error = null);
    final state = ref.read(vaultKeyControllerProvider);
    if (state is VaultKeyMissing) {
      await context.push('/vault-key-setup');
      return;
    }
    if (state is VaultKeyReady) {
      context.push('/vault');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final client = session is SessionAuthenticated ? session.client : null;
    final vaultKeyState = ref.watch(vaultKeyControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PassVault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(client == null ? 'Signed in' : 'Signed in as ${client.name ?? client.email}'),
            const SizedBox(height: 16),
            switch (vaultKeyState) {
              VaultKeyUnknown() => const CircularProgressIndicator(),
              VaultKeyMissing() => FilledButton(onPressed: _openVault, child: const Text('Set up your vault')),
              VaultKeyReady() => FilledButton(onPressed: _openVault, child: const Text('Open vault')),
            },
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
