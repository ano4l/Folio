import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// iPad requires a nonempty popover origin inside the presenting view.
abstract final class ShareText {
  static Future<void> show(
    BuildContext context,
    String text, {
    String? subject,
  }) async {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    try {
      await Share.share(text, subject: subject, sharePositionOrigin: origin);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sharing could not open. Please try again.'),
          ),
        );
      }
    }
  }
}
