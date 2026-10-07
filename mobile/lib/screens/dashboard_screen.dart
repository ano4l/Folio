import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_gauge.dart';
import '../widgets/doc_type_badge.dart';
import '../widgets/glass_container.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onAskTap;
  const DashboardScreen({super.key, this.onAskTap});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ready =
        state.documents.where((item) => item.status == 'Ready').length;
    final attention =
        state.documents.where((item) => item.status == 'Error').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final horizontal = wide ? 32.0 : 20.0;
        return RefreshIndicator(
          onRefresh: state.refreshDocuments,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 120),
                sliver: SliverList.list(
                  children: [
                    _Header(name: state.firstName),
                    const SizedBox(height: 24),
                    _VaultOverview(
                      documents: state.documents.length,
                      ready: ready,
                      attention: attention,
                      pending: state.pendingCount,
                      auditEvents: state.auditLogs.length,
                      wide: wide,
                    ),
                    const SizedBox(height: 28),
                    _AskCard(onTap: onAskTap),
                    const SizedBox(height: 28),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _RecentDocuments(state: state)),
                          const SizedBox(width: 20),
                          Expanded(child: _Deadlines(state: state)),
                        ],
                      )
                    else ...[
                      _RecentDocuments(state: state),
                      const SizedBox(height: 28),
                      _Deadlines(state: state),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  const _Header({required this.name});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Welcome back, $name',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 6),
      const Row(
        children: [
          Icon(
            CupertinoIcons.lock_shield_fill,
            size: 15,
            color: AppColors.success,
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Your encrypted document vault is protected and ready.',
              style: TextStyle(fontSize: 13, color: AppColors.slate),
            ),
          ),
        ],
      ),
    ],
  );
}

class _VaultOverview extends StatelessWidget {
  final int documents;
  final int ready;
  final int attention;
  final int pending;
  final int auditEvents;
  final bool wide;

  const _VaultOverview({
    required this.documents,
    required this.ready,
    required this.attention,
    required this.pending,
    required this.auditEvents,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) => GlassContainer(
    padding: const EdgeInsets.all(20),
    child:
        wide
            ? Row(
              children: [
                ActivityGauge(
                  documents: documents,
                  ready: ready,
                  attention: attention,
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: _Metrics(
                    documents: documents,
                    pending: pending,
                    auditEvents: auditEvents,
                  ),
                ),
              ],
            )
            : Column(
              children: [
                ActivityGauge(
                  documents: documents,
                  ready: ready,
                  attention: attention,
                ),
                const SizedBox(height: 16),
                _Metrics(
                  documents: documents,
                  pending: pending,
                  auditEvents: auditEvents,
                ),
              ],
            ),
  );
}

class _Metrics extends StatelessWidget {
  final int documents;
  final int pending;
  final int auditEvents;
  const _Metrics({
    required this.documents,
    required this.pending,
    required this.auditEvents,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Metric(
          value: '$documents',
          label: 'Documents',
          icon: CupertinoIcons.doc_text_fill,
          color: AppColors.teal,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _Metric(
          value: '$pending',
          label: 'Pending',
          icon: CupertinoIcons.clock_fill,
          color: AppColors.warning,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _Metric(
          value: '$auditEvents',
          label: 'Activity',
          icon: CupertinoIcons.shield_fill,
          color: AppColors.navy,
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AskCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _AskCard({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Ask Folio AI about your documents',
    child: GlassContainer(
      padding: EdgeInsets.zero,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E7C74), Color(0xFF116B68), Color(0xFF33455E)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            _SparkleIcon(),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask Folio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Get an answer grounded in your vault.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.arrow_up_right, color: Colors.white, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _SparkleIcon extends StatelessWidget {
  const _SparkleIcon();
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .15),
      shape: BoxShape.circle,
    ),
    child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 21),
  );
}

class _RecentDocuments extends StatelessWidget {
  final AppState state;
  const _RecentDocuments({required this.state});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionTitle('Recent documents'),
      const SizedBox(height: 12),
      if (state.documentsLoading)
        const _EmptyCard(
          icon: CupertinoIcons.arrow_2_circlepath,
          title: 'Refreshing your vault',
          detail: 'Securely loading your documents…',
        )
      else if (state.documents.isEmpty)
        const _EmptyCard(
          icon: Icons.upload_file_rounded,
          title: 'Your vault is ready',
          detail: 'Upload your first document from the Documents tab.',
        )
      else
        GlassContainer(
          padding: EdgeInsets.zero,
          child: Column(
            children:
                state.documents.take(3).toList().asMap().entries.map((entry) {
                  final doc = entry.value;
                  return Column(
                    children: [
                      Semantics(
                        button: true,
                        label: 'Open ${doc.title}',
                        child: ListTile(
                          minTileHeight: 68,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 5,
                          ),
                          leading: const _DocIcon(),
                          title: Text(
                            doc.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${doc.date} · ${doc.pages} pages · ${doc.status}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: DocTypeBadge(type: doc.type),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            state.openDocument(doc);
                          },
                        ),
                      ),
                      if (entry.key < state.documents.take(3).length - 1)
                        const Divider(height: 1, indent: 64, endIndent: 16),
                    ],
                  );
                }).toList(),
          ),
        ),
    ],
  );
}

class _Deadlines extends StatelessWidget {
  final AppState state;
  const _Deadlines({required this.state});

  @override
  Widget build(BuildContext context) {
    final pending = state.deadlines.where((item) => !item.completed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Next actions'),
        const SizedBox(height: 12),
        if (pending.isEmpty)
          const _EmptyCard(
            icon: CupertinoIcons.check_mark_circled_solid,
            title: 'Nothing urgent',
            detail: 'New obligations found in your documents will appear here.',
          )
        else
          GlassContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children:
                  pending
                      .take(3)
                      .map(
                        (deadline) => ListTile(
                          minTileHeight: 68,
                          leading: Icon(
                            CupertinoIcons.calendar,
                            color:
                                deadline.severity == 'high'
                                    ? AppColors.danger
                                    : AppColors.warning,
                          ),
                          title: Text(
                            deadline.action,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text('${deadline.doc} · ${deadline.due}'),
                          trailing: Text(
                            '${deadline.days}d',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
      ],
    );
  }
}

class _DocIcon extends StatelessWidget {
  const _DocIcon();
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: AppColors.tealLight,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(
      CupertinoIcons.doc_text_fill,
      color: AppColors.teal,
      size: 21,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.headlineSmall);
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.detail,
  });
  @override
  Widget build(BuildContext context) => GlassContainer(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Icon(icon, color: AppColors.teal, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
