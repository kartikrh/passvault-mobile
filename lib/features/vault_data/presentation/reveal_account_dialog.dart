import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/account.dart';

/// Phase 2 of RevealAccountModal's flow -- shown only after showStepUpGate
/// has already verified the user. Password stays masked behind its own
/// local eye-toggle even after step-up succeeds; Copy always works
/// regardless of visibility. Auto-closes after [popupIntervalSeconds]
/// (client.popupIntervalSeconds, default 10) the same way the web reveal
/// modal does.
Future<void> showRevealAccountDialog(
  BuildContext context, {
  required Account account,
  required int popupIntervalSeconds,
}) {
  return showDialog(
    context: context,
    builder: (context) => _RevealAccountDialog(account: account, popupIntervalSeconds: popupIntervalSeconds),
  );
}

class _RevealAccountDialog extends StatefulWidget {
  const _RevealAccountDialog({required this.account, required this.popupIntervalSeconds});

  final Account account;
  final int popupIntervalSeconds;

  @override
  State<_RevealAccountDialog> createState() => _RevealAccountDialogState();
}

class _RevealAccountDialogState extends State<_RevealAccountDialog> {
  bool _showPassword = false;
  late int _secondsLeft = widget.popupIntervalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    return AlertDialog(
      title: Text(account.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RevealRow(label: 'Username', value: account.username, onCopy: () => _copy('Username', account.username)),
          _RevealRow(
            label: 'Password',
            value: _showPassword ? account.password : '•' * account.password.length,
            onCopy: () => _copy('Password', account.password),
            trailing: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          if (account.url.isNotEmpty)
            _RevealRow(label: 'URL', value: account.url, onCopy: () => _copy('URL', account.url)),
          for (final q in account.securityQuestions) ...[
            const SizedBox(height: 8),
            Text(q.question, style: const TextStyle(fontWeight: FontWeight.bold)),
            _RevealRow(label: 'Answer', value: q.answer, onCopy: () => _copy('Answer', q.answer)),
          ],
          const SizedBox(height: 12),
          Text('Closing in ${_secondsLeft}s', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}

class _RevealRow extends StatelessWidget {
  const _RevealRow({required this.label, required this.value, required this.onCopy, this.trailing});

  final String label;
  final String value;
  final VoidCallback onCopy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
        ),
        ?trailing,
        IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: onCopy),
      ],
    );
  }
}
