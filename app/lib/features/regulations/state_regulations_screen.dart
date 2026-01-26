import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/regulations_service.dart';
import 'package:shed/shared/widgets/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🦌 STATE REGULATIONS & RECORDS SCREEN - 2026 PREMIUM
/// 
/// Clean, focused view showing:
/// - ONE official regulations portal link
/// - State record highlights (buck + bass)
class StateRegulationsScreen extends ConsumerStatefulWidget {
  const StateRegulationsScreen({
    super.key,
    required this.stateCode,
  });

  final String stateCode;

  @override
  ConsumerState<StateRegulationsScreen> createState() => _StateRegulationsScreenState();
}

class _StateRegulationsScreenState extends ConsumerState<StateRegulationsScreen> {
  bool _isLoading = true;
  String? _error;
  StatePortalLinks? _portalLinks;
  String? _officialRootUrl;
  StateRecordHighlights? _recordHighlights;
  
  String get _normalizedStateCode => widget.stateCode.toUpperCase();
  USState? get _state => USStates.byCode(_normalizedStateCode);
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final stateCode = _normalizedStateCode;
      
      // Load portal links, official root URL, and record highlights
      final portalLinks = await service.fetchPortalLinks(stateCode);
      final officialRoot = await service.getOfficialRootUrl(stateCode);
      
      StateRecordHighlights? recordHighlights;
      try {
        recordHighlights = await service.fetchRecordHighlights(stateCode);
      } catch (e) {
        debugPrint('Could not load record highlights: $e');
      }
      
      if (mounted) {
        setState(() {
          _portalLinks = portalLinks;
          _officialRootUrl = officialRoot;
          _recordHighlights = recordHighlights;
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
  
  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateName = _state?.name ?? widget.stateCode;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, stateName),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                        ? AppErrorState(message: _error!, onRetry: _loadData)
                        : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context, String stateName) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Row(
        children: [
          // Back button
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
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stateName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Regulations & Records',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Refresh button
          IconButton(
            onPressed: _loadData,
            icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCardSkeleton(aspectRatio: i == 0 ? 4 : 2.5),
        )),
      ),
    );
  }
  
  Widget _buildContent() {
    final agencyName = _portalLinks?.agencyName ?? 'State Wildlife Agency';
    
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
          // === OFFICIAL PORTAL CARD ===
          _buildOfficialPortalCard(agencyName),
          
          const SizedBox(height: AppSpacing.xl),
          
          // === STATE RECORDS SECTION ===
          _buildRecordsSection(),
        ],
      ),
    );
  }
  
  Widget _buildOfficialPortalCard(String agencyName) {
    final hasUrl = _officialRootUrl != null && _officialRootUrl!.isNotEmpty;
    
    return GestureDetector(
      onTap: hasUrl ? () => _openUrl(_officialRootUrl!) : null,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: hasUrl ? AppColors.accentGradient : null,
          color: hasUrl ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: hasUrl ? null : Border.all(color: AppColors.borderSubtle),
          boxShadow: hasUrl ? AppColors.shadowCard : null,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: hasUrl ? Colors.white.withValues(alpha: 0.2) : AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(
                Icons.account_balance_rounded,
                color: hasUrl ? Colors.white : AppColors.textTertiary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OFFICIAL REGULATIONS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: hasUrl ? Colors.white.withValues(alpha: 0.7) : AppColors.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    agencyName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: hasUrl ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasUrl ? 'Tap to visit official site →' : 'Link not available',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasUrl ? Colors.white.withValues(alpha: 0.8) : AppColors.textTertiary,
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
  
  Widget _buildRecordsSection() {
    final records = _recordHighlights;
    final hasBuck = records?.hasBuckRecord ?? false;
    final hasBass = records?.hasBassRecord ?? false;
    
    if (!hasBuck && !hasBass) {
      return _buildNoRecordsPlaceholder();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.emoji_events_rounded, size: 20, color: AppColors.accent),
            const SizedBox(width: 8),
            const Text(
              'State Records',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Official state record highlights',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Buck record card
        if (hasBuck) ...[
          _RecordCard(
            type: 'buck',
            title: records!.buckTitle ?? 'State Record Buck',
            species: records.buckSpecies,
            primaryStat: records.buckScoreText ?? records.buckWeightText,
            primaryLabel: records.buckScoreText != null ? 'Score' : 'Weight',
            personName: records.buckHunterName,
            personLabel: 'Hunter',
            dateText: records.buckDateText,
            locationText: records.buckLocationText,
            methodText: records.buckWeapon,
            photoUrl: records.buckPhotoUrl,
            photoVerified: records.buckPhotoVerified ?? false,
            storySummary: records.buckStorySummary,
            sourceUrl: records.buckSourceUrl,
            sourceName: records.buckSourceName,
            quoteText: null, // TODO: records.buckQuoteText
            accentColor: const Color(0xFF8B4513),
            icon: Icons.nature_people_rounded,
            onSourceTap: () => _openUrl(records.buckSourceUrl),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        
        // Bass record card
        if (hasBass)
          _RecordCard(
            type: 'bass',
            title: records!.bassTitle ?? 'State Record Bass',
            species: records.bassSpecies,
            primaryStat: records.bassWeightText,
            primaryLabel: 'Weight',
            personName: records.bassAnglerName,
            personLabel: 'Angler',
            dateText: records.bassDateText,
            locationText: records.bassLocationText,
            methodText: records.bassMethod,
            photoUrl: records.bassPhotoUrl,
            photoVerified: records.bassPhotoVerified ?? false,
            storySummary: records.bassStorySummary,
            sourceUrl: records.bassSourceUrl,
            sourceName: records.bassSourceName,
            quoteText: null, // TODO: records.bassQuoteText
            accentColor: const Color(0xFF1E88E5),
            icon: Icons.water_rounded,
            onSourceTap: () => _openUrl(records.bassSourceUrl),
          ),
      ],
    );
  }
  
  Widget _buildNoRecordsPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'State Records Coming Soon',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Record buck and bass data for this state will be added.',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Premium record card with expandable story summary
class _RecordCard extends StatefulWidget {
  const _RecordCard({
    required this.type,
    required this.title,
    this.species,
    this.primaryStat,
    this.primaryLabel,
    this.personName,
    this.personLabel,
    this.dateText,
    this.locationText,
    this.methodText,
    this.photoUrl,
    this.photoVerified = false,
    this.storySummary,
    this.sourceUrl,
    this.sourceName,
    this.quoteText,
    required this.accentColor,
    required this.icon,
    this.onSourceTap,
  });
  
  final String type;
  final String title;
  final String? species;
  final String? primaryStat;
  final String? primaryLabel;
  final String? personName;
  final String? personLabel;
  final String? dateText;
  final String? locationText;
  final String? methodText;
  final String? photoUrl;
  final bool photoVerified;
  final String? storySummary;
  final String? sourceUrl;
  final String? sourceName;
  final String? quoteText;
  final Color accentColor;
  final IconData icon;
  final VoidCallback? onSourceTap;
  
  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  bool _isExpanded = false;
  
  bool get _hasPhoto => widget.photoUrl != null && widget.photoUrl!.isNotEmpty && widget.photoVerified;
  bool get _hasStory => widget.storySummary != null && widget.storySummary!.isNotEmpty;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo or placeholder header
          _buildHeader(),
          
          // Stats row
          _buildStats(),
          
          // Expanded content (story + source)
          if (_isExpanded) _buildExpandedContent(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    if (_hasPhoto) {
      return _buildPhotoHeader();
    }
    return _buildPlaceholderHeader();
  }
  
  Widget _buildPhotoHeader() {
    return Container(
      height: 160,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.photoUrl!,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => _buildPlaceholderHeader(),
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                color: AppColors.surfaceHover,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(widget.accentColor),
                  ),
                ),
              );
            },
          ),
          // Gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                ),
              ),
            ),
          ),
          // Title on photo
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
                if (widget.species != null)
                  Text(
                    widget.species!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
              ],
            ),
          ),
          // Expand button
          Positioned(
            top: 8,
            right: 8,
            child: _buildExpandButton(light: true),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlaceholderHeader() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.accentColor.withValues(alpha: 0.08),
      ),
      child: Stack(
        children: [
          // Background icon
          Center(
            child: Icon(widget.icon, size: 56, color: widget.accentColor.withValues(alpha: 0.12)),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Photo unavailable badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera_outlined, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            'Photo unavailable',
                            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _buildExpandButton(light: false),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.species != null)
                  Text(
                    widget.species!,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandButton({required bool light}) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: light ? Colors.black.withValues(alpha: 0.4) : AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          color: light ? Colors.white : AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
  
  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Primary stat (score/weight) - prominent
          if (widget.primaryStat != null)
            _StatChip(
              label: widget.primaryLabel ?? 'Record',
              value: widget.primaryStat!,
              isPrimary: true,
              color: widget.accentColor,
            ),
          // Secondary stats
          if (widget.personName != null)
            _StatChip(label: widget.personLabel ?? 'By', value: widget.personName!),
          if (widget.dateText != null)
            _StatChip(label: 'Year', value: widget.dateText!),
          if (widget.locationText != null)
            _StatChip(label: 'Location', value: widget.locationText!),
          if (widget.methodText != null)
            _StatChip(label: 'Method', value: widget.methodText!),
        ],
      ),
    );
  }
  
  Widget _buildExpandedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppColors.borderSubtle),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Story summary
              if (_hasStory) ...[
                Row(
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 16, color: widget.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      'Story',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.storySummary!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  'Summary coming soon.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Quote (if available)
              if (widget.quoteText != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: widget.accentColor, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '"${widget.quoteText}"',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (widget.sourceName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '— ${widget.sourceName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Source button
              if (widget.sourceUrl != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onSourceTap,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(widget.sourceName ?? 'View Source'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.accentColor,
                      side: BorderSide(color: widget.accentColor.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Stat chip widget
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.isPrimary = false,
    this.color,
  });
  
  final String label;
  final String value;
  final bool isPrimary;
  final Color? color;
  
  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.accent).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: (color ?? AppColors.accent).withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.accent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.accent,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
