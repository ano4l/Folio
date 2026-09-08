import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable Apple-style Liquid Glass Container widget with frosted blur,
/// specular hair-line border, and subtle ambient drop shadow.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? tint;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;
  final AlignmentGeometry? alignment;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.opacity = 0.75,
    this.tint,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.onTap,
    this.boxShadow,
    this.alignment,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(20);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultBgColor = tint != null
        ? tint!.withValues(alpha: opacity)
        : (isDark
            ? const Color(0x3D1C1C1E)
            : Colors.white.withValues(alpha: opacity));

    final defaultBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.8),
          width: 1.0,
        );

    final defaultShadow = boxShadow ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ];

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      alignment: alignment,
      decoration: BoxDecoration(
        color: defaultBgColor,
        borderRadius: effectiveRadius,
        border: defaultBorder,
        boxShadow: defaultShadow,
      ),
      child: child,
    );

    content = ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          borderRadius: effectiveRadius,
          child: InkWell(
            borderRadius: effectiveRadius,
            onTap: onTap,
            child: ClipRRect(
              borderRadius: effectiveRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  width: width,
                  height: height,
                  padding: padding ?? const EdgeInsets.all(16),
                  alignment: alignment,
                  decoration: BoxDecoration(
                    color: defaultBgColor,
                    borderRadius: effectiveRadius,
                    border: defaultBorder,
                    boxShadow: defaultShadow,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return content;
  }
}
