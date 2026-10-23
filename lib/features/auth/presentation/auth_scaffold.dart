import 'package:flutter/material.dart';

import '../../../core/theme/glass_widgets.dart';

/// Shared chrome for every auth screen -- crystal emblem, holographic title
/// and the form on a frosted glass panel, scrollable so the keyboard never
/// covers the active field.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.children, this.icon = Icons.lock_outline});

  final String title;
  final List<Widget> children;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: CrystalIcon(icon: icon, size: 72)),
                  const SizedBox(height: 16),
                  Center(
                    child: HoloText(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
