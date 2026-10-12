import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/location/location_service.dart';
import '../../../core/providers.dart';

/// On-demand 2FA re-verification gate for a signed-in session -- used
/// before revealing/editing/deleting a saved account (see
/// verifyStepUpOtpService in PassVaultapi's services/vaultAuth.js and
/// passvault-client's StepUpGateModal/RevealAccountModal).
///
/// [entryId]/[entryName] are only passed for a *reveal* (logs
/// ACCOUNT_PASSWORD_VIEWED with best-effort location) -- omit both for an
/// edit/delete gate, matching StepUpGateModal's call shape.
///
/// Returns true once verified, false/null if the user cancelled or the
/// code was wrong.
Future<bool> showStepUpGate(
  BuildContext context, {
  required bool otpEnabled,
  String? entryId,
  String? entryName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: !otpEnabled, // no code to enter -- let it auto-submit
    builder: (context) => _StepUpDialog(otpEnabled: otpEnabled, entryId: entryId, entryName: entryName),
  );
  return result ?? false;
}

class _StepUpDialog extends ConsumerStatefulWidget {
  const _StepUpDialog({required this.otpEnabled, this.entryId, this.entryName});

  final bool otpEnabled;
  final String? entryId;
  final String? entryName;

  @override
  ConsumerState<_StepUpDialog> createState() => _StepUpDialogState();
}

class _StepUpDialogState extends ConsumerState<_StepUpDialog> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.otpEnabled) {
      // verifyOwnTotpCode is satisfied automatically when 2FA is off --
      // same auto-submit-with-no-code UX as StepUpOtpPrompt.
      Future.microtask(() => _submit(null));
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit(String? code) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      LocationCoordinates? coords;
      if (widget.entryId != null) {
        coords = await ref.read(locationServiceProvider).tryGetCurrentLocation();
      }
      final result = await ref.read(stepUpRepositoryProvider).verify(
            code: code,
            entryId: widget.entryId,
            entryName: widget.entryId != null ? widget.entryName : null,
            latitude: coords?.latitude,
            longitude: coords?.longitude,
          );
      if (!mounted) return;
      if (result.verified) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Verification failed.');
      }
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.otpEnabled) {
      return const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('One moment...'),
          ],
        ),
      );
    }

    return AlertDialog(
      title: const Text('Verify it\'s you'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter the 6-digit code from your authenticator app.'),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(labelText: '6-digit code'),
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
          ),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : () => _submit(_codeController.text.trim()),
          child: _submitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify'),
        ),
      ],
    );
  }
}
