import 'package:flutter/material.dart';

import '../../../core/theme/glass_widgets.dart';

/// Shown only while SessionController is bootstrapping (checking for a
/// stored token) -- the router redirects away as soon as that resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CrystalIcon(icon: Icons.lock_outline, size: 96),
            SizedBox(height: 24),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}
