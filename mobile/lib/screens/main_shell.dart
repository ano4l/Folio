import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import 'dashboard_screen.dart';
import 'documents_screen.dart';
import 'ask_ai_screen.dart';
import 'deadlines_screen.dart';
import 'security_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _titles = ['Dashboard', 'Documents', 'Ask AI', 'Deadlines', 'Security'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final screens = [
      DashboardScreen(onAskTap: () => setState(() => _index = 2)),
      const DocumentsScreen(),
      const AskAiScreen(),
      const DeadlinesScreen(),
      const SecurityScreen(),
    ];

    return Scaffold(
      extendBody: true, // Allow body content to flow under the translucent glass dock
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: AppColors.paper.withValues(alpha: 0.8),
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(_titles[_index]),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.bell, size: 20),
                      onPressed: () => _showNotifications(context, state),
                    ),
                    if (state.pendingCount > 0)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                          child: Text(
                            '',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                PopupMenuButton<String>(
                  offset: const Offset(0, 48),
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  icon: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.teal.withValues(alpha: 0.3), blurRadius: 8),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.teal,
                      child: Text('AM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem<String>(
                      value: 'profile',
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Alex Mokoena', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                          Text('alex.m@folio-student.app', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                          Text('Student Account', style: TextStyle(fontSize: 11, color: AppColors.slate)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(children: [
                        Icon(CupertinoIcons.power, size: 16, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Sign out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'logout') context.read<AppState>().logout();
                  },
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            borderRadius: BorderRadius.circular(32), // Liquid Glass Floating Dock Capsule
            opacity: 0.85,
            blur: 25.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DockItem(
                  icon: CupertinoIcons.house,
                  activeIcon: CupertinoIcons.house_fill,
                  label: 'Home',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _DockItem(
                  icon: CupertinoIcons.doc_text,
                  activeIcon: CupertinoIcons.doc_text_fill,
                  label: 'Docs',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _DockItem(
                  icon: CupertinoIcons.chat_bubble_2,
                  activeIcon: CupertinoIcons.chat_bubble_2_fill,
                  label: 'Ask AI',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _DockItem(
                  icon: CupertinoIcons.calendar,
                  activeIcon: CupertinoIcons.calendar_today,
                  label: 'Deadlines',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
                _DockItem(
                  icon: CupertinoIcons.shield,
                  activeIcon: CupertinoIcons.shield_fill,
                  label: 'Security',
                  selected: _index == 4,
                  onTap: () => setState(() => _index = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context, AppState state) {
    final pending = state.deadlines.where((d) => !d.completed).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pending Deadlines', style: Theme.of(context).textTheme.headlineSmall),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.slate, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('All caught up. No pending deadlines.', style: TextStyle(color: AppColors.slate))),
                )
              else
                ...pending.map((d) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_circle_fill,
                            color: d.severity == 'high' ? AppColors.danger : d.severity == 'medium' ? AppColors.warning : AppColors.teal,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.action, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                Text(' · due ', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('d left', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.warning)),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 22,
              color: selected ? AppColors.teal : AppColors.slate,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.teal : AppColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
