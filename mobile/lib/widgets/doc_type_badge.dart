import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DocTypeBadge extends StatelessWidget {
  final String type;
  const DocTypeBadge({super.key, required this.type});

  static const Map<String, _Style> _styles = {
    'Funding Award Letter': _Style('Funding', AppColors.warning, AppColors.warningLight),
    'Bursary Agreement': _Style('Bursary', AppColors.teal, AppColors.tealLight),
    'Fee Statement': _Style('Fees', AppColors.navy, AppColors.navyLight),
    'Bank Letter': _Style('Bank', AppColors.purple, AppColors.purpleLight),
    'Appeal Correspondence': _Style('Appeal', AppColors.danger, Color(0xFFFFEBEA)),
  };

  @override
  Widget build(BuildContext context) {
    final s = _styles[type] ?? const _Style('Doc', AppColors.slate, AppColors.paper);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: s.bg.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: s.fg.withValues(alpha: 0.2), width: 0.5),
          ),
          child: Text(
            s.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: s.fg,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _Style {
  final String label;
  final Color fg;
  final Color bg;
  const _Style(this.label, this.fg, this.bg);
}
