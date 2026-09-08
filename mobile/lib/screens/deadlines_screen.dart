import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class DeadlinesScreen extends StatefulWidget {
  const DeadlinesScreen({super.key});
  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  int _viewIndex = 0; // 0 = List, 1 = Calendar
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending = state.deadlines.where((d) => !d.completed).toList();
    final done = state.deadlines.where((d) => d.completed).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Row(
          children: [
            Expanded(child: Text('Deadline Tracker', style: Theme.of(context).textTheme.headlineMedium)),
            SizedBox(
              width: 140,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _viewIndex,
                children: const {
                  0: Icon(CupertinoIcons.list_bullet, size: 16),
                  1: Icon(CupertinoIcons.calendar, size: 16),
                },
                onValueChanged: (v) {
                  if (v != null) setState(() => _viewIndex = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_viewIndex == 1) ...[
          GlassContainer(
            padding: const EdgeInsets.all(12),
            child: TableCalendar(
              firstDay: DateTime(2026, 1, 1),
              lastDay: DateTime(2026, 12, 31),
              focusedDay: _focusedDay,
              onPageChanged: (d) => setState(() => _focusedDay = d),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                markerDecoration: BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              eventLoader: (day) => state.deadlines.where((d) => !d.completed).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (pending.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('All deadlines resolved.', style: TextStyle(color: AppColors.slate))),
          )
        else
          ...pending.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 54,
                        decoration: BoxDecoration(
                          color: d.severity == 'high'
                              ? AppColors.danger
                              : d.severity == 'medium'
                                  ? AppColors.warning
                                  : AppColors.teal,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.action, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                            const SizedBox(height: 3),
                            Text(d.doc, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                            const SizedBox(height: 4),
                            Text('Due  ·  days left', style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.checkmark_circle, color: AppColors.teal, size: 26),
                        tooltip: 'Mark complete',
                        onPressed: () {
                          state.resolveDeadline(d.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Task resolved!'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )),

        if (done.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Completed', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          GlassContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...done.map((d) => ListTile(
                      leading: const Icon(CupertinoIcons.checkmark_seal_fill, color: AppColors.success, size: 20),
                      title: Text(d.action, style: const TextStyle(fontSize: 13, decoration: TextDecoration.lineThrough, color: AppColors.slate)),
                      subtitle: Text(' · was due ', style: const TextStyle(fontSize: 11, color: AppColors.slate)),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
