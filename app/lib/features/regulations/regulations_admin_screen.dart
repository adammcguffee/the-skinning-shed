import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/regulations_service.dart';

/// 🛡️ RECORDS ADMIN - 2026 PREMIUM
/// 
/// Clean, purposeful admin control center:
/// - Record Data Overview
/// - Photo Verification Pipeline
/// - No clutter, no unused legacy tools
class RegulationsAdminScreen extends ConsumerStatefulWidget {
  const RegulationsAdminScreen({super.key});

  @override
  ConsumerState<RegulationsAdminScreen> createState() => _RegulationsAdminScreenState();
}

class _RegulationsAdminScreenState extends ConsumerState<RegulationsAdminScreen> {
  bool _isLoading = true;
  _RecordStats _stats = const _RecordStats();
  
  // Photo seeding run state
  _PhotoSeedRun? _activeRun;
  Timer? _pollTimer;
  List<_SeedEvent> _recentEvents = [];
  
  @override
  void initState() {
    super.initState();
    _loadStats();
    _checkForActiveRun();
  }
  
  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final client = service.client;
      if (client == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final response = await client
          .from('state_record_highlights')
          .select('state_code, data_quality, buck_photo_verified, bass_photo_verified, buck_story_summary, bass_story_summary');
      
      final rows = response as List;
      final total = rows.length;
      final buckVerified = rows.where((r) => r['buck_photo_verified'] == true).length;
      final bassVerified = rows.where((r) => r['bass_photo_verified'] == true).length;
      final highQuality = rows.where((r) => r['data_quality'] == 'high').length;
      final withBuckStory = rows.where((r) => r['buck_story_summary'] != null).length;
      final withBassStory = rows.where((r) => r['bass_story_summary'] != null).length;
      
      if (mounted) {
        setState(() {
          _stats = _RecordStats(
            totalStates: total,
            buckPhotosVerified: buckVerified,
            bassPhotosVerified: bassVerified,
            highQualityData: highQuality,
            withBuckStory: withBuckStory,
            withBassStory: withBassStory,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _checkForActiveRun() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final client = service.client;
      if (client == null) return;
      
      final response = await client
          .from('record_photo_seed_runs')
          .select()
          .inFilter('status', ['queued', 'running'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null && mounted) {
        setState(() {
          _activeRun = _PhotoSeedRun.fromJson(response);
        });
        _startPolling();
        _loadRecentEvents(response['id']);
      }
    } catch (e) {
      debugPrint('Error checking for active run: $e');
    }
  }
  
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollRunStatus());
  }
  
  Future<void> _pollRunStatus() async {
    if (_activeRun == null) {
      _pollTimer?.cancel();
      return;
    }
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final client = service.client;
      if (client == null) return;
      
      final response = await client
          .from('record_photo_seed_runs')
          .select()
          .eq('id', _activeRun!.id)
          .single();
      
      final run = _PhotoSeedRun.fromJson(response);
      
      if (mounted) {
        setState(() => _activeRun = run);
        
        if (!run.isActive) {
          _pollTimer?.cancel();
          _loadStats();
        }
      }
      
      _loadRecentEvents(run.id);
    } catch (e) {
      debugPrint('Error polling run status: $e');
    }
  }
  
  Future<void> _loadRecentEvents(String runId) async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final client = service.client;
      if (client == null) return;
      
      final response = await client
          .from('record_photo_seed_events')
          .select()
          .eq('run_id', runId)
          .order('created_at', ascending: false)
          .limit(20);
      
      if (mounted) {
        setState(() {
          _recentEvents = (response as List)
              .map((e) => _SeedEvent.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
    }
  }
  
  Future<void> _startPhotoSeeding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Start Photo Verification?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This will find and verify record photos from official sources.\n\n'
          'Only photos that pass strict verification will be stored.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final client = service.client;
      if (client == null) throw Exception('Not connected');
      
      final runResponse = await client
          .from('record_photo_seed_runs')
          .insert({
            'status': 'queued',
            'total_targets': 100,
            'processed': 0,
            'verified': 0,
            'missing': 0,
            'failed': 0,
          })
          .select()
          .single();
      
      final run = _PhotoSeedRun.fromJson(runResponse);
      
      setState(() {
        _activeRun = run;
        _recentEvents = [];
      });
      
      _startPolling();
      
      await client.functions.invoke(
        'seed-record-photos-strict',
        body: {'runId': run.id, 'mode': 'missing', 'limit': 50},
      );
      
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
  
  Future<void> _stopPhotoSeeding() async {
    if (_activeRun == null) return;
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final client = service.client;
      if (client == null) return;
      
      await client
          .from('record_photo_seed_runs')
          .update({'status': 'stopping'})
          .eq('id', _activeRun!.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stopping...'), backgroundColor: AppColors.warning),
        );
      }
    } catch (e) {
      debugPrint('Error stopping run: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Records Admin',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                Text(
                  'Manage state record data & photos',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadStats,
            icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh stats',
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats overview
          _buildStatsSection(),
          const SizedBox(height: AppSpacing.xl + 8),
          
          // Photo seeding section
          _buildPhotoSeedingSection(),
        ],
      ),
    );
  }
  
  Widget _buildStatsSection() {
    final totalPhotos = _stats.buckPhotosVerified + _stats.bassPhotosVerified;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.insights_rounded, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            const Text(
              'Record Data Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Summary card
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              // Main summary row
              Row(
                children: [
                  Expanded(
                    child: _BigStatTile(
                      label: 'Verified Photos',
                      value: '$totalPhotos / 100',
                      icon: Icons.photo_camera_rounded,
                      color: totalPhotos >= 80 ? AppColors.success : AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _BigStatTile(
                      label: 'States with Data',
                      value: '${_stats.totalStates} / 50',
                      icon: Icons.map_rounded,
                      color: _stats.totalStates >= 50 ? AppColors.success : AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Breakdown
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniStat(label: 'Buck Photos', value: '${_stats.buckPhotosVerified}/50'),
                    _MiniStat(label: 'Bass Photos', value: '${_stats.bassPhotosVerified}/50'),
                    _MiniStat(label: 'Buck Stories', value: '${_stats.withBuckStory}/50'),
                    _MiniStat(label: 'Bass Stories', value: '${_stats.withBassStory}/50'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPhotoSeedingSection() {
    final run = _activeRun;
    final hasActiveRun = run != null && run.isActive;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.image_search_rounded, size: 18, color: AppColors.info),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photo Verification Pipeline',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Finds and verifies actual record photos from official sources.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Progress tracker or start button
        if (hasActiveRun)
          _buildProgressTracker(run)
        else
          _buildStartButton(),
        
        // Recent events log
        if (_recentEvents.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _buildEventsLog(),
        ],
      ],
    );
  }
  
  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startPhotoSeeding,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start Photo Verification'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.info,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
  
  Widget _buildProgressTracker(_PhotoSeedRun run) {
    final progress = run.totalTargets > 0 ? run.processed / run.totalTargets : 0.0;
    final isRunning = run.status == 'running';
    final isStopping = run.status == 'stopping';
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isRunning ? AppColors.info.withValues(alpha: 0.4) : AppColors.borderSubtle,
          width: isRunning ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row with live indicator
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning ? AppColors.success : (isStopping ? AppColors.warning : AppColors.textTertiary),
                  boxShadow: isRunning
                      ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.5), blurRadius: 8)]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isRunning ? 'RUNNING' : (isStopping ? 'STOPPING...' : run.status.toUpperCase()),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isRunning ? AppColors.success : AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (run.currentState != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Processing ${run.currentState} — ${run.currentPhase ?? "..."}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.info),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceHover,
              valueColor: AlwaysStoppedAnimation(isRunning ? AppColors.info : AppColors.textTertiary),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          
          // Counters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${run.processed} / ${run.totalTargets} processed',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  _CounterChip(label: 'Verified', value: run.verified, color: AppColors.success),
                  const SizedBox(width: 8),
                  _CounterChip(label: 'Missing', value: run.missing, color: AppColors.warning),
                  const SizedBox(width: 8),
                  _CounterChip(label: 'Failed', value: run.failed, color: AppColors.error),
                ],
              ),
            ],
          ),
          
          // Stop button
          if (isRunning) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _stopPhotoSeeding,
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Stop'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
          
          // Completion summary
          if (!run.isActive && run.processed > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 20, color: AppColors.success),
                  const SizedBox(width: 10),
                  Text(
                    'Verified photos: ${run.verified} / ${run.processed}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildEventsLog() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _recentEvents.length,
              itemBuilder: (ctx, i) {
                final event = _recentEvents[i];
                return _EventRow(event: event);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// === DATA CLASSES ===

class _RecordStats {
  const _RecordStats({
    this.totalStates = 0,
    this.buckPhotosVerified = 0,
    this.bassPhotosVerified = 0,
    this.highQualityData = 0,
    this.withBuckStory = 0,
    this.withBassStory = 0,
  });
  
  final int totalStates;
  final int buckPhotosVerified;
  final int bassPhotosVerified;
  final int highQualityData;
  final int withBuckStory;
  final int withBassStory;
}

class _PhotoSeedRun {
  const _PhotoSeedRun({
    required this.id,
    required this.status,
    this.totalTargets = 100,
    this.processed = 0,
    this.verified = 0,
    this.missing = 0,
    this.failed = 0,
    this.currentState,
    this.currentPhase,
    this.lastMessage,
  });
  
  final String id;
  final String status;
  final int totalTargets;
  final int processed;
  final int verified;
  final int missing;
  final int failed;
  final String? currentState;
  final String? currentPhase;
  final String? lastMessage;
  
  bool get isActive => status == 'queued' || status == 'running' || status == 'stopping';
  
  factory _PhotoSeedRun.fromJson(Map<String, dynamic> json) => _PhotoSeedRun(
    id: json['id'] as String,
    status: json['status'] as String,
    totalTargets: json['total_targets'] as int? ?? 100,
    processed: json['processed'] as int? ?? 0,
    verified: json['verified'] as int? ?? 0,
    missing: json['missing'] as int? ?? 0,
    failed: json['failed'] as int? ?? 0,
    currentState: json['current_state'] as String?,
    currentPhase: json['current_phase'] as String?,
    lastMessage: json['last_message'] as String?,
  );
}

class _SeedEvent {
  const _SeedEvent({
    required this.id,
    required this.eventType,
    this.stateCode,
    this.recordType,
    this.message,
  });
  
  final String id;
  final String eventType;
  final String? stateCode;
  final String? recordType;
  final String? message;
  
  factory _SeedEvent.fromJson(Map<String, dynamic> json) => _SeedEvent(
    id: json['id'] as String,
    eventType: json['event_type'] as String,
    stateCode: json['state_code'] as String?,
    recordType: json['record_type'] as String?,
    message: json['message'] as String?,
  );
}

// === WIDGETS ===

class _BigStatTile extends StatelessWidget {
  const _BigStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  
  final String label;
  final String value;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({
    required this.label,
    required this.value,
    required this.color,
  });
  
  final String label;
  final int value;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  
  final _SeedEvent event;
  
  @override
  Widget build(BuildContext context) {
    final isVerified = event.eventType == 'verified';
    final isMissing = event.eventType == 'missing';
    final isFailed = event.eventType == 'failed';
    
    final icon = isVerified
        ? Icons.check_circle_outline
        : isMissing
            ? Icons.remove_circle_outline
            : isFailed
                ? Icons.error_outline
                : Icons.info_outline;
    
    final color = isVerified
        ? AppColors.success
        : isMissing
            ? AppColors.warning
            : isFailed
                ? AppColors.error
                : AppColors.textTertiary;
    
    // Human-readable message
    String message;
    if (isVerified) {
      message = '${event.stateCode} ${event.recordType} photo verified';
    } else if (isMissing) {
      message = '${event.stateCode} ${event.recordType} — no photo found';
    } else if (isFailed) {
      message = '${event.stateCode} ${event.recordType} — verification failed';
    } else {
      message = event.message ?? event.eventType;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
