/// Recover transient processing failures without uploading the original again.
class ProcessingSnapshot {
  const ProcessingSnapshot(this.status, this.summary);
  final String status;
  final String summary;
  bool get busy => status == 'Analyzing' || status == 'Scanning';
  bool get ready => status == 'Ready';
  bool get permanentReview =>
      status == 'Needs review' &&
      !summary.toLowerCase().contains(
        'ai summarisation is temporarily unavailable',
      );
}

Future<String> recoverDocumentProcessing({
  required Future<String> Function() process,
  required Future<ProcessingSnapshot?> Function() inspect,
  required void Function() ensureCurrent,
  required Future<void> Function(Duration) wait,
  void Function(String)? onStage,
}) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    ensureCurrent();
    onStage?.call(
      attempt == 0
          ? 'Reading and summarising…'
          : 'Retrying AI summary automatically…',
    );
    final status = await process();
    ensureCurrent();
    if (status == 'READY') return status;
    var snapshot = await inspect();
    ensureCurrent();
    // A timed-out request may still be running on the server. Observe it rather
    // than starting another provider request during its processing lease.
    for (var poll = 0; snapshot?.busy == true && poll < 25; poll++) {
      onStage?.call('Saved securely. Finishing your summary…');
      await wait(const Duration(seconds: 5));
      ensureCurrent();
      snapshot = await inspect();
      ensureCurrent();
    }
    if (snapshot?.ready == true) return 'READY';
    if (snapshot?.permanentReview == true) return 'REVIEW_REQUIRED';
    // Give a temporarily rate-limited AI provider time to recover between
    // requests. The later retry also outlasts the server's 120-second lease if
    // the original function was terminated.
    if (attempt < 2) {
      onStage?.call('Saved securely. Retrying summary shortly…');
      await wait(Duration(seconds: attempt == 0 ? 30 : 90));
    }
  }
  return 'PROCESSING_PENDING';
}
