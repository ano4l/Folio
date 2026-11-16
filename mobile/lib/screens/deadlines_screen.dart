import 'package:share_plus/share_plus.dart';
import '../services/study_export.dart';
import '../services/document_deadlines.dart';
import 'deadline_editor.dart';
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
  String _query = '';
  bool _highOnly = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Future<void> _reviewDates(AppState state) async {
    final owner = state.user?.id;
    final reviews = List<DocumentDeadlineCandidate>.of(
      state.deadlineDateReviews,
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder:
          (sheetContext) => SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .7,
            child: StatefulBuilder(
              builder:
                  (context, update) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: reviews.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const ListTile(
                          title: Text('Confirm document dates'),
                          subtitle: Text(
                            'Check the date and year against the source before adding it to your calendar.',
                          ),
                        );
                      }
                      final review = reviews[index - 1];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(review.sourceText),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      final doc =
                                          state.documents
                                              .where(
                                                (d) =>
                                                    d.id == review.documentId,
                                              )
                                              .firstOrNull;
                                      if (doc == null ||
                                          state.user?.id != owner) {
                                        return;
                                      }
                                      Navigator.pop(sheetContext);
                                      state.openDocument(doc);
                                    },
                                    child: const Text('Open source'),
                                  ),
                                  FilledButton(
                                    onPressed: () async {
                                      final due = await showDatePicker(
                                        context: context,
                                        helpText: 'Confirm the deadline date',
                                        initialDate:
                                            parseDocumentDeadlineDate(
                                              review.dateText,
                                            ) ??
                                            DateTime.now(),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime(2200, 12, 31),
                                      );
                                      if (due == null ||
                                          !context.mounted ||
                                          state.user?.id != owner) {
                                        return;
                                      }
                                      state.acceptDocumentDeadline(review, due);
                                      update(() => reviews.remove(review));
                                    },
                                    child: const Text('Choose date'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
    );
  }

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

  Future<void> _export(AppState state) async {
    if (!state.deadlines.any((d) => !d.completed)) return;
    try {
      final path = await StudyExport.textFile(
        StudyExport.calendar(state.deadlines),
        'ics',
      );
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox;
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/calendar')],
        subject: 'Folio deadlines',
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendar export could not finish.')),
        );
      }
    }
  }

  void _delete(AppState state, Deadline task) {
    final owner = state.user?.id;
    state.deleteDeadline(task.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (state.user?.id == owner) state.updateDeadline(task);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, List<Object?>>(
      (s) =>
          s.navigationIndex == 3
              ? [
                ...s.deadlines.map((d) => (d, d.completed)),
                ...s.documents,
                ...s.deadlineDateReviews,
              ]
              : const <Object?>[],
    );
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final dayOffsets = <Deadline, int>{
      for (final task in state.deadlines)
        task:
            task.dueDate == null
                ? task.days
                : DateTime.utc(
                  task.dueDate!.year,
                  task.dueDate!.month,
                  task.dueDate!.day,
                ).difference(todayUtc).inDays,
    };
    final allPending =
        state.deadlines
            .where(
              (d) =>
                  !d.completed &&
                  (!_highOnly || d.severity == 'high') &&
                  '${d.action} ${d.doc}'.toLowerCase().contains(_query),
            )
            .toList()
          ..sort((a, b) => dayOffsets[a]!.compareTo(dayOffsets[b]!));
    final eventsByDay = <DateTime, List<Deadline>>{};
    for (final task in allPending) {
      final due = task.dueDate;
      if (due == null) continue;
      (eventsByDay[DateTime.utc(due.year, due.month, due.day)] ??= []).add(
        task,
      );
    }
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
      'Overdue': pending.where((d) => dayOffsets[d]! < 0).toList(),
      'Today': pending.where((d) => dayOffsets[d] == 0).toList(),
      'Coming up':
          pending
              .where((d) => dayOffsets[d]! > 0 && dayOffsets[d]! <= 7)
              .toList(),
      'Later': pending.where((d) => dayOffsets[d]! > 7).toList(),
    };
    final rows = <({String? label, int count, Deadline? task})>[
      for (final entry in groups.entries.where((g) => g.value.isNotEmpty)) ...[
        (label: entry.key, count: entry.value.length, task: null),
        for (final task in entry.value) (label: null, count: 0, task: task),
        (label: null, count: 0, task: null),
      ],
    ];
    final headers = <Widget>[
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
      const SizedBox(height: 16),
      if (state.deadlineDateReviews.isNotEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_note_outlined),
          title: Text(
            '${state.deadlineDateReviews.length} document dates need review',
          ),
          subtitle: const Text('Confirm unclear dates and missing years.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _reviewDates(state),
        ),
      Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => showDeadlineEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('New task'),
          ),
          OutlinedButton.icon(
            onPressed:
                state.deadlines.any((d) => !d.completed)
                    ? () => _export(state)
                    : null,
            icon: const Icon(Icons.ios_share),
            label: const Text('Calendar export'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        decoration: const InputDecoration(
          hintText: 'Find a task or source',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilterChip(
          label: const Text('High priority'),
          selected: _highOnly,
          onSelected: (v) => setState(() => _highOnly = v),
        ),
      ),
      const SizedBox(height: 16),
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
                      firstDay: DateTime(1900),
                      lastDay: DateTime(2200, 12, 31),
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
                              eventsByDay[DateTime.utc(
                                day.year,
                                day.month,
                                day.day,
                              )] ??
                              const [],
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
    ];
    final footer = <Widget>[
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
                    onTap: () => showDeadlineEditor(context, task: task),
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
        'Saved on this device. Calendar export creates all-day events; your calendar app controls reminders.',
        style: theme.textTheme.bodySmall,
      ),
    ];

    return ListView.builder(
      key: const PageStorageKey('deadlines-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      itemCount: headers.length + rows.length + footer.length,
      itemBuilder: (context, index) {
        if (index < headers.length) return headers[index];
        final rowIndex = index - headers.length;
        if (rowIndex >= rows.length) return footer[rowIndex - rows.length];
        final entry = rows[rowIndex];
        if (entry.label != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  entry.label!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${entry.count}', style: theme.textTheme.labelMedium),
              ],
            ),
          );
        }
        final task = entry.task;
        if (task == null) return const SizedBox(height: 12);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TaskRow(
            key: ValueKey(task.id),
            task: task,
            onToggle: () => _toggle(state, task),
            onAction: (action) {
              if (action == 'edit') showDeadlineEditor(context, task: task);
              if (action == 'delete') _delete(state, task);
              if (action == 'snooze' && task.dueDate != null) {
                state.updateDeadline(
                  Deadline(
                    id: task.id,
                    action: task.action,
                    doc: task.doc,
                    documentId: task.documentId,
                    due:
                        task.dueDate!
                            .add(const Duration(days: 1))
                            .toIso8601String(),
                    days: 0,
                    severity: task.severity,
                  ),
                );
              }
            },
            onOpen: () {
              final doc =
                  state.documents
                      .where((d) => d.id == task.documentId)
                      .firstOrNull;
              if (doc != null) state.openDocument(doc);
            },
          ),
        );
      },
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onOpen,
    required this.onAction,
  });
  final Deadline task;
  final VoidCallback onToggle, onOpen;
  final ValueChanged<String> onAction;
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
                if (task.severity == 'high')
                  const Text(
                    'High priority',
                    style: TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                const SizedBox(height: 4),
                if (task.sourceKey != null) ...[
                  Text(
                    task.sourcePage == null
                        ? 'From document'
                        : 'From document · page ${task.sourcePage}',
                    style: theme.textTheme.labelSmall,
                  ),
                  if (task.sourceText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        task.sourceText!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
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
          PopupMenuButton<String>(
            tooltip: 'Task actions',
            onSelected: onAction,
            itemBuilder:
                (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit task')),
                  PopupMenuItem(
                    value: 'snooze',
                    child: Text('Move date by one day'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Delete task')),
                ],
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
