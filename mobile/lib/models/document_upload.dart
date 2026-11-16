enum UploadStatus { running, ready, needsReview, failed }

class DocumentUpload {
  const DocumentUpload({
    required this.id,
    required this.filePath,
    required this.title,
    required this.category,
    this.studySpaceId,
    this.documentId,
    this.stage = 'Preparing secure upload…',
    this.status = UploadStatus.running,
  });

  final int id;
  final String filePath;
  final String title;
  final String category;
  final String? studySpaceId;
  final String? documentId;
  final String stage;
  final UploadStatus status;
  bool get isRunning => status == UploadStatus.running;

  DocumentUpload update(
    String stage,
    UploadStatus status, {
    String? documentId,
  }) => DocumentUpload(
    id: id,
    filePath: filePath,
    title: title,
    category: category,
    studySpaceId: studySpaceId,
    documentId: documentId ?? this.documentId,
    stage: stage,
    status: status,
  );
}
