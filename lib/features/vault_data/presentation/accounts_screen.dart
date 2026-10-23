import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../vault_key/application/vault_key_controller.dart';
import '../domain/account.dart';
import '../domain/vault_entry.dart';
import 'account_form_screen.dart';
import 'reveal_account_dialog.dart';
import 'step_up_gate.dart';
import 'vault_widgets.dart';

/// Accounts tab -- list/add/edit/delete/reveal, each of the latter three
/// gated by a fresh 2FA step-up (see passvault-client's VaultAccountList.js:
/// edit and delete require step-up too, not just reveal).
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _loading = true;
  String? _error;
  List<VaultEntry> _entries = [];
  Map<String, String?> _revisionIds = {};
  String _search = '';
  // Entries saved with Hide stay out of the list until the user passes a
  // step-up via HiddenEntriesToggle.
  bool _showHidden = false;
  bool _driveReauth = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadIfDriveConnected);
  }

  String get _vaultKey {
    final state = ref.read(vaultKeyControllerProvider);
    if (state is! VaultKeyReady) throw StateError('Vault key must be ready.');
    return state.vaultKey;
  }

  bool get _otpEnabled {
    final session = ref.read(sessionControllerProvider);
    return session is SessionAuthenticated && session.client.otpEnabled;
  }

  int get _popupIntervalSeconds {
    final session = ref.read(sessionControllerProvider);
    return session is SessionAuthenticated ? session.client.popupIntervalSeconds : 10;
  }

  Future<void> _loadIfDriveConnected() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connected = await ref.read(driveRepositoryProvider).status();
      if (!connected) {
        if (!mounted) return;
        final result = await context.push<bool>('/drive-connect');
        if (result != true) {
          if (mounted) setState(() => _loading = false);
          return;
        }
      }
      await _load();
    } catch (e) {
      _handleError(e);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleError(Object e) {
    if (!mounted) return;
    setState(() {
      if (isDriveReauthRequired(e)) {
        _driveReauth = true;
        _error = null;
      } else {
        _error = ApiClient.toApiException(e).message;
      }
    });
  }

  Future<void> _reconnectDrive() async {
    final connected = await context.push<bool>('/drive-connect');
    if (connected == true && mounted) {
      setState(() => _driveReauth = false);
      await _load();
    }
  }

  bool get _otpEnabledForHidden {
    final session = ref.read(sessionControllerProvider);
    return session is SessionAuthenticated && session.client.otpEnabled;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(vaultDataRepositoryProvider).fetchEntries(
            vaultKey: _vaultKey,
            kinds: const [VaultFileKind.accounts],
          );
      setState(() {
        _entries = result.entries;
        _revisionIds = result.revisionIds;
      });
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _hiddenCount => _entries.where((e) => e.type == VaultEntryType.account && e.fields['hidden'] == true).length;

  List<Account> get _accounts {
    var accounts = _entries.where((e) => e.type == VaultEntryType.account).map(Account.fromEntry);
    if (!_showHidden) accounts = accounts.where((a) => !a.hidden);
    if (_search.isEmpty) return accounts.toList();
    final query = _search.toLowerCase();
    return accounts
        .where((a) =>
            a.title.toLowerCase().contains(query) ||
            a.username.toLowerCase().contains(query) ||
            a.tags.any((t) => t.toLowerCase().contains(query)))
        .toList();
  }

  Future<void> _add() async {
    final account = await Navigator.of(context).push<Account>(
      MaterialPageRoute(builder: (_) => const AccountFormScreen()),
    );
    if (account == null) return;
    setState(() => _error = null);
    try {
      final newEntry = account.toEntry(id: DateTime.now().microsecondsSinceEpoch.toString());
      final result = await ref.read(vaultDataRepositoryProvider).addEntry(
            vaultKey: _vaultKey,
            entries: _entries,
            revisionIds: _revisionIds,
            newEntry: newEntry,
          );
      setState(() {
        _entries = result.entries;
        _revisionIds = result.revisionIds;
      });
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _reveal(Account account) async {
    final verified = await showStepUpGate(context, otpEnabled: _otpEnabled, entryId: account.id, entryName: account.title);
    if (!verified || !mounted) return;
    await showRevealAccountDialog(context, account: account, popupIntervalSeconds: _popupIntervalSeconds);
  }

  Future<void> _edit(Account account) async {
    final verified = await showStepUpGate(context, otpEnabled: _otpEnabled);
    if (!verified || !mounted) return;
    final updated = await Navigator.of(context).push<Account>(
      MaterialPageRoute(builder: (_) => AccountFormScreen(initial: account)),
    );
    if (updated == null) return;
    setState(() => _error = null);
    try {
      final result = await ref.read(vaultDataRepositoryProvider).updateEntry(
            vaultKey: _vaultKey,
            entries: _entries,
            revisionIds: _revisionIds,
            updatedEntry: updated.toEntry(id: updated.id!),
          );
      setState(() {
        _entries = result.entries;
        _revisionIds = result.revisionIds;
      });
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _delete(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('This permanently deletes "${account.title}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final verified = await showStepUpGate(context, otpEnabled: _otpEnabled);
    if (!verified || !mounted) return;
    setState(() => _error = null);
    try {
      final result = await ref.read(vaultDataRepositoryProvider).deleteEntry(
            vaultKey: _vaultKey,
            entries: _entries,
            revisionIds: _revisionIds,
            entryId: account.id!,
            entryType: VaultEntryType.account,
          );
      setState(() {
        _entries = result.entries;
        _revisionIds = result.revisionIds;
      });
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  if (_driveReauth) DriveReauthCard(onReconnect: _reconnectDrive),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search accounts'),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                        HiddenEntriesToggle(
                          count: _hiddenCount,
                          revealed: _showHidden,
                          otpEnabled: _otpEnabledForHidden,
                          onChanged: (v) => setState(() => _showHidden = v),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (_accounts.isEmpty)
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No accounts yet.')))
                  else
                    ..._accounts.map(
                      (account) => Card(
                        child: ListTile(
                          leading: Icon(account.hidden ? Icons.visibility_off_outlined : Icons.key),
                          title: Text(account.title),
                          subtitle: account.username.isNotEmpty ? Text(account.username) : null,
                          onTap: () => _reveal(account),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(account)),
                              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(account)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
    );
  }
}
