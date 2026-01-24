import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/regulations_service.dart';
import 'package:shed/shared/widgets/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🛡️ REGULATIONS ADMIN SCREEN - 2025 PREMIUM
/// 
/// Admin-only screen for reviewing and approving pending regulation updates.
class RegulationsAdminScreen extends ConsumerStatefulWidget {
  const RegulationsAdminScreen({super.key});

  @override
  ConsumerState<RegulationsAdminScreen> createState() => _RegulationsAdminScreenState();
}

class _RegulationsAdminScreenState extends ConsumerState<RegulationsAdminScreen> {
  bool _isLoading = true;
  String? _error;
  List<PendingRegulation> _pendingRegulations = [];
  
  @override
  void initState() {
    super.initState();
    _loadPendingRegulations();
  }
  
  Future<void> _loadPendingRegulations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final pending = await service.fetchPendingRegulations();
      
      if (mounted) {
        setState(() {
          _pendingRegulations = pending;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _approvePending(PendingRegulation pending) async {
    if (pending.proposedSummary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No proposed summary to approve')),
      );
      return;
    }
    
    try {
      final service = ref.read(regulationsServiceProvider);
      await service.approvePendingRegulation(pending.id, pending.proposedSummary!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Regulation approved successfully')),
        );
        _loadPendingRegulations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  Future<void> _rejectPending(PendingRegulation pending) async {
    final notesController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Reject Update'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add a note explaining the rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Optional notes...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final service = ref.read(regulationsServiceProvider);
        await service.rejectPendingRegulation(
          pending.id, 
          notesController.text.isEmpty ? null : notesController.text,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Regulation rejected')),
          );
          _loadPendingRegulations();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
    
    notesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Row(
                  children: [
                    _BackButton(onTap: () => context.pop()),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Regulations Admin',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Review pending regulation updates',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _loadPendingRegulations,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? AppErrorState(
                            message: _error!,
                            onRetry: _loadPendingRegulations,
                          )
                        : _pendingRegulations.isEmpty
                            ? AppEmptyState(
                                icon: Icons.check_circle_outline_rounded,
                                title: 'All caught up!',
                                message: 'No pending regulation updates to review.',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                                itemCount: _pendingRegulations.length,
                                itemBuilder: (context, index) {
                                  return _PendingRegulationCard(
                                    pending: _pendingRegulations[index],
                                    onApprove: () => _approvePending(_pendingRegulations[index]),
                                    onReject: () => _rejectPending(_pendingRegulations[index]),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  const _BackButton({required this.onTap});
  
  final VoidCallback onTap;
  
  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PendingRegulationCard extends StatelessWidget {
  const _PendingRegulationCard({
    required this.pending,
    required this.onApprove,
    required this.onReject,
  });

  final PendingRegulation pending;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final stateName = USStates.byCode(pending.stateCode)?.name ?? pending.stateCode;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      pending.stateCode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$stateName - ${pending.category.label}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              
              // Season label
              Text(
                'Season: ${pending.seasonYearLabel}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              
              // Diff summary
              if (pending.diffSummary != null && pending.diffSummary!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    pending.diffSummary!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              
              // Source URL
              if (pending.sourceUrl != null) ...[
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(pending.sourceUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 14, color: AppColors.info),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          pending.sourceUrl!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.info,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: AppSpacing.md),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: pending.proposedSummary != null ? onApprove : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.textInverse,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
