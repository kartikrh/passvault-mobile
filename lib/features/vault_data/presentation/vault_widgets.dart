import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import 'step_up_gate.dart';

/// PassVaultapi drops a dead Drive refresh token (revoked, expired, or a
/// rotated White Label OAuth secret) and answers DRIVE_REAUTH_REQUIRED --
/// the screen should offer "Reconnect" rather than show a raw error.
bool isDriveReauthRequired(Object error) => ApiClient.toApiException(error).code == 'DRIVE_REAUTH_REQUIRED';

class DriveReauthCard extends StatelessWidget {
  const DriveReauthCard({super.key, required this.onReconnect});
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Your Google Drive connection has expired or was revoked. Reconnect to keep using your vault.'),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onReconnect, icon: const Icon(Icons.add_to_drive), label: const Text('Reconnect Google Drive')),
          ],
        ),
      ),
    );
  }
}

/// Eye button for entries saved with "Hide" -- showing them needs the same
/// step-up (biometrics or 2FA code) as revealing a password, like
/// passvault-client's HiddenEntriesToggle. Renders nothing when none are hidden.
class HiddenEntriesToggle extends StatelessWidget {
  const HiddenEntriesToggle({
    super.key,
    required this.count,
    required this.revealed,
    required this.otpEnabled,
    required this.onChanged,
  });

  final int count;
  final bool revealed;
  final bool otpEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return IconButton(
      tooltip: revealed ? 'Hide hidden items again' : 'Show $count hidden',
      icon: Badge(
        isLabelVisible: !revealed,
        label: Text('$count'),
        child: Icon(revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      ),
      onPressed: () async {
        if (revealed) {
          onChanged(false);
          return;
        }
        if (await showStepUpGate(context, otpEnabled: otpEnabled)) onChanged(true);
      },
    );
  }
}
