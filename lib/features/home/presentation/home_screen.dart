import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../account/domain/account_models.dart';
import '../../account/presentation/account_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass_widgets.dart';
import '../../auth/application/session_controller.dart';
import '../../vault_key/application/vault_key_controller.dart';

/// Dashboard: who's signed in, current plan + expiry, the vault entry point
/// (set up / unlock / open) and links to every account screen -- the mobile
/// counterpart of passvault-client's /dashboard + header menu.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // Step 1 of the vault gate, matching passvault-client's useVault: is a
    // vault key set up, and is it unlocked in this app session?
    Future.microtask(_checkVault);
  }

  Future<void> _checkVault() async {
    try {
      await ref.read(vaultKeyControllerProvider.notifier).checkStatus();
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.toApiException(e).message);
    }
  }

  Future<void> _openVault() async {
    setState(() => _error = null);
    final state = ref.read(vaultKeyControllerProvider);
    if (state is VaultKeyMissing) {
      await context.push('/vault-key-setup');
      return;
    }
    if (state is VaultKeyLocked) {
      await context.push('/vault-unlock');
      return;
    }
    if (state is VaultKeyReady) {
      context.push('/vault');
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(clientPackageProvider);
    await Future.wait([
      ref.read(sessionControllerProvider.notifier).refreshProfile().catchError((_) {}),
      _checkVault(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final client = session is SessionAuthenticated ? session.client : null;
    final vaultKeyState = ref.watch(vaultKeyControllerProvider);
    final packageAsync = ref.watch(clientPackageProvider);
    final logoUrl = ref.watch(whitelabelProvider).valueOrNull?.logoUrl;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            BrandLogo(url: logoUrl, height: 28),
            const SizedBox(width: 8),
            const Text('PassVault'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: HoloText(
                client == null ? 'Welcome' : 'Hi, ${client.name?.split(' ').first ?? client.username ?? client.email}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (client != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(client.email, style: Theme.of(context).textTheme.bodyMedium),
              ),
            _VaultCard(state: vaultKeyState, onOpen: _openVault, error: _error),
            packageAsync.when(
              data: (pkg) => _PlanCard(package: pkg),
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SectionCard(
                title: 'Your plan',
                children: [ErrorText(ApiClient.toApiException(e).message)],
              ),
            ),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _NavTile(icon: Icons.person_outline, title: 'Profile', route: '/profile'),
                  _NavTile(icon: Icons.security, title: 'Security & 2FA', route: '/security'),
                  _NavTile(
                    icon: Icons.password,
                    title: client?.hasPassword == false ? 'Set password' : 'Change password',
                    route: '/password',
                  ),
                  _NavTile(icon: Icons.history, title: 'Activity', route: '/activity'),
                  _NavTile(icon: Icons.workspace_premium_outlined, title: 'Upgrade plan', route: '/upgrade'),
                  _NavTile(icon: Icons.help_outline, title: 'Help & legal', route: '/pages'),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Appearance'),
                    subtitle: Text(ref.watch(paletteProvider).label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showAppearanceSheet(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({required this.state, required this.onOpen, this.error});

  final VaultKeyState state;
  final VoidCallback onOpen;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (String subtitle, Widget action) = switch (state) {
      VaultKeyUnknown() => ('Checking your vault...', const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()))),
      VaultKeyMissing() => (
          'Choose a vault password to start saving accounts and notes.',
          HoloButton(onPressed: onOpen, icon: Icons.add_moderator, child: const Text('Set up your vault')),
        ),
      VaultKeyLocked() => (
          'Locked -- unlock with your vault password or biometrics.',
          HoloButton(onPressed: onOpen, icon: Icons.lock_open, child: const Text('Unlock vault')),
        ),
      VaultKeyReady() => (
          'Unlocked on this device.',
          HoloButton(onPressed: onOpen, icon: Icons.folder_open, child: const Text('Open vault')),
        ),
    };
    final crystalIcon = switch (state) {
      VaultKeyReady() => Icons.lock_open,
      VaultKeyMissing() => Icons.add_moderator,
      _ => Icons.lock_outline,
    };
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CrystalIcon(icon: crystalIcon, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your vault', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ErrorText(error),
          action,
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.package});
  final ClientPackage? package;

  @override
  Widget build(BuildContext context) {
    final pkg = package;
    final colors = Theme.of(context).colorScheme;
    if (pkg == null) {
      return SectionCard(
        title: 'Your plan',
        subtitle: 'No plan assigned yet.',
        children: [OutlinedButton(onPressed: () => context.push('/upgrade'), child: const Text('See plans'))],
      );
    }
    final expiry = pkg.expiryDate == null
        ? null
        : pkg.isExpired
            ? 'Expired'
            : '${pkg.daysRemaining ?? 0} day${pkg.daysRemaining == 1 ? '' : 's'} left';
    final limits = [
      if (pkg.maxAccounts != null) '${pkg.maxAccounts} accounts',
      if (pkg.maxNotes != null) '${pkg.maxNotes} notes',
    ].join(' · ');
    return SectionCard(
      title: 'Your plan',
      children: [
        Row(
          children: [
            Expanded(child: Text(pkg.name, style: Theme.of(context).textTheme.titleLarge)),
            if (expiry != null)
              Chip(
                label: Text(expiry),
                backgroundColor: pkg.isExpired || (pkg.daysRemaining ?? 99) <= 7 ? colors.errorContainer : null,
              ),
          ],
        ),
        if (limits.isNotEmpty) Text(limits),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: () => context.push('/upgrade'), child: const Text('Upgrade plan')),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, required this.route});
  final IconData icon;
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}

/// Bottom sheet with the three glass palettes.
Future<void> showAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Choose a colour palette. It\'s remembered on this device.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            const PalettePicker(),
          ],
        ),
      ),
    ),
  );
}
