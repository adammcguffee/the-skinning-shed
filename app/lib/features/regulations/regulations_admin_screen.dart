import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// Includes coverage dashboard, bulk import/export, and seed sources.
class RegulationsAdminScreen extends ConsumerStatefulWidget {
  const RegulationsAdminScreen({super.key});

  @override
  ConsumerState<RegulationsAdminScreen> createState() => _RegulationsAdminScreenState();
}

class _RegulationsAdminScreenState extends ConsumerState<RegulationsAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  List<PendingRegulation> _pendingRegulations = [];
  Map<String, Map<String, RegulationCoverage>> _coverage = {};
  bool _isRunningChecker = false;
  bool _showMissingOnly = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final pending = await service.fetchPendingRegulations();
      final coverage = await service.fetchCoverageData();
      
      if (mounted) {
        setState(() {
          _pendingRegulations = pending;
          _coverage = coverage;
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
  
  Future<void> _loadPendingRegulations() async {
    final service = ref.read(regulationsServiceProvider);
    final pending = await service.fetchPendingRegulations();
    if (mounted) {
      setState(() {
        _pendingRegulations = pending;
      });
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
  
  Future<void> _runChecker() async {
    setState(() => _isRunningChecker = true);
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final result = await service.runRegulationsChecker();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check complete: ${result['checked']} sources, ${result['changed']} changed'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error running checker: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRunningChecker = false);
      }
    }
  }
  
  Future<void> _showBulkImportDialog() async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Bulk Import Regulations'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste JSON array of regulations:',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    hintText: '[\n  {"state_code": "TX", "category": "deer", ...}\n]',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    
    controller.dispose();
    
    if (result != null && result.isNotEmpty) {
      try {
        final parsed = jsonDecode(result) as List;
        final regulations = parsed.map((e) => e as Map<String, dynamic>).toList();
        
        final service = ref.read(regulationsServiceProvider);
        final count = await service.importBulkRegulations(regulations);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported $count regulations to pending'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid JSON: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _exportRegulations() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final data = await service.exportRegulations();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      
      await Clipboard.setData(ClipboardData(text: json));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${data.length} regulations to clipboard'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }
  
  Future<void> _seedSources() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Seed Sources'),
        content: const Text(
          'This will upsert official source URLs for all 50 states from the seed file. '
          'Existing sources will be updated with new URLs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: const Text('Seed Sources'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      // Load seed data from assets or use embedded data
      final seedData = _getSourcesSeedData();
      
      final service = ref.read(regulationsServiceProvider);
      final result = await service.seedSources(seedData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seeded sources: ${result['inserted']} inserted, ${result['updated']} updated'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seed error: $e')),
        );
      }
    }
  }
  
  /// Get seed data for all 50 states - embedded for reliability
  List<Map<String, dynamic>> _getSourcesSeedData() {
    // Return embedded seed data for all 50 states
    return _allStatesSeedData;
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
                            'Manage regulations for all 50 states',
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
                      onPressed: _loadData,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              
              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    boxShadow: AppColors.shadowCard,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(text: 'Pending (${_pendingRegulations.length})'),
                    const Tab(text: 'Coverage'),
                    const Tab(text: 'Tools'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? AppErrorState(
                            message: _error!,
                            onRetry: _loadData,
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildPendingTab(),
                              _buildCoverageTab(),
                              _buildToolsTab(),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPendingTab() {
    if (_pendingRegulations.isEmpty) {
      return AppEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'All caught up!',
        message: 'No pending regulation updates to review.',
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: _pendingRegulations.length,
      itemBuilder: (context, index) {
        return _PendingRegulationCard(
          pending: _pendingRegulations[index],
          onApprove: () => _approvePending(_pendingRegulations[index]),
          onReject: () => _rejectPending(_pendingRegulations[index]),
        );
      },
    );
  }
  
  Widget _buildCoverageTab() {
    final allStates = USStates.all;
    final categories = ['deer', 'turkey', 'fishing'];
    
    // Filter states if showing missing only
    final filteredStates = _showMissingOnly
        ? allStates.where((state) {
            for (final cat in categories) {
              final cov = _coverage[state.code]?[cat];
              if (cov == null || cov.isMissing) return true;
            }
            return false;
          }).toList()
        : allStates;
    
    // Count totals
    int totalApproved = 0;
    int totalPending = 0;
    int totalMissing = 0;
    
    for (final state in allStates) {
      for (final cat in categories) {
        final cov = _coverage[state.code]?[cat];
        if (cov == null || cov.isMissing) {
          totalMissing++;
        } else if (cov.hasApproved) {
          totalApproved++;
        } else if (cov.hasPending) {
          totalPending++;
        }
      }
    }
    
    return Column(
      children: [
        // Summary row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Row(
            children: [
              _CoverageSummaryChip(
                label: 'Approved',
                count: totalApproved,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              _CoverageSummaryChip(
                label: 'Pending',
                count: totalPending,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              _CoverageSummaryChip(
                label: 'Missing',
                count: totalMissing,
                color: AppColors.error,
              ),
              const Spacer(),
              // Filter toggle
              Row(
                children: [
                  Text(
                    'Missing only',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: _showMissingOnly,
                    onChanged: (v) => setState(() => _showMissingOnly = v),
                    activeColor: AppColors.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        
        // Grid header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Row(
            children: [
              const SizedBox(width: 60),
              ...categories.map((cat) => Expanded(
                child: Center(
                  child: Text(
                    cat[0].toUpperCase() + cat.substring(1),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 4),
        
        // Grid
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            itemCount: filteredStates.length,
            itemBuilder: (context, index) {
              final state = filteredStates[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        state.code,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    ...categories.map((cat) {
                      final cov = _coverage[state.code]?[cat];
                      return Expanded(
                        child: Center(
                          child: _CoverageCell(coverage: cov),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildToolsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        children: [
          // Run Checker
          _RunCheckerButton(
            isRunning: _isRunningChecker,
            onPressed: _runChecker,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Seed Sources
          _ToolCard(
            icon: Icons.cloud_download_outlined,
            title: 'Seed Sources',
            description: 'Populate source URLs for all 50 states from embedded seed data',
            buttonLabel: 'Seed Sources',
            onPressed: _seedSources,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Bulk Import
          _ToolCard(
            icon: Icons.upload_file_outlined,
            title: 'Bulk Import',
            description: 'Import regulations from JSON into pending queue',
            buttonLabel: 'Import JSON',
            onPressed: _showBulkImportDialog,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Export
          _ToolCard(
            icon: Icons.download_outlined,
            title: 'Export Approved',
            description: 'Export all approved regulations as JSON to clipboard',
            buttonLabel: 'Export',
            onPressed: _exportRegulations,
          ),
        ],
      ),
    );
  }
}

class _RunCheckerButton extends StatelessWidget {
  const _RunCheckerButton({
    required this.isRunning,
    required this.onPressed,
  });
  
  final bool isRunning;
  final VoidCallback onPressed;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(
              Icons.sync_rounded,
              color: AppColors.info,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Regulations Checker',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Check official sources for updates',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isRunning ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            child: isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text('Run Now'),
          ),
        ],
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
    final showRegion = !pending.isStatewide;
    
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
                      showRegion
                          ? '$stateName - ${pending.category.label} - ${pending.regionLabel}'
                          : '$stateName - ${pending.category.label}',
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

class _CoverageSummaryChip extends StatelessWidget {
  const _CoverageSummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });
  
  final String label;
  final int count;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverageCell extends StatelessWidget {
  const _CoverageCell({this.coverage});
  
  final RegulationCoverage? coverage;
  
  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String tooltip;
    
    if (coverage == null || coverage!.isMissing) {
      icon = Icons.close_rounded;
      color = AppColors.error;
      tooltip = 'Missing';
    } else if (coverage!.hasApproved) {
      icon = Icons.check_circle_rounded;
      color = AppColors.success;
      tooltip = '${coverage!.approvedCount} approved';
    } else if (coverage!.hasPending) {
      icon = Icons.pending_rounded;
      color = AppColors.warning;
      tooltip = '${coverage!.pendingCount} pending';
    } else {
      icon = Icons.close_rounded;
      color = AppColors.error;
      tooltip = 'Missing';
    }
    
    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });
  
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

/// Embedded seed data for all 50 states - official wildlife agency regulation URLs
const _allStatesSeedData = <Map<String, dynamic>>[
  // Alabama
  {'state_code': 'AL', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.outdooralabama.com/hunting/deer-hunting', 'source_name': 'Alabama DCNR'},
  {'state_code': 'AL', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.outdooralabama.com/hunting/turkey-hunting', 'source_name': 'Alabama DCNR'},
  {'state_code': 'AL', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.outdooralabama.com/fishing', 'source_name': 'Alabama DCNR'},
  // Alaska
  {'state_code': 'AK', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.adfg.alaska.gov/index.cfm?adfg=hunting.main', 'source_name': 'Alaska DFG'},
  {'state_code': 'AK', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.adfg.alaska.gov/index.cfm?adfg=hunting.main', 'source_name': 'Alaska DFG'},
  {'state_code': 'AK', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.adfg.alaska.gov/index.cfm?adfg=fishregulations.main', 'source_name': 'Alaska DFG'},
  // Arizona
  {'state_code': 'AZ', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.azgfd.com/hunting/regulations/', 'source_name': 'Arizona Game & Fish'},
  {'state_code': 'AZ', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.azgfd.com/hunting/regulations/', 'source_name': 'Arizona Game & Fish'},
  {'state_code': 'AZ', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.azgfd.com/fishing/regulations/', 'source_name': 'Arizona Game & Fish'},
  // Arkansas
  {'state_code': 'AR', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.agfc.com/en/hunting/big-game/deer/', 'source_name': 'Arkansas GFC'},
  {'state_code': 'AR', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.agfc.com/en/hunting/big-game/turkey/', 'source_name': 'Arkansas GFC'},
  {'state_code': 'AR', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.agfc.com/en/fishing/regulations/', 'source_name': 'Arkansas GFC'},
  // California
  {'state_code': 'CA', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://wildlife.ca.gov/hunting/deer', 'source_name': 'California DFW'},
  {'state_code': 'CA', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://wildlife.ca.gov/hunting/upland-game-birds', 'source_name': 'California DFW'},
  {'state_code': 'CA', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://wildlife.ca.gov/fishing', 'source_name': 'California DFW'},
  // Colorado
  {'state_code': 'CO', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://cpw.state.co.us/thingstodo/Pages/Deer.aspx', 'source_name': 'Colorado Parks & Wildlife'},
  {'state_code': 'CO', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://cpw.state.co.us/thingstodo/Pages/Turkey.aspx', 'source_name': 'Colorado Parks & Wildlife'},
  {'state_code': 'CO', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://cpw.state.co.us/thingstodo/Pages/Fishing.aspx', 'source_name': 'Colorado Parks & Wildlife'},
  // Connecticut
  {'state_code': 'CT', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://portal.ct.gov/DEEP/Hunting/Deer/Deer-Hunting', 'source_name': 'Connecticut DEEP'},
  {'state_code': 'CT', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://portal.ct.gov/DEEP/Hunting/Turkey/Turkey-Hunting', 'source_name': 'Connecticut DEEP'},
  {'state_code': 'CT', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://portal.ct.gov/DEEP/Fishing/Fishing', 'source_name': 'Connecticut DEEP'},
  // Delaware
  {'state_code': 'DE', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://dnrec.delaware.gov/fish-wildlife/hunting/', 'source_name': 'Delaware DFW'},
  {'state_code': 'DE', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://dnrec.delaware.gov/fish-wildlife/hunting/', 'source_name': 'Delaware DFW'},
  {'state_code': 'DE', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://dnrec.delaware.gov/fish-wildlife/fishing/', 'source_name': 'Delaware DFW'},
  // Florida
  {'state_code': 'FL', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://myfwc.com/hunting/deer/', 'source_name': 'Florida FWC'},
  {'state_code': 'FL', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://myfwc.com/hunting/turkey/', 'source_name': 'Florida FWC'},
  {'state_code': 'FL', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://myfwc.com/fishing/', 'source_name': 'Florida FWC'},
  // Georgia
  {'state_code': 'GA', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://georgiawildlife.com/hunting/deer', 'source_name': 'Georgia DNR'},
  {'state_code': 'GA', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://georgiawildlife.com/hunting/turkey', 'source_name': 'Georgia DNR'},
  {'state_code': 'GA', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://georgiawildlife.com/fishing', 'source_name': 'Georgia DNR'},
  // Hawaii
  {'state_code': 'HI', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://dlnr.hawaii.gov/hunting/', 'source_name': 'Hawaii DLNR'},
  {'state_code': 'HI', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://dlnr.hawaii.gov/hunting/', 'source_name': 'Hawaii DLNR'},
  {'state_code': 'HI', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://dlnr.hawaii.gov/dar/fishing/', 'source_name': 'Hawaii DLNR'},
  // Idaho
  {'state_code': 'ID', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://idfg.idaho.gov/hunt/deer', 'source_name': 'Idaho Fish & Game'},
  {'state_code': 'ID', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://idfg.idaho.gov/hunt/turkey', 'source_name': 'Idaho Fish & Game'},
  {'state_code': 'ID', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://idfg.idaho.gov/fish', 'source_name': 'Idaho Fish & Game'},
  // Illinois
  {'state_code': 'IL', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www2.illinois.gov/dnr/hunting/deer/Pages/default.aspx', 'source_name': 'Illinois DNR'},
  {'state_code': 'IL', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www2.illinois.gov/dnr/hunting/turkey/Pages/default.aspx', 'source_name': 'Illinois DNR'},
  {'state_code': 'IL', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www2.illinois.gov/dnr/fishing/Pages/default.aspx', 'source_name': 'Illinois DNR'},
  // Indiana
  {'state_code': 'IN', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.in.gov/dnr/fish-and-wildlife/hunting-and-trapping/deer-hunting/', 'source_name': 'Indiana DNR'},
  {'state_code': 'IN', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.in.gov/dnr/fish-and-wildlife/hunting-and-trapping/turkey-hunting/', 'source_name': 'Indiana DNR'},
  {'state_code': 'IN', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.in.gov/dnr/fish-and-wildlife/fishing/', 'source_name': 'Indiana DNR'},
  // Iowa
  {'state_code': 'IA', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.iowadnr.gov/Hunting/Deer-Hunting', 'source_name': 'Iowa DNR'},
  {'state_code': 'IA', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.iowadnr.gov/Hunting/Turkey-Hunting', 'source_name': 'Iowa DNR'},
  {'state_code': 'IA', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.iowadnr.gov/Fishing', 'source_name': 'Iowa DNR'},
  // Kansas
  {'state_code': 'KS', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://ksoutdoors.com/Hunting/Big-Game/Deer', 'source_name': 'Kansas Wildlife'},
  {'state_code': 'KS', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://ksoutdoors.com/Hunting/Upland-Birds/Turkey', 'source_name': 'Kansas Wildlife'},
  {'state_code': 'KS', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://ksoutdoors.com/Fishing', 'source_name': 'Kansas Wildlife'},
  // Kentucky
  {'state_code': 'KY', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://fw.ky.gov/Hunt/Pages/Deer-Hunting.aspx', 'source_name': 'Kentucky DFW'},
  {'state_code': 'KY', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://fw.ky.gov/Hunt/Pages/Turkey-Hunting.aspx', 'source_name': 'Kentucky DFW'},
  {'state_code': 'KY', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://fw.ky.gov/Fish/Pages/default.aspx', 'source_name': 'Kentucky DFW'},
  // Louisiana
  {'state_code': 'LA', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wlf.louisiana.gov/page/deer', 'source_name': 'Louisiana WLF'},
  {'state_code': 'LA', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wlf.louisiana.gov/page/turkey', 'source_name': 'Louisiana WLF'},
  {'state_code': 'LA', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wlf.louisiana.gov/page/freshwater-fishing', 'source_name': 'Louisiana WLF'},
  // Maine
  {'state_code': 'ME', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.maine.gov/ifw/hunting-trapping/hunting-laws.html', 'source_name': 'Maine IFW'},
  {'state_code': 'ME', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.maine.gov/ifw/hunting-trapping/hunting-laws.html', 'source_name': 'Maine IFW'},
  {'state_code': 'ME', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.maine.gov/ifw/fishing-boating/fishing/laws-rules/', 'source_name': 'Maine IFW'},
  // Maryland
  {'state_code': 'MD', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://dnr.maryland.gov/wildlife/Pages/hunt_trap/deerhunting.aspx', 'source_name': 'Maryland DNR'},
  {'state_code': 'MD', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://dnr.maryland.gov/wildlife/Pages/hunt_trap/turkeyhunting.aspx', 'source_name': 'Maryland DNR'},
  {'state_code': 'MD', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://dnr.maryland.gov/fisheries/Pages/regulations/index.aspx', 'source_name': 'Maryland DNR'},
  // Massachusetts
  {'state_code': 'MA', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.mass.gov/info-details/deer-hunting-regulations', 'source_name': 'Massachusetts DFW'},
  {'state_code': 'MA', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.mass.gov/info-details/turkey-hunting-regulations', 'source_name': 'Massachusetts DFW'},
  {'state_code': 'MA', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.mass.gov/freshwater-fishing-regulations', 'source_name': 'Massachusetts DFW'},
  // Michigan
  {'state_code': 'MI', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.michigan.gov/dnr/things-to-do/hunting/deer', 'source_name': 'Michigan DNR'},
  {'state_code': 'MI', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.michigan.gov/dnr/things-to-do/hunting/turkey', 'source_name': 'Michigan DNR'},
  {'state_code': 'MI', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.michigan.gov/dnr/things-to-do/fishing', 'source_name': 'Michigan DNR'},
  // Minnesota
  {'state_code': 'MN', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.dnr.state.mn.us/hunting/deer/index.html', 'source_name': 'Minnesota DNR'},
  {'state_code': 'MN', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.dnr.state.mn.us/hunting/turkey/index.html', 'source_name': 'Minnesota DNR'},
  {'state_code': 'MN', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.dnr.state.mn.us/fishing/index.html', 'source_name': 'Minnesota DNR'},
  // Mississippi
  {'state_code': 'MS', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.mdwfp.com/wildlife-hunting/deer-program/', 'source_name': 'Mississippi DWFP'},
  {'state_code': 'MS', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.mdwfp.com/wildlife-hunting/turkey-program/', 'source_name': 'Mississippi DWFP'},
  {'state_code': 'MS', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.mdwfp.com/fishing-boating/', 'source_name': 'Mississippi DWFP'},
  // Missouri
  {'state_code': 'MO', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://mdc.mo.gov/hunting-trapping/species/deer', 'source_name': 'Missouri MDC'},
  {'state_code': 'MO', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://mdc.mo.gov/hunting-trapping/species/turkey', 'source_name': 'Missouri MDC'},
  {'state_code': 'MO', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://mdc.mo.gov/fishing', 'source_name': 'Missouri MDC'},
  // Montana
  {'state_code': 'MT', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://fwp.mt.gov/hunt/deer', 'source_name': 'Montana FWP'},
  {'state_code': 'MT', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://fwp.mt.gov/hunt/turkey', 'source_name': 'Montana FWP'},
  {'state_code': 'MT', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://fwp.mt.gov/fish', 'source_name': 'Montana FWP'},
  // Nebraska
  {'state_code': 'NE', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://outdoornebraska.gov/huntbiggame/', 'source_name': 'Nebraska Game & Parks'},
  {'state_code': 'NE', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://outdoornebraska.gov/huntturkey/', 'source_name': 'Nebraska Game & Parks'},
  {'state_code': 'NE', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://outdoornebraska.gov/fishing/', 'source_name': 'Nebraska Game & Parks'},
  // Nevada
  {'state_code': 'NV', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.ndow.org/hunt/big-game-hunting/deer/', 'source_name': 'Nevada DOW'},
  {'state_code': 'NV', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.ndow.org/hunt/upland-game/wild-turkey/', 'source_name': 'Nevada DOW'},
  {'state_code': 'NV', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.ndow.org/fish/', 'source_name': 'Nevada DOW'},
  // New Hampshire
  {'state_code': 'NH', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wildlife.nh.gov/hunting/deer', 'source_name': 'New Hampshire FG'},
  {'state_code': 'NH', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wildlife.nh.gov/hunting/turkey', 'source_name': 'New Hampshire FG'},
  {'state_code': 'NH', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wildlife.nh.gov/fishing', 'source_name': 'New Hampshire FG'},
  // New Jersey
  {'state_code': 'NJ', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.nj.gov/dep/fgw/deerinfo.htm', 'source_name': 'New Jersey DFW'},
  {'state_code': 'NJ', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.nj.gov/dep/fgw/turkinfo.htm', 'source_name': 'New Jersey DFW'},
  {'state_code': 'NJ', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.nj.gov/dep/fgw/fishinfo.htm', 'source_name': 'New Jersey DFW'},
  // New Mexico
  {'state_code': 'NM', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wildlife.state.nm.us/hunting/species/deer/', 'source_name': 'New Mexico DGF'},
  {'state_code': 'NM', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wildlife.state.nm.us/hunting/species/turkey/', 'source_name': 'New Mexico DGF'},
  {'state_code': 'NM', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wildlife.state.nm.us/fishing/', 'source_name': 'New Mexico DGF'},
  // New York
  {'state_code': 'NY', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.dec.ny.gov/outdoor/deer.html', 'source_name': 'New York DEC'},
  {'state_code': 'NY', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.dec.ny.gov/outdoor/turkey.html', 'source_name': 'New York DEC'},
  {'state_code': 'NY', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.dec.ny.gov/outdoor/fishing.html', 'source_name': 'New York DEC'},
  // North Carolina
  {'state_code': 'NC', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.ncwildlife.org/Hunting/Seasons-Regulations/Deer', 'source_name': 'North Carolina WRC'},
  {'state_code': 'NC', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.ncwildlife.org/Hunting/Seasons-Regulations/Turkey', 'source_name': 'North Carolina WRC'},
  {'state_code': 'NC', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.ncwildlife.org/Fishing/Regulations', 'source_name': 'North Carolina WRC'},
  // North Dakota
  {'state_code': 'ND', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://gf.nd.gov/hunting/deer', 'source_name': 'North Dakota GF'},
  {'state_code': 'ND', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://gf.nd.gov/hunting/turkey', 'source_name': 'North Dakota GF'},
  {'state_code': 'ND', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://gf.nd.gov/fishing', 'source_name': 'North Dakota GF'},
  // Ohio
  {'state_code': 'OH', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://ohiodnr.gov/buy-and-apply/hunting-fishing-boating/hunting-resources/deer', 'source_name': 'Ohio DNR'},
  {'state_code': 'OH', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://ohiodnr.gov/buy-and-apply/hunting-fishing-boating/hunting-resources/wild-turkey', 'source_name': 'Ohio DNR'},
  {'state_code': 'OH', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://ohiodnr.gov/buy-and-apply/hunting-fishing-boating/fishing-resources', 'source_name': 'Ohio DNR'},
  // Oklahoma
  {'state_code': 'OK', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wildlifedepartment.com/hunting/deer', 'source_name': 'Oklahoma DWC'},
  {'state_code': 'OK', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wildlifedepartment.com/hunting/turkey', 'source_name': 'Oklahoma DWC'},
  {'state_code': 'OK', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.wildlifedepartment.com/fishing', 'source_name': 'Oklahoma DWC'},
  // Oregon
  {'state_code': 'OR', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://myodfw.com/hunting/big-game/deer', 'source_name': 'Oregon DFW'},
  {'state_code': 'OR', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://myodfw.com/hunting/upland-birds/wild-turkey', 'source_name': 'Oregon DFW'},
  {'state_code': 'OR', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://myodfw.com/fishing', 'source_name': 'Oregon DFW'},
  // Pennsylvania
  {'state_code': 'PA', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.pgc.pa.gov/HuntTrap/Law/Pages/HuntTrapSeasonsDates.aspx', 'source_name': 'Pennsylvania GC'},
  {'state_code': 'PA', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.pgc.pa.gov/HuntTrap/Law/Pages/HuntTrapSeasonsDates.aspx', 'source_name': 'Pennsylvania GC'},
  {'state_code': 'PA', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.fishandboat.com/Fish/FishingRegulations/Pages/default.aspx', 'source_name': 'Pennsylvania Fish & Boat'},
  // Rhode Island
  {'state_code': 'RI', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://dem.ri.gov/natural-resources-bureau/fish-wildlife/hunting', 'source_name': 'Rhode Island DEM'},
  {'state_code': 'RI', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://dem.ri.gov/natural-resources-bureau/fish-wildlife/hunting', 'source_name': 'Rhode Island DEM'},
  {'state_code': 'RI', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://dem.ri.gov/natural-resources-bureau/fish-wildlife/freshwater-fisheries', 'source_name': 'Rhode Island DEM'},
  // South Carolina
  {'state_code': 'SC', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.dnr.sc.gov/hunting/deer/', 'source_name': 'South Carolina DNR'},
  {'state_code': 'SC', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.dnr.sc.gov/hunting/turkey/', 'source_name': 'South Carolina DNR'},
  {'state_code': 'SC', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.dnr.sc.gov/fishing/', 'source_name': 'South Carolina DNR'},
  // South Dakota
  {'state_code': 'SD', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://gfp.sd.gov/deer/', 'source_name': 'South Dakota GFP'},
  {'state_code': 'SD', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://gfp.sd.gov/turkey/', 'source_name': 'South Dakota GFP'},
  {'state_code': 'SD', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://gfp.sd.gov/fishing/', 'source_name': 'South Dakota GFP'},
  // Tennessee
  {'state_code': 'TN', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://www.tn.gov/twra/hunting/big-game/deer.html', 'source_name': 'Tennessee TWRA'},
  {'state_code': 'TN', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://www.tn.gov/twra/hunting/big-game/turkey.html', 'source_name': 'Tennessee TWRA'},
  {'state_code': 'TN', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://www.tn.gov/twra/fishing.html', 'source_name': 'Tennessee TWRA'},
  // Texas
  {'state_code': 'TX', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://tpwd.texas.gov/regulations/outdoor-annual/hunting/deer', 'source_name': 'Texas Parks & Wildlife'},
  {'state_code': 'TX', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://tpwd.texas.gov/regulations/outdoor-annual/hunting/turkey', 'source_name': 'Texas Parks & Wildlife'},
  {'state_code': 'TX', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://tpwd.texas.gov/regulations/outdoor-annual/fishing', 'source_name': 'Texas Parks & Wildlife'},
  // Utah
  {'state_code': 'UT', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://wildlife.utah.gov/deer.html', 'source_name': 'Utah DWR'},
  {'state_code': 'UT', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://wildlife.utah.gov/turkey.html', 'source_name': 'Utah DWR'},
  {'state_code': 'UT', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://wildlife.utah.gov/fishing-in-utah.html', 'source_name': 'Utah DWR'},
  // Vermont
  {'state_code': 'VT', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://vtfishandwildlife.com/hunt/deer-hunting', 'source_name': 'Vermont FW'},
  {'state_code': 'VT', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://vtfishandwildlife.com/hunt/turkey-hunting', 'source_name': 'Vermont FW'},
  {'state_code': 'VT', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://vtfishandwildlife.com/fish', 'source_name': 'Vermont FW'},
  // Virginia
  {'state_code': 'VA', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://dwr.virginia.gov/hunting/deer/', 'source_name': 'Virginia DWR'},
  {'state_code': 'VA', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://dwr.virginia.gov/hunting/turkey/', 'source_name': 'Virginia DWR'},
  {'state_code': 'VA', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://dwr.virginia.gov/fishing/', 'source_name': 'Virginia DWR'},
  // Washington
  {'state_code': 'WA', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://wdfw.wa.gov/hunting/regulations/deer', 'source_name': 'Washington DFW'},
  {'state_code': 'WA', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://wdfw.wa.gov/hunting/regulations/turkey', 'source_name': 'Washington DFW'},
  {'state_code': 'WA', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://wdfw.wa.gov/fishing/regulations', 'source_name': 'Washington DFW'},
  // West Virginia
  {'state_code': 'WV', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://wvdnr.gov/hunting/deer/', 'source_name': 'West Virginia DNR'},
  {'state_code': 'WV', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://wvdnr.gov/hunting/turkey/', 'source_name': 'West Virginia DNR'},
  {'state_code': 'WV', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://wvdnr.gov/fishing/', 'source_name': 'West Virginia DNR'},
  // Wisconsin
  {'state_code': 'WI', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://dnr.wisconsin.gov/topic/Hunt/deer', 'source_name': 'Wisconsin DNR'},
  {'state_code': 'WI', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://dnr.wisconsin.gov/topic/Hunt/turkey', 'source_name': 'Wisconsin DNR'},
  {'state_code': 'WI', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://dnr.wisconsin.gov/topic/Fishing', 'source_name': 'Wisconsin DNR'},
  // Wyoming
  {'state_code': 'WY', 'category': 'deer', 'region_key': 'STATEWIDE', 'source_url': 'https://wgfd.wyo.gov/Hunting/Deer', 'source_name': 'Wyoming Game & Fish'},
  {'state_code': 'WY', 'category': 'turkey', 'region_key': 'STATEWIDE', 'source_url': 'https://wgfd.wyo.gov/Hunting/Turkey', 'source_name': 'Wyoming Game & Fish'},
  {'state_code': 'WY', 'category': 'fishing', 'region_key': 'STATEWIDE', 'source_url': 'https://wgfd.wyo.gov/Fishing', 'source_name': 'Wyoming Game & Fish'},
];
