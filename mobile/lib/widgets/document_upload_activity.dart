import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/document_upload.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class DocumentUploadActivity extends StatelessWidget {
  const DocumentUploadActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final uploads = context.select<AppState, List<DocumentUpload>>(
      (s) => s.documentUploads,
    );
    if (uploads.isEmpty) return const SizedBox.shrink();
    final state = context.read<AppState>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children:
          uploads.reversed
              .map(
                (upload) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              upload.isRunning
                                  ? Icons.cloud_upload_outlined
                                  : upload.status == UploadStatus.ready
                                  ? Icons.check_circle_outline
                                  : Icons.info_outline,
                              color:
                                  upload.status == UploadStatus.failed
                                      ? AppColors.danger
                                      : AppColors.teal,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                upload.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!upload.isRunning)
                              IconButton(
                                tooltip: 'Dismiss upload status',
                                onPressed:
                                    () =>
                                        state.dismissDocumentUpload(upload.id),
                                icon: const Icon(Icons.close),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(upload.stage),
                        if (upload.isRunning) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(minHeight: 3),
                          const SizedBox(height: 8),
                          const Text('You can keep using Folio.'),
                        ],
                        if (upload.status == UploadStatus.failed ||
                            upload.status == UploadStatus.needsReview)
                          TextButton(
                            onPressed:
                                () => state.retryDocumentUpload(upload.id),
                            child: Text(
                              upload.documentId == null
                                  ? 'Try again'
                                  : 'Retry summary',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class DocumentUploadButton extends StatelessWidget {
  const DocumentUploadButton({super.key});

  @override
  Widget build(BuildContext context) {
    final uploads = context.select<AppState, List<DocumentUpload>>(
      (s) => s.documentUploads,
    );
    if (uploads.isEmpty) return const SizedBox.shrink();
    final running = uploads.where((u) => u.isRunning).length;
    return IconButton(
      tooltip: running > 0 ? '$running uploads in progress' : 'Upload results',
      icon: Badge(
        label: Text('${running > 0 ? running : uploads.length}'),
        child: Icon(
          running > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
        ),
      ),
      onPressed:
          () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder:
                (context) => DraggableScrollableSheet(
                  initialChildSize: 0.5,
                  minChildSize: 0.25,
                  maxChildSize: 0.9,
                  expand: false,
                  builder:
                      (_, controller) => ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          Text(
                            'Uploads',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          const DocumentUploadActivity(),
                        ],
                      ),
                ),
          ),
    );
  }
}
