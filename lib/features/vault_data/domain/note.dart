import 'vault_entry.dart';

/// Note fields, matching passvault-client's AddNoteForm.js exactly:
/// { title, body, color, pinned, archived, tags }.
class Note {
  final String? id;
  final String title;
  final String body;
  final String? color;
  final bool pinned;
  final bool archived;
  final List<String> tags;

  const Note({
    this.id,
    required this.title,
    required this.body,
    this.color,
    this.pinned = false,
    this.archived = false,
    this.tags = const [],
  });

  factory Note.fromEntry(VaultEntry entry) {
    final tags = (entry.fields['tags'] as List<dynamic>? ?? []).cast<String>();
    return Note(
      id: entry.id,
      title: entry.fields['title'] as String? ?? '',
      body: entry.fields['body'] as String? ?? '',
      color: entry.fields['color'] as String?,
      pinned: entry.fields['pinned'] as bool? ?? false,
      archived: entry.fields['archived'] as bool? ?? false,
      tags: tags,
    );
  }

  VaultEntry toEntry({required String id}) => VaultEntry(
        id: id,
        type: VaultEntryType.note,
        fields: {
          'title': title,
          'body': body,
          'color': color,
          'pinned': pinned,
          'archived': archived,
          'tags': tags,
        },
      );

  Note copyWith({String? title, String? body, String? color, bool? pinned, bool? archived, List<String>? tags}) => Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        color: color ?? this.color,
        pinned: pinned ?? this.pinned,
        archived: archived ?? this.archived,
        tags: tags ?? this.tags,
      );
}
