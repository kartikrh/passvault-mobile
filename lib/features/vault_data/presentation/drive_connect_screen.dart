import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/auth_scaffold.dart';
import '../data/google_drive_connect_service.dart';

/// Vault entries (accounts/notes) live in the client's own Google Drive
/// (appDataFolder) -- PassVaultapi only proxies to it, so nothing can be
/// listed/saved until this consent step completes (see
/// services/vaultDrive.js's connectDriveService).
class DriveConnectScreen extends ConsumerStatefulWidget {
  const DriveConnectScreen({super.key});

  @override
  ConsumerState<DriveConnectScreen> createState() => _DriveConnectScreenState();
}

class _DriveConnectScreenState extends ConsumerState<DriveConnectScreen> {
  bool _connecting = false;
  String? _error;

  Future<void> _connect(String googleClientId) async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final code = await GoogleDriveConnectService(googleClientId).requestServerAuthCode();
      final connected = await ref.read(driveRepositoryProvider).connect(code);
      if (!mounted) return;
      if (connected) {
        context.pop(true);
      } else {
        setState(() => _error = 'Google Drive did not connect -- please try again.');
      }
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final whitelabel = ref.watch(whitelabelProvider);

    return AuthScaffold(
      title: 'Connect Google Drive',
      children: [
        const Text(
          'PassVault stores your encrypted vault in your own Google Drive -- '
          'connect it to start saving accounts and notes.',
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
        ],
        whitelabel.when(
          data: (config) {
            if (config.googleClientId == null) {
              return const Text('Google Drive is not configured for this deployment yet.');
            }
            return FilledButton(
              onPressed: _connecting ? null : () => _connect(config.googleClientId!),
              child: _connecting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Connect Google Drive'),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load configuration: $e'),
        ),
      ],
    );
  }
}
