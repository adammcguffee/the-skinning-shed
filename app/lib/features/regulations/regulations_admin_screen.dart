import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/regulations_service.dart';

/// 🛡️ REGULATIONS ADMIN SCREEN - SIMPLIFIED 2026
/// 
/// Clean, professional admin interface with:
/// - Overview: Stats dashboard
/// - Actions: Verify links
/// - Danger Zone: Reset data
class RegulationsAdminScreen extends ConsumerStatefulWidget {
  const RegulationsAdminScreen({super.key});

  @override
  ConsumerState<RegulationsAdminScreen> createState() => _RegulationsAdminScreenState();
}

class _RegulationsAdminScreenState extends ConsumerState<RegulationsAdminScreen> {
  bool _isLoading = true;
  String? _error;
  _AdminStats _stats = const _AdminStats();
  bool _isVerifying = false;
  String? _verifyProgress;
  List<_BrokenLink> _brokenLinks = [];
  bool _showBrokenLinks = false;
  
  // Server-side verification state
  VerifyRunStatus? _currentRun;
  bool _isCanceling = false;
  
  // Auto-repair state
  bool _isRepairing = false;
  RepairResult? _lastRepairResult;
  
  // Discovery repair run state (resumable)
  RepairRunStatus? _repairRun;
  bool _isRepairCanceling = false;
  
  // Job queue run state (NEW - uses droplet worker)
  AdminRunStatus? _activeDiscoveryRun;
  AdminRunStatus? _activeExtractionRun;
  bool _isDiscoveryStopping = false;
  bool _isExtractionStopping = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _checkForExistingRun();
    _checkForExistingRepairRun();
    _checkForActiveJobQueueRuns();
  }
  
  /// Check for active job queue runs on page load (for resume).
  Future<void> _checkForActiveJobQueueRuns() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final latestRun = await service.getJobQueueRunStatus();
      
      if (latestRun != null && latestRun.isRunning && mounted) {
        if (latestRun.type == 'discover') {
          setState(() => _activeDiscoveryRun = latestRun);
          _pollJobQueueDiscoveryRun(latestRun.runId);
        } else if (latestRun.type == 'extract') {
          setState(() => _activeExtractionRun = latestRun);
          _pollJobQueueExtractionRun(latestRun.runId);
        }
      }
    } catch (e) {
      debugPrint('[RegsAdmin] Error checking for active job queue runs: $e');
    }
  }
  
  /// Clear all run states (used before reset to stop polling).
  void _clearAllRunStates() {
    setState(() {
      // Clear job queue runs
      _activeDiscoveryRun = null;
      _activeExtractionRun = null;
      _isDiscoveryStopping = false;
      _isExtractionStopping = false;
      
      // Clear legacy runs
      _currentRun = null;
      _isCanceling = false;
      _isVerifying = false;
      _verifyProgress = null;
      
      // Clear repair runs
      _repairRun = null;
      _isRepairCanceling = false;
      _isRepairing = false;
      _lastRepairResult = null;
    });
  }

  /// Check for an existing running repair run on page load (for resume).
  Future<void> _checkForExistingRepairRun() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final latestRun = await service.getLatestRepairRunStatus();
      
      if (latestRun != null && latestRun.isRunning && mounted) {
        setState(() => _repairRun = latestRun);
        _pollRepairRun(latestRun.runId);
      }
    } catch (e) {
      debugPrint('[RegsAdmin] Error checking for existing repair run: $e');
    }
  }

  /// Check for an existing running verification on page load (for resume).
  Future<void> _checkForExistingRun() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final latestRun = await service.getLatestVerifyRunStatus();
      
      if (latestRun != null && latestRun.isRunning && mounted) {
        // Resume the running verification
        setState(() {
          _currentRun = latestRun;
          _isVerifying = true;
          _verifyProgress = 'Resuming verification... (${latestRun.processedStates}/${latestRun.totalStates})';
        });
        // Continue polling
        _pollVerification(latestRun.runId);
      }
    } catch (e) {
      debugPrint('[RegsAdmin] Error checking for existing run: $e');
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(regulationsServiceProvider);
      final stats = await service.fetchAdminStats();
      final broken = await service.fetchBrokenLinks();
      
      if (mounted) {
        setState(() {
          _stats = _AdminStats.fromMap(stats);
          _brokenLinks = broken.map((b) => _BrokenLink.fromMap(b)).toList();
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

  /// Start server-side verification.
  Future<void> _verifyAllLinks() async {
    setState(() {
      _isVerifying = true;
      _verifyProgress = 'Starting verification...';
      _currentRun = null;
    });

    try {
      final service = ref.read(regulationsServiceProvider);
      
      // Start a new run (or resume existing)
      final run = await service.startVerificationRun();
      
      if (mounted) {
        setState(() {
          _currentRun = run;
          _verifyProgress = run.resumed 
              ? 'Resuming... (${run.processedStates}/${run.totalStates})'
              : 'Started verification...';
        });
        
        // Begin polling
        _pollVerification(run.runId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _verifyProgress = null;
          _currentRun = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Poll the verification run until complete.
  Future<void> _pollVerification(String runId) async {
    final service = ref.read(regulationsServiceProvider);

    while (mounted && _isVerifying && !_isCanceling) {
      try {
        final status = await service.continueVerificationRun(runId);
        
        if (!mounted) break;
        
        setState(() {
          _currentRun = status;
          _verifyProgress = status.lastStateCode != null
              ? 'Verifying ${status.lastStateCode}... (${status.processedStates}/${status.totalStates})'
              : 'Processing... (${status.processedStates}/${status.totalStates})';
        });

        if (status.done) {
          // Verification complete
          if (mounted) {
            setState(() {
              _isVerifying = false;
              _verifyProgress = null;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Verification complete: ${status.okCount} OK, ${status.brokenCount} broken',
                ),
                backgroundColor: status.brokenCount == 0 ? AppColors.success : AppColors.warning,
              ),
            );
            _loadStats();
          }
          break;
        }

        // Small delay between batches to avoid hammering the server
        await Future.delayed(const Duration(milliseconds: 500));
        
      } catch (e) {
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _verifyProgress = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
        break;
      }
    }
  }

  /// Cancel the current verification run.
  Future<void> _cancelVerification() async {
    if (_currentRun == null) return;
    
    setState(() => _isCanceling = true);
    
    try {
      final service = ref.read(regulationsServiceProvider);
      await service.cancelVerificationRun(_currentRun!.runId);
      
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _verifyProgress = null;
          _currentRun = null;
          _isCanceling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification canceled')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCanceling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error canceling: $e')),
        );
      }
    }
  }

  /// Auto-fix broken links (http->https, redirect canonicalization).
  Future<void> _repairBrokenLinks() async {
    setState(() {
      _isRepairing = true;
      _lastRepairResult = null;
    });

    try {
      final service = ref.read(regulationsServiceProvider);
      final result = await service.repairBrokenLinks();
      
      if (mounted) {
        setState(() {
          _isRepairing = false;
          _lastRepairResult = result;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Repaired ${result.repaired} links. ${result.stillBroken} still broken.',
            ),
            backgroundColor: result.repaired > 0 ? AppColors.success : AppColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Reload stats to reflect changes
        _loadStats();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRepairing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Start discovery repair run.
  Future<void> _startRepairRun() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final run = await service.startRepairRun();
      
      if (mounted) {
        setState(() => _repairRun = run);
        
        if (!run.done) {
          _pollRepairRun(run.runId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Poll repair run until complete.
  Future<void> _pollRepairRun(String runId, {bool fullRebuild = false}) async {
    final service = ref.read(regulationsServiceProvider);

    while (mounted && _repairRun != null && !_isRepairCanceling) {
      try {
        final status = await service.continueRepairRun(runId, fullRebuild: fullRebuild);
        
        if (!mounted) break;
        
        setState(() => _repairRun = status);

        if (status.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Discovery complete: ${status.fixedCount} fixed, ${status.skippedCount} skipped',
              ),
              backgroundColor: status.fixedCount > 0 ? AppColors.success : AppColors.warning,
            ),
          );
          _loadStats();
          break;
        }

        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 300));
        
      } catch (e) {
        if (mounted) {
          setState(() => _repairRun = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
        break;
      }
    }
  }

  /// Cancel repair run.
  Future<void> _cancelRepairRun() async {
    if (_repairRun == null) return;
    
    setState(() => _isRepairCanceling = true);
    
    try {
      final service = ref.read(regulationsServiceProvider);
      await service.cancelRepairRun(_repairRun!.runId);
      
      if (mounted) {
        setState(() {
          _repairRun = null;
          _isRepairCanceling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repair canceled')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRepairCanceling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ============================================================
  // JOB QUEUE EXTRACTION METHODS (Droplet Worker)
  // ============================================================

  /// Start a new job queue extraction run.
  Future<void> _startExtractionRun({String tier = 'basic'}) async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final run = await service.startJobQueueExtractionRun(tier: tier);
      
      if (mounted) {
        setState(() => _activeExtractionRun = run);
        _pollJobQueueExtractionRun(run.runId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extraction started: ${run.progressTotal} jobs queued'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting extraction: $e')),
        );
      }
    }
  }

  /// Poll job queue extraction run until done.
  Future<void> _pollJobQueueExtractionRun(String runId) async {
    final service = ref.read(regulationsServiceProvider);

    while (mounted && _activeExtractionRun != null && !_isExtractionStopping) {
      try {
        // Wait before polling
        await Future.delayed(const Duration(seconds: 2));
        
        if (!mounted || _activeExtractionRun == null) break;
        
        final status = await service.getJobQueueRunStatus(runId: runId);
        
        // Handle 404 / run not found (e.g., after reset)
        if (status == null) {
          if (mounted) {
            setState(() => _activeExtractionRun = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Run ended or was reset')),
            );
            _loadStats();
          }
          break;
        }
        
        if (!mounted) break;
        
        setState(() => _activeExtractionRun = status);

        if (status.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Extraction complete: ${status.summaryLabel}'),
              backgroundColor: (status.jobs['done'] ?? 0) > 0 
                  ? AppColors.success 
                  : AppColors.warning,
            ),
          );
          _loadStats();
          break;
        }
        
      } catch (e) {
        if (mounted) {
          // Check if it's a 404 error
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('404') || errorStr.contains('not found')) {
            setState(() => _activeExtractionRun = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Run ended or was reset')),
            );
            _loadStats();
            break;
          }
          debugPrint('[RegsAdmin] Poll error: $e');
        }
      }
    }
  }

  /// Stop extraction run (actually stops on server).
  Future<void> _stopExtractionRun() async {
    if (_activeExtractionRun == null) return;
    
    setState(() => _isExtractionStopping = true);
    
    try {
      final service = ref.read(regulationsServiceProvider);
      await service.stopJobQueueRun(_activeExtractionRun!.runId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stopping extraction...')),
        );
        
        // Keep polling until stopped
        while (mounted && _activeExtractionRun != null) {
          await Future.delayed(const Duration(seconds: 1));
          final status = await service.getJobQueueRunStatus(runId: _activeExtractionRun!.runId);
          if (status == null || status.done) {
            setState(() {
              _activeExtractionRun = status;
              _isExtractionStopping = false;
            });
            break;
          }
          setState(() => _activeExtractionRun = status);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extraction stopped')),
        );
        _loadStats();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtractionStopping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping: $e')),
        );
      }
    }
  }

  // ============================================================
  // JOB QUEUE DISCOVERY METHODS (Droplet Worker)
  // ============================================================

  /// Start a new job queue discovery run.
  Future<void> _startDiscoveryRun({String tier = 'basic'}) async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final run = await service.startJobQueueDiscoveryRun(tier: tier);
      
      if (mounted) {
        setState(() => _activeDiscoveryRun = run);
        _pollJobQueueDiscoveryRun(run.runId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discovery started: Queued ${run.progressTotal} states'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting discovery: $e')),
        );
      }
    }
  }

  /// Resume a discovery run by enqueueing missing states.
  Future<void> _resumeDiscoveryRun() async {
    if (_activeDiscoveryRun == null) return;
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final run = await service.resumeDiscoveryRun(
        _activeDiscoveryRun!.runId,
        tier: _activeDiscoveryRun!.tier == 'pro' ? 'pro' : 'basic',
      );
      
      if (mounted) {
        setState(() => _activeDiscoveryRun = run);
        _pollJobQueueDiscoveryRun(run.runId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resumed discovery: Queued ${run.progressTotal} states'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resuming discovery: $e')),
        );
      }
    }
  }

  /// Requeue stuck jobs in the current discovery run.
  Future<void> _requeueDiscoveryRun() async {
    if (_activeDiscoveryRun == null) return;
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final result = await service.requeDiscoveryRun(_activeDiscoveryRun!.runId);
      
      final requeued = result['requeued_stuck'] as int? ?? 0;
      final cleared = result['locks_cleared'] as int? ?? 0;
      
      if (mounted) {
        // Refresh status
        final status = await service.getJobQueueRunStatus(runId: _activeDiscoveryRun!.runId);
        if (status != null) {
          setState(() => _activeDiscoveryRun = status);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Requeued $requeued stuck jobs, cleared $cleared locks'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requeuing: $e')),
        );
      }
    }
  }

  /// Poll job queue discovery run until done.
  Future<void> _pollJobQueueDiscoveryRun(String runId) async {
    final service = ref.read(regulationsServiceProvider);

    while (mounted && _activeDiscoveryRun != null && !_isDiscoveryStopping) {
      try {
        // Wait before polling
        await Future.delayed(const Duration(seconds: 2));
        
        if (!mounted || _activeDiscoveryRun == null) break;
        
        final status = await service.getJobQueueRunStatus(runId: runId);
        
        // Handle 404 / run not found (e.g., after reset)
        if (status == null) {
          if (mounted) {
            setState(() => _activeDiscoveryRun = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Run ended or was reset')),
            );
            _loadStats();
          }
          break;
        }
        
        if (!mounted) break;
        
        setState(() => _activeDiscoveryRun = status);

        if (status.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Discovery complete: ${status.summaryLabel}'),
              backgroundColor: (status.jobs['done'] ?? 0) > 0 
                  ? AppColors.success 
                  : AppColors.warning,
            ),
          );
          _loadStats();
          break;
        }
        
      } catch (e) {
        if (mounted) {
          // Check if it's a 404 error
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('404') || errorStr.contains('not found')) {
            setState(() => _activeDiscoveryRun = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Run ended or was reset')),
            );
            _loadStats();
            break;
          }
          debugPrint('[RegsAdmin] Poll error: $e');
        }
      }
    }
  }

  /// Stop discovery run (actually stops on server).
  Future<void> _stopDiscoveryRun() async {
    if (_activeDiscoveryRun == null) return;
    
    setState(() => _isDiscoveryStopping = true);
    
    try {
      final service = ref.read(regulationsServiceProvider);
      await service.stopJobQueueRun(_activeDiscoveryRun!.runId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stopping discovery...')),
        );
        
        // Keep polling until stopped
        while (mounted && _activeDiscoveryRun != null) {
          await Future.delayed(const Duration(seconds: 1));
          final status = await service.getJobQueueRunStatus(runId: _activeDiscoveryRun!.runId);
          if (status == null || status.done) {
            setState(() {
              _activeDiscoveryRun = status;
              _isDiscoveryStopping = false;
            });
            break;
          }
          setState(() => _activeDiscoveryRun = status);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discovery stopped')),
        );
        _loadStats();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDiscoveryStopping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping: $e')),
        );
      }
    }
  }

  /// View repair report in dialog.
  Future<void> _viewRepairReport() async {
    final runId = _repairRun?.runId;
    if (runId == null) return;

    try {
      final service = ref.read(regulationsServiceProvider);
      final items = await service.fetchRepairRunItems(runId);
      
      if (mounted) {
        _showRepairReportDialog(items);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    }
  }

  void _showRepairReportDialog(List<RepairRunItem> items) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 500),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.article_outlined, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Text(
                    'Repair Report',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildReportStat(
                      'Total',
                      items.length.toString(),
                      AppColors.textPrimary,
                    ),
                    _buildReportStat(
                      'Fixed',
                      items.where((e) => e.isFixed).length.toString(),
                      AppColors.success,
                    ),
                    _buildReportStat(
                      'Skipped',
                      items.where((e) => !e.isFixed).length.toString(),
                      AppColors.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Items list
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: item.isFixed 
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.isFixed 
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.stateCode,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: item.isFixed ? AppColors.success : AppColors.warning,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.fieldLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                item.isFixed ? Icons.check_circle : Icons.help_outline,
                                size: 16,
                                color: item.isFixed ? AppColors.success : AppColors.warning,
                              ),
                            ],
                          ),
                          if (item.newUrl != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'New: ${item.newUrl}',
                              style: TextStyle(fontSize: 11, color: AppColors.success),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (item.message != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.message!,
                              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                            ),
                          ],
                          Text(
                            'Crawled ${item.pagesCrawled} pages, ${item.candidatesFound} candidates',
                            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
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

  Widget _buildReportStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRepairProgressStat(String label, int value, Color color) {
    return Row(
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
          '$label: $value',
          style: TextStyle(
            fontSize: 11,
            color: color,
          ),
        ),
      ],
    );
  }
  
  /// Truncate skip reason for display.
  String _truncateReason(String reason) {
    if (reason.length <= 25) return reason;
    // Truncate and clean up
    var short = reason.substring(0, 25);
    if (short.contains(':')) {
      short = short.split(':').first;
    }
    return '$short...';
  }

  Future<void> _resetData() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ResetOptionsDialog(),
    );
    
    if (result == null || !mounted) return;
    
    // Show confirmation with RESET code
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Confirm ${result.replaceAll('_', ' ').toUpperCase()}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getResetDescription(result),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Type RESET to confirm',
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
            onPressed: () {
              if (controller.text == 'RESET') {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Type RESET to confirm')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    try {
      setState(() => _isLoading = true);
      
      // IMPORTANT: Clear all active run states BEFORE reset
      // This stops polling and prevents 404 errors after runs are deleted
      _clearAllRunStates();
      
      final service = ref.read(regulationsServiceProvider);
      Map<String, dynamic> resetResult;
      String successMessage;
      
      // Use the appropriate reset function based on type
      if (result == 'full') {
        // Full reset: delete all portal links and reseed from official roots
        resetResult = await service.resetFull(confirmCode: 'RESET');
        final results = resetResult['results'] as Map<String, dynamic>?;
        final deleted = results?['portal_rows_deleted'] ?? 0;
        final inserted = results?['portal_rows_inserted'] ?? 0;
        successMessage = 'Full reset complete. Run GPT Discovery to repopulate portal links.';
      } else if (result == 'verification') {
        // Verification reset: clear flags only
        resetResult = await service.resetVerification(confirmCode: 'RESET');
        final results = resetResult['results'] as Map<String, dynamic>?;
        final updated = results?['portal_rows_updated'] ?? 0;
        successMessage = 'Verification reset: $updated rows cleared. Run Verify to re-check links.';
      } else {
        // Extracted reset: use legacy method
        resetResult = await service.resetData(type: result, confirmCode: 'RESET');
        successMessage = 'Reset complete';
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Immediately reload stats to show updated counts
        await _loadStats();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset failed: $e')),
        );
      }
    }
  }
  
  String _getResetDescription(String type) {
    switch (type) {
      case 'verification':
        return 'This will clear all verification flags, status codes, and timestamps.\n\n'
               'All discovered URLs will remain intact.\n'
               'Use this to re-run link verification from scratch.';
      case 'extracted':
        return 'This will clear:\n'
               '• All job queue data (runs, jobs, events)\n'
               '• All extracted regulations data\n'
               '• All verification status\n\n'
               'Portal URLs and official roots will be preserved.';
      case 'full':
        return 'This will DELETE all portal link rows and RESEED from official roots.\n\n'
               'All data will be cleared:\n'
               '• All discovered URLs\n'
               '• All verification status\n'
               '• All job queue data\n'
               '• All extracted regulations\n\n'
               'Only the 50 state codes from official roots will remain.';
      default:
        return 'Unknown reset type';
    }
  }

  // Legacy method kept for compatibility
  Future<void> _resetDataLegacy() async {
    final controller = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Reset Regulations Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will clear all portal link verification status. '
              'Official roots will NOT be deleted.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Type RESET to confirm:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'RESET',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text == 'RESET') {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (confirmed == true) {
      try {
        final service = ref.read(regulationsServiceProvider);
        await service.resetVerificationStatus();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification status reset'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadStats();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
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
              _buildHeader(),
              
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildError()
                        : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regulations Admin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Manage official portal links',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load stats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Section
          _buildSectionHeader('Overview'),
          const SizedBox(height: 12),
          _buildOverviewCards(),
          
          const SizedBox(height: 32),
          
          // Actions Section
          _buildSectionHeader('Actions'),
          const SizedBox(height: 12),
          _buildActionsCard(),
          
          const SizedBox(height: 32),
          
          // Broken Links Section (always visible)
          _buildBrokenLinksSection(),
          const SizedBox(height: 32),
          
          // Danger Zone
          _buildDangerZone(),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Column(
      children: [
        // Row 1: Roots + Portal Rows
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.account_tree_rounded,
                label: 'Official Roots',
                value: '${_stats.rootsCount}/50',
                color: _stats.rootsCount == 50 ? AppColors.success : AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.table_rows_rounded,
                label: 'Portal Rows',
                value: '${_stats.portalRowsCount}/50',
                color: _stats.portalRowsCount == 50 ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Fields Filled + Verified
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.link_rounded,
                label: 'Fields Filled',
                value: '${_stats.filledFieldsCount}/${_stats.totalPossibleFields}',
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.verified_rounded,
                label: 'Fields Verified',
                value: '${_stats.verifiedFieldsCount}/${_stats.totalPossibleFields}',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 3: PDF Sources + Extractable States
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF Sources',
                value: '${_stats.pdfFieldsCount}',
                color: _stats.pdfFieldsCount > 0 ? AppColors.info : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.auto_awesome_rounded,
                label: 'Extractable',
                value: '${_stats.extractableStatesCount}/50',
                color: _stats.extractableStatesCount > 0 ? AppColors.accent : AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 4: Broken Links
        _StatCard(
          icon: Icons.link_off_rounded,
          label: 'Broken Links',
          value: '${_stats.brokenCount}',
          color: _stats.brokenCount > 0 ? AppColors.error : AppColors.success,
        ),
        // Missing states warning
        if (_stats.missingStateCodes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildMissingStatesCard(),
        ],
        // Last verified
        if (_stats.lastVerifiedAt != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Last verified: ${_formatDate(_stats.lastVerifiedAt!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildMissingStatesCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'Missing Portal Rows: ${_stats.missingStateCodes.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'States: ${_stats.missingStateCodes.join(", ")}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fixMissingStates,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: const Text('Fix Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _fixMissingStates() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final inserted = await service.ensurePortalRows();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(inserted.isEmpty 
                ? 'No missing states found' 
                : 'Added ${inserted.length} missing state(s): ${inserted.join(", ")}'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadStats(); // Refresh stats
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

  Widget _buildActionsCard() {
    // Check if there are any portal URLs to work with
    final hasPortalUrls = _stats.filledFieldsCount > 0;
    final hasBrokenLinks = _brokenLinks.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ====== GPT-GUIDED DISCOVERY SECTION (Always enabled - creates URLs) ======
          _buildDiscoverySection(),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // ====== EXTRACT FACTS SECTION ======
          _buildExtractionSection(),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // ====== VERIFY PORTAL LINKS SECTION ======
          Text(
            'Verify Portal Links',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasPortalUrls
                ? 'Server-side verification with timeout & retry. Safe to navigate away.'
                : 'No portal URLs to verify. Run GPT Discovery first.',
            style: TextStyle(
              fontSize: 13,
              color: hasPortalUrls ? AppColors.textSecondary : AppColors.warning,
            ),
          ),
          const SizedBox(height: 16),
          if (_isVerifying) ...[
            // Progress bar with actual progress value
            LinearProgressIndicator(
              value: _currentRun?.progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
            const SizedBox(height: 12),
            // Progress text with counts
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _verifyProgress ?? 'Verifying...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_currentRun != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_currentRun!.okCount} OK • ${_currentRun!.brokenCount} broken',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Cancel button
                TextButton.icon(
                  onPressed: _isCanceling ? null : _cancelVerification,
                  icon: Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: _isCanceling ? AppColors.textTertiary : AppColors.error,
                  ),
                  label: Text(
                    _isCanceling ? 'Canceling...' : 'Cancel',
                    style: TextStyle(
                      color: _isCanceling ? AppColors.textTertiary : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasPortalUrls ? _verifyAllLinks : null,
                icon: const Icon(Icons.verified_rounded),
                label: Text(hasPortalUrls ? 'Verify All Links' : 'Nothing to Verify (0 URLs)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasPortalUrls ? AppColors.accent : AppColors.textTertiary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          
          // ====== AUTO-FIX BROKEN LINKS SECTION ======
          if (!_isVerifying) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Auto-Fix Broken Links',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasBrokenLinks
                  ? 'Attempts conservative fixes: HTTP→HTTPS, trailing slash, redirect canonicalization.'
                  : 'No broken links detected. Run Verify first to find broken links.',
              style: TextStyle(
                fontSize: 13,
                color: hasBrokenLinks ? AppColors.textSecondary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            if (_isRepairing)
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Repairing broken links...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: hasBrokenLinks ? _repairBrokenLinks : null,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: Text(hasBrokenLinks 
                      ? 'Auto-Fix ${_brokenLinks.length} Broken Links' 
                      : 'No Broken Links'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: hasBrokenLinks ? AppColors.warning : AppColors.textTertiary,
                    side: BorderSide(color: hasBrokenLinks 
                        ? AppColors.warning.withValues(alpha: 0.5)
                        : AppColors.textTertiary.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_lastRepairResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last repair: ${_lastRepairResult!.repaired} fixed, ${_lastRepairResult!.stillBroken} still broken',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _lastRepairResult!.repaired > 0 
                              ? AppColors.success 
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (_lastRepairResult!.details.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...(_lastRepairResult!.details.take(5).map((d) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${d.state} ${d.field}: ${d.actionLabel}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ))),
                        if (_lastRepairResult!.details.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '... and ${_lastRepairResult!.details.length - 5} more',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
            
            // Discovery Repair section
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Official Discovery Repair',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Crawls official state domains to find replacement URLs for broken links.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (_repairRun != null && _repairRun!.isRunning) ...[
              // Running state with progress
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Running Discovery Repair...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _repairRun!.progress,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress: ${_repairRun!.progressPercent}%',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          _repairRun!.progressText,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildRepairProgressStat('Fixed', _repairRun!.fixedCount, AppColors.success),
                        const SizedBox(width: 12),
                        _buildRepairProgressStat('Skipped', _repairRun!.skippedCount, AppColors.warning),
                        const SizedBox(width: 12),
                        _buildRepairProgressStat('Errors', _repairRun!.errorCount, AppColors.error),
                      ],
                    ),
                    if (_repairRun!.lastStateCode != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Current: ${_repairRun!.lastStateCode}',
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                    // Show skip reasons distribution
                    if (_repairRun!.skipReasons != null && _repairRun!.skipReasons!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text(
                        'Skip reasons:',
                        style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _repairRun!.skipReasons!.entries.map((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_truncateReason(e.key)}: ${e.value}',
                              style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isRepairCanceling ? null : _cancelRepairRun,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: BorderSide(color: AppColors.warning),
                        ),
                        child: Text(_isRepairCanceling ? 'Canceling...' : 'Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Start button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startRepairRun,
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: const Text('Repair via Official Discovery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              // Show completed run summary
              if (_repairRun != null && _repairRun!.isComplete) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _repairRun!.fixedCount > 0 
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _repairRun!.fixedCount > 0 
                                ? Icons.check_circle_outline 
                                : Icons.info_outline,
                            size: 16,
                            color: _repairRun!.fixedCount > 0 
                                ? AppColors.success 
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Discovery complete: ${_repairRun!.fixedCount} fixed, ${_repairRun!.skippedCount} skipped',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _repairRun!.fixedCount > 0 
                                  ? AppColors.success 
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _viewRepairReport,
                            icon: Icon(Icons.article_outlined, size: 16, color: AppColors.accent),
                            label: Text(
                              'View Full Report',
                              style: TextStyle(fontSize: 12, color: AppColors.accent),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: _viewRepairHistory,
                            icon: Icon(Icons.history_rounded, size: 16, color: AppColors.textSecondary),
                            label: Text(
                              'Repair History',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
            
            // Full Rebuild section
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Full Rebuild (Keep Official Roots)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Resets all portal sub-links to null, then runs GPT discovery for all 50 states. Official PDF roots are preserved.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_repairRun != null && _repairRun!.isRunning) ? null : _showRebuildDialog,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Rebuild Portal Links'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: BorderSide(color: AppColors.warning),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
          ],
        ],
      ),
    );
  }
  
  Widget _buildExtractionSection() {
    final hasExtractableSources = _stats.hasExtractableSources;
    final hasPdfSources = _stats.hasPdfSources;
    
    // Build helper text based on available sources
    String helperText;
    if (hasExtractableSources) {
      if (hasPdfSources) {
        helperText = 'Extract from ${_stats.extractableStatesCount} states (${_stats.pdfFieldsCount} PDFs). Parses PDFs on server.';
      } else {
        helperText = 'Extract from ${_stats.extractableStatesCount} states. Only publishes when confidence >= 85%.';
      }
    } else {
      helperText = 'No portal URLs to extract from. Run GPT Discovery first.';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              'Extract Facts (Deer/Turkey)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (hasPdfSources) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PDF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: TextStyle(
            fontSize: 13,
            color: hasExtractableSources ? AppColors.textSecondary : AppColors.warning,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_activeExtractionRun != null && _activeExtractionRun!.isRunning) ...[
          // Progress bar
          LinearProgressIndicator(
            value: _activeExtractionRun!.progress,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_activeExtractionRun!.progressDone}/${_activeExtractionRun!.progressTotal} jobs',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activeExtractionRun!.summaryLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    // Show status: either "Extracting: XX" or status label
                    Text(
                      _activeExtractionRun!.hasStoppableJobs
                          ? (_activeExtractionRun!.lastState != null
                              ? '${_activeExtractionRun!.tier.toUpperCase()} • Extracting: ${_activeExtractionRun!.lastState}'
                              : '${_activeExtractionRun!.tier.toUpperCase()} • Starting...')
                          : '${_activeExtractionRun!.tier.toUpperCase()} • ${_activeExtractionRun!.statusLabel}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Only show Stop button if there are stoppable jobs
              if (_activeExtractionRun!.hasStoppableJobs)
                TextButton.icon(
                  onPressed: _isExtractionStopping ? null : _stopExtractionRun,
                  icon: Icon(
                    Icons.stop_circle_outlined,
                    size: 18,
                    color: _isExtractionStopping ? AppColors.textTertiary : AppColors.error,
                  ),
                  label: Text(
                    _isExtractionStopping ? 'Stopping...' : 'Stop',
                    style: TextStyle(
                      color: _isExtractionStopping ? AppColors.textTertiary : AppColors.error,
                    ),
                  ),
                )
              else
                // Show "finishing" indicator when no stoppable jobs
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Finishing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ] else ...[
          // Results display (if completed)
          if (_activeExtractionRun != null && _activeExtractionRun!.done) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _activeExtractionRun!.wasStopped 
                      ? AppColors.warning.withValues(alpha: 0.3)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _activeExtractionRun!.wasStopped 
                            ? Icons.stop_circle_outlined 
                            : Icons.check_circle_outline, 
                        size: 16, 
                        color: _activeExtractionRun!.wasStopped 
                            ? AppColors.warning 
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _activeExtractionRun!.wasStopped 
                            ? 'Extraction stopped' 
                            : 'Extraction complete',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _activeExtractionRun!.wasStopped 
                              ? AppColors.warning 
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _activeExtractionRun!.summaryLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Start buttons row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasExtractableSources ? () => _startExtractionRun(tier: 'basic') : null,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(hasExtractableSources ? 'Extract Facts Now' : 'Run Discovery First'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasExtractableSources ? AppColors.accent : AppColors.textTertiary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: hasExtractableSources ? () => _startExtractionRun(tier: 'pro') : null,
                  icon: Icon(Icons.bolt, size: 16, color: hasExtractableSources ? AppColors.accent : AppColors.textTertiary),
                  label: Text(
                    'PRO',
                    style: TextStyle(
                      color: hasExtractableSources ? AppColors.accent : AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: hasExtractableSources 
                        ? AppColors.accent.withValues(alpha: 0.5)
                        : AppColors.textTertiary.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
  
  Widget _buildDiscoverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.travel_explore_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              'GPT-Guided Discovery',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Smart crawler guided by GPT to find portal links. Crawls 40-80 pages per state, validates strictly.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_activeDiscoveryRun != null && _activeDiscoveryRun!.isRunning) ...[
          // Progress bar
          LinearProgressIndicator(
            value: _activeDiscoveryRun!.progress,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Done: ${_activeDiscoveryRun!.progressDone}/${_activeDiscoveryRun!.progressTotal} states',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Show detailed counts
                    Builder(
                      builder: (context) {
                        final jobs = _activeDiscoveryRun!.jobs;
                        final parts = <String>[];
                        if ((jobs['queued'] ?? 0) > 0) parts.add('Queued: ${jobs['queued']}');
                        if ((jobs['running'] ?? 0) > 0) parts.add('Running: ${jobs['running']}');
                        if ((jobs['failed'] ?? 0) > 0) parts.add('Failed: ${jobs['failed']}');
                        if ((jobs['skipped'] ?? 0) > 0) parts.add('Skipped: ${jobs['skipped']}');
                        
                        return Text(
                          parts.isEmpty ? 'Processing...' : parts.join(' • '),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                    // Show status: either "Crawling: XX" or "Finishing..." or status label
                    Text(
                      _activeDiscoveryRun!.hasStoppableJobs
                          ? (_activeDiscoveryRun!.lastState != null
                              ? '${_activeDiscoveryRun!.tier.toUpperCase()} • Crawling: ${_activeDiscoveryRun!.lastState}'
                              : '${_activeDiscoveryRun!.tier.toUpperCase()} • Starting...')
                          : '${_activeDiscoveryRun!.tier.toUpperCase()} • ${_activeDiscoveryRun!.statusLabel}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Show Stop and Resume buttons
              if (_activeDiscoveryRun!.hasStoppableJobs) ...[
                TextButton.icon(
                  onPressed: _isDiscoveryStopping ? null : _stopDiscoveryRun,
                  icon: Icon(
                    Icons.stop_circle_outlined,
                    size: 18,
                    color: _isDiscoveryStopping ? AppColors.textTertiary : AppColors.error,
                  ),
                  label: Text(
                    _isDiscoveryStopping ? 'Stopping...' : 'Stop',
                    style: TextStyle(
                      color: _isDiscoveryStopping ? AppColors.textTertiary : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _resumeDiscoveryRun,
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                  ),
                  label: const Text('Resume'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _requeueDiscoveryRun,
                  icon: const Icon(
                    Icons.refresh,
                    size: 18,
                  ),
                  label: const Text('Unstick'),
                ),
              ]
              else
                // Show "finishing" indicator when no stoppable jobs
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Finishing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ] else ...[
          // Results display (if completed)
          if (_activeDiscoveryRun != null && _activeDiscoveryRun!.done) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _activeDiscoveryRun!.wasStopped 
                      ? AppColors.warning.withValues(alpha: 0.3)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _activeDiscoveryRun!.wasStopped 
                            ? Icons.stop_circle_outlined 
                            : Icons.check_circle_outline, 
                        size: 16, 
                        color: _activeDiscoveryRun!.wasStopped 
                            ? AppColors.warning 
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _activeDiscoveryRun!.wasStopped 
                            ? 'Discovery stopped' 
                            : 'Discovery complete',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _activeDiscoveryRun!.wasStopped 
                              ? AppColors.warning 
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _activeDiscoveryRun!.summaryLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Show Resume and Unstick buttons if stopped but not completed
            if (_activeDiscoveryRun!.wasStopped && !_activeDiscoveryRun!.allJobsTerminal)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _resumeDiscoveryRun,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Resume'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _requeueDiscoveryRun,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Unstick'),
                    ),
                  ],
                ),
              ),
          ],
          
          // Start buttons row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startDiscoveryRun(tier: 'basic'),
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: const Text('Run GPT Discovery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _startDiscoveryRun(tier: 'pro'),
                  icon: Icon(Icons.bolt, size: 16, color: AppColors.accent),
                  label: Text(
                    'PRO',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
  
  /// Show repair history modal with undo functionality.
  Future<void> _viewRepairHistory() async {
    final service = ref.read(regulationsServiceProvider);
    
    showDialog(
      context: context,
      builder: (ctx) => _RepairHistoryDialog(service: service),
    );
  }
  
  /// Show rebuild confirmation dialog.
  Future<void> _showRebuildDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _RebuildConfirmDialog(),
    );
    
    if (confirmed == true && mounted) {
      await _executeRebuild();
    }
  }
  
  /// Execute full rebuild: reset portal links then run GPT discovery.
  Future<void> _executeRebuild() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      
      // Step 1: Reset portal links
      setState(() => _verifyProgress = 'Resetting portal links...');
      await service.resetPortalLinks(confirmCode: 'RESET', preserveLocks: true);
      
      if (!mounted) return;
      
      // Step 2: Start full rebuild GPT discovery
      setState(() => _verifyProgress = 'Starting GPT discovery for all states...');
      final run = await service.startRepairRun(fullRebuild: true);
      
      if (!mounted) return;
      setState(() {
        _repairRun = run;
        _verifyProgress = null;
      });
      
      // Poll for progress
      _pollRepairRun(run.runId, fullRebuild: true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Full rebuild started. GPT is discovering portal links...'),
          backgroundColor: AppColors.info,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _verifyProgress = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rebuild failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildBrokenLinksSection() {
    final hasBrokenLinks = _brokenLinks.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasBrokenLinks ? () => setState(() => _showBrokenLinks = !_showBrokenLinks) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  hasBrokenLinks ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  size: 18,
                  color: hasBrokenLinks ? AppColors.error : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  hasBrokenLinks 
                      ? 'Broken Links (${_brokenLinks.length})'
                      : 'No Broken Links',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasBrokenLinks ? AppColors.error : AppColors.success,
                  ),
                ),
                const Spacer(),
                if (hasBrokenLinks)
                  Icon(
                    _showBrokenLinks ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
        if (!hasBrokenLinks) ...[
          const SizedBox(height: 8),
          Text(
            _stats.filledFieldsCount > 0
                ? 'All portal links are healthy. Run Verify to check again.'
                : 'No portal links to check. Run GPT Discovery first.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (_showBrokenLinks && hasBrokenLinks) ...[
          const SizedBox(height: 12),
          // Group broken links by state
          ..._buildGroupedBrokenLinks(),
        ],
      ],
    );
  }

  /// Build broken links grouped by state with expandable details.
  List<Widget> _buildGroupedBrokenLinks() {
    // Group by state
    final grouped = <String, List<_BrokenLink>>{};
    for (final link in _brokenLinks) {
      grouped.putIfAbsent(link.stateCode, () => []).add(link);
    }
    
    final states = grouped.keys.toList()..sort();
    
    return states.map((stateCode) {
      final links = grouped[stateCode]!;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              stateCode,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
          title: Text(
            '${links.length} broken link${links.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          children: links.map((link) => _buildBrokenLinkItem(link)).toList(),
        ),
      );
    }).toList();
  }

  Widget _buildBrokenLinkItem(_BrokenLink link) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  link.field,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  link.statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.error,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          if (link.url != null) ...[
            const SizedBox(height: 4),
            Text(
              link.url!,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (link.error != null && link.error!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              link.error!,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _editBrokenLink(link),
                icon: Icon(Icons.edit_rounded, size: 14, color: AppColors.accent),
                label: Text(
                  'Edit URL',
                  style: TextStyle(fontSize: 12, color: AppColors.accent),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show dialog to manually edit a broken link URL.
  Future<void> _editBrokenLink(_BrokenLink link) async {
    final controller = TextEditingController(text: link.url ?? '');
    
    final newUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Edit ${link.field} URL',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'State: ${link.stateCode}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the correct official URL. This will reset verification status.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (newUrl != null && newUrl.isNotEmpty && newUrl != link.url) {
      try {
        final service = ref.read(regulationsServiceProvider);
        await service.updatePortalLinkUrl(
          stateCode: link.stateCode,
          field: link.field,
          newUrl: newUrl,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('URL updated for ${link.stateCode} ${link.field}'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadStats(); // Reload to refresh broken links
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Reset various levels of data. Official root URLs are always preserved.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _resetData,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset Data...'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${date.month}/${date.day}/${date.year}';
  }
}

// ============================================================================
// MODELS
// ============================================================================

class _AdminStats {
  const _AdminStats({
    this.rootsCount = 0,
    this.portalRowsCount = 0,
    this.filledFieldsCount = 0,
    this.verifiedFieldsCount = 0,
    this.pdfFieldsCount = 0,
    this.miscRelatedCount = 0,
    this.extractableStatesCount = 0,
    this.brokenCount = 0,
    this.missingStateCodes = const [],
    this.lastVerifiedAt,
  });

  final int rootsCount;
  final int portalRowsCount;
  final int filledFieldsCount;
  final int verifiedFieldsCount;
  final int pdfFieldsCount;
  final int miscRelatedCount;
  final int extractableStatesCount;
  final int brokenCount;
  final List<String> missingStateCodes;
  final DateTime? lastVerifiedAt;

  /// Total possible fields (9 per state * 50 states = 450)
  int get totalPossibleFields => rootsCount * 9;
  
  /// Whether all states have portal rows
  bool get allStatesHavePortalRows => portalRowsCount >= rootsCount;
  
  /// True if any extractable sources exist (HTML, PDF, or misc)
  bool get hasExtractableSources => extractableStatesCount > 0;
  
  /// True if we have PDF sources
  bool get hasPdfSources => pdfFieldsCount > 0;

  factory _AdminStats.fromMap(Map<String, dynamic> map) {
    return _AdminStats(
      rootsCount: map['roots_count'] ?? 0,
      portalRowsCount: map['portal_rows_count'] ?? 0,
      filledFieldsCount: map['filled_fields_count'] ?? 0,
      verifiedFieldsCount: map['verified_fields_count'] ?? 0,
      pdfFieldsCount: map['pdf_fields_count'] ?? 0,
      miscRelatedCount: map['misc_related_count'] ?? 0,
      extractableStatesCount: map['extractable_states_count'] ?? 0,
      brokenCount: map['broken_count'] ?? 0,
      missingStateCodes: (map['missing_state_codes'] as List?)
          ?.map((e) => e as String)
          .toList() ?? [],
      lastVerifiedAt: map['last_verified_at'] != null
          ? DateTime.tryParse(map['last_verified_at'])
          : null,
    );
  }
}

class _BrokenLink {
  const _BrokenLink({
    required this.stateCode,
    required this.field,
    this.url,
    this.status,
    this.error,
  });

  final String stateCode;
  final String field;
  final String? url;
  final int? status;
  final String? error;

  factory _BrokenLink.fromMap(Map<String, dynamic> map) {
    return _BrokenLink(
      stateCode: map['state_code'] ?? '',
      field: map['field'] ?? '',
      url: map['url'] as String?,
      status: map['status'],
      error: map['error'],
    );
  }
  
  String get statusLabel {
    if (status == null) return 'Timeout/Error';
    if (status == 404) return '404 Not Found';
    if (status == 403) return '403 Forbidden';
    if (status == 500) return '500 Server Error';
    if (status! >= 500) return '$status Server Error';
    return 'HTTP $status';
  }
}

// ============================================================================
// WIDGETS
// ============================================================================

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog showing repair history with undo functionality.
class _RepairHistoryDialog extends StatefulWidget {
  const _RepairHistoryDialog({required this.service});
  
  final RegulationsService service;
  
  @override
  State<_RepairHistoryDialog> createState() => _RepairHistoryDialogState();
}

class _RepairHistoryDialogState extends State<_RepairHistoryDialog> {
  bool _isLoading = true;
  List<RepairAuditRecord> _repairs = [];
  String? _error;
  String? _undoingId;
  
  @override
  void initState() {
    super.initState();
    _loadRepairs();
  }
  
  Future<void> _loadRepairs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final repairs = await widget.service.fetchRecentRepairs(limit: 50);
      if (mounted) {
        setState(() {
          _repairs = repairs;
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
  
  Future<void> _undoRepair(RepairAuditRecord repair) async {
    setState(() => _undoingId = repair.id);
    
    try {
      await widget.service.undoRepair(repair.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Undone: ${repair.stateCode} ${repair.fieldLabel}'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadRepairs(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Undo failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _undoingId = null);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Repair History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: TextStyle(color: AppColors.error),
                          ),
                        )
                      : _repairs.isEmpty
                          ? Center(
                              child: Text(
                                'No repair history yet',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _repairs.length,
                              itemBuilder: (ctx, idx) => _buildRepairItem(_repairs[idx]),
                            ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRepairItem(RepairAuditRecord repair) {
    final isUndoing = _undoingId == repair.id;
    
    Color statusColor;
    IconData statusIcon;
    switch (repair.status) {
      case 'fixed':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'undone':
        statusColor = AppColors.warning;
        statusIcon = Icons.undo;
        break;
      case 'skipped':
        statusColor = AppColors.textTertiary;
        statusIcon = Icons.skip_next;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.info_outline;
    }
    
    return Card(
      color: AppColors.background,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  '${repair.stateCode} • ${repair.fieldLabel}',
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
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    repair.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            
            // Confidence + reason
            if (repair.confidence != null && repair.confidence! > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _ConfidenceBadge(confidence: repair.confidence!),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      repair.gptReason ?? repair.message ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            
            // URLs
            if (repair.newUrl != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.link, size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      repair.newUrl!,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.accent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            
            // Validation info
            if (repair.validationReason != null) ...[
              const SizedBox(height: 4),
              Text(
                'Validation: ${repair.validationReason}',
                style: TextStyle(
                  fontSize: 10,
                  color: repair.validationPassed == true 
                      ? AppColors.success 
                      : AppColors.textTertiary,
                ),
              ),
            ],
            
            // Undo button for fixed repairs
            if (repair.canUndo) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isUndoing ? null : () => _undoRepair(repair),
                  icon: isUndoing
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.undo, size: 14),
                  label: Text(isUndoing ? 'Undoing...' : 'Undo This Repair'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
            
            // Timestamp
            if (repair.repairedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(repair.repairedAt!),
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Badge showing GPT confidence level.
class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});
  
  final int confidence;
  
  @override
  Widget build(BuildContext context) {
    Color color;
    if (confidence >= 75) {
      color = AppColors.success;
    } else if (confidence >= 50) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$confidence%',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Dialog to choose reset type.
class _ResetOptionsDialog extends StatelessWidget {
  const _ResetOptionsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.warning_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          const Text('Reset Data'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose what to reset:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            
            // Reset Verification Only
            _ResetOptionTile(
              title: 'Reset Verification Only',
              subtitle: 'Clear verification flags and status codes. '
                       'All discovered URLs remain intact.',
              icon: Icons.verified_outlined,
              color: AppColors.info,
              onTap: () => Navigator.pop(context, 'verification'),
            ),
            const SizedBox(height: 12),
            
            // Reset Extracted Data
            _ResetOptionTile(
              title: 'Reset Extracted Data',
              subtitle: 'Clear job queue, extracted regulations, and verification. '
                       'Keep discovered URLs and official roots.',
              icon: Icons.delete_sweep_outlined,
              color: AppColors.warning,
              onTap: () => Navigator.pop(context, 'extracted'),
            ),
            const SizedBox(height: 12),
            
            // Full Reset
            _ResetOptionTile(
              title: 'Full Reset (Reseed Portal Links)',
              subtitle: 'DELETE all portal rows and RESEED from official roots. '
                       'Guarantees clean slate with no stale data.',
              icon: Icons.restore_outlined,
              color: AppColors.error,
              onTap: () => Navigator.pop(context, 'full'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ResetOptionTile extends StatelessWidget {
  const _ResetOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog to confirm full rebuild with RESET confirmation.
class _RebuildConfirmDialog extends StatefulWidget {
  const _RebuildConfirmDialog();
  
  @override
  State<_RebuildConfirmDialog> createState() => _RebuildConfirmDialogState();
}

class _RebuildConfirmDialogState extends State<_RebuildConfirmDialog> {
  final _controller = TextEditingController();
  bool _isValid = false;
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _isValid = _controller.text.trim().toUpperCase() == 'RESET';
      });
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.warning_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            'Rebuild Portal Links',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action will:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBullet('Reset ALL portal sub-links to Unavailable'),
                  _buildBullet('Run GPT discovery for all 50 states'),
                  _buildBullet('Keep official PDF roots intact'),
                  _buildBullet('Preserve locked field settings'),
                  const SizedBox(height: 8),
                  Text(
                    'This may take several minutes.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Type RESET to confirm:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'RESET',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.warning),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isValid ? () => Navigator.of(context).pop(true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.textTertiary,
          ),
          child: const Text('Rebuild'),
        ),
      ],
    );
  }
  
  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppColors.warning)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}