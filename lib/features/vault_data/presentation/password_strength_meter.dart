import 'package:flutter/material.dart';

import '../../../utils/password_strength.dart';

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final strength = getPasswordStrength(password);
    final (color, progress) = switch (strength) {
      PasswordStrength.tooShort => (Colors.red, 0.15),
      PasswordStrength.weak => (Colors.orange, 0.4),
      PasswordStrength.medium => (Colors.amber, 0.7),
      PasswordStrength.strong => (Colors.green, 1.0),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, color: color, minHeight: 4),
          ),
          Text(passwordStrengthLabel(strength), style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
