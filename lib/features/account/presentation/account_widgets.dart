import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/glass_widgets.dart';

/// Asks for a fresh 6-digit authenticator code for actions the server
/// verifies inline (suspend / delete account -- see PassVaultapi's
/// verifyOwnTotpCode). Returns null if cancelled.
Future<String?> showCodePrompt(BuildContext context, {required String title, required String message}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '6-digit code'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final code = controller.text.trim();
            if (code.length == 6) Navigator.pop(context, code);
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Titled card used to group settings on the account screens.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
    );
  }
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    );
  }
}

/// Brand logo from White Label config, falling back to the app icon.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.url, this.height = 40});
  final String? url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = CrystalIcon(icon: Icons.shield_outlined, size: height);
    if (url == null) return fallback;
    return Image.network(url!, height: height, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback);
  }
}
