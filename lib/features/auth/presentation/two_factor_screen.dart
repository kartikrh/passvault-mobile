import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../application/session_controller.dart';
import '../domain/auth_outcome.dart';
import 'auth_scaffold.dart';

/// Second step for a login/Google-sign-in/enrollment challenge (see
/// beginTwoFactorChallenge in PassVaultapi's services/vaultAuth.js) --
/// covers both a returning login's OTP prompt and first-time Google
/// Authenticator enrollment (qrCode present) with the same POST
/// /vault/auth/verifyOtp call.
class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key, required this.challenge});

  final TwoFactorRequired challenge;

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final outcome = await ref.read(authRepositoryProvider).verifyOtp(
            pendingToken: widget.challenge.pendingToken,
            code: code,
          );
      if (!mounted) return;
      switch (outcome) {
        case AuthSuccess(:final client):
          ref.read(sessionControllerProvider.notifier).setAuthenticated(client);
          context.go('/home');
        case TwoFactorRequired():
          setState(() => _error = 'Unexpected response -- please try again.');
      }
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMail = widget.challenge.otpType == OtpType.mail;
    final qrCode = widget.challenge.qrCode;

    return AuthScaffold(
      title: 'Two-factor verification',
      children: [
        if (isMail)
          const Text('We emailed a 6-digit code to your address. Enter it below.')
        else if (qrCode != null) ...[
          const Text('Scan this QR code with Google Authenticator, then enter the 6-digit code it shows.'),
          const SizedBox(height: 16),
          Center(child: Image.memory(base64Decode(qrCode.split(',').last), width: 200, height: 200)),
        ] else
          const Text('Enter the 6-digit code from your authenticator app.'),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(labelText: '6-digit code'),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify'),
        ),
      ],
    );
  }
}
