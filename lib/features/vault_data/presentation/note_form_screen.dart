import 'package:flutter/material.dart';

import '../domain/note.dart';
import '../domain/note_color.dart';
import 'tags_editor.dart';

/// Add/edit form for a Note -- matches passvault-client's AddNoteForm.js:
/// title, body, color, tags. pinned/archived are toggled from the list, not
/// this form (a new note is always unpinned/unarchived).
class NoteFormScreen extends StatefulWidget {
  const NoteFormScreen({super.key, this.initial});

  final Note? initial;

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  late final _titleController = TextEditingController(text: widget.initial?.title ?? '');
  late final _bodyController = TextEditingController(text: widget.initial?.body ?? '');
  late String? _color = widget.initial?.color;
  late List<String> _tags = List.of(widget.initial?.tags ?? []);

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleController.text.trim().isEmpty && _bodyController.text.trim().isEmpty) {
      return; // matches AddNoteForm.js: title optional only if body is non-empty
    }
    Navigator.of(context).pop(
      (widget.initial ?? const Note(title: '', body: '')).copyWith(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        color: _color,
        tags: _tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial != null ? 'Edit note' : 'Add note'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            decoration: const InputDecoration(labelText: 'Note'),
            minLines: 4,
            maxLines: 10,
          ),
          const SizedBox(height: 24),
          Text('Color', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: noteColorOptions
                .map(
                  (option) => InkWell(
                    onTap: () => setState(() => _color = option.value),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: option.swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == option.value ? Theme.of(context).colorScheme.primary : Colors.grey,
                          width: _color == option.value ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          TagsEditor(tags: _tags, onChanged: (t) => setState(() => _tags = t)),
        ],
      ),
    );
  }
}
