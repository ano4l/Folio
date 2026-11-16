import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/document.dart';
import '../models/study.dart';
import '../services/app_state.dart';
import '../services/study_export.dart';
import '../services/sample_course.dart';
import '../theme/app_theme.dart';
import 'ask_ai_screen.dart';
import 'document_reader_screen.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});
  Future<void> _create(BuildContext context) async {
    final name = await _nameDialog(context, 'New study space');
    if (name == null || !context.mounted) return;
    final space = context.read<AppState>().createStudySpace(name);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StudySpaceScreen(spaceId: space.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, List<Object?>>(
      (s) => [...s.studySpaces, ...s.studyNotes, ...s.studyCards],
    );
    final state = context.read<AppState>();
    final due = state.studyCards.where((c) => c.due(DateTime.now())).length;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Study')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New study space'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
        children: [
          Text(
            'Make your material stick.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            due > 0
                ? '$due revision cards ready to review. Pick a course to get started.'
                : 'Learn, practise and keep what matters. All connected to your course material.',
          ),
          const SizedBox(height: 24),
          if (state.studySpaces.isEmpty)
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_stories_outlined,
                    color: AppColors.teal,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lecture notes → explanations → quizzes → revision',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _create(context),
                    child: const Text('Create your first space'),
                  ),
                ],
              ),
            ),
          for (final space in state.studySpaces)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Surface(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.menu_book_outlined,
                    color: AppColors.teal,
                  ),
                  title: Text(space.name),
                  subtitle: Text(
                    '${space.documentIds.length} sources · ${state.notesForSpace(space.id).length} notes · ${state.cardsForSpace(space.id).where((c) => c.due(DateTime.now())).length} cards due',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => StudySpaceScreen(spaceId: space.id),
                        ),
                      ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const _PrivacyFootnote(),
        ],
      ),
    );
  }
}

class StudySpaceScreen extends StatefulWidget {
  const StudySpaceScreen({super.key, required this.spaceId});
  final String spaceId;
  @override
  State<StudySpaceScreen> createState() => _StudySpaceScreenState();
}

class _StudySpaceScreenState extends State<StudySpaceScreen> {
  bool _uploading = false;
  String _stage = '', _query = '';
  int _section = 0;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _existing(AppState state, StudySpace space) async {
    final selected = {...space.documentIds};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (sheet) => StatefulBuilder(
            builder:
                (context, update) => SizedBox(
                  height: MediaQuery.sizeOf(context).height * .65,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Course sources',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'Ready documents can be used for quizzes and explanations.',
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child:
                              state.documents.isEmpty
                                  ? const Center(
                                    child: Text(
                                      'Your vault is empty. Upload course material first.',
                                    ),
                                  )
                                  : ListView(
                                    children: [
                                      for (final doc in state.documents)
                                        CheckboxListTile(
                                          value: selected.contains(doc.id),
                                          title: Text(doc.title),
                                          subtitle: Text(doc.status),
                                          onChanged:
                                              (value) => update(() {
                                                if (value == true) {
                                                  selected.add(doc.id);
                                                } else {
                                                  selected.remove(doc.id);
                                                }
                                              }),
                                        ),
                                    ],
                                  ),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(sheet, selected),
                          child: Text('Save ${selected.length} sources'),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    if (result != null && mounted) state.setStudyDocuments(space.id, result);
  }

  Future<void> _upload(AppState state) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'docx', 'png', 'jpg', 'jpeg'],
      );
    } on PlatformException {
      if (mounted) _message('The file picker could not open. Try again.');
      return;
    }
    if (!mounted || result == null || result.files.single.path == null) return;
    final file = result.files.single;
    state.startDocumentUpload(
      file.path!,
      file.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      category: 'Study Material',
      studySpaceId: widget.spaceId,
    );
    _message(
      'Source uploading. Keep Folio open; your summary will appear automatically. Track progress in Documents.',
    );
  }

  Future<void> _sample(AppState state) async {
    setState(() {
      _uploading = true;
      _stage = 'Preparing sample course material…';
    });
    try {
      final path = await StudyExport.pdf(SampleCourse.title, SampleCourse.text);
      if (!mounted) return;
      state.startDocumentUpload(
        path,
        SampleCourse.title,
        category: 'Study Material',
        studySpaceId: widget.spaceId,
      );
      _message(
        'Sample source uploading. You can keep using Folio while we prepare it.',
      );
    } catch (error) {
      _message('The sample material could not be prepared. Try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _note(
    AppState state,
    List<Document> docs, {
    StudyNote? note,
  }) async {
    if (note == null && docs.isEmpty) {
      _message('Add a source before creating a note.');
      return;
    }
    final title = TextEditingController(text: note?.title ?? '');
    final body = TextEditingController(text: note?.body ?? '');
    var sourceId = note?.documentId ?? docs.first.id;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => StatefulBuilder(
            builder:
                (context, update) => AlertDialog(
                  title: Text(
                    note == null ? 'New study note' : 'Edit study note',
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: title,
                          maxLength: 80,
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),
                        TextField(
                          controller: body,
                          minLines: 4,
                          maxLines: 8,
                          maxLength: 6000,
                          decoration: InputDecoration(
                            labelText: 'What matters',
                            errorText: error,
                          ),
                        ),
                        if (note == null)
                          DropdownButtonFormField<String>(
                            initialValue: sourceId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Source',
                            ),
                            items:
                                docs
                                    .map(
                                      (d) => DropdownMenuItem(
                                        value: d.id,
                                        child: Text(
                                          d.title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (id) {
                              if (id != null) sourceId = id;
                            },
                          ),
                        if (note != null)
                          Text(
                            'Source: ${note.documentTitle}${note.sourcePage == null ? '' : ' · page ${note.sourcePage}'}',
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (body.text.trim().isEmpty) {
                          update(() => error = 'Enter a note before saving.');
                        } else {
                          Navigator.pop(dialog, true);
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
    if (saved == true && mounted) {
      try {
        if (note == null) {
          state.saveStudyNote(
            spaceId: widget.spaceId,
            title: title.text,
            body: body.text,
            documentId: sourceId,
          );
        } else {
          state.updateStudyNote(note.id, title.text, body.text);
        }
      } on FormatException catch (e) {
        _message(e.message);
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      title.dispose();
      body.dispose();
    });
  }

  Future<void> _export(AppState state, StudySpace space, bool pdf) async {
    final content = StudyExport.markdown(
      space,
      state.notesForSpace(space.id),
      state.cardsForSpace(space.id),
    );
    try {
      final path =
          pdf
              ? await StudyExport.pdf(space.name, content)
              : await StudyExport.textFile(content, 'md');
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox;
      await Share.shareXFiles(
        [XFile(path, mimeType: pdf ? 'application/pdf' : 'text/markdown')],
        subject: space.name,
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      _message('Export could not finish. Try again.');
    }
  }

  Future<void> _plan(
    AppState state,
    StudySpace space,
    List<Document> docs,
  ) async {
    if (docs.isEmpty) {
      _message('Add course material before planning revision.');
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = await showDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 14)),
      firstDate: today.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 3),
    );
    if (!mounted || exam == null) return;
    final days =
        DateTime.utc(
          exam.year,
          exam.month,
          exam.day,
        ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    final offsets =
        <int>{
            (days * .25).floor(),
            (days * .5).floor(),
            (days * .8).floor(),
          }.toList()
          ..sort();
    final proposed = <(String, DateTime)>[
      for (var i = 0; i < offsets.length; i++)
        (
          '${['Read & make notes', 'Practise questions', 'Review weak concepts'][i]} · ${space.name}',
          DateTime(today.year, today.month, today.day + offsets[i]),
        ),
      ('Exam · ${space.name}', exam),
    ];
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: const Text('Your revision plan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in proposed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${item.$2.day}/${item.$2.month}/${item.$2.year} · ${item.$1}',
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Add to Deadlines'),
              ),
            ],
          ),
    );
    if (accepted == true && mounted) {
      for (final item in proposed) {
        if (!state.deadlines.any(
          (d) => d.action == item.$1 && d.dueDate == item.$2,
        )) {
          state.addDeadline(doc: docs.first, action: item.$1, due: item.$2);
        }
      }
      _message(
        'Revision plan saved in Deadlines. Export it there to your calendar.',
      );
    }
  }

  void _openSource(AppState state, String id, {int? page}) {
    final doc = state.documents.where((d) => d.id == id).firstOrNull;
    if (doc == null) {
      _message('This source is unavailable. Check your recycle bin.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder:
            (_) => DocumentReaderScreen(
              document: doc,
              initialPage: page,
              studySpaceId: widget.spaceId,
            ),
      ),
    );
  }

  Future<void> _manage(AppState state, StudySpace space, String action) async {
    if (action == 'rename') {
      final name = await _nameDialog(
        context,
        'Rename study space',
        initial: space.name,
      );
      if (name != null && mounted) state.renameStudySpace(space.id, name);
    } else if (action == 'delete') {
      final yes = await showDialog<bool>(
        context: context,
        builder:
            (dialog) => AlertDialog(
              title: const Text('Delete this study space?'),
              content: const Text(
                'Its saved notes and revision cards will be removed. Source documents stay in your vault.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );
      if (yes == true && mounted) {
        state.deleteStudySpace(space.id);
        Navigator.pop(context);
      }
    } else {
      await _export(state, space, action == 'pdf');
    }
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, List<Object?>>((s) {
      final progress = s.studyProgress(widget.spaceId);
      return [
        ...s.studySpaces,
        ...s.studyNotes,
        ...s.studyCards,
        ...s.documents,
        progress.answered,
        progress.correct,
        progress.rounds,
      ];
    });
    final state = context.read<AppState>();
    final space =
        state.studySpaces.where((s) => s.id == widget.spaceId).firstOrNull;
    if (space == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This study space is unavailable.')),
      );
    }
    final docs =
        state.documents.where((d) => space.documentIds.contains(d.id)).toList();
    final notes =
        state
            .notesForSpace(space.id)
            .where(
              (n) => '${n.title} ${n.body} ${n.documentTitle}'
                  .toLowerCase()
                  .contains(_query),
            )
            .toList();
    final cards = state.cardsForSpace(space.id);
    final due = cards.where((c) => c.due(DateTime.now())).toList();
    final progress = state.studyProgress(space.id);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(space.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Study space actions',
            onSelected: (action) => _manage(state, space, action),
            itemBuilder:
                (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Text('Export notes & cards as PDF'),
                  ),
                  PopupMenuItem(
                    value: 'markdown',
                    child: Text('Export as Markdown'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete study space'),
                  ),
                ],
          ),
        ],
      ),
      floatingActionButton:
          _section == 1
              ? FloatingActionButton.extended(
                onPressed: () => _note(state, docs),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('New note'),
              )
              : null,
      body: RefreshIndicator(
        onRefresh: state.refreshDocuments,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
          children: [
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR LEARNING SO FAR',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.teal,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      Text('${progress.rounds} quiz rounds'),
                      Text('${progress.answered} answered'),
                      Text(
                        progress.answered == 0
                            ? 'Accuracy —'
                            : '${(progress.accuracy * 100).round()}% accuracy',
                      ),
                      Text('${due.length} cards due'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress.accuracy,
                    backgroundColor: AppColors.teal.withValues(alpha: .08),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Accuracy reflects answers in saved chats, including repeated practice.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Sources')),
                ButtonSegment(value: 1, label: Text('Notes')),
                ButtonSegment(value: 2, label: Text('Revision')),
              ],
              selected: {_section},
              onSelectionChanged: (v) => setState(() => _section = v.single),
            ),
            const SizedBox(height: 20),
            if (_section == 0) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Course material',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _existing(state, space),
                    child: const Text('From vault'),
                  ),
                ],
              ),
              if (space.documentIds.any((id) => !docs.any((d) => d.id == id)))
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Some linked sources are unavailable. Restore them from the recycle bin or update your course sources.',
                  ),
                ),
              if (state.documentsError.isNotEmpty)
                Text(
                  state.documentsError,
                  style: const TextStyle(color: AppColors.danger),
                ),
              if (_uploading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(_stage),
              ],
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Add lecture slides, readings or past papers to start learning.',
                  ),
                ),
              if (docs.isEmpty)
                TextButton.icon(
                  onPressed: _uploading ? null : () => _sample(state),
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Try sample lecture material'),
                ),
              for (final doc in docs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${doc.pages} pages · ${doc.status}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          doc.summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed:
                                  doc.status == 'Ready'
                                      ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder:
                                              (_) => DocumentChatPage(
                                                document: doc,
                                                studySpaceId: space.id,
                                                studyMode: true,
                                              ),
                                        ),
                                      )
                                      : null,
                              icon: const Icon(
                                Icons.auto_awesome_outlined,
                                size: 18,
                              ),
                              label: const Text('Study'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _openSource(state, doc.id),
                              icon: const Icon(
                                Icons.menu_book_outlined,
                                size: 18,
                              ),
                              label: const Text('Read'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _uploading ? null : () => _upload(state),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload course material'),
              ),
              TextButton.icon(
                onPressed: () => _plan(state, space, docs),
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('Plan revision for an exam'),
              ),
            ],
            if (_section == 1) ...[
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Find notes or concepts',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged:
                    (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 16),
              if (notes.isEmpty)
                _Surface(
                  child: Text(
                    _query.isEmpty
                        ? 'Save explanations from Study chat, capture passages in the reader, or write your own linked notes.'
                        : 'No notes match this search.',
                  ),
                ),
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                note.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Note actions',
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _note(state, docs, note: note);
                                }
                                if (action == 'card') {
                                  try {
                                    state.addStudyCard(
                                      spaceId: space.id,
                                      front: note.title,
                                      back: note.body,
                                      documentId: note.documentId,
                                      sourcePage: note.sourcePage,
                                    );
                                    _message('Added to revision cards.');
                                  } on FormatException catch (e) {
                                    _message(e.message);
                                  }
                                }
                                if (action == 'delete') {
                                  final owner = state.user?.id;
                                  state.deleteStudyNote(note.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Note removed.'),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: () {
                                          if (state.user?.id == owner) {
                                            state.restoreStudyNote(note);
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                              itemBuilder:
                                  (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit note'),
                                    ),
                                    PopupMenuItem(
                                      value: 'card',
                                      child: Text('Make revision card'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                            ),
                          ],
                        ),
                        SelectableText(note.body),
                        TextButton.icon(
                          onPressed:
                              () => _openSource(
                                state,
                                note.documentId,
                                page: note.sourcePage,
                              ),
                          icon: const Icon(Icons.menu_book_outlined, size: 16),
                          label: Text(
                            '${note.documentTitle}${note.sourcePage == null ? '' : ' · p${note.sourcePage}'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            if (_section == 2) ...[
              Text(
                'Recall first. Reveal second.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Make cards from saved notes or quiz questions. “Got it” schedules tomorrow, then doubles the interval up to 30 days. “Again” brings it back in 10 minutes.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    due.isEmpty
                        ? null
                        : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder:
                                (_) => StudyReviewScreen(spaceId: space.id),
                          ),
                        ),
                icon: const Icon(Icons.flip_outlined),
                label: Text('Review ${due.length} due cards'),
              ),
              if (cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'Your revision deck is empty. Save a quiz question as a card or use a note’s menu.',
                  ),
                ),
              for (final card in cards)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    card.front,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${card.reviews} reviews · ${card.due(DateTime.now()) ? 'Due now' : 'Next: ${DateTime.tryParse(card.dueAt)?.toLocal().toString().split(' ').first ?? 'scheduled'}'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete card',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder:
                            (dialog) => AlertDialog(
                              title: const Text('Delete revision card?'),
                              content: Text(card.front),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                      );
                      if (yes == true && mounted) {
                        state.deleteStudyCard(card.id);
                      }
                    },
                  ),
                ),
            ],
            const SizedBox(height: 24),
            const _PrivacyFootnote(),
          ],
        ),
      ),
    );
  }
}

class StudyReviewScreen extends StatefulWidget {
  const StudyReviewScreen({super.key, required this.spaceId});
  final String spaceId;
  @override
  State<StudyReviewScreen> createState() => _StudyReviewScreenState();
}

class _StudyReviewScreenState extends State<StudyReviewScreen> {
  List<String>? _ids;
  int _index = 0, _recalled = 0;
  bool _revealed = false;
  @override
  Widget build(BuildContext context) {
    context.select<AppState, List<Object?>>(
      (s) => [...s.studyCards.where((c) => c.spaceId == widget.spaceId)],
    );
    final state = context.read<AppState>();
    _ids ??=
        state
            .cardsForSpace(widget.spaceId)
            .where((c) => c.due(DateTime.now()))
            .map((c) => c.id)
            .toList();
    final card =
        _index < _ids!.length
            ? state.studyCards.where((c) => c.id == _ids![_index]).firstOrNull
            : null;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Revision session')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (card == null) ...[
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.teal,
                size: 56,
              ),
              const SizedBox(height: 24),
              Text(
                'Session complete.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '$_recalled of $_index cards recalled. Your next review times are saved.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to course'),
              ),
            ] else ...[
              Text(
                'CARD ${_index + 1} OF ${_ids!.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _index / _ids!.length),
              const SizedBox(height: 24),
              _Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.front,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    if (_revealed) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      SelectableText(card.back),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          final doc =
                              state.documents
                                  .where((d) => d.id == card.documentId)
                                  .firstOrNull;
                          if (doc != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => DocumentReaderScreen(
                                      document: doc,
                                      initialPage: card.sourcePage,
                                      studySpaceId: widget.spaceId,
                                    ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.menu_book_outlined),
                        label: Text('Check ${card.documentTitle}'),
                      ),
                      if (card.sourceExcerpt.isNotEmpty)
                        Text(
                          '“${card.sourceExcerpt}”',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ] else
                      const Text(
                        'Try explaining the answer out loud before revealing it.',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!_revealed)
                FilledButton(
                  onPressed: () => setState(() => _revealed = true),
                  child: const Text('Reveal answer'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rate(state, card, false),
                        child: const Text('Again · 10 min'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _rate(state, card, true),
                        child: const Text('Got it'),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _rate(AppState state, StudyCard card, bool recalled) {
    state.reviewStudyCard(card.id, recalled);
    setState(() {
      _index++;
      if (recalled) _recalled++;
      _revealed = false;
    });
  }
}

Future<String?> _nameDialog(
  BuildContext context,
  String title, {
  String initial = '',
}) async {
  final input = TextEditingController(text: initial);
  String? error;
  final name = await showDialog<String>(
    context: context,
    builder:
        (dialog) => StatefulBuilder(
          builder:
              (context, update) => AlertDialog(
                title: Text(title),
                content: TextField(
                  controller: input,
                  autofocus: true,
                  maxLength: 64,
                  decoration: InputDecoration(
                    labelText: 'Course name',
                    hintText: 'e.g. Software Engineering',
                    errorText: error,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (input.text.trim().isEmpty) {
                        update(() => error = 'Enter a course name.');
                      } else {
                        Navigator.pop(dialog, input.text.trim());
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
        ),
  );
  Future<void>.delayed(const Duration(milliseconds: 400), input.dispose);
  return name;
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.teal.withValues(alpha: .1)),
    ),
    child: child,
  );
}

class _PrivacyFootnote extends StatelessWidget {
  const _PrivacyFootnote();
  @override
  Widget build(BuildContext context) => const Text(
    'Study spaces, notes, cards and progress are saved securely on this device for your account. Export a copy to keep it elsewhere. AI questions use readable text from the selected source; check the original when details matter.',
    style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.slate),
  );
}
