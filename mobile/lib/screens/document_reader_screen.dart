import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document.dart';
import '../services/app_state.dart';
import '../services/study_export.dart';
import '../theme/app_theme.dart';
import '../widgets/document_text.dart';
import 'ask_ai_screen.dart';

/// Reads extracted text, retaining only page numbers supplied by extraction.
class DocumentReaderScreen extends StatefulWidget {
  const DocumentReaderScreen({
    super.key,
    required this.document,
    this.initialPage,
    this.studySpaceId,
  });
  final Document document;
  final int? initialPage;
  final String? studySpaceId;
  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  int? _page;
  int? _selectionPage;
  String _query = '', _selection = '';
  double _fontSize = 16;
  final _search = TextEditingController();
  Timer? _searchDebounce;
  late final List<SourcePage> _pages =
      widget.document.sourcePages.isNotEmpty
          ? widget.document.sourcePages
          : [SourcePage(0, widget.document.rawText)];
  final Map<SourcePage, String> _searchText = {};
  String _normalized(SourcePage page) =>
      _searchText.putIfAbsent(page, () => page.text.toLowerCase());
  late final List<SourcePage> _displaySections = [
    for (final page in _pages)
      for (final text in documentTextSections(page.text))
        SourcePage(page.number, text),
  ];
  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _original() async {
    try {
      final uri = await context.read<AppState>().api.originalDocument(
        widget.document.id,
      );
      if (mounted &&
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _message('No viewer could open this file.');
      }
    } catch (_) {
      _message('Original file could not open. Check your connection.');
    }
  }

  Future<void> _export(bool pdf) async {
    try {
      final text = widget.document.rawText;
      final path =
          pdf
              ? await StudyExport.pdf(widget.document.title, text)
              : await StudyExport.textFile(text, 'txt');
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox;
      await Share.shareXFiles(
        [XFile(path, mimeType: pdf ? 'application/pdf' : 'text/plain')],
        subject: widget.document.title,
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      _message('Export could not finish.');
    }
  }

  Future<void> _saveSelection() async {
    final state = context.read<AppState>();
    final selection = _selection.trim();
    final page = _selectionPage;
    if (selection.isEmpty) {
      _message('Select a passage first.');
      return;
    }
    var spaceId = widget.studySpaceId;
    if (spaceId == null) {
      if (state.studySpaces.isEmpty) {
        _message('Create a study space first to keep linked notes.');
        return;
      }
      spaceId = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder:
            (sheet) => ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Save passage to a study space')),
                for (final space in state.studySpaces)
                  ListTile(
                    title: Text(space.name),
                    onTap: () => Navigator.pop(sheet, space.id),
                  ),
              ],
            ),
      );
    }
    if (!mounted || spaceId == null) return;
    try {
      state.saveStudyNote(
        spaceId: spaceId,
        title: '${widget.document.title}${page == null ? '' : ' · page $page'}',
        body: selection,
        documentId: widget.document.id,
        sourcePage: page,
      );
      _message('Passage saved with its source.');
    } on FormatException catch (e) {
      _message(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final hasPages = doc.sourcePages.isNotEmpty;
    final pages = _pages;
    if (_page != null && !pages.any((p) => p.number == _page)) _page = null;
    final visible =
        (_query.isEmpty ? _displaySections : pages)
            .where(
              (p) =>
                  (_page == null || p.number == _page) &&
                  (_query.isEmpty ||
                      _normalized(p).contains(_query.toLowerCase())),
            )
            .toList();
    final matches =
        _query.isEmpty
            ? 0
            : pages.fold<int>(
              0,
              (sum, p) =>
                  sum + _query.toLowerCase().allMatches(_normalized(p)).length,
            );
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Reader actions',
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'original',
                    child: Text('Open original file'),
                  ),
                  PopupMenuItem(
                    value: 'text',
                    child: Text('Export extracted text'),
                  ),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Text('Extracted text as PDF'),
                  ),
                ],
            onSelected: (action) {
              if (action == 'original') {
                _original();
              } else {
                _export(action == 'pdf');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Find in this document',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _query.isEmpty
                            ? null
                            : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchDebounce?.cancel();
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                  ),
                  onChanged: (value) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 180),
                      () {
                        if (!mounted) return;
                        setState(() {
                          _query = value;
                          _page = null;
                        });
                      },
                    );
                  },
                ),
                if (_query.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$matches ${matches == 1 ? 'match' : 'matches'} across the readable text',
                      ),
                    ),
                  ),
                Row(
                  children: [
                    if (hasPages)
                      Expanded(
                        child: DropdownButton<int?>(
                          isExpanded: true,
                          value: _page,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All pages'),
                            ),
                            for (final p in pages)
                              DropdownMenuItem<int?>(
                                value: p.number,
                                child: Text('Page ${p.number}'),
                              ),
                          ],
                          onChanged: (value) => setState(() => _page = value),
                        ),
                      )
                    else
                      const Expanded(
                        child: Text(
                          'Extracted text · page unknown',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Smaller text',
                      onPressed:
                          _fontSize <= 14
                              ? null
                              : () => setState(() => _fontSize -= 2),
                      icon: const Icon(Icons.text_decrease),
                    ),
                    IconButton(
                      tooltip: 'Larger text',
                      onPressed:
                          _fontSize >= 24
                              ? null
                              : () => setState(() => _fontSize += 2),
                      icon: const Icon(Icons.text_increase),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                visible.isEmpty || doc.rawText.isEmpty
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No readable text matches. Try a different search or open the original file.',
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final page = visible[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasPages) ...[
                                Text(
                                  'PAGE ${page.number}',
                                  style: const TextStyle(
                                    color: AppColors.teal,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              SelectionArea(
                                onSelectionChanged: (content) {
                                  if (content?.plainText.trim().isNotEmpty !=
                                      true) {
                                    return;
                                  }
                                  _selection = content!.plainText;
                                  _selectionPage =
                                      hasPages ? page.number : null;
                                },
                                child: Text.rich(
                                  _highlight(page.text),
                                  style: TextStyle(
                                    fontSize: _fontSize,
                                    height: 1.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saveSelection,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Save selected passage'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        doc.status != 'Ready'
                            ? null
                            : () {
                              final selection = _selection.trim();
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => DocumentChatPage(
                                        document: doc,
                                        studyMode: widget.studySpaceId != null,
                                        studySpaceId: widget.studySpaceId,
                                      ),
                                ),
                              );
                              if (selection.isNotEmpty) {
                                context.read<AppState>().setDraft(
                                  doc.id,
                                  'Explain this passage: ${selection.length > 1700 ? selection.substring(0, 1700) : selection}',
                                );
                              }
                            },
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Ask about this'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _highlight(String text) {
    if (_query.isEmpty) return TextSpan(text: text);
    final lower = text.toLowerCase();
    final query = _query.toLowerCase();
    var start = 0;
    final spans = <TextSpan>[];
    while (true) {
      final index = lower.indexOf(query, start);
      if (index < 0) break;
      spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(backgroundColor: Color(0xFFFFE9AB)),
        ),
      );
      start = index + query.length;
    }
    spans.add(TextSpan(text: text.substring(start)));
    return TextSpan(children: spans);
  }
}
