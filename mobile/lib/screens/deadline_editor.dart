import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../services/app_state.dart';

Future<void> showDeadlineEditor(
  BuildContext context, {
  Deadline? task,
  Document? document,
}) async {
  final state = context.read<AppState>();
  final owner = state.user?.id;
  final action = TextEditingController(text: task?.action ?? '');
  var due = task?.dueDate ?? DateTime.now().add(const Duration(days: 1));
  String? documentId = task?.documentId ?? document?.id;
  if (!state.documents.any((d) => d.id == documentId)) documentId = null;
  var priority = task?.severity ?? 'medium';
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (dialog) => StatefulBuilder(
          builder:
              (context, update) => AlertDialog(
                title: Text(task == null ? 'New task' : 'Edit task'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: action,
                        maxLength: 160,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'What needs doing?',
                          errorText: error,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: Text('${due.day}/${due.month}/${due.year}'),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: due,
                            firstDate: DateTime(
                              due.year < now.year - 10
                                  ? due.year
                                  : now.year - 10,
                            ),
                            lastDate: DateTime(
                              due.year > now.year + 10
                                  ? due.year
                                  : now.year + 10,
                              12,
                              31,
                            ),
                          );
                          if (picked != null && context.mounted) {
                            update(() => due = picked);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text('Normal'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                        ],
                        onChanged: (v) {
                          if (v != null) priority = v;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String?>(
                        initialValue: documentId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Source document (optional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Personal task'),
                          ),
                          for (final d in state.documents)
                            DropdownMenuItem<String?>(
                              value: d.id,
                              child: Text(
                                d.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => documentId = v,
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
                      if (action.text.trim().isEmpty) {
                        update(() => error = 'Enter a task.');
                      } else {
                        Navigator.pop(dialog, true);
                      }
                    },
                    child: const Text('Save task'),
                  ),
                ],
              ),
        ),
  );
  if (saved == true && context.mounted && state.user?.id == owner) {
    final doc = state.documents.where((d) => d.id == documentId).firstOrNull;
    state.updateDeadline(
      Deadline(
        id: task?.id ?? DateTime.now().microsecondsSinceEpoch,
        action: action.text.trim(),
        doc: doc?.title ?? 'Personal task',
        documentId: doc?.id,
        due: DateTime(due.year, due.month, due.day).toIso8601String(),
        days: 0,
        severity: priority,
        completed: task?.completed ?? false,
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Task saved on this device.')));
  }
  Future<void>.delayed(const Duration(milliseconds: 400), action.dispose);
}
