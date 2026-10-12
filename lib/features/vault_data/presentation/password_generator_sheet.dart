import 'package:flutter/material.dart';

import '../../../utils/password_generator.dart';

/// Bottom sheet for AccountFormScreen's password field -- no equivalent in
/// passvault-client (see password_generator.dart's doc comment), designed
/// fresh for this app.
Future<String?> showPasswordGeneratorSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _PasswordGeneratorSheet(),
  );
}

class _PasswordGeneratorSheet extends StatefulWidget {
  const _PasswordGeneratorSheet();

  @override
  State<_PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<_PasswordGeneratorSheet> {
  var _options = const PasswordGeneratorOptions();
  late String _generated = generatePassword(_options);

  void _regenerate([PasswordGeneratorOptions? next]) {
    setState(() {
      _options = next ?? _options;
      _generated = generatePassword(_options);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Generate password', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SelectableText(_generated, style: const TextStyle(fontFamily: 'monospace', fontSize: 18)),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Length: ${_options.length}'),
              Expanded(
                child: Slider(
                  value: _options.length.toDouble(),
                  min: 8,
                  max: 32,
                  divisions: 24,
                  onChanged: (v) => _regenerate(_options.copyWith(length: v.round())),
                ),
              ),
            ],
          ),
          CheckboxListTile(
            title: const Text('Uppercase (A-Z)'),
            value: _options.useUppercase,
            onChanged: (v) => _regenerate(_options.copyWith(useUppercase: v)),
          ),
          CheckboxListTile(
            title: const Text('Lowercase (a-z)'),
            value: _options.useLowercase,
            onChanged: (v) => _regenerate(_options.copyWith(useLowercase: v)),
          ),
          CheckboxListTile(
            title: const Text('Digits (0-9)'),
            value: _options.useDigits,
            onChanged: (v) => _regenerate(_options.copyWith(useDigits: v)),
          ),
          CheckboxListTile(
            title: const Text('Symbols (!@#...)'),
            value: _options.useSymbols,
            onChanged: (v) => _regenerate(_options.copyWith(useSymbols: v)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: () => _regenerate(), child: const Text('Regenerate')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_generated),
                  child: const Text('Use this'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
