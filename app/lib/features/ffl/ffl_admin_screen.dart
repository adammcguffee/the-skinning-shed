import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../app/theme/app_colors.dart';
import '../../services/ffl_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// FFL ADMIN SCREEN - Import Status & Manual Trigger
// ════════════════════════════════════════════════════════════════════════════

class FFLAdminScreen extends ConsumerStatefulWidget {
  const FFLAdminScreen({super.key});

  @override
  ConsumerState<FFLAdminScreen> createState() => _FFLAdminScreenState();
}

class _FFLAdminScreenState extends ConsumerState<FFLAdminScreen> {
  bool _isTriggering = false;

  Future<void> _triggerImport() async {
    setState(() => _isTriggering = true);

    final service = ref.read(fflServiceProvider);
    final success = await service.triggerManualImport();

    if (mounted) {
      setState(() => _isTriggering = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Import triggered!' : 'Failed to trigger import'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );

      if (success) {
        // Refresh import runs after a delay
        await Future.delayed(const Duration(seconds: 2));
        ref.invalidate(fflImportRunsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final importRunsAsync = ref.watch(fflImportRunsProvider);
    final latestAsync = ref.watch(fflLatestImportProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'FFL Import Admin',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sync_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ATF FFL Import',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Monthly auto-import from ATF Complete Listing',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Latest successful import
                  latestAsync.when(
                    loading: () => const _LoadingRow(),
                    error: (_, __) => const _ErrorRow(message: 'Error loading status'),
                    data: (latest) {
                      if (latest == null) {
                        return const _InfoRow(
                          icon: Icons.info_outline_rounded,
                          color: AppColors.warning,
                          label: 'Status',
                          value: 'No successful imports yet',
                        );
                      }

                      return Column(
                        children: [
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            color: AppColors.success,
                            label: 'Last Imported',
                            value: latest.monthLabel,
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.schedule_rounded,
                            color: AppColors.textSecondary,
                            label: 'Import Time',
                            value: latest.finishedAt != null
                                ? timeago.format(latest.finishedAt!)
                                : 'Unknown',
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.storage_rounded,
                            color: AppColors.primary,
                            label: 'Records',
                            value: '${latest.rowsTotal ?? 0} total',
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Manual import button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isTriggering ? null : _triggerImport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isTriggering
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(_isTriggering ? 'Triggering...' : 'Run Import Now'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Import History
            const Text(
              'Import History',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            importRunsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading history'),
              data: (runs) {
                if (runs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: const Center(
                      child: Text(
                        'No import runs yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                return Column(
                  children: runs.map((run) => _ImportRunCard(run: run)).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Import runs automatically on the 3rd and 10th of each month at 4:10 AM UTC.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 12),
        Text('Loading...', style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
        const SizedBox(width: 12),
        Text(message, style: const TextStyle(color: AppColors.error)),
      ],
    );
  }
}

class _ImportRunCard extends StatelessWidget {
  const _ImportRunCard({required this.run});

  final FFLImportRun run;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (run.status) {
      'success' => AppColors.success,
      'failed' => AppColors.error,
      'running' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

    final statusIcon = switch (run.status) {
      'success' => Icons.check_circle_rounded,
      'failed' => Icons.cancel_rounded,
      'running' => Icons.sync_rounded,
      _ => Icons.help_outline_rounded,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.monthLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  run.status == 'success'
                      ? '${run.rowsInserted ?? 0} records'
                      : run.error ?? run.status,
                  style: TextStyle(
                    color: run.status == 'failed' ? AppColors.error : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Timestamp
          Text(
            run.finishedAt != null
                ? timeago.format(run.finishedAt!)
                : 'In progress',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
