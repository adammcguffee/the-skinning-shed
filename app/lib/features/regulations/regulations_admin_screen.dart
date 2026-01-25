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

  @override
  void initState() {
    super.initState();
    _loadStats();
    _checkForExistingRun();
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

  Future<void> _resetData() async {
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
          
          // Broken Links Section (if any)
          if (_brokenLinks.isNotEmpty) ...[
            _buildBrokenLinksSection(),
            const SizedBox(height: 32),
          ],
          
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
        // Row 1: Roots + Total Links
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
                icon: Icons.link_rounded,
                label: 'Portal Links',
                value: '${_stats.totalLinksCount}',
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Verified + Broken
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.verified_rounded,
                label: 'Verified Links',
                value: '${_stats.verifiedCount}',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.link_off_rounded,
                label: 'Broken Links',
                value: '${_stats.brokenCount}',
                color: _stats.brokenCount > 0 ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Last verified
        if (_stats.lastVerifiedAt != null)
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
    );
  }

  Widget _buildActionsCard() {
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
            'Server-side verification with timeout & retry. Safe to navigate away.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
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
                onPressed: _verifyAllLinks,
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Verify All Links'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrokenLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showBrokenLinks = !_showBrokenLinks),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Broken Links (${_brokenLinks.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showBrokenLinks ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_showBrokenLinks) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _brokenLinks.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColors.border,
              ),
              itemBuilder: (context, index) {
                final link = _brokenLinks[index];
                return ListTile(
                  dense: true,
                  leading: Text(
                    link.stateCode,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  title: Text(
                    link.field,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    link.error ?? 'Unknown error',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                    ),
                  ),
                  trailing: Text(
                    'HTTP ${link.status ?? '?'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
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
            'Reset verification status for all portal links. This does not delete official roots.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _resetData,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset Verification Status'),
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
    this.totalLinksCount = 0,
    this.verifiedCount = 0,
    this.brokenCount = 0,
    this.lastVerifiedAt,
  });

  final int rootsCount;
  final int totalLinksCount;
  final int verifiedCount;
  final int brokenCount;
  final DateTime? lastVerifiedAt;

  factory _AdminStats.fromMap(Map<String, dynamic> map) {
    return _AdminStats(
      rootsCount: map['roots_count'] ?? 0,
      totalLinksCount: map['total_links_count'] ?? 0,
      verifiedCount: map['verified_count'] ?? 0,
      brokenCount: map['broken_count'] ?? 0,
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
    this.status,
    this.error,
  });

  final String stateCode;
  final String field;
  final int? status;
  final String? error;

  factory _BrokenLink.fromMap(Map<String, dynamic> map) {
    return _BrokenLink(
      stateCode: map['state_code'] ?? '',
      field: map['field'] ?? '',
      status: map['status'],
      error: map['error'],
    );
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
