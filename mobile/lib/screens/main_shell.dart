import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/folio_logo.dart';
import '../widgets/folio_motion.dart';
import 'ask_ai_screen.dart';
import 'dashboard_screen.dart';
import 'deadlines_screen.dart';
import 'documents_screen.dart';
import 'security_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int get _index => context.read<AppState>().navigationIndex;

  static const _items = [
    _NavItem('Home', CupertinoIcons.house, CupertinoIcons.house_fill),
    _NavItem(
      'Documents',
      CupertinoIcons.doc_text,
      CupertinoIcons.doc_text_fill,
    ),
    _NavItem(
      'Ask AI',
      CupertinoIcons.chat_bubble_2,
      CupertinoIcons.chat_bubble_2_fill,
    ),
    _NavItem(
      'Deadlines',
      CupertinoIcons.calendar,
      CupertinoIcons.calendar_today,
    ),
    _NavItem('Security', CupertinoIcons.shield, CupertinoIcons.shield_fill),
  ];

  void _select(int index) {
    if (_index == index) return;
    HapticFeedback.selectionClick();
    context.read<AppState>().navigate(index);
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, (int, int, String?)>(
      (s) => (s.navigationIndex, s.pendingCount, s.user?.id),
    );
    final state = context.read<AppState>();
    final media = MediaQuery.of(context);
    final expanded = media.size.width >= 760;
    final hinge =
        media.displayFeatures
            .where(
              (feature) =>
                  feature.type == DisplayFeatureType.hinge &&
                  feature.bounds.width > 0,
            )
            .firstOrNull;
    final screens = [
      DashboardScreen(onAskTap: () => _select(2)),
      const DocumentsScreen(),
      const AskAiScreen(),
      const DeadlinesScreen(),
      const SecurityScreen(),
    ];

    return Scaffold(
      extendBody: Theme.of(context).platform == TargetPlatform.iOS,
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (expanded)
              _NavigationRail(index: _index, onSelect: _select, state: state),
            if (hinge != null) SizedBox(width: hinge.bounds.width),
            Expanded(
              child: Column(
                children: [
                  _TopBar(title: _items[_index].label, state: state),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: FolioTabStack(index: _index, children: screens),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          expanded || media.viewInsets.bottom > 0
              ? null
              : _BottomDock(index: _index, onSelect: _select),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final AppState state;
  const _TopBar({required this.title, required this.state});

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: AppColors.card,
      border: const Border(
        bottom: BorderSide(color: AppColors.line, width: .5),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        _NotificationButton(state: state),
        const SizedBox(width: 4),
        _ProfileButton(state: state),
      ],
    ),
  );
}

class _NotificationButton extends StatelessWidget {
  final AppState state;
  const _NotificationButton({required this.state});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${state.pendingCount} pending notifications',
    child: Stack(
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            HapticFeedback.lightImpact();
            _showNotifications(context, state);
          },
          icon: const Icon(CupertinoIcons.bell, size: 21),
        ),
        if (state.pendingCount > 0)
          Positioned(
            right: 8,
            top: 7,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${state.pendingCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ProfileButton extends StatelessWidget {
  final AppState state;
  const _ProfileButton({required this.state});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Account',
    offset: const Offset(0, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    onSelected: (value) {
      if (value == 'logout') state.logout();
    },
    itemBuilder:
        (_) => [
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.user?.displayName ?? 'Student',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  state.user?.email ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(CupertinoIcons.power, color: AppColors.danger, size: 18),
                SizedBox(width: 10),
                Text('Sign out', style: TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
        ],
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.teal,
        child: Text(
          _initials(state.user?.displayName ?? 'Student'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _BottomDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _BottomDock({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final tabs = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Row(
        children: List.generate(_MainShellState._items.length, (itemIndex) {
          final item = _MainShellState._items[itemIndex];
          return Expanded(
            child: _DockItem(
              item: item,
              selected: index == itemIndex,
              onTap: () => onSelect(itemIndex),
            ),
          );
        }),
      ),
    );
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(top: false, child: tabs),
      );
    }
    final highContrast = MediaQuery.highContrastOf(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter:
                highContrast
                    ? ImageFilter.blur()
                    : ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color:
                    highContrast
                        ? AppColors.card
                        : AppColors.card.withValues(alpha: .78),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color:
                      highContrast
                          ? AppColors.slate
                          : Colors.white.withValues(alpha: .9),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: .1),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: tabs,
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _DockItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: item.label,
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration:
            MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: FolioMotion.duration(context),
              curve: FolioMotion.curve,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.tealLight : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 22,
                color: selected ? AppColors.teal : AppColors.slate,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label == 'Documents' ? 'Docs' : item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.teal : AppColors.slate,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavigationRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final AppState state;
  const _NavigationRail({
    required this.index,
    required this.onSelect,
    required this.state,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 250,
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
    decoration: const BoxDecoration(color: AppColors.ink),
    child: Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: FolioLogo(size: 38, light: true),
        ),
        const SizedBox(height: 28),
        ...List.generate(_MainShellState._items.length, (itemIndex) {
          final item = _MainShellState._items[itemIndex];
          final selected = itemIndex == index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              minTileHeight: 48,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              selected: selected,
              selectedTileColor: Colors.white.withValues(alpha: .1),
              leading: Icon(
                selected ? item.activeIcon : item.icon,
                color: selected ? Colors.white : Colors.white60,
                size: 21,
              ),
              title: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.white70,
                ),
              ),
              onTap: () => onSelect(itemIndex),
            ),
          );
        }),
        const Spacer(),
        Text(
          state.user?.email ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    ),
  );
}

void _showNotifications(BuildContext context, AppState state) {
  final pending = state.deadlines.where((item) => !item.completed).toList();
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder:
        (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: AppColors.success,
                            size: 34,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'You’re all caught up',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'No pending deadlines.',
                            style: TextStyle(color: AppColors.slate),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...pending.map(
                    (item) => ListTile(
                      leading: const Icon(
                        CupertinoIcons.calendar,
                        color: AppColors.warning,
                      ),
                      title: Text(item.action),
                      subtitle: Text('${item.doc} · ${item.due}'),
                      trailing: Text('${item.days}d'),
                    ),
                  ),
              ],
            ),
          ),
        ),
  );
}

String _initials(String name) =>
    name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem(this.label, this.icon, this.activeIcon);
}
