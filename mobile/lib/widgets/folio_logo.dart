import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FolioLogo extends StatelessWidget {
  final double size;
  final bool light;
  final bool showTagline;
  const FolioLogo({
    super.key,
    this.size = 40,
    this.light = false,
    this.showTagline = false,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(size * .22),
        ),
        child: Icon(
          Icons.folder_rounded,
          color: Colors.white,
          size: size * .55,
        ),
      ),
      SizedBox(width: size * .25),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Folio',
            style: AppTheme.display(
              size: size * .54,
              color: light ? Colors.white : AppColors.ink,
            ),
          ),
          if (showTagline)
            Text(
              'STUDENT FINANCE, SIMPLIFIED',
              style: TextStyle(
                fontSize: size * .19,
                letterSpacing: 1.05,
                fontWeight: FontWeight.w700,
                color: light ? Colors.white60 : AppColors.slate,
              ),
            ),
        ],
      ),
    ],
  );
}
