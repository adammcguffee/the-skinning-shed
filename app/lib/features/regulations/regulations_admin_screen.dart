import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/regulations_service.dart';

/// 🛡️ REGULATIONS & RECORDS ADMIN - 2026 PREMIUM
/// 
/// Clean admin interface for managing state records and photos.
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
      
      // Load record stats
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
          _loadStats(); // Refresh stats when done
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
          .limit(15);
      
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
        title: const Text('Start Photo Verification?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This will attempt to find and verify ACTUAL record photos from official sources using GPT.\n\n'
          'Only photos that pass strict verification will be stored. Others will show "Photo unavailable".',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Start Verification'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final client = service.client;
      if (client == null) throw Exception('Not connected');
      
      // Create a new run
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
      
      // Trigger the Edge Function
      await client.functions.invoke(
        'seed-record-photos-strict',
        body: {'runId': run.id, 'mode': 'missing', 'limit': 50},
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting verification: $e'),
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
          const SnackBar(content: Text('Stopping verification...'), backgroundColor: AppColors.warning),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Records Admin',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
        AppSpacing.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats overview
          _buildStatsSection(),
          const SizedBox(height: AppSpacing.xl),
          
          // Photo seeding section
          _buildPhotoSeedingSection(),
          const SizedBox(height: AppSpacing.xl),
          
          // Advanced tools (collapsed)
          _buildAdvancedSection(),
        ],
      ),
    );
  }
  
  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insights_rounded, size: 20, color: AppColors.accent),
            const SizedBox(width: 8),
            const Text(
              'Record Data Overview',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Stats grid
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _StatTile(
                    label: 'States with Data',
                    value: '${_stats.totalStates}/50',
                    isGood: _stats.totalStates >= 50,
                    icon: Icons.map_rounded,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatTile(
                    label: 'High Quality',
                    value: '${_stats.highQualityData}',
                    isGood: _stats.highQualityData >= 25,
                    icon: Icons.star_rounded,
                  )),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatTile(
                    label: 'Buck Photos Verified',
                    value: '${_stats.buckPhotosVerified}/50',
                    isGood: _stats.buckPhotosVerified > 0,
                    icon: Icons.photo_camera_rounded,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatTile(
                    label: 'Bass Photos Verified',
                    value: '${_stats.bassPhotosVerified}/50',
                    isGood: _stats.bassPhotosVerified > 0,
                    icon: Icons.photo_camera_rounded,
                  )),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatTile(
                    label: 'Buck Stories',
                    value: '${_stats.withBuckStory}/50',
                    isGood: _stats.withBuckStory >= 50,
                    icon: Icons.auto_stories_rounded,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatTile(
                    label: 'Bass Stories',
                    value: '${_stats.withBassStory}/50',
                    isGood: _stats.withBassStory >= 50,
                    icon: Icons.auto_stories_rounded,
                  )),
                ],
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
            Icon(Icons.image_search_rounded, size: 20, color: AppColors.info),
            const SizedBox(width: 8),
            const Text(
              'Photo Verification Pipeline',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Uses GPT to find and verify actual record photos from official sources.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Progress tracker (when running)
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
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
  
  Widget _buildProgressTracker(_PhotoSeedRun run) {
    final progress = run.totalTargets > 0 ? run.processed / run.totalTargets : 0.0;
    final isRunning = run.status == 'running';
    final isStopping = run.status == 'stopping';
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: isRunning ? AppColors.info.withValues(alpha: 0.3) : AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning ? AppColors.success : (isStopping ? AppColors.warning : AppColors.textTertiary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                run.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isRunning ? AppColors.success : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (run.currentState != null)
                Text(
                  'Processing: ${run.currentState} (${run.currentPhase ?? "..."})',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceHover,
              valueColor: AlwaysStoppedAnimation(isRunning ? AppColors.info : AppColors.textTertiary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          
          // Counters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${run.processed}/${run.totalTargets} processed',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
          
          // Last message
          if (run.lastMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              run.lastMessage!,
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          // Stop button
          if (isRunning) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _stopPhotoSeeding,
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Stop'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildEventsLog() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: _recentEvents.length,
              itemBuilder: (ctx, i) {
                final event = _recentEvents[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        event.eventType == 'verified' ? Icons.check_circle_outline :
                        event.eventType == 'missing' ? Icons.help_outline :
                        event.eventType == 'failed' ? Icons.error_outline :
                        Icons.info_outline,
                        size: 14,
                        color: event.eventType == 'verified' ? AppColors.success :
                               event.eventType == 'missing' ? AppColors.warning :
                               event.eventType == 'failed' ? AppColors.error :
                               AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${event.stateCode ?? ""} ${event.recordType ?? ""}: ${event.message ?? event.eventType}',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAdvancedSection() {
    return ExpansionTile(
      title: Row(
        children: [
          Icon(Icons.settings_rounded, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            'Advanced Tools',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ],
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8),
      children: [
        Text(
          'Legacy link discovery and repair tools have been deprecated. '
          'The app now uses a single canonical official link per state.',
          style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
        ),
      ],
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.isGood = false,
  });
  
  final String label;
  final String value;
  final IconData icon;
  final bool isGood;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGood ? AppColors.success.withValues(alpha: 0.08) : AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isGood ? AppColors.success : AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isGood ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
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
