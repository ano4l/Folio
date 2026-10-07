import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// One renderer for summaries and chat. Never loads remote images from AI text.
class AiContent extends StatelessWidget {
  const AiContent({
    super.key,
    required this.text,
    this.streaming = false,
    this.sourceNumbers = const [],
    this.onSource,
  });
  final String text;
  final bool streaming;
  final List<String> sourceNumbers;
  final ValueChanged<String>? onSource;

  static String plainText(String text) => text
      .replaceAll(RegExp(r'\[SOURCE:\d+\]'), '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll('**', '')
      .replaceAll('`', '');

  @override
  Widget build(BuildContext context) {
    var content = text.replaceAllMapped(
      RegExp(r'\[SOURCE:(\d+)\]'),
      (match) =>
          sourceNumbers.contains(match[1])
              ? '[Source ${match[1]}](folio-source:${match[1]})'
              : '',
    );
    if (streaming) {
      content = content.replaceAll(RegExp(r'\[SOURCE:[^\]]*$'), '');
      if ('**'.allMatches(content).length.isOdd) content += '**';
    }
    final theme = Theme.of(context);
    return MarkdownBody(
      data: content,
      selectable: !streaming,
      imageBuilder: (uri, title, alt) => const SizedBox.shrink(),
      onTapLink: (text, href, title) async {
        final uri = Uri.tryParse(href ?? '');
        if (uri?.scheme == 'folio-source') {
          onSource?.call(uri!.path);
          return;
        }
        if (uri == null || !['https', 'http'].contains(uri.scheme)) return;
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          /* Link may be unavailable. */
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
        h1: theme.textTheme.titleLarge,
        h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        h3: theme.textTheme.titleMedium,
        blockSpacing: 16,
        listIndent: 20,
        tableColumnWidth: const FlexColumnWidth(),
      ),
    );
  }
}
