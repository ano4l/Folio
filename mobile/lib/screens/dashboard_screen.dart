import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/doc_type_badge.dart';
import '../widgets/glass_container.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onAskTap;
  const DashboardScreen({super.key, this.onAskTap});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back, Alex', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text('Encrypted document vault & AI retrieval assistant active.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),

          // Glass Stats Row
          Row(children: [
            _StatCard(
              icon: CupertinoIcons.doc_text_fill,
              label: 'Documents',
              value: '',
              color: AppColors.teal,
              bg: AppColors.tealLight,
            ),
            const SizedBox(width: 10),
            _StatCard(
              icon: CupertinoIcons.clock_fill,
              label: 'Pending',
              value: '',
              color: AppColors.warning,
              bg: AppColors.warningLight,
            ),
            const SizedBox(width: 10),
            _StatCard(
              icon: CupertinoIcons.shield_fill,
              label: 'Audit events',
              value: '',
              color: AppColors.navy,
              bg: AppColors.navyLight,
            ),
          ]),
          const SizedBox(height: 28),

          // Quick AI Prompt Banner
          _SectionTitle('Ask your documents'),
          const SizedBox(height: 10),
          GlassContainer(
            padding: EdgeInsets.zero,
            onTap: onAskTap,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF007AFF),
                    Color(0xFF0A84FF),
                    Color(0xFF5856D6),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ask Folio AI', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('Grounded search across all vault files…', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Recent Documents Grouped Section
          _SectionTitle('Recent documents'),
          const SizedBox(height: 10),
          GlassContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...state.documents.take(3).toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final doc = entry.value;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(CupertinoIcons.doc_text, color: AppColors.teal, size: 22),
                        ),
                        title: Text(doc.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(' ·  pgs · % OCR',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                        trailing: DocTypeBadge(type: doc.type),
                      ),
                      if (idx < 2) const Divider(height: 1, indent: 64, endIndent: 16, color: AppColors.line),
                    ],
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Urgent Deadlines Grouped Section
          _SectionTitle('Urgent deadlines'),
          const SizedBox(height: 10),
          GlassContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...state.deadlines.where((d) => !d.completed).toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final d = entry.value;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: d.severity == 'high'
                                ? const Color(0xFFFFEBEA)
                                : d.severity == 'medium'
                                    ? AppColors.warningLight
                                    : AppColors.tealLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            CupertinoIcons.calendar,
                            color: d.severity == 'high'
                                ? AppColors.danger
                                : d.severity == 'medium'
                                    ? AppColors.warning
                                    : AppColors.teal,
                            size: 20,
                          ),
                        ),
                        title: Text(d.action, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(' · due ', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(' days',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning)),
                        ),
                      ),
                      if (idx < state.deadlines.where((d) => !d.completed).length - 1)
                        const Divider(height: 1, indent: 64, endIndent: 16, color: AppColors.line),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.headlineSmall);
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.slate)),
          ],
        ),
      ),
    );
  }
}
