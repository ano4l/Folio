import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/share_text.dart';
import '../models/document.dart';
import '../models/document_categories.dart';
import '../widgets/document_upload_activity.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../services/document_scanner.dart';
import '../theme/app_theme.dart';
import '../widgets/doc_type_badge.dart';
import '../widgets/glass_container.dart';
import '../widgets/ai_content.dart';
import '../widgets/document_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ask_ai_screen.dart';
import 'document_tools_sheet.dart';
import 'study_screen.dart';
import 'document_reader_screen.dart';
import 'document_metadata_editor.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _needsReview = false;
  bool _favoritesOnly = false;
  String _sort = 'recent';
  String? _category;
  Timer? _searchDebounce;
  final _searchText = Expando<String>('document search text');

  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, List<Object?>>(
      (s) =>
          s.navigationIndex == 1
              ? [
                s.navigationIndex,
                s.documentsLoading,
                s.documentsError,
                ...s.documents,
                ...s.deletedDocs,
                ...s.favoriteDocumentIds,
              ]
              : const <Object?>[],
    );
    final state = context.read<AppState>();
    // The selected document opens as its own page from MainShell.
    final query = _query.trim().toLowerCase();
    final visible =
        state.documents
            .where(
              (d) =>
                  (!_needsReview || d.status != 'Ready') &&
                  (!_favoritesOnly ||
                      state.favoriteDocumentIds.contains(d.id)) &&
                  (_category == null || _category == d.type) &&
                  (query.isEmpty ||
                      (_searchText[d] ??=
                              '${d.title} ${d.type} ${d.summary} ${d.rawText}'
                                  .toLowerCase())
                          .contains(query)),
            )
            .toList();

    if (_sort == 'title') {
      visible.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    }
    if (_sort == 'pages') visible.sort((a, b) => b.pages.compareTo(a.pages));

    final headers = <Widget>[
      Text(
        'Your paperwork, in order.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Text(
        '${state.documents.length} documents · encrypted at rest',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StudyScreen()),
            ),
        icon: const Icon(Icons.auto_stories_outlined),
        label: const Align(
          alignment: Alignment.centerLeft,
          child: Text('Study from course material'),
        ),
      ),
      const SizedBox(height: 16),
      if (!kIsWeb &&
          (Theme.of(context).platform == TargetPlatform.iOS ||
              Theme.of(context).platform == TargetPlatform.android)) ...[
        _DocumentToolsEntry(
          onTap:
              () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: AppColors.paper,
                showDragHandle: true,
                builder:
                    (_) => DocumentToolsSheet(
                      onScan: () => _showUploadModal(context),
                    ),
              ),
        ),
        const SizedBox(height: 20),
      ],
      TextField(
        controller: _search,
        onChanged: _searchChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Find a document…',
          suffixIcon:
              _query.isEmpty
                  ? null
                  : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      _searchDebounce?.cancel();
                      setState(() => _query = '');
                    },
                  ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilterChip(
          label: const Text('Needs attention'),
          selected: _needsReview,
          onSelected: (value) => setState(() => _needsReview = value),
        ),
      ),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('Favourites'),
            selected: _favoritesOnly,
            onSelected: (value) => setState(() => _favoritesOnly = value),
          ),
          DropdownButton<String>(
            value: _sort,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'recent', child: Text('Recent first')),
              DropdownMenuItem(value: 'title', child: Text('A–Z')),
              DropdownMenuItem(value: 'pages', child: Text('Most pages')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _sort = value);
            },
          ),
        ],
      ),
      if (state.documents.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All categories'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
              ),
              for (final type
                  in (state.documents.map((d) => d.type).toSet().toList()
                    ..sort()))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: _category == type,
                    onSelected:
                        (selected) =>
                            setState(() => _category = selected ? type : null),
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      const DocumentUploadActivity(),
      if (state.documentsLoading) const LinearProgressIndicator(),
      if (state.documentsError.isNotEmpty)
        ListTile(
          title: Text(state.documentsError),
          trailing: TextButton(
            onPressed: state.refreshDocuments,
            child: const Text('Retry'),
          ),
        ),
      if (!state.documentsLoading && state.documents.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'Upload a PDF, Word document, or a clear photo to get started.',
          ),
        ),
      if (visible.isEmpty && state.documents.isNotEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('No matching documents. Try another search.'),
        ),
    ];
    final footer = <Widget>[
      if (state.deletedDocs.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          'Recently removed on this device',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        GlassContainer(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ...state.deletedDocs.map(
                (d) => ListTile(
                  leading: const Icon(
                    CupertinoIcons.trash,
                    color: AppColors.slate,
                    size: 20,
                  ),
                  title: Text(
                    d.title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      try {
                        await state.restoreDoc(d);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error is ApiException
                                    ? error.message
                                    : 'The document could not be restored. Try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_counterclockwise,
                          size: 14,
                          color: AppColors.teal,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Restore',
                          style: TextStyle(fontSize: 13, color: AppColors.teal),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ];

    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: 8,
        ), // elevated above glass bottom dock
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.teal,
          elevation: 4,
          icon: const Icon(
            CupertinoIcons.cloud_upload_fill,
            color: Colors.white,
            size: 20,
          ),
          label: const Text(
            'Upload',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          onPressed: () => _showUploadModal(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: state.refreshDocuments,
        child: ListView.builder(
          key: const PageStorageKey('document-vault-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: headers.length + visible.length + footer.length,
          itemBuilder: (context, index) {
            if (index < headers.length) return headers[index];
            final row = index - headers.length;
            if (row >= visible.length) return footer[row - visible.length];
            final d = visible[row];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassContainer(
                padding: EdgeInsets.zero,
                onTap: () => state.selectDoc(d),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          CupertinoIcons.doc_text,
                          color: AppColors.teal,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AiContent.plainText(d.summary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                DocTypeBadge(type: d.type),
                                Text(
                                  d.status,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip:
                            state.favoriteDocumentIds.contains(d.id)
                                ? 'Remove favourite'
                                : 'Favourite document',
                        onPressed: () => state.toggleFavoriteDocument(d.id),
                        icon: Icon(
                          state.favoriteDocumentIds.contains(d.id)
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showUploadModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UploadSheet(),
    );
  }
}

class _DocumentToolsEntry extends StatelessWidget {
  final VoidCallback onTap;
  const _DocumentToolsEntry({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open document tools',
    child: GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(CupertinoIcons.doc_on_doc, color: AppColors.teal),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document tools',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  'Scan, combine, extract or convert',
                  style: TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: AppColors.slate,
          ),
        ],
      ),
    ),
  );
}

class _UploadSheet extends StatefulWidget {
  const _UploadSheet();
  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  String? _fileName;
  String? _filePath;
  final _titleCtrl = TextEditingController();
  String _type = 'Document';
  bool _scanning = false;

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final path = await DocumentScanner.scan();
      if (!mounted || path == null) return;
      setState(() {
        _filePath = path;
        _fileName = 'Scanned document.pdf';
        if (_titleCtrl.text.isEmpty) _titleCtrl.text = 'Scanned document';
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is PlatformException && error.message != null
                  ? error.message!
                  : 'Scanner unavailable. You can still choose a file or photo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx'],
      );
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The file picker could not open. Try again.'),
          ),
        );
      }
      return;
    }
    final picked = result?.files.single;
    if (mounted && picked != null && picked.path != null) {
      setState(() {
        _fileName = picked.name;
        _filePath = picked.path;
        if (_titleCtrl.text.isEmpty) {
          _titleCtrl.text = _fileName!.replaceAll(RegExp(r'\.[^.]+$'), '');
        }
      });
    }
  }

  void _submit() {
    if (_filePath == null || _titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a file and enter a title.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    context.read<AppState>().startDocumentUpload(
      _filePath!,
      _titleCtrl.text.trim(),
      category: _type,
    );
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Upload started. Keep Folio open and use any page while we prepare your summary.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: SingleChildScrollView(
        child: GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Secure Paperwork Upload',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppColors.slate,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(
                  _scanning ? 'Opening scanner…' : 'Scan pages with camera',
                ),
              ),
              const Text(
                'Scan up to 20 pages and review the crop before saving. Scanner availability depends on your device. Text is read on your device; originals and extracted text are uploaded for AI summaries.',
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color:
                        _fileName != null
                            ? AppColors.tealLight
                            : AppColors.card.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          _fileName != null ? AppColors.teal : AppColors.line,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _fileName != null
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.cloud_upload,
                        color: AppColors.teal,
                        size: 38,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fileName ?? 'Tap to choose PDF or Image file',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Document title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Category'),
                items:
                    documentCategories
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _scanning ? null : _submit,
                child: const Text('Upload & summarise'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DocumentDetailView extends StatefulWidget {
  final Document doc;
  const DocumentDetailView({super.key, required this.doc});

  @override
  State<DocumentDetailView> createState() => _DocumentDetailViewState();
}

class _DocumentDetailViewState extends State<DocumentDetailView> {
  int _tabIndex = 0;
  bool _deleting = false;

  Future<void> _delete() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final doc = widget.doc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Move to recycle bin?'),
            content: Text(
              'You can restore ${doc.title} from this device’s recently removed list.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep document'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Move to bin'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await state.softDeleteDoc(doc);
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Moved to recycle bin.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await state.restoreDoc(doc);
                } catch (_) {
                  if (messenger.mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Restore failed. Try again from the recycle bin.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _deleting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'The document could not be deleted. Try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _addTask() async {
    final state = context.read<AppState>();
    final action = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add a document task'),
            content: TextField(
              controller: action,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'What do you need to do?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (action.text.trim().isNotEmpty) {
                    Navigator.pop(context, action.text.trim());
                  }
                },
                child: const Text('Choose date'),
              ),
            ],
          ),
    );
    // Dispose after the closing dialog animation releases its text field.
    Future<void>.delayed(const Duration(milliseconds: 400), action.dispose);
    if (name == null || !mounted) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (date == null || !mounted) return;
    state.addDeadline(doc: widget.doc, action: name, due: date);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task saved on this device. Find it in Deadlines.'),
      ),
    );
  }

  void _openDocumentChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentChatPage(document: widget.doc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final doc = widget.doc;
    final processing = context.select<AppState, bool>(
      (s) =>
          s.documentUploads.any((u) => u.documentId == doc.id && u.isRunning),
    );

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          doc.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Document actions',
            enabled: !_deleting,
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit title & category'),
                  ),
                  PopupMenuItem(
                    value: 'original',
                    child: Text('Open original file'),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Text('Share extracted text'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Move to recycle bin',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
            onSelected: (action) async {
              if (action == 'edit') {
                await showDocumentMetadataEditor(context, doc);
                return;
              }
              if (action == 'delete') {
                await _delete();
                return;
              }
              if (action == 'share') {
                await ShareText.show(
                  context,
                  doc.rawText.isNotEmpty ? doc.rawText : doc.summary,
                  subject: doc.title,
                );
                return;
              }
              try {
                final uri = await state.api.originalDocument(doc.id);
                if (!await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                )) {
                  throw const ApiException(
                    'No app on this device can open the original file.',
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error is ApiException
                            ? error.message
                            : 'The original file could not be opened right now.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openDocumentChat(context),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Ask this document'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => DocumentReaderScreen(document: doc),
                          ),
                        ),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Read & save passages'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add_task),
                    label: const Text('Add task'),
                  ),
                  if (doc.status != 'Ready')
                    OutlinedButton.icon(
                      onPressed:
                          processing
                              ? null
                              : () => state.startDocumentProcessing(
                                doc.id,
                                doc.title,
                              ),
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        processing
                            ? 'Summarising in background…'
                            : 'Retry processing',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _tabIndex,
                  children: const {
                    0: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Extracted Data',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    1: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Extracted text',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  },
                  onValueChanged: (v) {
                    if (v != null) setState(() => _tabIndex = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _tabIndex == 0
                      ?
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                DocTypeBadge(type: doc.type),
                                const SizedBox(width: 10),
                                Text(
                                  '${doc.date} · ${doc.pages} pages',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.slate,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GlassContainer(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.sparkles,
                                        size: 16,
                                        color: AppColors.teal,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'AI Grounded Summary',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  AiContent(text: doc.summary),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.tealLight,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          CupertinoIcons.lightbulb_fill,
                                          color: AppColors.teal,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Ask Folio about this document for a clearer explanation or action list.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.4,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Extracted Entities',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            GlassContainer(
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  ...doc.entities.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final e = entry.value;
                                    return Column(
                                      children: [
                                        ListTile(
                                          title: Text(
                                            e.label,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.slate,
                                            ),
                                          ),
                                          subtitle: Text(
                                            e.value,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                        if (idx < doc.entities.length - 1)
                                          const Divider(
                                            height: 1,
                                            indent: 16,
                                            endIndent: 16,
                                            color: AppColors.line,
                                          ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      : DocumentTextList(
                        text:
                            doc.rawText.isNotEmpty
                                ? doc.rawText
                                : 'No extracted text is available. Check the original document.',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.7,
                          color: AppColors.ink,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
