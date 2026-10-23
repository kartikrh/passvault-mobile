import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../vault_key/application/vault_key_controller.dart';
import '../domain/note.dart';
import '../domain/note_color.dart';
import '../domain/vault_entry.dart';
import 'note_form_screen.dart';
import 'vault_widgets.dart';

/// Notes tab -- list/add/edit/delete, pin/archive toggles. No step-up gate
/// (unlike accounts): notes carry no password to protect the same way, and
/// passvault-client's NotesGrid.js gates none of this behind 2FA.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  bool _loading = true;
  String? _error;
  List<VaultEntry> _entries = [];
  Map<String, String?> _revisionIds = {};
  String _search = '';
  // Entries saved with Hide stay out of the list until the user passes a
  // step-up via HiddenEntriesToggle.
  bool _showHidden = false;
  bool _driveReauth = false;
  bool _showArchived = false;

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
            kinds: const [VaultFileKind.notes],
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

  int get _hiddenCount => _entries.where((e) => e.type == VaultEntryType.note && e.fields['hidden'] == true).length;

  List<Note> get _notes {
    var notes = _entries.where((e) => e.type == VaultEntryType.note).map(Note.fromEntry);
    if (!_showHidden) notes = notes.where((n) => !n.hidden);
    if (!_showArchived) notes = notes.where((n) => !n.archived);
    if (_search.isNotEmpty) {
      final query = _search.toLowerCase();
      notes = notes.where((n) =>
          n.title.toLowerCase().contains(query) ||
          n.body.toLowerCase().contains(query) ||
          n.tags.any((t) => t.toLowerCase().contains(query)));
    }
    final list = notes.toList()..sort((a, b) => (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0));
    return list;
  }

  Future<void> _save(Note note) async {
    setState(() => _error = null);
    try {
      final isNew = note.id == null;
      final result = isNew
          ? await ref.read(vaultDataRepositoryProvider).addEntry(
                vaultKey: _vaultKey,
                entries: _entries,
                revisionIds: _revisionIds,
                newEntry: note.toEntry(id: DateTime.now().microsecondsSinceEpoch.toString()),
              )
          : await ref.read(vaultDataRepositoryProvider).updateEntry(
                vaultKey: _vaultKey,
                entries: _entries,
                revisionIds: _revisionIds,
                updatedEntry: note.toEntry(id: note.id!),
              );
      setState(() {
        _entries = result.entries;
        _revisionIds = result.revisionIds;
      });
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _add() async {
    final note = await Navigator.of(context).push<Note>(MaterialPageRoute(builder: (_) => const NoteFormScreen()));
    if (note != null) await _save(note);
  }

  Future<void> _edit(Note note) async {
    final updated = await Navigator.of(context).push<Note>(
      MaterialPageRoute(builder: (_) => NoteFormScreen(initial: note)),
    );
    if (updated != null) await _save(updated);
  }

  Future<void> _togglePinned(Note note) => _save(note.copyWith(pinned: !note.pinned));

  Future<void> _toggleArchived(Note note) => _save(note.copyWith(archived: !note.archived));

  Future<void> _delete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('This permanently deletes "${note.title.isEmpty ? '(untitled)' : note.title}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _error = null);
    try {
      final result = await ref.read(vaultDataRepositoryProvider).deleteEntry(
            vaultKey: _vaultKey,
            entries: _entries,
            revisionIds: _revisionIds,
            entryId: note.id!,
            entryType: VaultEntryType.note,
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
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search notes'),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                        HiddenEntriesToggle(
                          count: _hiddenCount,
                          revealed: _showHidden,
                          otpEnabled: _otpEnabledForHidden,
                          onChanged: (v) => setState(() => _showHidden = v),
                        ),
                        IconButton(
                          icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
                          tooltip: 'Show archived',
                          onPressed: () => setState(() => _showArchived = !_showArchived),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (_notes.isEmpty)
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No notes yet.')))
                  else
                    ..._notes.map(
                      (note) => Card(
                        color: noteColorSwatch(note.color),
                        child: ListTile(
                          leading: note.hidden
                              ? const Icon(Icons.visibility_off_outlined)
                              : note.pinned
                                  ? const Icon(Icons.push_pin)
                                  : null,
                          title: Text(note.title.isEmpty ? '(untitled)' : note.title),
                          subtitle: Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _edit(note),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) => switch (action) {
                              'pin' => _togglePinned(note),
                              'archive' => _toggleArchived(note),
                              'delete' => _delete(note),
                              _ => null,
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'pin', child: Text(note.pinned ? 'Unpin' : 'Pin')),
                              PopupMenuItem(value: 'archive', child: Text(note.archived ? 'Unarchive' : 'Archive')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
