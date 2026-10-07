import 'package:flutter/material.dart';

abstract final class FolioMotion {
  static Duration duration(BuildContext context, [int milliseconds = 180]) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(milliseconds: milliseconds);
  static const curve = Curves.easeOutCubic;
}

/// Retains page state while animating only the active page. Hidden tabs do not
/// animate or receive keyboard focus, and repaint isolation protects siblings.
class FolioTabStack extends StatefulWidget {
  const FolioTabStack({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;
  @override
  State<FolioTabStack> createState() => _FolioTabStackState();
}

class _FolioTabStackState extends State<FolioTabStack>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );
  late final _fade = Tween<double>(
    begin: .82,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: FolioMotion.curve));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void didUpdateWidget(FolioTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: ExcludeFocus(
              excluding: i != widget.index,
              child: RepaintBoundary(child: widget.children[i]),
            ),
          ),
      ],
    ),
  );
}
