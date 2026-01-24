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
  Map<String, int> _checkerStats = {'auto_approved': 0, 'pending': 0, 'manual': 0};
  bool _isRunningChecker = false;
  bool _showMissingOnly = false;
  Map<String, dynamic>? _lastRunResult;
  SourceCounts _sourceCounts = const SourceCounts();
  Map<String, dynamic> _coverageStats = {};
  
  // Portal links coverage
  List<StatePortalLinks> _portalLinks = [];
  bool _isVerifyingLinks = false;
  
  // Discovery run state (full 50-state discovery with progress)
  DiscoveryRun? _activeDiscoveryRun;
  DiscoveryRunProgress? _discoveryProgress;
  List<DiscoveryRunItem> _discoveryItems = [];
  bool _isDiscoveryRunning = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Added Links tab
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
      final stats = await service.getCheckerStats(days: 7);
      final sourceCounts = await service.fetchSourceCounts();
      final coverageStats = await service.fetchCoverageStats();
      final portalLinks = await service.fetchAllPortalLinks();
      
      // Check for active discovery run (resume after refresh)
      final activeRun = await service.getActiveDiscoveryRun();
      
      if (mounted) {
        setState(() {
          _pendingRegulations = pending;
          _coverage = coverage;
          _checkerStats = stats;
          _sourceCounts = sourceCounts;
          _coverageStats = coverageStats;
          _portalLinks = portalLinks;
          _activeDiscoveryRun = activeRun;
          _isDiscoveryRunning = activeRun?.isRunning ?? false;
          _isLoading = false;
        });
        
        // If there's an active run, resume it
        if (activeRun?.isRunning == true) {
          _resumeDiscoveryRun(activeRun!.id);
        }
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
  
  Future<void> _loadPortalLinks() async {
    final service = ref.read(regulationsServiceProvider);
    final portalLinks = await service.fetchAllPortalLinks();
    if (mounted) {
      setState(() {
        _portalLinks = portalLinks;
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
        setState(() => _lastRunResult = result);
        
        final autoApproved = result['auto_approved'] ?? 0;
        final pending = result['pending'] ?? 0;
        final checked = result['checked'] ?? 0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Check complete: $checked sources. '
              'Auto-approved: $autoApproved, Pending: $pending'
            ),
            backgroundColor: autoApproved > 0 ? AppColors.success : AppColors.info,
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
  
  Future<void> _loadCoverageStats() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final stats = await service.fetchCoverageStats();
      if (mounted) {
        setState(() => _coverageStats = stats);
      }
    } catch (e) {
      // ignore
    }
  }
  
  Future<void> _deleteJunkPending() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final deleted = await service.deleteJunkPending();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $deleted junk pending items'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
  
  Future<void> _verifyPortalLinks() async {
    setState(() => _isVerifyingLinks = true);
    try {
      final service = ref.read(regulationsServiceProvider);
      final result = await service.verifyPortalLinks();
      
      final ok = result['verified_ok'] ?? result['ok'] ?? 0;
      final broken = result['failed'] ?? result['broken'] ?? 0;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verified: $ok OK, $broken broken'),
            backgroundColor: broken > 0 ? AppColors.warning : AppColors.success,
          ),
        );
        _loadData(); // Reload to show updated verification status
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verify error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifyingLinks = false);
      }
    }
  }
  
  Future<void> _showEditLinksDialog(StatePortalLinks links) async {
    final seasonsController = TextEditingController(text: links.seasonsUrl ?? '');
    final regsController = TextEditingController(text: links.regulationsUrl ?? '');
    final fishingController = TextEditingController(text: links.fishingUrl ?? '');
    final licensingController = TextEditingController(text: links.licensingUrl ?? '');
    final buyController = TextEditingController(text: links.buyLicenseUrl ?? '');
    final recordsController = TextEditingController(text: links.recordsUrl ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Edit Links: ${links.stateName}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LinkTextField(
                  label: 'Hunting Seasons URL',
                  controller: seasonsController,
                  isVerified: links.verifiedSeasonsOk,
                ),
                const SizedBox(height: AppSpacing.sm),
                _LinkTextField(
                  label: 'Hunting Regulations URL',
                  controller: regsController,
                  isVerified: links.verifiedRegsOk,
                ),
                const SizedBox(height: AppSpacing.sm),
                _LinkTextField(
                  label: 'Fishing Regulations URL',
                  controller: fishingController,
                  isVerified: links.verifiedFishingOk,
                ),
                const SizedBox(height: AppSpacing.sm),
                _LinkTextField(
                  label: 'Licensing Info URL',
                  controller: licensingController,
                  isVerified: links.verifiedLicensingOk,
                ),
                const SizedBox(height: AppSpacing.sm),
                _LinkTextField(
                  label: 'Buy License URL',
                  controller: buyController,
                  isVerified: links.verifiedBuyLicenseOk,
                ),
                const SizedBox(height: AppSpacing.sm),
                _LinkTextField(
                  label: 'Records URL (optional)',
                  controller: recordsController,
                  isVerified: links.verifiedRecordsOk,
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: AppColors.info),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Changed URLs will be marked as unverified. Run "Verify Now" after editing.',
                          style: TextStyle(fontSize: 11, color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      try {
        final service = ref.read(regulationsServiceProvider);
        await service.updatePortalLink(
          stateCode: links.stateCode,
          huntingSeasonsUrl: seasonsController.text,
          huntingRegsUrl: regsController.text,
          fishingRegsUrl: fishingController.text,
          licensingUrl: licensingController.text,
          buyLicenseUrl: buyController.text,
          recordsUrl: recordsController.text,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Links updated. Run Verify to check.'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
    
    seasonsController.dispose();
    regsController.dispose();
    fishingController.dispose();
    licensingController.dispose();
    buyController.dispose();
    recordsController.dispose();
  }
  
  /// Start a new full discovery run (all 50 states with progress tracking).
  Future<void> _startFullDiscovery() async {
    if (_isDiscoveryRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discovery already in progress')),
      );
      return;
    }
    
    try {
      setState(() {
        _isDiscoveryRunning = true;
        _discoveryProgress = null;
        _discoveryItems = [];
      });
      
      final service = ref.read(regulationsServiceProvider);
      final run = await service.startDiscoveryRun(batchSize: 5);
      
      setState(() {
        _activeDiscoveryRun = run;
      });
      
      // Start processing batches
      await _runDiscoveryLoop(run.id);
      
    } catch (e) {
      setState(() {
        _isDiscoveryRunning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Discovery error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
  
  /// Resume an existing discovery run.
  Future<void> _resumeDiscoveryRun(String runId) async {
    if (_isDiscoveryRunning) return;
    
    setState(() {
      _isDiscoveryRunning = true;
    });
    
    await _runDiscoveryLoop(runId);
  }
  
  /// Process discovery batches in a loop until done.
  Future<void> _runDiscoveryLoop(String runId) async {
    final service = ref.read(regulationsServiceProvider);
    
    try {
      while (mounted && _isDiscoveryRunning) {
        final progress = await service.continueDiscoveryRun(runId);
        
        if (mounted) {
          setState(() {
            _discoveryProgress = progress;
          });
        }
        
        // Check if done
        if (progress.isDone || progress.status != 'running') {
          // Load final items for audit
          final items = await service.getDiscoveryRunItems(runId);
          
          if (mounted) {
            setState(() {
              _isDiscoveryRunning = false;
              _discoveryItems = items;
            });
            
            // Refresh portal links
            await _loadPortalLinks();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Discovery complete: ${progress.statsOk} ok, ${progress.statsSkipped} skipped, ${progress.statsError} errors'),
                backgroundColor: AppColors.success,
              ),
            );
          }
          return;
        }
        
        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDiscoveryRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Discovery error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
  
  /// Cancel the active discovery run.
  Future<void> _cancelDiscovery() async {
    if (_activeDiscoveryRun == null) return;
    
    try {
      final service = ref.read(regulationsServiceProvider);
      await service.cancelDiscoveryRun(_activeDiscoveryRun!.id);
      
      setState(() {
        _isDiscoveryRunning = false;
        _activeDiscoveryRun = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discovery canceled')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancel error: $e')),
      );
    }
  }
  
  /// Legacy method - now starts full discovery.
  Future<void> _discoverPortalLinks() async {
    await _startFullDiscovery();
  }
  
  Future<void> _showBrokenLinksReport() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final broken = await service.fetchBrokenLinks();
      
      if (!mounted) return;
      
      if (broken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No broken links! All portal links verified.'),
            backgroundColor: AppColors.success,
          ),
        );
        return;
      }
      
      showShedCenterModal(
        context: context,
        title: 'Broken Links (${broken.length} states)',
        maxWidth: 600,
        maxHeight: 700,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: broken.length,
          itemBuilder: (context, index) {
            final state = broken[index];
            return ListTile(
              title: Text('${state['state_name']} (${state['state_code']})'),
              subtitle: Text('Last verified: ${state['last_verified_at'] ?? 'never'}'),
              trailing: const Icon(Icons.warning_rounded, color: AppColors.warning),
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  Future<void> _showResetConfirmation() async {
    final confirmController = TextEditingController();
    bool includeAuditLog = false;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              const Text('Reset Regulations Data'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will DELETE:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '• All pending regulations\n'
                  '• All approved regulations\n'
                  '• All extraction sources',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                // Checkbox for audit log
                Row(
                  children: [
                    Checkbox(
                      value: includeAuditLog,
                      onChanged: (v) => setDialogState(() => includeAuditLog = v ?? false),
                      activeColor: AppColors.error,
                    ),
                    Expanded(
                      child: Text(
                        'Also delete audit log',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Portal links will be preserved but marked unverified.',
                          style: TextStyle(fontSize: 11, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Type RESET to confirm:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: confirmController,
                  decoration: InputDecoration(
                    hintText: 'RESET',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (confirmController.text.trim().toUpperCase() == 'RESET') {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Type RESET to confirm')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Reset Data'),
            ),
          ],
        ),
      ),
    );
    
    confirmController.dispose();
    
    if (confirmed == true) {
      try {
        final service = ref.read(regulationsServiceProvider);
        // Use the checkbox value - includeAuditLog is in outer scope, accessible here
        final result = await service.resetRegulationsData(includeAuditLog: includeAuditLog);
        
        if (mounted) {
          final auditCount = result['audit'] as int? ?? 0;
          final auditMsg = auditCount > 0 ? ', $auditCount audit' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reset: ${result['pending']} pending, ${result['approved']} approved, ${result['sources']} sources$auditMsg deleted'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reset error: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _seedSources() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Seed Extraction Sources'),
        content: const Text(
          'This will upsert 150 official source URLs (50 states × 3 categories) for extraction. '
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
  
  Future<void> _seedPortalLinks() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Seed Portal Links'),
        content: const Text(
          'This will upsert portal links for all 50 states. '
          'Portal links provide quick access to seasons, regulations, licensing, and fishing pages.',
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
            child: const Text('Seed Portal'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final portalData = _getPortalLinksSeedData();
      final service = ref.read(regulationsServiceProvider);
      final result = await service.seedPortalLinks(portalData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seeded portal links: ${result['inserted']} inserted, ${result['updated']} updated'),
            backgroundColor: AppColors.success,
          ),
        );
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
  
  /// Get portal links seed data for all 50 states
  List<Map<String, dynamic>> _getPortalLinksSeedData() {
    return _allStatesPortalLinks;
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
              
              // Automation explanation banner
              Container(
                margin: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding, 
                  0, 
                  AppSpacing.screenPadding, 
                  AppSpacing.md,
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Automated Updates',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Weekly automation checks official sources. High-confidence changes auto-approve. Others appear in Pending for manual review.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
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
                    const Tab(text: 'Links'),
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
                              _buildLinksTab(),
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
        // Summary row - wrapped to prevent overflow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CoverageSummaryChip(
                label: 'Approved',
                count: totalApproved,
                color: AppColors.success,
              ),
              _CoverageSummaryChip(
                label: 'Pending',
                count: totalPending,
                color: AppColors.warning,
              ),
              _CoverageSummaryChip(
                label: 'Missing',
                count: totalMissing,
                color: AppColors.error,
              ),
              // Filter toggle
              Row(
                mainAxisSize: MainAxisSize.min,
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
                    overflow: TextOverflow.ellipsis,
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
  
  Widget _buildLinksTab() {
    final allStates = USStates.all;
    
    // Build map for quick lookup
    final linksMap = <String, StatePortalLinks>{};
    for (final link in _portalLinks) {
      linksMap[link.stateCode] = link;
    }
    
    // Count stats - ALL counts are per STATE (not per URL field)
    int verifiedCount = 0;  // States with at least one verified link
    int brokenCount = 0;    // States with URLs but none verified
    int missingCount = 0;   // States with no URLs at all
    
    for (final state in allStates) {
      final link = linksMap[state.code];
      if (link == null) {
        // No portal links record for this state
        missingCount++;
      } else if (link.hasAnyVerifiedLinks) {
        // At least one verified link - counts as verified state
        verifiedCount++;
      } else if (link.hasSeasons || link.hasRegulations || link.hasFishing || 
                 link.hasLicensing || link.hasBuyLicense || link.hasRecords) {
        // Has URLs but none are verified - broken state
        brokenCount++;
      } else {
        // Has portal links record but no URLs populated
        missingCount++;
      }
    }
    
    return Column(
      children: [
        // Header with verify button and stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trust banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_rounded, size: 20, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Official State Agency Sources Only',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Links must be verified 200 OK to show in app. Unverified links show "Unavailable".',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              
              // Stats row
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _CoverageSummaryChip(
                    label: 'Verified',
                    count: verifiedCount,
                    color: AppColors.success,
                  ),
                  _CoverageSummaryChip(
                    label: 'Broken',
                    count: brokenCount,
                    color: AppColors.error,
                  ),
                  _CoverageSummaryChip(
                    label: 'Missing',
                    count: missingCount,
                    color: AppColors.textTertiary,
                  ),
                  // Verify button
                  ElevatedButton.icon(
                    onPressed: _isVerifyingLinks ? null : _verifyPortalLinks,
                    icon: _isVerifyingLinks
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_rounded, size: 14),
                    label: const Text('Verify All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        
        // Column headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Row(
            children: const [
              SizedBox(width: 50, child: Text('State', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              Expanded(child: Center(child: Text('Seasons', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
              Expanded(child: Center(child: Text('Regs', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
              Expanded(child: Center(child: Text('Fish', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
              Expanded(child: Center(child: Text('License', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
              Expanded(child: Center(child: Text('Buy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
              SizedBox(width: 36),
            ],
          ),
        ),
        const Divider(height: 8),
        
        // Links matrix
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            itemCount: allStates.length,
            itemBuilder: (context, index) {
              final state = allStates[index];
              final link = linksMap[state.code];
              
              return _PortalLinksRow(
                stateCode: state.code,
                links: link,
                onEdit: link != null ? () => _showEditLinksDialog(link) : null,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DISCOVERY PROGRESS PANEL (shown when running or has recent results)
          if (_isDiscoveryRunning || _discoveryProgress != null)
            _DiscoveryProgressPanel(
              progress: _discoveryProgress,
              isRunning: _isDiscoveryRunning,
              items: _discoveryItems,
              onCancel: _cancelDiscovery,
            ),
          if (_isDiscoveryRunning || _discoveryProgress != null)
            const SizedBox(height: AppSpacing.lg),
          
          // SETUP WIZARD - Clear step-by-step guide
          _SetupWizardCard(
            portalCount: _coverageStats['portal_coverage'] as int? ?? 0,
            verifiedCount: _portalLinks.where((l) => l.hasAnyVerifiedLinks).length,
            isVerifying: _isVerifyingLinks,
            isDiscovering: _isDiscoveryRunning,
            discoveryProgress: _discoveryProgress,
            onSeedPortal: _seedPortalLinks,
            onVerify: _verifyPortalLinks,
            onDiscover: _startFullDiscovery,
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Coverage Dashboard (portal-first)
          _CoverageDashboardCard(
            stats: _coverageStats,
            onRefresh: _loadCoverageStats,
            onDeleteJunk: _deleteJunkPending,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // How it works explanation
          _HowItWorksCard(),
          const SizedBox(height: AppSpacing.md),
          
          // Source counts display
          _SourceCountsCard(counts: _sourceCounts),
          const SizedBox(height: AppSpacing.md),
          
          // Checker stats header
          _CheckerStatsCard(
            stats: _checkerStats,
            lastResult: _lastRunResult,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Run Checker
          _RunCheckerButton(
            isRunning: _isRunningChecker,
            onPressed: _runChecker,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Seed section header
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Seed Data',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          
          // Seed Portal Links (50)
          _ToolCard(
            icon: Icons.link_rounded,
            title: 'Step 1: Seed Portal Links',
            description: 'Creates official agency link buttons for all 50 states (from official roots table)',
            buttonLabel: 'Seed Portal Links',
            onPressed: _seedPortalLinks,
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Seed Extraction Sources (150)
          _ToolCard(
            icon: Icons.cloud_download_outlined,
            title: 'Seed Extraction Sources (Optional)',
            description: 'Populate 150 source URLs for facts extraction (50 states × 3 categories)',
            buttonLabel: 'Seed Sources',
            onPressed: _seedSources,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Portal Links section
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Portal Links Management',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          
          // Verify Links
          _ToolCard(
            icon: Icons.verified_rounded,
            title: 'Step 2: Verify Portal Links',
            description: 'Checks each link responds with HTTP 200. Broken links are hidden from users.',
            buttonLabel: 'Verify All Links',
            onPressed: _verifyPortalLinks,
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Discover Links (Official Domains Only) - Full 50-state run
          _ToolCard(
            icon: Icons.travel_explore_rounded,
            title: 'Full Discovery (All 50 States)',
            description: _isDiscoveryRunning
                ? 'Discovery in progress: ${_discoveryProgress?.processed ?? 0}/${_discoveryProgress?.total ?? 50}'
                : 'Crawls all official .gov sites to find portal links. Shows live progress.',
            buttonLabel: _isDiscoveryRunning 
                ? 'Running... ${_discoveryProgress?.processed ?? 0}/50' 
                : 'Run Full Discovery',
            onPressed: _isDiscoveryRunning ? () {} : () => _startFullDiscovery(),
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Broken Links Report
          _ToolCard(
            icon: Icons.link_off_rounded,
            title: 'Broken Links Report',
            description: 'View and fix broken portal links',
            buttonLabel: 'View Report',
            onPressed: _showBrokenLinksReport,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Import/Export section
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Import / Export',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          
          // Bulk Import
          _ToolCard(
            icon: Icons.upload_file_outlined,
            title: 'Bulk Import',
            description: 'Import regulations from JSON into pending queue',
            buttonLabel: 'Import JSON',
            onPressed: _showBulkImportDialog,
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Export
          _ToolCard(
            icon: Icons.download_outlined,
            title: 'Export Approved',
            description: 'Export all approved regulations as JSON to clipboard',
            buttonLabel: 'Export',
            onPressed: _exportRegulations,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Danger Zone
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Danger Zone',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
          
          // Reset Data
          _ToolCard(
            icon: Icons.delete_forever_rounded,
            title: 'Reset Regulations Data',
            description: 'Delete all pending, approved, and sources. Keeps portal links.',
            buttonLabel: 'Reset',
            onPressed: _showResetConfirmation,
            isDanger: true,
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
    final confidencePercent = (pending.confidenceScore * 100).toInt();
    final isHighConfidence = pending.isHighConfidence;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with confidence badge
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
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Confidence badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isHighConfidence 
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      '$confidencePercent%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isHighConfidence ? AppColors.success : AppColors.warning,
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
              
              // Pending reason (prominent)
              if (pending.pendingReason != null && pending.pendingReason!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          pending.pendingReason!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Extraction warnings
              if (pending.extractionWarnings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: pending.extractionWarnings.map((warning) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      warning,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.warning,
                      ),
                    ),
                  )).toList(),
                ),
              ],
              
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
              
              // Actions - Wrap to prevent overflow on small screens
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
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
    this.isDanger = false,
  });
  
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool isDanger;
  
  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppColors.error : AppColors.accent;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDanger ? AppColors.error.withValues(alpha: 0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isDanger ? AppColors.error.withValues(alpha: 0.3) : AppColors.borderSubtle
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDanger ? AppColors.error : AppColors.textPrimary,
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
              backgroundColor: color,
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

/// Portal links seed data for all 50 states
const _allStatesPortalLinks = <Map<String, dynamic>>[
  {'state_code': 'AL', 'state_name': 'Alabama', 'agency_name': 'Alabama DCNR', 'seasons_url': 'https://www.outdooralabama.com/hunting/seasons-bag-limits', 'regulations_url': 'https://www.outdooralabama.com/hunting', 'licensing_url': 'https://www.outdooralabama.com/licenses', 'buy_license_url': 'https://www.outdooralabama.com/licenses/buy-licenses-online', 'fishing_url': 'https://www.outdooralabama.com/fishing'},
  {'state_code': 'AK', 'state_name': 'Alaska', 'agency_name': 'Alaska DFG', 'seasons_url': 'https://www.adfg.alaska.gov/index.cfm?adfg=huntingmain.main', 'regulations_url': 'https://www.adfg.alaska.gov/index.cfm?adfg=hunting.main', 'licensing_url': 'https://www.adfg.alaska.gov/index.cfm?adfg=license.main', 'buy_license_url': 'https://store.prior.adfg.state.ak.us/', 'fishing_url': 'https://www.adfg.alaska.gov/index.cfm?adfg=fishregulations.main'},
  {'state_code': 'AZ', 'state_name': 'Arizona', 'agency_name': 'Arizona Game & Fish', 'seasons_url': 'https://www.azgfd.com/hunting/regulations/', 'regulations_url': 'https://www.azgfd.com/hunting/', 'licensing_url': 'https://www.azgfd.com/license/', 'buy_license_url': 'https://license.azgfd.com/', 'fishing_url': 'https://www.azgfd.com/fishing/regulations/'},
  {'state_code': 'AR', 'state_name': 'Arkansas', 'agency_name': 'Arkansas GFC', 'seasons_url': 'https://www.agfc.com/en/hunting/seasons/', 'regulations_url': 'https://www.agfc.com/en/hunting/', 'licensing_url': 'https://www.agfc.com/en/licenses/', 'buy_license_url': 'https://www.agfc.com/en/buy-a-license/', 'fishing_url': 'https://www.agfc.com/en/fishing/regulations/'},
  {'state_code': 'CA', 'state_name': 'California', 'agency_name': 'California DFW', 'seasons_url': 'https://wildlife.ca.gov/hunting', 'regulations_url': 'https://wildlife.ca.gov/hunting', 'licensing_url': 'https://wildlife.ca.gov/licensing', 'buy_license_url': 'https://wildlife.ca.gov/Licensing/Hunting', 'fishing_url': 'https://wildlife.ca.gov/fishing'},
  {'state_code': 'CO', 'state_name': 'Colorado', 'agency_name': 'Colorado Parks & Wildlife', 'seasons_url': 'https://cpw.state.co.us/thingstodo/Pages/Hunting.aspx', 'regulations_url': 'https://cpw.state.co.us/thingstodo/Pages/Hunting.aspx', 'licensing_url': 'https://cpw.state.co.us/buyapply/Pages/Hunting.aspx', 'buy_license_url': 'https://cpw.state.co.us/buyapply/Pages/Hunting.aspx', 'fishing_url': 'https://cpw.state.co.us/thingstodo/Pages/Fishing.aspx'},
  {'state_code': 'CT', 'state_name': 'Connecticut', 'agency_name': 'Connecticut DEEP', 'seasons_url': 'https://portal.ct.gov/DEEP/Hunting/Hunting-Seasons', 'regulations_url': 'https://portal.ct.gov/DEEP/Hunting/Hunting', 'licensing_url': 'https://portal.ct.gov/DEEP/Hunting/Hunting-License', 'buy_license_url': 'https://ct.aspirafocus.com/internetsales', 'fishing_url': 'https://portal.ct.gov/DEEP/Fishing/Fishing'},
  {'state_code': 'DE', 'state_name': 'Delaware', 'agency_name': 'Delaware DFW', 'seasons_url': 'https://dnrec.delaware.gov/fish-wildlife/hunting/', 'regulations_url': 'https://dnrec.delaware.gov/fish-wildlife/hunting/', 'licensing_url': 'https://dnrec.delaware.gov/fish-wildlife/licenses/', 'buy_license_url': 'https://dnrec.delaware.gov/fish-wildlife/licenses/', 'fishing_url': 'https://dnrec.delaware.gov/fish-wildlife/fishing/'},
  {'state_code': 'FL', 'state_name': 'Florida', 'agency_name': 'Florida FWC', 'seasons_url': 'https://myfwc.com/hunting/season-dates/', 'regulations_url': 'https://myfwc.com/hunting/', 'licensing_url': 'https://myfwc.com/license/', 'buy_license_url': 'https://gooutdoorsflorida.com/', 'fishing_url': 'https://myfwc.com/fishing/'},
  {'state_code': 'GA', 'state_name': 'Georgia', 'agency_name': 'Georgia DNR', 'seasons_url': 'https://georgiawildlife.com/hunting/seasons', 'regulations_url': 'https://georgiawildlife.com/hunting', 'licensing_url': 'https://georgiawildlife.com/licenses-permits-passes', 'buy_license_url': 'https://gooutdoorsgeorgia.com/', 'fishing_url': 'https://georgiawildlife.com/fishing'},
  {'state_code': 'HI', 'state_name': 'Hawaii', 'agency_name': 'Hawaii DLNR', 'seasons_url': 'https://dlnr.hawaii.gov/hunting/', 'regulations_url': 'https://dlnr.hawaii.gov/hunting/', 'licensing_url': 'https://dlnr.hawaii.gov/hunting/licenses/', 'buy_license_url': 'https://dlnr.hawaii.gov/hunting/licenses/', 'fishing_url': 'https://dlnr.hawaii.gov/dar/fishing/'},
  {'state_code': 'ID', 'state_name': 'Idaho', 'agency_name': 'Idaho Fish & Game', 'seasons_url': 'https://idfg.idaho.gov/hunt', 'regulations_url': 'https://idfg.idaho.gov/hunt', 'licensing_url': 'https://idfg.idaho.gov/licenses', 'buy_license_url': 'https://idfg.idaho.gov/buy', 'fishing_url': 'https://idfg.idaho.gov/fish'},
  {'state_code': 'IL', 'state_name': 'Illinois', 'agency_name': 'Illinois DNR', 'seasons_url': 'https://www2.illinois.gov/dnr/hunting/Pages/HuntingSeasons.aspx', 'regulations_url': 'https://www2.illinois.gov/dnr/hunting/Pages/default.aspx', 'licensing_url': 'https://www2.illinois.gov/dnr/LPR/Pages/default.aspx', 'buy_license_url': 'https://www.exploremoreil.com/', 'fishing_url': 'https://www2.illinois.gov/dnr/fishing/Pages/default.aspx'},
  {'state_code': 'IN', 'state_name': 'Indiana', 'agency_name': 'Indiana DNR', 'seasons_url': 'https://www.in.gov/dnr/fish-and-wildlife/hunting-and-trapping/hunting-seasons/', 'regulations_url': 'https://www.in.gov/dnr/fish-and-wildlife/hunting-and-trapping/', 'licensing_url': 'https://www.in.gov/dnr/fish-and-wildlife/licenses-and-permits/', 'buy_license_url': 'https://secure.in.gov/apps/dnr/portal/#/home', 'fishing_url': 'https://www.in.gov/dnr/fish-and-wildlife/fishing/'},
  {'state_code': 'IA', 'state_name': 'Iowa', 'agency_name': 'Iowa DNR', 'seasons_url': 'https://www.iowadnr.gov/Hunting/Seasons', 'regulations_url': 'https://www.iowadnr.gov/Hunting', 'licensing_url': 'https://www.iowadnr.gov/Hunting/Licenses', 'buy_license_url': 'https://www.gooutdoorsiowa.com/', 'fishing_url': 'https://www.iowadnr.gov/Fishing'},
  {'state_code': 'KS', 'state_name': 'Kansas', 'agency_name': 'Kansas Wildlife', 'seasons_url': 'https://ksoutdoors.com/Hunting/Seasons-More', 'regulations_url': 'https://ksoutdoors.com/Hunting', 'licensing_url': 'https://ksoutdoors.com/License-Permits', 'buy_license_url': 'https://ksoutdoors.com/License-Permits/Buy-A-License', 'fishing_url': 'https://ksoutdoors.com/Fishing'},
  {'state_code': 'KY', 'state_name': 'Kentucky', 'agency_name': 'Kentucky DFW', 'seasons_url': 'https://fw.ky.gov/Hunt/Pages/Seasons-Dates.aspx', 'regulations_url': 'https://fw.ky.gov/Hunt/Pages/default.aspx', 'licensing_url': 'https://fw.ky.gov/License/Pages/default.aspx', 'buy_license_url': 'https://app.fw.ky.gov/SportLicense/', 'fishing_url': 'https://fw.ky.gov/Fish/Pages/default.aspx'},
  {'state_code': 'LA', 'state_name': 'Louisiana', 'agency_name': 'Louisiana WLF', 'seasons_url': 'https://www.wlf.louisiana.gov/page/hunting-seasons', 'regulations_url': 'https://www.wlf.louisiana.gov/page/hunting', 'licensing_url': 'https://www.wlf.louisiana.gov/page/licenses-permits', 'buy_license_url': 'https://la-web.s3licensing.com/', 'fishing_url': 'https://www.wlf.louisiana.gov/page/freshwater-fishing'},
  {'state_code': 'ME', 'state_name': 'Maine', 'agency_name': 'Maine IFW', 'seasons_url': 'https://www.maine.gov/ifw/hunting-trapping/hunting-laws.html', 'regulations_url': 'https://www.maine.gov/ifw/hunting-trapping/', 'licensing_url': 'https://www.maine.gov/ifw/licenses-permits/', 'buy_license_url': 'https://moses.informe.org/online/licensing/', 'fishing_url': 'https://www.maine.gov/ifw/fishing-boating/fishing/'},
  {'state_code': 'MD', 'state_name': 'Maryland', 'agency_name': 'Maryland DNR', 'seasons_url': 'https://dnr.maryland.gov/wildlife/Pages/hunt_trap/seasons.aspx', 'regulations_url': 'https://dnr.maryland.gov/wildlife/Pages/hunt_trap/default.aspx', 'licensing_url': 'https://dnr.maryland.gov/fisheries/Pages/license.aspx', 'buy_license_url': 'https://compass.dnr.maryland.gov/', 'fishing_url': 'https://dnr.maryland.gov/fisheries/Pages/regulations/'},
  {'state_code': 'MA', 'state_name': 'Massachusetts', 'agency_name': 'Massachusetts DFW', 'seasons_url': 'https://www.mass.gov/service-details/hunting-seasons', 'regulations_url': 'https://www.mass.gov/hunting-regulations', 'licensing_url': 'https://www.mass.gov/how-to/buy-a-hunting-or-fishing-license', 'buy_license_url': 'https://www.mass.gov/how-to/buy-a-hunting-or-fishing-license', 'fishing_url': 'https://www.mass.gov/freshwater-fishing-regulations'},
  {'state_code': 'MI', 'state_name': 'Michigan', 'agency_name': 'Michigan DNR', 'seasons_url': 'https://www.michigan.gov/dnr/things-to-do/hunting/seasons', 'regulations_url': 'https://www.michigan.gov/dnr/things-to-do/hunting', 'licensing_url': 'https://www.michigan.gov/dnr/buy-and-apply/licenses', 'buy_license_url': 'https://www.mdnr-elicense.com/', 'fishing_url': 'https://www.michigan.gov/dnr/things-to-do/fishing'},
  {'state_code': 'MN', 'state_name': 'Minnesota', 'agency_name': 'Minnesota DNR', 'seasons_url': 'https://www.dnr.state.mn.us/hunting/seasons.html', 'regulations_url': 'https://www.dnr.state.mn.us/hunting/index.html', 'licensing_url': 'https://www.dnr.state.mn.us/licenses/index.html', 'buy_license_url': 'https://www.dnr.state.mn.us/buyalicense/index.html', 'fishing_url': 'https://www.dnr.state.mn.us/fishing/index.html'},
  {'state_code': 'MS', 'state_name': 'Mississippi', 'agency_name': 'Mississippi DWFP', 'seasons_url': 'https://www.mdwfp.com/wildlife-hunting/hunting-seasons/', 'regulations_url': 'https://www.mdwfp.com/wildlife-hunting/', 'licensing_url': 'https://www.mdwfp.com/license/', 'buy_license_url': 'https://www.ms.gov/mdwfp/license/', 'fishing_url': 'https://www.mdwfp.com/fishing-boating/'},
  {'state_code': 'MO', 'state_name': 'Missouri', 'agency_name': 'Missouri MDC', 'seasons_url': 'https://mdc.mo.gov/hunting-trapping/seasons', 'regulations_url': 'https://mdc.mo.gov/hunting-trapping', 'licensing_url': 'https://mdc.mo.gov/permits/hunting-permits', 'buy_license_url': 'https://mdc-web.s3licensing.com/', 'fishing_url': 'https://mdc.mo.gov/fishing'},
  {'state_code': 'MT', 'state_name': 'Montana', 'agency_name': 'Montana FWP', 'seasons_url': 'https://fwp.mt.gov/hunt/regulations', 'regulations_url': 'https://fwp.mt.gov/hunt', 'licensing_url': 'https://fwp.mt.gov/buyandapply', 'buy_license_url': 'https://fwp.mt.gov/buyandapply', 'fishing_url': 'https://fwp.mt.gov/fish'},
  {'state_code': 'NE', 'state_name': 'Nebraska', 'agency_name': 'Nebraska Game & Parks', 'seasons_url': 'https://outdoornebraska.gov/huntingseasons/', 'regulations_url': 'https://outdoornebraska.gov/hunt/', 'licensing_url': 'https://outdoornebraska.gov/permits/', 'buy_license_url': 'https://outdoornebraska.ne.gov/', 'fishing_url': 'https://outdoornebraska.gov/fishing/'},
  {'state_code': 'NV', 'state_name': 'Nevada', 'agency_name': 'Nevada DOW', 'seasons_url': 'https://www.ndow.org/hunt/seasons-regulations/', 'regulations_url': 'https://www.ndow.org/hunt/', 'licensing_url': 'https://www.ndow.org/licenses-tags/', 'buy_license_url': 'https://www.ndow.org/licenses-tags/', 'fishing_url': 'https://www.ndow.org/fish/'},
  {'state_code': 'NH', 'state_name': 'New Hampshire', 'agency_name': 'New Hampshire FG', 'seasons_url': 'https://www.wildlife.nh.gov/hunting/seasons', 'regulations_url': 'https://www.wildlife.nh.gov/hunting', 'licensing_url': 'https://www.wildlife.nh.gov/licensing', 'buy_license_url': 'https://www.wildlife.nh.gov/licensing', 'fishing_url': 'https://www.wildlife.nh.gov/fishing'},
  {'state_code': 'NJ', 'state_name': 'New Jersey', 'agency_name': 'New Jersey DFW', 'seasons_url': 'https://www.nj.gov/dep/fgw/hunting_dates.htm', 'regulations_url': 'https://www.nj.gov/dep/fgw/hunting.htm', 'licensing_url': 'https://www.nj.gov/dep/fgw/licenses.htm', 'buy_license_url': 'https://www.njfishandwildlife.com/', 'fishing_url': 'https://www.nj.gov/dep/fgw/fishing.htm'},
  {'state_code': 'NM', 'state_name': 'New Mexico', 'agency_name': 'New Mexico DGF', 'seasons_url': 'https://www.wildlife.state.nm.us/hunting/game-and-seasons/', 'regulations_url': 'https://www.wildlife.state.nm.us/hunting/', 'licensing_url': 'https://www.wildlife.state.nm.us/hunting/licenses-and-applications/', 'buy_license_url': 'https://onlinesales.wildlife.state.nm.us/', 'fishing_url': 'https://www.wildlife.state.nm.us/fishing/'},
  {'state_code': 'NY', 'state_name': 'New York', 'agency_name': 'New York DEC', 'seasons_url': 'https://www.dec.ny.gov/outdoor/hunting_seasons.html', 'regulations_url': 'https://www.dec.ny.gov/outdoor/hunting.html', 'licensing_url': 'https://www.dec.ny.gov/permits/6094.html', 'buy_license_url': 'https://decals.dec.ny.gov/', 'fishing_url': 'https://www.dec.ny.gov/outdoor/fishing.html'},
  {'state_code': 'NC', 'state_name': 'North Carolina', 'agency_name': 'North Carolina WRC', 'seasons_url': 'https://www.ncwildlife.org/Hunting/Seasons-Regulations', 'regulations_url': 'https://www.ncwildlife.org/Hunting', 'licensing_url': 'https://www.ncwildlife.org/Licensing', 'buy_license_url': 'https://www.ncwildlife.org/Licensing/How-to-Buy', 'fishing_url': 'https://www.ncwildlife.org/Fishing/Regulations'},
  {'state_code': 'ND', 'state_name': 'North Dakota', 'agency_name': 'North Dakota GF', 'seasons_url': 'https://gf.nd.gov/hunting/seasons', 'regulations_url': 'https://gf.nd.gov/hunting', 'licensing_url': 'https://gf.nd.gov/licensing', 'buy_license_url': 'https://gf.nd.gov/licensing', 'fishing_url': 'https://gf.nd.gov/fishing'},
  {'state_code': 'OH', 'state_name': 'Ohio', 'agency_name': 'Ohio DNR', 'seasons_url': 'https://ohiodnr.gov/buy-and-apply/hunting-fishing-boating/hunting-resources/hunting-seasons-bag-limits', 'regulations_url': 'https://ohiodnr.gov/buy-and-apply/hunting-fishing-boating/hunting-resources', 'licensing_url': 'https://ohiodnr.gov/buy-and-apply/hunting-fishing-boating/hunting-resources/hunting-license', 'buy_license_url': 'https://oh-web.s3licensing.com/', 'fishing_url': 'https://ohiodnr.gov/buy-and-apply/hunting-fishing-boating/fishing-resources'},
  {'state_code': 'OK', 'state_name': 'Oklahoma', 'agency_name': 'Oklahoma DWC', 'seasons_url': 'https://www.wildlifedepartment.com/hunting/seasons', 'regulations_url': 'https://www.wildlifedepartment.com/hunting', 'licensing_url': 'https://www.wildlifedepartment.com/licensing', 'buy_license_url': 'https://www.gooutdoorsoklahoma.com/', 'fishing_url': 'https://www.wildlifedepartment.com/fishing'},
  {'state_code': 'OR', 'state_name': 'Oregon', 'agency_name': 'Oregon DFW', 'seasons_url': 'https://myodfw.com/hunting/seasons', 'regulations_url': 'https://myodfw.com/hunting', 'licensing_url': 'https://myodfw.com/licenses-and-tags', 'buy_license_url': 'https://odfw.huntfishoregon.com/', 'fishing_url': 'https://myodfw.com/fishing'},
  {'state_code': 'PA', 'state_name': 'Pennsylvania', 'agency_name': 'Pennsylvania GC', 'seasons_url': 'https://www.pgc.pa.gov/HuntTrap/Law/Pages/HuntTrapSeasonsDates.aspx', 'regulations_url': 'https://www.pgc.pa.gov/HuntTrap/Pages/default.aspx', 'licensing_url': 'https://www.pgc.pa.gov/HuntTrap/Law/Pages/Licenses.aspx', 'buy_license_url': 'https://www.pgc.pa.gov/HuntTrap/Law/Pages/HuntingLicenses.aspx', 'fishing_url': 'https://www.fishandboat.com/Fish/FishingRegulations/Pages/default.aspx'},
  {'state_code': 'RI', 'state_name': 'Rhode Island', 'agency_name': 'Rhode Island DEM', 'seasons_url': 'https://dem.ri.gov/natural-resources-bureau/fish-wildlife/hunting', 'regulations_url': 'https://dem.ri.gov/natural-resources-bureau/fish-wildlife/hunting', 'licensing_url': 'https://dem.ri.gov/natural-resources-bureau/fish-wildlife/licenses-permits', 'buy_license_url': 'https://dem.ri.gov/natural-resources-bureau/fish-wildlife/licenses-permits', 'fishing_url': 'https://dem.ri.gov/natural-resources-bureau/fish-wildlife/freshwater-fisheries'},
  {'state_code': 'SC', 'state_name': 'South Carolina', 'agency_name': 'South Carolina DNR', 'seasons_url': 'https://www.dnr.sc.gov/hunting/seasons/', 'regulations_url': 'https://www.dnr.sc.gov/hunting/', 'licensing_url': 'https://www.dnr.sc.gov/licenses/', 'buy_license_url': 'https://www.sc.wildlifelicense.com/', 'fishing_url': 'https://www.dnr.sc.gov/fishing/'},
  {'state_code': 'SD', 'state_name': 'South Dakota', 'agency_name': 'South Dakota GFP', 'seasons_url': 'https://gfp.sd.gov/hunting/', 'regulations_url': 'https://gfp.sd.gov/hunting/', 'licensing_url': 'https://gfp.sd.gov/licenses/', 'buy_license_url': 'https://gfp.sd.gov/licenses/', 'fishing_url': 'https://gfp.sd.gov/fishing/'},
  {'state_code': 'TN', 'state_name': 'Tennessee', 'agency_name': 'Tennessee TWRA', 'seasons_url': 'https://www.tn.gov/twra/hunting/seasons.html', 'regulations_url': 'https://www.tn.gov/twra/hunting.html', 'licensing_url': 'https://www.tn.gov/twra/license-sales.html', 'buy_license_url': 'https://www.gooutdoorstennessee.com/', 'fishing_url': 'https://www.tn.gov/twra/fishing.html'},
  {'state_code': 'TX', 'state_name': 'Texas', 'agency_name': 'Texas Parks & Wildlife', 'seasons_url': 'https://tpwd.texas.gov/regulations/outdoor-annual/hunting/general-regulations/seasons', 'regulations_url': 'https://tpwd.texas.gov/regulations/outdoor-annual/hunting', 'licensing_url': 'https://tpwd.texas.gov/business/licenses/', 'buy_license_url': 'https://tpwd.texas.gov/business/licenses/online-sales/', 'fishing_url': 'https://tpwd.texas.gov/regulations/outdoor-annual/fishing'},
  {'state_code': 'UT', 'state_name': 'Utah', 'agency_name': 'Utah DWR', 'seasons_url': 'https://wildlife.utah.gov/hunting-in-utah.html', 'regulations_url': 'https://wildlife.utah.gov/hunting-in-utah.html', 'licensing_url': 'https://wildlife.utah.gov/licenses.html', 'buy_license_url': 'https://wildlife.utah.gov/licenses.html', 'fishing_url': 'https://wildlife.utah.gov/fishing-in-utah.html'},
  {'state_code': 'VT', 'state_name': 'Vermont', 'agency_name': 'Vermont FW', 'seasons_url': 'https://vtfishandwildlife.com/hunt/hunting-seasons', 'regulations_url': 'https://vtfishandwildlife.com/hunt', 'licensing_url': 'https://vtfishandwildlife.com/licenses-and-lotteries', 'buy_license_url': 'https://vtfishandwildlife.com/licenses-and-lotteries', 'fishing_url': 'https://vtfishandwildlife.com/fish'},
  {'state_code': 'VA', 'state_name': 'Virginia', 'agency_name': 'Virginia DWR', 'seasons_url': 'https://dwr.virginia.gov/hunting/regulations/', 'regulations_url': 'https://dwr.virginia.gov/hunting/', 'licensing_url': 'https://dwr.virginia.gov/licenses/', 'buy_license_url': 'https://gooutdoorsvirginia.com/', 'fishing_url': 'https://dwr.virginia.gov/fishing/'},
  {'state_code': 'WA', 'state_name': 'Washington', 'agency_name': 'Washington DFW', 'seasons_url': 'https://wdfw.wa.gov/hunting/regulations', 'regulations_url': 'https://wdfw.wa.gov/hunting', 'licensing_url': 'https://wdfw.wa.gov/licensing', 'buy_license_url': 'https://fishhunt.dfw.wa.gov/', 'fishing_url': 'https://wdfw.wa.gov/fishing/regulations'},
  {'state_code': 'WV', 'state_name': 'West Virginia', 'agency_name': 'West Virginia DNR', 'seasons_url': 'https://wvdnr.gov/hunting/seasons/', 'regulations_url': 'https://wvdnr.gov/hunting/', 'licensing_url': 'https://wvdnr.gov/licenses/', 'buy_license_url': 'https://www.wvhunt.com/', 'fishing_url': 'https://wvdnr.gov/fishing/'},
  {'state_code': 'WI', 'state_name': 'Wisconsin', 'agency_name': 'Wisconsin DNR', 'seasons_url': 'https://dnr.wisconsin.gov/topic/Hunt/seasons', 'regulations_url': 'https://dnr.wisconsin.gov/topic/Hunt', 'licensing_url': 'https://dnr.wisconsin.gov/permits/licenses', 'buy_license_url': 'https://gowild.wi.gov/', 'fishing_url': 'https://dnr.wisconsin.gov/topic/Fishing'},
  {'state_code': 'WY', 'state_name': 'Wyoming', 'agency_name': 'Wyoming Game & Fish', 'seasons_url': 'https://wgfd.wyo.gov/Hunting/Season-Dates', 'regulations_url': 'https://wgfd.wyo.gov/Hunting', 'licensing_url': 'https://wgfd.wyo.gov/Apply-or-Buy', 'buy_license_url': 'https://wgfd.wyo.gov/Apply-or-Buy', 'fishing_url': 'https://wgfd.wyo.gov/Fishing'},
];

/// Coverage Dashboard - portal-first metrics
class _CoverageDashboardCard extends StatelessWidget {
  const _CoverageDashboardCard({
    required this.stats,
    required this.onRefresh,
    required this.onDeleteJunk,
  });
  
  final Map<String, dynamic> stats;
  final VoidCallback onRefresh;
  final VoidCallback onDeleteJunk;
  
  @override
  Widget build(BuildContext context) {
    final portalCoverage = stats['portal_coverage'] ?? 0;
    final portalTotal = stats['portal_total'] ?? 50;
    final factsStates = stats['facts_states'] ?? 0;
    final factsRows = stats['facts_total_rows'] ?? 0;
    final pendingCount = stats['pending_count'] ?? 0;
    final sourcesExtractable = stats['sources_extractable'] ?? 0;
    final sourcesPortalOnly = stats['sources_portal_only'] ?? 0;
    
    final portalComplete = portalCoverage >= portalTotal;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.08),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.dashboard_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Coverage Dashboard',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: onRefresh,
                tooltip: 'Refresh stats',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Two-layer metrics
          Row(
            children: [
              // Portal Links (always complete)
              Expanded(
                child: _MetricBox(
                  icon: Icons.link_rounded,
                  label: 'Portal Links',
                  value: '$portalCoverage/$portalTotal',
                  subtitle: 'Official links',
                  color: portalComplete ? AppColors.success : AppColors.warning,
                  isComplete: portalComplete,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Extracted Facts (optional)
              Expanded(
                child: _MetricBox(
                  icon: Icons.fact_check_rounded,
                  label: 'Extracted Facts',
                  value: '$factsStates states',
                  subtitle: '$factsRows rows',
                  color: AppColors.info,
                  isComplete: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Sources breakdown
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  icon: Icons.source_rounded,
                  label: 'Extractable',
                  value: '$sourcesExtractable',
                  subtitle: 'sources',
                  color: AppColors.accent,
                  isComplete: false,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MetricBox(
                  icon: Icons.warning_amber_rounded,
                  label: 'Pending',
                  value: '$pendingCount',
                  subtitle: 'to review',
                  color: pendingCount > 0 ? AppColors.warning : AppColors.success,
                  isComplete: pendingCount == 0,
                ),
              ),
            ],
          ),
          
          // Delete junk button if pending > 0
          if (pendingCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDeleteJunk,
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: const Text('Clear Junk Pending'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.isComplete,
  });
  
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final bool isComplete;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              if (isComplete) ...[
                const Spacer(),
                Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Explanation card for how the system works.
class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'How This System Works',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '• Portal links always work – direct links to official state pages\n'
            '• Checker extracts facts from structured pages when possible\n'
            '• High-confidence extractions (≥85%) auto-approve\n'
            '• Lower confidence items appear in Pending for manual review\n'
            '• Automation runs weekly to detect changes',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Source counts display card.
class _SourceCountsCard extends StatelessWidget {
  const _SourceCountsCard({required this.counts});
  
  final SourceCounts counts;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.source_rounded, size: 18, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Extraction Sources',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: counts.total >= 150 ? AppColors.success.withValues(alpha: 0.15) : AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${counts.total} total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: counts.total >= 150 ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _CountItem(label: 'Deer', count: counts.deer, target: 50),
              ),
              Expanded(
                child: _CountItem(label: 'Turkey', count: counts.turkey, target: 50),
              ),
              Expanded(
                child: _CountItem(label: 'Fishing', count: counts.fishing, target: 50),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountItem extends StatelessWidget {
  const _CountItem({
    required this.label,
    required this.count,
    required this.target,
  });
  
  final String label;
  final int count;
  final int target;
  
  @override
  Widget build(BuildContext context) {
    final isComplete = count >= target;
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isComplete ? AppColors.success : AppColors.warning,
          ),
        ),
        Text(
          '$label / $target',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Stats card showing checker activity over the past week.
class _CheckerStatsCard extends StatelessWidget {
  const _CheckerStatsCard({
    required this.stats,
    this.lastResult,
  });
  
  final Map<String, int> stats;
  final Map<String, dynamic>? lastResult;
  
  @override
  Widget build(BuildContext context) {
    final autoApproved = stats['auto_approved'] ?? 0;
    final pending = stats['pending'] ?? 0;
    final manual = stats['manual'] ?? 0;
    final total = autoApproved + pending + manual;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Checker Activity (Last 7 Days)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Auto-Approved',
                  value: autoApproved,
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.pending_rounded,
                  label: 'Pending',
                  value: pending,
                  color: AppColors.warning,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.verified_user_rounded,
                  label: 'Manual',
                  value: manual,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          
          if (total > 0) ...[
            const SizedBox(height: AppSpacing.md),
            // Auto-approval rate
            Row(
              children: [
                Text(
                  'Auto-approval rate: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${((autoApproved / total) * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: autoApproved > pending ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
          
          if (lastResult != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Last run: ${lastResult!['checked'] ?? 0} sources checked, '
              '${lastResult!['auto_approved'] ?? 0} auto-approved, '
              '${lastResult!['pending'] ?? 0} pending',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Portal links row in the coverage matrix.
class _PortalLinksRow extends StatelessWidget {
  const _PortalLinksRow({
    required this.stateCode,
    required this.links,
    this.onEdit,
  });
  
  final String stateCode;
  final StatePortalLinks? links;
  final VoidCallback? onEdit;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              stateCode,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(child: _LinkStatusCell(hasUrl: links?.hasSeasons ?? false, isVerified: links?.canShowSeasons ?? false)),
          Expanded(child: _LinkStatusCell(hasUrl: links?.hasRegulations ?? false, isVerified: links?.canShowRegulations ?? false)),
          Expanded(child: _LinkStatusCell(hasUrl: links?.hasFishing ?? false, isVerified: links?.canShowFishing ?? false)),
          Expanded(child: _LinkStatusCell(hasUrl: links?.hasLicensing ?? false, isVerified: links?.canShowLicensing ?? false)),
          Expanded(child: _LinkStatusCell(hasUrl: links?.hasBuyLicense ?? false, isVerified: links?.canShowBuyLicense ?? false)),
          SizedBox(
            width: 36,
            child: links != null
                ? IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.textTertiary,
                    tooltip: 'Edit links',
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Link status cell showing verified/broken/missing status.
class _LinkStatusCell extends StatelessWidget {
  const _LinkStatusCell({
    required this.hasUrl,
    required this.isVerified,
  });
  
  final bool hasUrl;
  final bool isVerified;
  
  @override
  Widget build(BuildContext context) {
    if (!hasUrl) {
      // Missing - no URL configured
      return Center(
        child: Icon(
          Icons.remove_rounded,
          size: 14,
          color: AppColors.textTertiary.withValues(alpha: 0.5),
        ),
      );
    }
    
    if (isVerified) {
      // Verified OK
      return Center(
        child: Icon(
          Icons.check_circle_rounded,
          size: 14,
          color: AppColors.success,
        ),
      );
    }
    
    // Has URL but not verified (broken or unverified)
    return Center(
      child: Icon(
        Icons.warning_rounded,
        size: 14,
        color: AppColors.error,
      ),
    );
  }
}

/// Text field for editing portal links with verification indicator.
class _LinkTextField extends StatelessWidget {
  const _LinkTextField({
    required this.label,
    required this.controller,
    required this.isVerified,
  });
  
  final String label;
  final TextEditingController controller;
  final bool isVerified;
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        hintText: 'https://...',
        hintStyle: TextStyle(
          fontSize: 12,
          color: AppColors.textTertiary,
        ),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: isVerified
            ? const Icon(Icons.verified_rounded, size: 16, color: AppColors.success)
            : controller.text.isNotEmpty
                ? const Icon(Icons.warning_rounded, size: 16, color: AppColors.warning)
                : null,
      ),
      style: const TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
      ),
    );
  }
}

/// Setup Wizard card - guides admin through the setup process step by step.
class _SetupWizardCard extends StatelessWidget {
  const _SetupWizardCard({
    required this.portalCount,
    required this.verifiedCount,
    required this.isVerifying,
    required this.isDiscovering,
    this.discoveryProgress,
    required this.onSeedPortal,
    required this.onVerify,
    required this.onDiscover,
  });
  
  final int portalCount;
  final int verifiedCount;
  final bool isVerifying;
  final bool isDiscovering;
  final DiscoveryRunProgress? discoveryProgress;
  final VoidCallback onSeedPortal;
  final VoidCallback onVerify;
  final VoidCallback onDiscover;
  
  @override
  Widget build(BuildContext context) {
    // Determine current step
    final step1Done = portalCount >= 50;
    final step2Done = verifiedCount >= 25; // At least half verified
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.rocket_launch_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Setup Wizard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // Progress indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  step2Done ? '✓ Complete' : step1Done ? '2/3 Steps' : '1/3 Steps',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: step2Done ? AppColors.success : AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Follow these steps to set up official state portal links:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Step 1: Seed Portal Links
          _WizardStep(
            number: 1,
            title: 'Seed Portal Links',
            description: 'Populates official agency URLs for all 50 states.',
            isDone: step1Done,
            isActive: !step1Done,
            buttonLabel: step1Done ? 'Done ($portalCount/50)' : 'Seed Now',
            onPressed: step1Done ? null : onSeedPortal,
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Step 2: Verify Links
          _WizardStep(
            number: 2,
            title: 'Verify Links',
            description: 'Checks each URL is working (200 OK). Broken links are hidden.',
            isDone: step2Done,
            isActive: step1Done && !step2Done,
            buttonLabel: isVerifying 
                ? 'Verifying...' 
                : step2Done 
                    ? 'Done ($verifiedCount verified)' 
                    : 'Verify All',
            onPressed: isVerifying || !step1Done ? null : onVerify,
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Step 3: Full Discovery (50 states)
          _WizardStep(
            number: 3,
            title: 'Full Discovery (50 states)',
            description: isDiscovering && discoveryProgress != null
                ? 'Processing ${discoveryProgress!.processed}/${discoveryProgress!.total} states... Current: ${discoveryProgress!.lastStateCode ?? "starting"}'
                : 'Crawls all official .gov sites to find season/regulation pages. Shows live progress.',
            isDone: discoveryProgress?.isDone == true,
            isActive: step1Done,
            isOptional: true,
            buttonLabel: isDiscovering 
                ? '${discoveryProgress?.processed ?? 0}/${discoveryProgress?.total ?? 50}...' 
                : 'Run Full Discovery',
            onPressed: isDiscovering ? null : onDiscover,
          ),
          
          const SizedBox(height: AppSpacing.md),
          // Status summary
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                _StatusBadge(
                  label: 'Portal',
                  value: '$portalCount/50',
                  color: portalCount >= 50 ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.md),
                _StatusBadge(
                  label: 'Verified',
                  value: '$verifiedCount',
                  color: verifiedCount > 0 ? AppColors.success : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single step in the setup wizard.
class _WizardStep extends StatelessWidget {
  const _WizardStep({
    required this.number,
    required this.title,
    required this.description,
    required this.isDone,
    required this.isActive,
    required this.buttonLabel,
    this.isOptional = false,
    this.onPressed,
  });
  
  final int number;
  final String title;
  final String description;
  final bool isDone;
  final bool isActive;
  final bool isOptional;
  final String buttonLabel;
  final VoidCallback? onPressed;
  
  @override
  Widget build(BuildContext context) {
    final color = isDone 
        ? AppColors.success 
        : isActive 
            ? AppColors.accent 
            : AppColors.textTertiary;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isActive 
            ? AppColors.accent.withValues(alpha: 0.1) 
            : AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: isActive 
            ? Border.all(color: AppColors.accent.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          // Step number/check
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isDone
                  ? Icon(Icons.check_rounded, size: 14, color: color)
                  : Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          
          // Title and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (isOptional)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'OPTIONAL',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          
          // Action button
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? AppColors.accent : AppColors.surface,
                foregroundColor: isActive ? Colors.white : AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                elevation: 0,
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status badge for the wizard summary.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.value,
    required this.color,
  });
  
  final String label;
  final String value;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Discovery progress panel - shows live progress during full 50-state discovery.
class _DiscoveryProgressPanel extends StatefulWidget {
  const _DiscoveryProgressPanel({
    required this.progress,
    required this.isRunning,
    required this.items,
    required this.onCancel,
  });
  
  final DiscoveryRunProgress? progress;
  final bool isRunning;
  final List<DiscoveryRunItem> items;
  final VoidCallback onCancel;
  
  @override
  State<_DiscoveryProgressPanel> createState() => _DiscoveryProgressPanelState();
}

class _DiscoveryProgressPanelState extends State<_DiscoveryProgressPanel> {
  bool _showDetails = false;
  
  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final processed = progress?.processed ?? 0;
    final total = progress?.total ?? 50;
    final progressValue = total > 0 ? processed / total : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.isRunning 
            ? AppColors.info.withValues(alpha: 0.1)
            : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: widget.isRunning 
              ? AppColors.info.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                widget.isRunning ? Icons.sync_rounded : Icons.check_circle_rounded,
                size: 20,
                color: widget.isRunning ? AppColors.info : AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.isRunning 
                      ? 'Discovery in Progress'
                      : 'Discovery Complete',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (widget.isRunning)
                TextButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation(
                widget.isRunning ? AppColors.info : AppColors.success,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Progress text
          Row(
            children: [
              Text(
                'Processed: $processed/$total states',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (progress?.lastStateCode != null) ...[
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Current: ${progress!.lastStateCode}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Stats row
          Row(
            children: [
              _MiniStat(
                icon: Icons.check_circle_rounded,
                label: 'OK',
                value: progress?.statsOk ?? 0,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(
                icon: Icons.skip_next_rounded,
                label: 'Skipped',
                value: progress?.statsSkipped ?? 0,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(
                icon: Icons.error_rounded,
                label: 'Error',
                value: progress?.statsError ?? 0,
                color: AppColors.error,
              ),
            ],
          ),
          
          // Details toggle
          if (widget.items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () => setState(() => _showDetails = !_showDetails),
              child: Row(
                children: [
                  Icon(
                    _showDetails ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showDetails ? 'Hide Details' : 'Show Details (${widget.items.length} states)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            
            // Details list
            if (_showDetails) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return _DiscoveryItemRow(item: item);
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Mini stat badge for discovery progress.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Row showing a single state's discovery result.
class _DiscoveryItemRow extends StatefulWidget {
  const _DiscoveryItemRow({required this.item});
  
  final DiscoveryRunItem item;
  
  @override
  State<_DiscoveryItemRow> createState() => _DiscoveryItemRowState();
}

class _DiscoveryItemRowState extends State<_DiscoveryItemRow> {
  bool _expanded = false;
  
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final statusColor = item.isOk 
        ? AppColors.success 
        : item.isSkipped 
            ? AppColors.warning 
            : AppColors.error;
    
    return Column(
      children: [
        InkWell(
          onTap: item.discoveredUrls.isNotEmpty 
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Status icon
                Icon(
                  item.isOk 
                      ? Icons.check_circle_rounded 
                      : item.isSkipped 
                          ? Icons.skip_next_rounded 
                          : Icons.error_rounded,
                  size: 14,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                
                // State code
                SizedBox(
                  width: 28,
                  child: Text(
                    item.stateCode,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Message
                Expanded(
                  child: Text(
                    item.message ?? item.status,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Expand icon if has URLs
                if (item.discoveredUrls.isNotEmpty)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
        
        // Expanded URLs
        if (_expanded && item.discoveredUrls.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(40, 0, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: item.discoveredUrls.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          entry.key.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.accent,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        
        const Divider(height: 1, color: AppColors.borderSubtle),
      ],
    );
  }
}
