import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'folio_motion.dart';

class GlassContainer extends StatefulWidget {
  final Widget child;
  final double blur, opacity;
  final Color? tint;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding, margin;
  final Border? border;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;
  final AlignmentGeometry? alignment;
  final double? width, height;
  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 0,
    this.opacity = 1,
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
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(20);
    final decoration = BoxDecoration(
      color: widget.tint ?? AppColors.card,
      borderRadius: radius,
      border: widget.border ?? Border.all(color: AppColors.line),
      boxShadow: widget.boxShadow ?? const [],
    );
    final content = Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding ?? const EdgeInsets.all(16),
      alignment: widget.alignment,
      child: widget.child,
    );
    final surface =
        widget.onTap == null
            ? DecoratedBox(decoration: decoration, child: content)
            : Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: decoration,
                child: InkWell(
                  borderRadius: radius,
                  onTap: widget.onTap,
                  onHighlightChanged:
                      (pressed) => setState(() => _pressed = pressed),
                  child: content,
                ),
              ),
            );
    final wrapped = AnimatedScale(
      scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .985 : 1,
      duration: FolioMotion.duration(context, 120),
      curve: FolioMotion.curve,
      child: surface,
    );
    return widget.margin == null
        ? wrapped
        : Padding(padding: widget.margin!, child: wrapped);
  }
}
