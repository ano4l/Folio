import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/document.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/folio_motion.dart';
import '../widgets/glass_container.dart';

class DeadlinesScreen extends StatefulWidget {
  const DeadlinesScreen({super.key});
  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  bool _calendar = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  void _toggle(AppState state, Deadline task) {
    HapticFeedback.selectionClick();
    state.resolveDeadline(task.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          task.completed
              ? 'Task completed. One less thing to remember.'
              : 'Task moved back to your list.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => state.resolveDeadline(task.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final allPending =
        state.deadlines.where((d) => !d.completed).toList()
          ..sort((a, b) => a.days.compareTo(b.days));
    final pending =
        allPending
            .where(
              (d) =>
                  !_calendar ||
                  _selectedDay == null ||
                  isSameDay(d.dueDate, _selectedDay),
            )
            .toList();
    final done = state.deadlines.where((d) => d.completed).toList();
    final groups = <String, List<Deadline>>{
      'Overdue': pending.where((d) => d.days < 0).toList(),
      'Today': pending.where((d) => d.days == 0).toList(),
      'Coming up': pending.where((d) => d.days > 0 && d.days <= 7).toList(),
      'Later': pending.where((d) => d.days > 7).toList(),
    };
    return ListView(
      key: const PageStorageKey('deadlines-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text(
          'A little more peace of mind.',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          allPending.isEmpty
              ? 'Your next steps, all in one place.'
              : '${allPending.length} ${allPending.length == 1 ? 'task' : 'tasks'} to take care of. Start with what matters next.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.view_agenda_outlined),
                label: Text('List'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.calendar_month_outlined),
                label: Text('Calendar'),
              ),
            ],
            selected: {_calendar},
            onSelectionChanged:
                (value) => setState(() => _calendar = value.single),
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSize(
          duration: FolioMotion.duration(context, 220),
          curve: FolioMotion.curve,
          alignment: Alignment.topCenter,
          child:
              _calendar
                  ? Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(12),
                      child: TableCalendar<Deadline>(
                        firstDay: DateTime(DateTime.now().year - 5),
                        lastDay: DateTime(DateTime.now().year + 5, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate:
                            (day) => isSameDay(day, _selectedDay),
                        onDaySelected:
                            (day, focused) => setState(() {
                              _selectedDay = day;
                              _focusedDay = focused;
                            }),
                        onPageChanged:
                            (day) => setState(() {
                              _focusedDay = day;
                              _selectedDay = null;
                            }),
                        availableGestures: AvailableGestures.horizontalSwipe,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                        calendarStyle: const CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: AppColors.tealLight,
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w700,
                          ),
                          markerDecoration: BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        eventLoader:
                            (day) =>
                                allPending
                                    .where((d) => isSameDay(d.dueDate, day))
                                    .toList(),
                      ),
                    ),
                  )
                  : const SizedBox(width: double.infinity),
        ),
        if (_calendar && _selectedDay != null)
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              label: Text(DateFormat.yMMMMd().format(_selectedDay!)),
              deleteButtonTooltipMessage: 'Show all dates',
              onDeleted: () => setState(() => _selectedDay = null),
            ),
          ),
        if (pending.isEmpty)
          GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.teal,
                  size: 32,
                ),
                const SizedBox(height: 16),
                Text(
                  _calendar && _selectedDay != null
                      ? 'Nothing due on this day.'
                      : state.deadlines.isEmpty
                      ? 'Turn paperwork into a plan.'
                      : 'You’re all caught up.',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _calendar && _selectedDay != null
                      ? 'Choose another day or clear the date filter.'
                      : 'Open a document and add a task with a date you’ve checked.',
                ),
                if (!_calendar || _selectedDay == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextButton.icon(
                      onPressed: () => state.navigate(1),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Open documents'),
                    ),
                  ),
              ],
            ),
          ),
        for (final entry in groups.entries.where(
          (g) => g.value.isNotEmpty,
        )) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  entry.key,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value.length}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
          for (final task in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskRow(
                key: ValueKey(task.id),
                task: task,
                onToggle: () => _toggle(state, task),
                onOpen: () {
                  final doc =
                      state.documents
                          .where((d) => d.id == task.documentId)
                          .firstOrNull;
                  if (doc != null) state.openDocument(doc);
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (done.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: GlassContainer(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                key: const PageStorageKey('completed-tasks'),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text('Completed · ${done.length}'),
                subtitle: const Text('A little progress, kept here.'),
                children: [
                  for (final task in done)
                    ListTile(
                      title: Text(
                        task.action,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(task.doc),
                      leading: const Icon(
                        Icons.check_circle,
                        color: AppColors.teal,
                      ),
                      trailing: IconButton(
                        tooltip: 'Mark incomplete',
                        onPressed: () => _toggle(state, task),
                        icon: const Icon(Icons.undo),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Saved on this device. Calendar view does not send reminders.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onOpen,
  });
  final Deadline task;
  final VoidCallback onToggle, onOpen;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgent = task.days <= 0;
    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.action,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  task.days < 0
                      ? '${-task.days} ${task.days == -1 ? 'day' : 'days'} overdue'
                      : task.days == 0
                      ? 'Due today'
                      : task.dueDate == null
                      ? task.due
                      : DateFormat('EEE, d MMM').format(task.dueDate!),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: urgent ? AppColors.danger : AppColors.teal,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: task.documentId == null ? null : onOpen,
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    task.doc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Complete ${task.action}',
            onPressed: onToggle,
            icon: const Icon(
              Icons.radio_button_unchecked,
              color: AppColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}
