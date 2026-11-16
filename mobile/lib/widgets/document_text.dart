import 'package:flutter/material.dart';

/// Keeps the original characters while bounding individual paragraph layouts.
/// These are display sections, never inferred source pages.
List<String> documentTextSections(String text, {int maxLength = 2400}) {
  final sections = <String>[];
  var start = 0;
  while (start < text.length) {
    var end = (start + maxLength).clamp(0, text.length);
    if (end < text.length) {
      final newline = text.lastIndexOf('\n', end - 1);
      final space = text.lastIndexOf(' ', end - 1);
      final boundary = newline > start + maxLength ~/ 2 ? newline : space;
      if (boundary > start + maxLength ~/ 2) end = boundary + 1;
      // Never split a UTF-16 surrogate pair.
      final unit = text.codeUnitAt(end - 1);
      if (unit >= 0xD800 && unit <= 0xDBFF) end--;
    }
    sections.add(text.substring(start, end));
    start = end;
  }
  return sections;
}

class DocumentTextList extends StatefulWidget {
  const DocumentTextList({super.key, required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<DocumentTextList> createState() => _DocumentTextListState();
}

class _DocumentTextListState extends State<DocumentTextList> {
  late List<String> _sections = documentTextSections(widget.text);

  @override
  void didUpdateWidget(DocumentTextList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _sections = documentTextSections(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: ListView.builder(
      key: const PageStorageKey('document-extracted-text'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      itemCount: _sections.length,
      itemBuilder:
          (context, index) => Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(_sections[index], style: widget.style),
          ),
    ),
  );
}
