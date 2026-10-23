import 'vault_entry.dart';

/// Note fields, matching passvault-client's AddNoteForm.js / NoteCard.js:
/// { title, body, color, pinned, archived, tags, hidden }. Unknown stored
/// fields ride along in [extra] so a mobile edit never strips them.
class Note {
  final String? id;
  final String title;
  final String body;
  final String? color;
  final bool pinned;
  final bool archived;
  final List<String> tags;
  final bool hidden;
  final Map<String, dynamic> extra;

  const Note({
    this.id,
    required this.title,
    required this.body,
    this.color,
    this.pinned = false,
    this.archived = false,
    this.tags = const [],
    this.hidden = false,
    this.extra = const {},
  });

  static const _knownFields = {'title', 'body', 'color', 'pinned', 'archived', 'tags', 'hidden'};

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
      hidden: entry.fields['hidden'] as bool? ?? false,
      extra: Map.of(entry.fields)..removeWhere((key, _) => _knownFields.contains(key)),
    );
  }

  VaultEntry toEntry({required String id}) => VaultEntry(
        id: id,
        type: VaultEntryType.note,
        fields: {
          ...extra,
          'title': title,
          'body': body,
          'color': color,
          'pinned': pinned,
          'archived': archived,
          'tags': tags,
          'hidden': hidden,
        },
      );

  Note copyWith({
    String? title,
    String? body,
    String? color,
    bool? pinned,
    bool? archived,
    List<String>? tags,
    bool? hidden,
  }) =>
      Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        color: color ?? this.color,
        pinned: pinned ?? this.pinned,
        archived: archived ?? this.archived,
        tags: tags ?? this.tags,
        hidden: hidden ?? this.hidden,
        extra: extra,
      );
}
