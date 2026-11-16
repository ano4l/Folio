import 'package:share_plus/share_plus.dart';
import '../services/study_export.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  String _query = '';
  String? _category;
  Future<void> _exportActivity(AppState state) async {
    String csv(String text) {
      final safe = RegExp(r'^\s*[=+\-@]').hasMatch(text) ? "'$text" : text;
      return '"${safe.replaceAll('"', '""')}"';
    }

    final lines = [
      'Time,Actor,Action,Detail,Category',
      ...state.auditLogs.map(
        (log) => [
          log.time,
          log.actor,
          log.action,
          log.detail,
          log.category,
        ].map(csv).join(','),
      ),
    ];
    try {
      final path = await StudyExport.textFile(lines.join('\r\n'), 'csv');
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox;
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')],
        subject: 'Folio device activity',
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity export could not finish.')),
        );
      }
    }
  }

  static const Map<String, Color> _catColors = {
    'Access': AppColors.teal,
    'AI Queries': AppColors.purple,
    'Security': AppColors.navy,
    'Document': AppColors.warning,
    'Study': AppColors.teal,
  };

  @override
  Widget build(BuildContext context) {
    context.select<AppState, List<Object?>>(
      (s) =>
          s.navigationIndex == 4
              ? [s.biometricEnabled, s.biometricAvailable, ...s.auditLogs]
              : const <Object?>[],
    );
    final state = context.read<AppState>();

    final logs =
        state.auditLogs
            .where(
              (log) =>
                  (_category == null || log.category == _category) &&
                  '${log.action} ${log.detail} ${log.actor}'
                      .toLowerCase()
                      .contains(_query),
            )
            .toList();
    final headers = <Widget>[
      Text(
        'Security & Compliance',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 4),
      Text(
        'Account protection and activity on this device',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 20),

      GlassContainer(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.number,
                  color: AppColors.teal,
                  size: 20,
                ),
              ),
              title: const Text(
                'Multi-factor authentication',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Require 6-digit code on sign-in',
                style: TextStyle(fontSize: 12, color: AppColors.slate),
              ),
              trailing: const Chip(label: Text('Required')),
            ),
            const Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: AppColors.line,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.viewfinder,
                  color: AppColors.teal,
                  size: 20,
                ),
              ),
              title: const Text(
                'Biometric unlock',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Device face or fingerprint • not an account passkey',
                style: TextStyle(fontSize: 12, color: AppColors.slate),
              ),
              trailing: CupertinoSwitch(
                activeTrackColor: AppColors.teal,
                value: state.biometricEnabled,
                onChanged:
                    state.biometricAvailable
                        ? (value) => _changeBiometric(context, state, value)
                        : null,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),

      Text(
        'Activity on this device',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 4),
      const Text(
        'The last 300 events saved for your account on this device. This is not a complete or tamper-proof audit ledger.',
        style: TextStyle(fontSize: 12, color: AppColors.slate),
      ),
      const SizedBox(height: 12),

      if (state.auditLogs.isEmpty)
        const GlassContainer(
          child: Text(
            'Your document, study and assistant activity will appear here.',
            style: TextStyle(color: AppColors.slate),
          ),
        ),

      Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Find activity',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          IconButton(
            tooltip: 'Export device activity',
            onPressed:
                state.auditLogs.isEmpty ? null : () => _exportActivity(state),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('All activity'),
              selected: _category == null,
              onSelected: (_) => setState(() => _category = null),
            ),
            for (final category in _catColors.keys)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected:
                      (selected) => setState(
                        () => _category = selected ? category : null,
                      ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: headers.length + logs.length,
      itemBuilder: (context, index) {
        if (index < headers.length) return headers[index];
        final log = logs[index - headers.length];
        final c = _catColors[log.category] ?? AppColors.slate;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassContainer(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    log.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: c,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.action,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log.detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${log.time} · ${log.actor}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeBiometric(
    BuildContext context,
    AppState state,
    bool enabled,
  ) async {
    if (!enabled) {
      await state.setBiometricEnabled(false);
      return;
    }
    try {
      final verified = await LocalAuthentication().authenticate(
        localizedReason: 'Confirm your identity to enable biometric app lock',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (verified) {
        await state.setBiometricEnabled(true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric app lock enabled.')),
          );
        }
      }
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric verification was not completed.'),
          ),
        );
      }
    }
  }
}
