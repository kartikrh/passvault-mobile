import 'package:flutter/material.dart';

/// Shared by Accounts and Notes add/edit forms -- matches
/// passvault-client's TagsEditor.js: a free-text chip input, deduplicated.
class TagsEditor extends StatefulWidget {
  const TagsEditor({super.key, required this.tags, required this.onChanged});

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<TagsEditor> createState() => _TagsEditorState();
}

class _TagsEditorState extends State<TagsEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty || widget.tags.contains(tag)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.tags, tag]);
    _controller.clear();
  }

  void _removeTag(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(labelText: 'Add a tag', hintText: 'Press enter to add'),
          onSubmitted: _addTag,
        ),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.tags
                .map((tag) => Chip(label: Text(tag), onDeleted: () => _removeTag(tag)))
                .toList(),
          ),
        ],
      ],
    );
  }
}
