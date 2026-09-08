import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FolioLogo extends StatelessWidget {
  final double size;
  const FolioLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A84FF),
                Color(0xFF007AFF),
                Color(0xFF5856D6),
              ],
            ),
            borderRadius: BorderRadius.circular(size * 0.28), // Apple continuous squircle feel
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                blurRadius: size * 0.3,
                offset: Offset(0, size * 0.1),
              ),
            ],
          ),
          child: Icon(Icons.description_rounded, color: Colors.white, size: size * 0.55),
        ),
        const SizedBox(width: 12),
        Text(
          'Folio',
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}
