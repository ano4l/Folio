import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_state.dart';
import '../services/document_scanner.dart';
import '../services/study_export.dart';
import '../theme/app_theme.dart';

enum _Tool { merge, images, pages, rotate, word }

class DocumentToolsSheet extends StatefulWidget {
  final VoidCallback onScan;
  const DocumentToolsSheet({super.key, required this.onScan});

  @override
  State<DocumentToolsSheet> createState() => _DocumentToolsSheetState();
}

class _DocumentToolsSheetState extends State<DocumentToolsSheet> {
  final _title = TextEditingController();
  String? _resultPath;
  String _resultLabel = '';
  String _stage = '';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _run(_Tool tool) async {
    final extensions = switch (tool) {
      _Tool.merge || _Tool.pages || _Tool.rotate => ['pdf'],
      _Tool.images => ['jpg', 'jpeg', 'png'],
      _Tool.word => ['docx'],
    };
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: tool == _Tool.merge || tool == _Tool.images,
      );
      if (!mounted || selection == null) return;
      var paths =
          selection.files.map((file) => file.path).whereType<String>().toList();
      if (paths.length != selection.files.length || paths.isEmpty) {
        _message(
          'One of the selected files is unavailable. Choose local copies.',
        );
        return;
      }
      if (tool == _Tool.merge && paths.length < 2) {
        _message('Choose at least two PDFs to combine.');
        return;
      }
      if (paths.length > 20) {
        _message('Choose no more than 20 files at a time.');
        return;
      }
      if (tool == _Tool.merge || tool == _Tool.images) {
        final ordered = await _orderFiles(paths);
        if (ordered == null || !mounted) return;
        paths = ordered;
      }
      String? pages;
      if (tool == _Tool.pages) {
        pages = await _askPages();
        if (pages == null || !mounted) return;
      }
      int degrees = 90;
      if (tool == _Tool.rotate) {
        final rotation = await showDialog<int>(
          context: context,
          builder:
              (dialog) => SimpleDialog(
                title: const Text('Rotate all pages'),
                children: [
                  for (final value in [90, 180, 270])
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialog, value),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('$value° clockwise'),
                      ),
                    ),
                ],
              ),
        );
        if (rotation == null || !mounted) return;
        degrees = rotation;
      }
      setState(() {
        _busy = true;
        _stage = 'Preparing PDF on your device…';
      });
      final output = switch (tool) {
        _Tool.merge => await DocumentScanner.mergePdfs(paths),
        _Tool.images => await DocumentScanner.imagesToPdf(paths),
        _Tool.pages => await DocumentScanner.extractPages(paths.single, pages!),
        _Tool.rotate => await DocumentScanner.rotatePdf(paths.single, degrees),
        _Tool.word => await DocumentScanner.wordToPdf(paths.single),
      };
      if (!mounted) return;
      setState(() {
        _resultPath = output;
        _resultLabel = switch (tool) {
          _Tool.merge => 'Combined PDF',
          _Tool.images => 'Images as PDF',
          _Tool.pages => 'Selected pages',
          _Tool.rotate => 'Rotated PDF',
          _Tool.word => 'Word text as PDF',
        };
        _title.text = switch (tool) {
          _Tool.merge => 'Combined document',
          _Tool.images => 'Photo document',
          _Tool.pages => 'Selected pages',
          _Tool.rotate => 'Rotated document',
          _Tool.word => selection.files.single.name.replaceFirst(
            RegExp(r'\.docx$', caseSensitive: false),
            '',
          ),
        };
      });
      HapticFeedback.lightImpact();
    } catch (error) {
      if (mounted) {
        _message(
          error is PlatformException
              ? error.message ?? 'The document tool could not finish.'
              : error is FormatException
              ? error.message
              : 'The document tool could not finish. Please try another file.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>?> _orderFiles(List<String> paths) async {
    final ordered = [...paths];
    return showModalBottomSheet<List<String>>(
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
                          'Choose your page order',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Drag the handles to reorder files before creating your PDF.',
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: ordered.length,
                            onReorder:
                                (oldIndex, newIndex) => update(() {
                                  if (newIndex > oldIndex) newIndex--;
                                  final item = ordered.removeAt(oldIndex);
                                  ordered.insert(newIndex, item);
                                }),
                            itemBuilder:
                                (context, index) => ListTile(
                                  key: ValueKey(ordered[index]),
                                  leading: Text('${index + 1}'),
                                  title: Text(
                                    File(ordered[index]).uri.pathSegments.last,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.pop(sheet, ordered),
                          child: const Text('Create PDF in this order'),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Future<void> _textPdf() async {
    final text = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: const Text('Text to PDF'),
            content: TextField(
              controller: text,
              minLines: 5,
              maxLines: 10,
              maxLength: 20000,
              decoration: const InputDecoration(
                labelText: 'Paste or write your text',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (text.text.trim().isNotEmpty) {
                    Navigator.pop(dialog, text.text.trim());
                  }
                },
                child: const Text('Create PDF'),
              ),
            ],
          ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), text.dispose);
    if (body == null || !mounted) return;
    setState(() {
      _busy = true;
      _stage = 'Creating your PDF…';
    });
    try {
      final path = await StudyExport.pdf('Notes', body);
      if (mounted) {
        setState(() {
          _resultPath = path;
          _resultLabel = 'Text as PDF';
          _title.text = 'My notes';
        });
      }
    } catch (_) {
      if (mounted) _message('Could not create the PDF. Try a shorter text.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPages() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Select PDF pages'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Page numbers',
                hintText: '1-3,5',
                helperText: 'Keep the pages in the order entered.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Extract'),
              ),
            ],
          ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    return value;
  }

  Future<void> _saveToVault() async {
    final path = _resultPath;
    final title = _title.text.trim();
    if (path == null || title.isEmpty) {
      _message('Enter a title for your document.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    context.read<AppState>().startDocumentUpload(
      path,
      title,
      category: 'Document',
    );
    Navigator.pop(context);
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'PDF uploading. Keep Folio open and track its summary in Documents.',
          ),
        ),
      );
    }
  }

  Future<void> _share() async {
    final path = _resultPath;
    if (path == null || !await File(path).exists() || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
    try {
      await Share.shareXFiles([
        XFile(
          path,
          mimeType: 'application/pdf',
          name:
              '${_title.text.trim().isEmpty ? 'Folio document' : _title.text.trim()}.pdf',
        ),
      ], sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size);
    } catch (_) {
      if (mounted) _message('Sharing could not open. Please try again.');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _resultPath == null ? 'Document tools' : 'PDF is ready',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _resultPath == null
                      ? 'Prepare paperwork on your device, then save it for Folio to analyse.'
                      : '$_resultLabel · prepared on this device',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                if (_resultPath == null) ...[
                  if (_busy) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      _stage,
                      style: const TextStyle(color: AppColors.slate),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _ToolRow(
                    icon: CupertinoIcons.camera_viewfinder,
                    title: 'Scan pages',
                    detail: 'Camera scan, crop and text recognition',
                    onTap:
                        _busy
                            ? null
                            : () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => widget.onScan(),
                              );
                            },
                  ),
                  _ToolRow(
                    icon: CupertinoIcons.doc_on_doc,
                    title: 'Combine PDFs',
                    detail: 'Merge files in your chosen order',
                    onTap: _busy ? null : () => _run(_Tool.merge),
                  ),
                  _ToolRow(
                    icon: CupertinoIcons.photo_on_rectangle,
                    title: 'Images to PDF',
                    detail: 'Turn photos into one shareable PDF',
                    onTap: _busy ? null : () => _run(_Tool.images),
                  ),
                  _ToolRow(
                    icon: CupertinoIcons.doc_text,
                    title: 'Extract, reorder or remove pages',
                    detail: 'Enter any order; omitted pages are removed',
                    onTap: _busy ? null : () => _run(_Tool.pages),
                  ),
                  _ToolRow(
                    icon: Icons.rotate_90_degrees_cw,
                    title: 'Rotate PDF pages',
                    detail: 'Correct orientation in a new copy',
                    onTap: _busy ? null : () => _run(_Tool.rotate),
                  ),
                  _ToolRow(
                    icon: Icons.edit_note_outlined,
                    title: 'Text to PDF',
                    detail: 'Make a clean PDF from notes or pasted text',
                    onTap: _busy ? null : _textPdf,
                  ),
                  _ToolRow(
                    icon: CupertinoIcons.doc_richtext,
                    title: 'Word to PDF',
                    detail: 'Export readable DOCX text; review the new layout',
                    onTap: _busy ? null : () => _run(_Tool.word),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Files stay on this device until you choose Save to vault & analyse. Each finished PDF must be under 20 MB.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                ] else ...[
                  TextField(
                    controller: _title,
                    enabled: !_busy,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Document title',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_busy) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      _stage,
                      style: const TextStyle(color: AppColors.slate),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _saveToVault,
                    icon: const Icon(CupertinoIcons.cloud_upload),
                    label: const Text('Save to vault & analyse'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: const Icon(CupertinoIcons.share),
                    label: const Text('Share PDF'),
                  ),
                  TextButton(
                    onPressed:
                        _busy ? null : () => setState(() => _resultPath = null),
                    child: const Text('Use another tool'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ToolRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;
  const _ToolRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.teal, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: AppColors.slate,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
