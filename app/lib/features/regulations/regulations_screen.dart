import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/regulations_service.dart';
import 'package:shed/shared/widgets/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🔗 OFFICIAL LINKS - 2026 PREMIUM
/// 
/// Clean, direct state grid.
/// Clicking a tile opens the official state wildlife portal immediately.
/// No intermediate screens - direct external links.
class RegulationsScreen extends ConsumerStatefulWidget {
  const RegulationsScreen({super.key});

  @override
  ConsumerState<RegulationsScreen> createState() => _RegulationsScreenState();
}

class _RegulationsScreenState extends ConsumerState<RegulationsScreen> {
  String _searchQuery = '';
  Map<String, String?> _officialUrls = {};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadOfficialUrls();
  }
  
  Future<void> _loadOfficialUrls() async {
    setState(() => _isLoading = true);
    
    try {
      final service = ref.read(regulationsServiceProvider);
      final urls = await service.fetchAllOfficialRootUrls();
      if (mounted) {
        setState(() {
          _officialUrls = urls;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading official URLs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _openOfficialUrl(String stateCode, String stateName) async {
    final url = _officialUrls[stateCode];
    
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$stateName portal not yet verified',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.borderSubtle),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return Column(
      children: [
        // Top bar (web only)
        if (isWide)
          AppTopBar(
            title: 'Official Links',
            subtitle: 'Verified state wildlife & fisheries portals',
          ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mobile header
                      if (!isWide) ...[
                        Text(
                          'Official Links',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Verified state wildlife & fisheries portals',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      
                      // Search field
                      _buildSearchField(),
                      const SizedBox(height: AppSpacing.lg),
                      
                      // State selection grid
                      _buildStateGrid(isWide),
                      
                      const SizedBox(height: AppSpacing.xl),
                      
                      // Info card (subtle)
                      _buildInfoCard(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
  
  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search states...',
        hintStyle: TextStyle(color: AppColors.textTertiary),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: AppColors.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      style: const TextStyle(color: AppColors.textPrimary),
      onChanged: (value) {
        setState(() => _searchQuery = value.toLowerCase());
      },
    );
  }
  
  Widget _buildStateGrid(bool isWide) {
    final crossAxisCount = isWide ? 6 : 4;
    
    // Filter states by search query
    final states = USStates.all.where((state) {
      if (_searchQuery.isEmpty) return true;
      return state.name.toLowerCase().contains(_searchQuery) ||
             state.code.toLowerCase().contains(_searchQuery);
    }).toList();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.0,
      ),
      itemCount: states.length,
      itemBuilder: (context, index) {
        final state = states[index];
        final hasUrl = _officialUrls[state.code] != null && 
                       _officialUrls[state.code]!.isNotEmpty;
        
        return _StateLinkCard(
          stateCode: state.code,
          stateName: state.name,
          hasUrl: hasUrl,
          onTap: () => _openOfficialUrl(state.code, state.name),
        );
      },
    );
  }
  
  Widget _buildInfoCard() {
    final statesWithUrls = _officialUrls.values.where((u) => u != null && u.isNotEmpty).length;
    
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.success,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Direct links to official sources',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'We link directly to state wildlife agencies — no summaries, no guesswork.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
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

/// Premium state tile with external link indicator
class _StateLinkCard extends StatefulWidget {
  const _StateLinkCard({
    required this.stateCode,
    required this.stateName,
    required this.hasUrl,
    required this.onTap,
  });

  final String stateCode;
  final String stateName;
  final bool hasUrl;
  final VoidCallback onTap;

  @override
  State<_StateLinkCard> createState() => _StateLinkCardState();
}

class _StateLinkCardState extends State<_StateLinkCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Open ${widget.stateName} wildlife portal',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translate(0.0, _isHovered && widget.hasUrl ? -2.0 : 0.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isHovered && widget.hasUrl
                    ? [
                        AppColors.accent.withValues(alpha: 0.15),
                        AppColors.accent.withValues(alpha: 0.08),
                      ]
                    : [
                        AppColors.surface,
                        AppColors.surface.withValues(alpha: 0.95),
                      ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: _isHovered && widget.hasUrl
                    ? AppColors.accent.withValues(alpha: 0.4)
                    : AppColors.borderSubtle,
                width: _isHovered && widget.hasUrl ? 1.5 : 1,
              ),
              boxShadow: _isHovered && widget.hasUrl
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 1),
              child: Stack(
                children: [
                  // Main content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // State abbreviation (large)
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _isHovered && widget.hasUrl
                                ? AppColors.accent
                                : AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                          child: Text(widget.stateCode),
                        ),
                        const SizedBox(height: 2),
                        // State name (small)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            widget.stateName,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // External link indicator (top right, shown on hover)
                  if (_isHovered && widget.hasUrl)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.open_in_new_rounded,
                        size: 12,
                        color: AppColors.accent.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
