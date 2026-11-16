import 'package:flutter/material.dart';

abstract final class FolioMotion {
  static Duration duration(BuildContext context, [int milliseconds = 180]) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(milliseconds: milliseconds);
  static const curve = Curves.easeOutCubic;
}

/// Retains visited pages in the viewport's keep-alive bucket. Unlike Offstage,
/// inactive pages aren't laid out when the visible tab changes constraints.
class FolioTabStack extends StatefulWidget {
  const FolioTabStack({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;
  @override
  State<FolioTabStack> createState() => _FolioTabStackState();
}

class _FolioTabStackState extends State<FolioTabStack> {
  late final PageController _controller = PageController(
    initialPage: widget.index,
  );

  @override
  void didUpdateWidget(FolioTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && _controller.hasClients) {
      _controller.jumpToPage(widget.index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
    controller: _controller,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: widget.children.length,
    itemBuilder:
        (context, i) => _RetainedTab(
          key: ValueKey(i),
          child: TickerMode(
            enabled: i == widget.index,
            child: ExcludeFocus(
              excluding: i != widget.index,
              child: RepaintBoundary(child: widget.children[i]),
            ),
          ),
        ),
  );
}

class _RetainedTab extends StatefulWidget {
  const _RetainedTab({super.key, required this.child});
  final Widget child;
  @override
  State<_RetainedTab> createState() => _RetainedTabState();
}

class _RetainedTabState extends State<_RetainedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
