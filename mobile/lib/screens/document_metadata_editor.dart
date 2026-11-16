import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../models/document_categories.dart';
import '../services/app_state.dart';

Future<void> showDocumentMetadataEditor(
  BuildContext context,
  Document document,
) async {
  final state = context.read<AppState>();
  final owner = state.user?.id;
  final title = TextEditingController(text: document.title);
  final category = TextEditingController(text: document.type);
  var saving = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (dialog) => StatefulBuilder(
          builder:
              (context, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                  title: const Text('Edit document details'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: title,
                          maxLength: 240,
                          enabled: !saving,
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),
                        TextField(
                          controller: category,
                          maxLength: 80,
                          enabled: !saving,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            helperText:
                                'Choose a suggestion or enter your own.',
                            suffixIcon: PopupMenuButton<String>(
                              tooltip: 'Suggested categories',
                              enabled: !saving,
                              icon: const Icon(Icons.expand_more),
                              onSelected:
                                  (value) =>
                                      update(() => category.text = value),
                              itemBuilder:
                                  (_) =>
                                      documentCategories
                                          .map(
                                            (value) => PopupMenuItem(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(),
                            ),
                          ),
                        ),
                        if (error != null)
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        if (saving) const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(dialog),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          saving
                              ? null
                              : () async {
                                if (title.text.trim().isEmpty ||
                                    category.text.trim().isEmpty) {
                                  update(
                                    () => error = 'Enter a title and category.',
                                  );
                                  return;
                                }
                                update(() {
                                  saving = true;
                                  error = null;
                                });
                                try {
                                  if (state.user?.id != owner) {
                                    if (dialog.mounted) Navigator.pop(dialog);
                                    return;
                                  }
                                  await state.updateDocumentMetadata(
                                    document,
                                    title.text,
                                    category.text,
                                  );
                                  if (dialog.mounted) Navigator.pop(dialog);
                                } catch (_) {
                                  if (dialog.mounted) {
                                    update(() {
                                      saving = false;
                                      error =
                                          'Could not save. Check your connection and try again.';
                                    });
                                  }
                                }
                              },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
        ),
  );
  Future<void>.delayed(const Duration(milliseconds: 400), () {
    title.dispose();
    category.dispose();
  });
}
