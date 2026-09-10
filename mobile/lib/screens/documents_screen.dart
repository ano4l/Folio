import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/document.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/doc_type_badge.dart';
import '../widgets/glass_container.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final doc = state.selectedDoc;

    if (doc != null) return DocumentDetailView(doc: doc);

    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70), // elevated above glass bottom dock
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.teal,
          elevation: 4,
          icon: const Icon(CupertinoIcons.cloud_upload_fill, color: Colors.white, size: 20),
          label: const Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          onPressed: () => _showUploadModal(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text('Document Vault', style: Theme.of(context).textTheme.headlineMedium),
          Text(' documents · encrypted at rest',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ...state.documents.map((d) => Padding(
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
                          child: const Icon(CupertinoIcons.doc_text, color: AppColors.teal, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                              const SizedBox(height: 4),
                              Text(d.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.4)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  DocTypeBadge(type: d.type),
                                  const Spacer(),
                                  Text('% OCR', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
          if (state.deletedDocs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Recycle Bin', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            GlassContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ...state.deletedDocs.map((d) => ListTile(
                        leading: const Icon(CupertinoIcons.trash, color: AppColors.slate, size: 20),
                        title: Text(d.title, style: const TextStyle(fontSize: 13, color: AppColors.slate, decoration: TextDecoration.lineThrough)),
                        trailing: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => state.restoreDoc(d),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.arrow_counterclockwise, size: 14, color: AppColors.teal),
                              SizedBox(width: 4),
                              Text('Restore', style: TextStyle(fontSize: 13, color: AppColors.teal)),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showUploadModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UploadSheet(),
    );
  }
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
  String _type = 'Funding Award Letter';
  bool _uploading = false;

  static const _types = [
    'Funding Award Letter', 'Bursary Agreement', 'Fee Statement', 'Bank Letter', 'Appeal Correspondence',
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _fileName = result.files.single.name;
        _filePath = result.files.single.path;
        if (_titleCtrl.text.isEmpty) _titleCtrl.text = _fileName!.replaceAll(RegExp(r'\.[^.]+$'), '');
      });
    }
  }

  Future<void> _submit() async {
    if (_filePath == null || _titleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a file and enter a title.')));
      return;
    }
    setState(() => _uploading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final state = context.read<AppState>();
    state.addDocument(Document(
      id: DateTime.now().millisecondsSinceEpoch,
      title: _titleCtrl.text,
      type: _type,
      date: _today(),
      pages: 1,
      status: 'Ready',
      confidence: 92,
      summary: 'Newly uploaded document. OCR extraction completed.',
      entities: const [],
      rawText: 'Document uploaded: \nOCR extraction complete.',
    ));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Document processed successfully!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  String _today() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Secure Paperwork Upload', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.slate, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: _fileName != null ? AppColors.tealLight : AppColors.card.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _fileName != null ? AppColors.teal : AppColors.line, width: 1),
              ),
              child: Column(children: [
                Icon(_fileName != null ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.cloud_upload,
                    color: AppColors.teal, size: 38),
                const SizedBox(height: 8),
                Text(_fileName ?? 'Tap to choose PDF or Image file',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Document title'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))).toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _uploading ? null : _submit,
            child: _uploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Upload & process'),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final doc = widget.doc;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back, size: 22),
          onPressed: () => state.selectDoc(null),
        ),
        title: Text(doc.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.share, size: 20),
            onPressed: () => Share.share(doc.rawText.isNotEmpty ? doc.rawText : doc.summary, subject: doc.title),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.trash, color: AppColors.danger, size: 20),
            onPressed: () {
              state.softDeleteDoc(doc);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Moved to recycle bin.'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Cupertino Sliding Segmented Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _tabIndex,
                  children: const {
                    0: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Extracted Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    1: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('OCR Raw Text', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  },
                  onValueChanged: (v) {
                    if (v != null) setState(() => _tabIndex = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  // Extracted Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DocTypeBadge(type: doc.type),
                            const SizedBox(width: 10),
                            Text(' ·  pages', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
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
                                  Icon(CupertinoIcons.sparkles, size: 16, color: AppColors.teal),
                                  SizedBox(width: 6),
                                  Text('AI Grounded Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(doc.summary, style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.ink)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Extracted Entities', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
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
                                      title: Text(e.label, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                                      subtitle: Text(e.value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                                    ),
                                    if (idx < doc.entities.length - 1) const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // OCR Text Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(18),
                      child: SelectableText(
                        doc.rawText.isNotEmpty ? doc.rawText : doc.summary,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.7, color: AppColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
