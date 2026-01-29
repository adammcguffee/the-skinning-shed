import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/moderation_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Admin Reports Page - View and manage user reports.
class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ContentReport> _pendingReports = [];
  List<ContentReport> _resolvedReports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(moderationServiceProvider);
      
      final pending = await service.fetchReports(statusFilter: 'pending');
      final resolved = await service.fetchReports(statusFilter: 'resolved');
      
      if (mounted) {
        setState(() {
          _pendingReports = pending;
          _resolvedReports = resolved;
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

  Future<void> _resolveReport(ContentReport report, String resolution) async {
    try {
      final service = ref.read(moderationServiceProvider);
      await service.resolveReport(reportId: report.id, resolution: resolution);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report marked as: $resolution'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showResolveMenu(ContentReport report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              // Title
              Text(
                'Resolve Report',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose an action for this report:',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              // Actions
              _ResolveOption(
                icon: Icons.check_circle_outline,
                label: 'No Action Needed',
                subtitle: 'Content is fine, dismiss report',
                color: AppColors.success,
                onTap: () {
                  Navigator.pop(ctx);
                  _resolveReport(report, 'no_action');
                },
              ),
              _ResolveOption(
                icon: Icons.warning_amber_outlined,
                label: 'Warning Issued',
                subtitle: 'User warned but content stays',
                color: AppColors.warning,
                onTap: () {
                  Navigator.pop(ctx);
                  _resolveReport(report, 'warning');
                },
              ),
              _ResolveOption(
                icon: Icons.delete_outline,
                label: 'Content Removed',
                subtitle: 'Violating content was deleted',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(ctx);
                  _resolveReport(report, 'removed');
                },
              ),
              _ResolveOption(
                icon: Icons.close_outlined,
                label: 'Dismissed',
                subtitle: 'False or invalid report',
                color: AppColors.textTertiary,
                onTap: () {
                  Navigator.pop(ctx);
                  _resolveReport(report, 'dismissed');
                },
              ),
              
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            PageHeader(
              title: 'Reports',
              subtitle: '${_pendingReports.length} pending',
            ),
            
            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.textInverse,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: 'Pending (${_pendingReports.length})'),
                  Tab(text: 'Resolved (${_resolvedReports.length})'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.accent),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: AppColors.error),
                              const SizedBox(height: AppSpacing.md),
                              Text('Error: $_error', style: TextStyle(color: AppColors.error)),
                              const SizedBox(height: AppSpacing.md),
                              ElevatedButton(
                                onPressed: _loadReports,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildReportsList(_pendingReports, isPending: true),
                            _buildReportsList(_resolvedReports, isPending: false),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList(List<ContentReport> reports, {required bool isPending}) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline : Icons.history,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isPending ? 'No pending reports' : 'No resolved reports yet',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          return           _ReportCard(
            report: report,
            onResolve: isPending ? () => _showResolveMenu(report) : null,
            onViewTarget: () {
              if (report.isPostReport && report.postId != null) {
                context.push('/trophy/${report.postId}');
              } else if (report.isSwapShopReport && report.swapShopListingId != null) {
                context.push('/swap-shop/${report.swapShopListingId}');
              }
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    this.onResolve,
    this.onViewTarget,
  });

  final ContentReport report;
  final VoidCallback? onResolve;
  final VoidCallback? onViewTarget;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: report.isPending ? AppColors.warning.withValues(alpha: 0.3) : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: report.isPostReport 
                      ? AppColors.accent.withValues(alpha: 0.1)
                      : report.isSwapShopReport
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  report.targetType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: report.isPostReport 
                        ? AppColors.accent 
                        : report.isSwapShopReport 
                            ? AppColors.success 
                            : AppColors.info,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              
              // Reason badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  report.reasonLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Status or time
              if (report.isPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                )
              else
                Text(
                  report.resolution ?? 'resolved',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Content preview
          Text(
            report.targetPreview,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Details if provided
          if (report.details != null && report.details!.isNotEmpty) ...[
            Text(
              'Details: ${report.details}',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          
          // Meta info
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Reported by ${report.reporterName ?? 'Unknown'} • ${timeago.format(report.createdAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          if (report.targetOwnerName != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.account_circle_outlined, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  'Content owner: ${report.targetOwnerName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
          
          // Actions
          if (onResolve != null || onViewTarget != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (onViewTarget != null && (report.isPostReport || report.isSwapShopReport))
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewTarget,
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: Text(report.isSwapShopReport ? 'View Listing' : 'View Post'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.borderSubtle),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                if (onViewTarget != null && (report.isPostReport || report.isSwapShopReport) && onResolve != null)
                  const SizedBox(width: AppSpacing.sm),
                if (onResolve != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onResolve,
                      icon: const Icon(Icons.gavel_outlined, size: 16),
                      label: const Text('Resolve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textInverse,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ResolveOption extends StatelessWidget {
  const _ResolveOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
