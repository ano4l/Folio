import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  static const Map<String, Color> _catColors = {
    'Access': AppColors.teal,
    'AI Queries': AppColors.purple,
    'Security': AppColors.navy,
    'Document': AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Text('Security & Compliance', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text('POPIA-aligned access controls and audit ledger',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),

        // Governance Toggles Group
        GlassContainer(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(CupertinoIcons.number, color: AppColors.teal, size: 20),
                ),
                title: const Text('Multi-factor authentication', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Require 6-digit code on sign-in', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                trailing: CupertinoSwitch(
                  activeTrackColor: AppColors.teal,
                  value: state.mfaEnabled,
                  onChanged: (_) => state.toggleMfa(),
                ),
              ),
              const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.line),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(CupertinoIcons.viewfinder, color: AppColors.teal, size: 20),
                ),
                title: const Text('Biometric unlock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Face ID / fingerprint passkey', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                trailing: CupertinoSwitch(
                  activeTrackColor: AppColors.teal,
                  value: state.biometricEnabled,
                  onChanged: (_) => state.toggleBiometric(),
                ),
              ),
              const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.line),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(CupertinoIcons.share, color: AppColors.teal, size: 20),
                ),
                title: const Text('Financial aid data share', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Share verified documents with funders', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                trailing: CupertinoSwitch(
                  activeTrackColor: AppColors.teal,
                  value: state.sharingEnabled,
                  onChanged: (_) => state.toggleSharing(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        Text('Immutable POPIA Access Ledger', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Every vault interaction is cryptographically logged.',
            style: TextStyle(fontSize: 12, color: AppColors.slate)),
        const SizedBox(height: 12),

        ...state.auditLogs.map((log) {
          final c = _catColors[log.category] ?? AppColors.slate;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassContainer(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(log.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.action, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text(log.detail, style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.3)),
                        const SizedBox(height: 4),
                        Text(' · ', style: const TextStyle(fontSize: 11, color: AppColors.slate)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
