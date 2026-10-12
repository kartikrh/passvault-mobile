import 'package:flutter/material.dart';

/// Mirrors passvault-client's NoteColorSwatches.js NOTE_COLORS exactly --
/// same preset names/labels/swatch hexes, so a note's color looks the same
/// on both clients.
class NoteColorOption {
  final String? value;
  final String label;
  final Color swatch;
  const NoteColorOption({required this.value, required this.label, required this.swatch});
}

const noteColorOptions = <NoteColorOption>[
  NoteColorOption(value: null, label: 'Default', swatch: Color(0xFFFFFFFF)),
  NoteColorOption(value: 'red', label: 'Red', swatch: Color(0xFFF6CBCB)),
  NoteColorOption(value: 'orange', label: 'Orange', swatch: Color(0xFFF7DCAE)),
  NoteColorOption(value: 'yellow', label: 'Yellow', swatch: Color(0xFFF9EDB0)),
  NoteColorOption(value: 'green', label: 'Green', swatch: Color(0xFFC9E8C9)),
  NoteColorOption(value: 'teal', label: 'Teal', swatch: Color(0xFFB6DEDE)),
  NoteColorOption(value: 'blue', label: 'Blue', swatch: Color(0xFFBCD6F2)),
  NoteColorOption(value: 'purple', label: 'Purple', swatch: Color(0xFFD5C9EC)),
  NoteColorOption(value: 'pink', label: 'Pink', swatch: Color(0xFFF3CFE3)),
  NoteColorOption(value: 'gray', label: 'Gray', swatch: Color(0xFFE0E0E0)),
];

Color noteColorSwatch(String? color) =>
    noteColorOptions.firstWhere((c) => c.value == color, orElse: () => noteColorOptions.first).swatch;
