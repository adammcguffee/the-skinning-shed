import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/regulations_service.dart';
import 'package:shed/shared/widgets/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🦌 STATE REGULATIONS & RECORDS - 2026 PREMIUM
/// 
/// Clean, focused, intentional design:
/// - ONE official regulations portal link
/// - State record highlights with square hero images
/// - Story-first content layout
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
              _buildHeroHeader(context, stateName),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                        ? AppErrorState(message: _error!, onRetry: _loadData)
                        : _buildContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeroHeader(BuildContext context, String stateName) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Row(
        children: [
          // Back button
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
          const SizedBox(width: AppSpacing.sm),
          
          // Home button
          GestureDetector(
            onTap: () => context.go('/'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(Icons.home_rounded, size: 20, color: AppColors.textSecondary),
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
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Regulations & Records',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
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
          child: AppCardSkeleton(aspectRatio: i == 0 ? 4 : 1.5),
        )),
      ),
    );
  }
  
  Widget _buildContent(BuildContext context) {
    final agencyName = _portalLinks?.agencyName ?? 'State Wildlife Agency';
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 720;
    
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
          // === OFFICIAL PORTAL CARD (PRIMARY CTA) ===
          _buildOfficialPortalCard(agencyName),
          
          const SizedBox(height: AppSpacing.xl + 8),
          
          // === STATE RECORDS SECTION ===
          _buildRecordsSection(isWide),
        ],
      ),
    );
  }
  
  Widget _buildOfficialPortalCard(String agencyName) {
    final hasUrl = _officialRootUrl != null && _officialRootUrl!.isNotEmpty;
    
    return GestureDetector(
      onTap: hasUrl ? () => _openUrl(_officialRootUrl!) : null,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg + 4),
        decoration: BoxDecoration(
          gradient: hasUrl ? AppColors.accentGradient : null,
          color: hasUrl ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: hasUrl ? null : Border.all(color: AppColors.borderSubtle),
          boxShadow: hasUrl
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
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
                    'OFFICIAL REGULATIONS PORTAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: hasUrl ? Colors.white.withValues(alpha: 0.8) : AppColors.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    agencyName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: hasUrl ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (hasUrl)
              Icon(
                Icons.open_in_new_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecordsSection(bool isWide) {
    final records = _recordHighlights;
    final hasBuck = records?.hasBuckRecord ?? false;
    final hasBass = records?.hasBassRecord ?? false;
    final stateName = _state?.name ?? widget.stateCode;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.emoji_events_rounded, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'State Records',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Official record highlights',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        
        // Records layout
        if (!hasBuck && !hasBass)
          _buildNoRecordsPlaceholder()
        else if (isWide)
          // Desktop: Two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasBuck)
                Expanded(
                  child: _RecordCard(
                    type: 'buck',
                    title: '$stateName State Record Whitetail',
                    species: records?.buckSpecies,
                    primaryStat: records?.buckScoreText ?? records?.buckWeightText,
                    primaryLabel: records?.buckScoreText != null ? 'Score' : 'Weight',
                    personName: records?.buckHunterName,
                    personLabel: 'Hunter',
                    dateText: records?.buckDateText,
                    locationText: records?.buckLocationText,
                    methodText: records?.buckWeapon,
                    photoUrl: records?.buckPhotoUrl,
                    photoVerified: records?.buckPhotoVerified ?? false,
                    storySummary: records?.buckStorySummary,
                    sourceUrl: records?.buckSourceUrl,
                    sourceName: records?.buckSourceName,
                    accentColor: const Color(0xFF8B4513),
                    icon: Icons.nature_people_rounded,
                    onSourceTap: () => _openUrl(records?.buckSourceUrl),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              if (hasBuck && hasBass) const SizedBox(width: AppSpacing.md),
              if (hasBass)
                Expanded(
                  child: _RecordCard(
                    type: 'bass',
                    title: '$stateName State Record Largemouth Bass',
                    species: records?.bassSpecies,
                    primaryStat: records?.bassWeightText,
                    primaryLabel: 'Weight',
                    personName: records?.bassAnglerName,
                    personLabel: 'Angler',
                    dateText: records?.bassDateText,
                    locationText: records?.bassLocationText,
                    methodText: records?.bassMethod,
                    photoUrl: records?.bassPhotoUrl,
                    photoVerified: records?.bassPhotoVerified ?? false,
                    storySummary: records?.bassStorySummary,
                    sourceUrl: records?.bassSourceUrl,
                    sourceName: records?.bassSourceName,
                    accentColor: const Color(0xFF1565C0),
                    icon: Icons.water_rounded,
                    onSourceTap: () => _openUrl(records?.bassSourceUrl),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          )
        else
          // Mobile: Stack vertically
          Column(
            children: [
              if (hasBuck)
                _RecordCard(
                  type: 'buck',
                  title: '$stateName State Record Whitetail',
                  species: records?.buckSpecies,
                  primaryStat: records?.buckScoreText ?? records?.buckWeightText,
                  primaryLabel: records?.buckScoreText != null ? 'Score' : 'Weight',
                  personName: records?.buckHunterName,
                  personLabel: 'Hunter',
                  dateText: records?.buckDateText,
                  locationText: records?.buckLocationText,
                  methodText: records?.buckWeapon,
                  photoUrl: records?.buckPhotoUrl,
                  photoVerified: records?.buckPhotoVerified ?? false,
                  storySummary: records?.buckStorySummary,
                  sourceUrl: records?.buckSourceUrl,
                  sourceName: records?.buckSourceName,
                  accentColor: const Color(0xFF8B4513),
                  icon: Icons.nature_people_rounded,
                  onSourceTap: () => _openUrl(records?.buckSourceUrl),
                ),
              if (hasBuck && hasBass) ...[
                const SizedBox(height: AppSpacing.md),
                // Subtle divider between cards on mobile
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: AppColors.borderSubtle,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (hasBass)
                _RecordCard(
                  type: 'bass',
                  title: '$stateName State Record Largemouth Bass',
                  species: records?.bassSpecies,
                  primaryStat: records?.bassWeightText,
                  primaryLabel: 'Weight',
                  personName: records?.bassAnglerName,
                  personLabel: 'Angler',
                  dateText: records?.bassDateText,
                  locationText: records?.bassLocationText,
                  methodText: records?.bassMethod,
                  photoUrl: records?.bassPhotoUrl,
                  photoVerified: records?.bassPhotoVerified ?? false,
                  storySummary: records?.bassStorySummary,
                  sourceUrl: records?.bassSourceUrl,
                  sourceName: records?.bassSourceName,
                  accentColor: const Color(0xFF1565C0),
                  icon: Icons.water_rounded,
                  onSourceTap: () => _openUrl(records?.bassSourceUrl),
                ),
            ],
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
            'Record Data Coming Soon',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Trophy highlights for this state will be added.',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Premium record card with SQUARE hero image and story-first content
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
  final Color accentColor;
  final IconData icon;
  final VoidCallback? onSourceTap;
  
  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = true; // Default expanded to show story
  
  bool get _hasPhoto => widget.photoUrl != null && widget.photoUrl!.isNotEmpty && widget.photoVerified;
  bool get _hasStory => widget.storySummary != null && widget.storySummary!.isNotEmpty;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // SQUARE hero image
          _buildHeroImage(),
          
          // Title below image
          _buildTitleSection(),
          
          // Stats chips
          _buildStats(),
          
          // Expandable content (story + source)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _buildExpandedContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeroImage() {
    return AspectRatio(
      aspectRatio: 1.0, // SQUARE
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_hasPhoto)
            Image.network(
              widget.photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => _buildPlaceholderImage(),
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: widget.accentColor.withValues(alpha: 0.08),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(widget.accentColor),
                    ),
                  ),
                );
              },
            )
          else
            _buildPlaceholderImage(),
          
          // Gradient overlay at bottom for readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          
          // Expand/collapse button
          Positioned(
            top: 12,
            right: 12,
            child: _buildExpandButton(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlaceholderImage() {
    return Container(
      color: widget.accentColor.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.icon,
            size: 56,
            color: widget.accentColor.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_camera_outlined, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'Photo unavailable',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandButton() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
  
  Widget _buildTitleSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          if (widget.species != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.species!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.borderSubtle),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // STORY SECTION (IMPORTANT - ALWAYS VISIBLE)
              Row(
                children: [
                  Icon(Icons.auto_stories_rounded, size: 18, color: widget.accentColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Story',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_hasStory)
                Text(
                  widget.storySummary!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Text(
                  'Story details for this record are being compiled from official sources.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Source button
              if (widget.sourceUrl != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: widget.onSourceTap,
                    icon: Icon(Icons.open_in_new_rounded, size: 16, color: widget.accentColor),
                    label: Text(
                      'View Source',
                      style: TextStyle(color: widget.accentColor),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: widget.accentColor.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
          color: (color ?? AppColors.accent).withValues(alpha: 0.12),
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
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.accent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
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
