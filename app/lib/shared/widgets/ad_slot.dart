import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../services/ad_service.dart';

/// Debug overlay provider - toggle to show ad slot boundaries.
/// Only functional in debug builds.
final showAdDebugOverlayProvider = StateProvider<bool>((ref) => false);

/// A widget that displays an ad creative in the header area.
/// 
/// Shows the ad image if available, or returns [SizedBox.shrink()] if:
/// - No ad exists for this slot
/// - Ad is disabled or outside date window
/// - Image fails to load
/// 
/// Responsive: hidden on mobile widths to avoid crowding.
class AdSlot extends ConsumerStatefulWidget {
  const AdSlot({
    super.key,
    required this.page,
    required this.position,
    this.maxWidth = 220,
    this.maxHeight = 120,
  });

  /// Page identifier (use AdPages constants).
  final String page;
  
  /// Position: "left" or "right".
  final String position;
  
  /// Maximum width constraint.
  final double maxWidth;
  
  /// Maximum height constraint.
  final double maxHeight;

  @override
  ConsumerState<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends ConsumerState<AdSlot> {
  AdCreative? _creative;
  bool _loading = true;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void didUpdateWidget(AdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page || oldWidget.position != widget.position) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    setState(() {
      _loading = true;
      _imageLoaded = false;
    });

    try {
      final adService = ref.read(adServiceProvider);
      final creative = await adService.fetchAdSlot(
        page: widget.page,
        position: widget.position,
      );

      if (mounted) {
        setState(() {
          _creative = creative;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creative = null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _onAdTap() async {
    final clickUrl = _creative?.clickUrl;
    if (clickUrl == null || clickUrl.isEmpty) return;

    final uri = Uri.tryParse(clickUrl);
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('AdSlot: Failed to launch URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDebugOverlay = kDebugMode && ref.watch(showAdDebugOverlayProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Check responsive visibility
    final isTabletOrAbove = screenWidth >= AppSpacing.breakpointTablet;
    final isDesktop = screenWidth >= AppSpacing.breakpointDesktop;
    
    // Determine if slot should be visible
    final shouldShowSlot = isTabletOrAbove && 
        (widget.position == AdPosition.right || isDesktop);

    // In debug mode with overlay, always show the slot boundary
    if (showDebugOverlay && shouldShowSlot) {
      return _buildDebugOverlay(context);
    }

    // Hide during loading to prevent layout jumps
    if (_loading) {
      return const SizedBox.shrink();
    }

    // No ad available
    if (_creative == null) {
      return const SizedBox.shrink();
    }

    // Hide on mobile (< 768px)
    if (!isTabletOrAbove) {
      return const SizedBox.shrink();
    }
    
    // On tablet (768-1024), only show right ad to save space
    if (!isDesktop && widget.position == AdPosition.left) {
      return const SizedBox.shrink();
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      ),
      child: MouseRegion(
        cursor: _creative?.clickUrl != null 
            ? SystemMouseCursors.click 
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: _creative?.clickUrl != null ? _onAdTap : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: AnimatedOpacity(
              opacity: _imageLoaded ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Image.network(
                _creative!.imageUrl,
                fit: BoxFit.contain,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    // Image loaded successfully
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_imageLoaded) {
                        setState(() => _imageLoaded = true);
                      }
                    });
                    return child;
                  }
                  // Still loading - return empty to avoid layout jump
                  return const SizedBox.shrink();
                },
                errorBuilder: (context, error, stackTrace) {
                  // Image failed to load - hide the slot entirely
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build debug overlay showing slot boundary and key.
  Widget _buildDebugOverlay(BuildContext context) {
    final slotKey = '${widget.page}:${widget.position}';
    final hasAd = _creative != null;

    return Container(
      width: widget.maxWidth,
      height: widget.maxHeight,
      decoration: BoxDecoration(
        color: hasAd 
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.15),
        border: Border.all(
          color: hasAd ? Colors.green : Colors.orange,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Stack(
        children: [
          // Show actual ad if available
          if (hasAd && _creative != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
                child: Opacity(
                  opacity: 0.7,
                  child: Image.network(
                    _creative!.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          // Debug label
          Positioned(
            top: 4,
            left: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    slotKey,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    hasAd ? 'AD LOADED' : 'NO AD',
                    style: TextStyle(
                      color: hasAd ? Colors.greenAccent : Colors.orangeAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pre-built header row with ad slots on left/right and banner in center.
/// 
/// Use this in AppScaffold instead of just BannerHeader.appTop().
/// Ads only appear when:
/// - Screen is wide enough (tablet/desktop)
/// - An ad exists and is enabled for the page/position
class AdAwareBannerHeader extends ConsumerStatefulWidget {
  const AdAwareBannerHeader({
    super.key,
    required this.page,
    required this.bannerWidget,
    this.maxBannerWidth = 900,
    this.adMaxWidth = 220,
    this.adMaxHeight = 120,
  });

  /// Current page identifier for ad targeting.
  final String page;
  
  /// The banner widget to show in the center.
  final Widget bannerWidget;
  
  /// Max width for the center banner.
  final double maxBannerWidth;
  
  /// Max width for ad slots.
  final double adMaxWidth;
  
  /// Max height for ad slots.
  final double adMaxHeight;

  @override
  ConsumerState<AdAwareBannerHeader> createState() => _AdAwareBannerHeaderState();
}

class _AdAwareBannerHeaderState extends ConsumerState<AdAwareBannerHeader> {
  AdCreative? _leftAd;
  AdCreative? _rightAd;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  @override
  void didUpdateWidget(AdAwareBannerHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      _loadAds();
    }
  }

  Future<void> _loadAds() async {
    setState(() => _loading = true);

    try {
      final adService = ref.read(adServiceProvider);
      final ads = await adService.prefetchAdsForPage(widget.page);

      if (mounted) {
        setState(() {
          _leftAd = ads.left;
          _rightAd = ads.right;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _leftAd = null;
          _rightAd = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointDesktop;
    final isTablet = screenWidth >= AppSpacing.breakpointTablet && !isWide;
    
    // On mobile, just show the banner centered
    if (screenWidth < AppSpacing.breakpointTablet) {
      return widget.bannerWidget;
    }

    // Determine which ads to show based on screen size
    final showLeftAd = isWide && _leftAd != null;
    final showRightAd = (isWide || isTablet) && _rightAd != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left slot (only on desktop if ad exists)
        if (showLeftAd)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AdSlot(
              page: widget.page,
              position: AdPosition.left,
              maxWidth: widget.adMaxWidth,
              maxHeight: widget.adMaxHeight,
            ),
          )
        else if (isWide)
          // Spacer to balance when no left ad
          SizedBox(width: widget.adMaxWidth + AppSpacing.md),
        
        // Center banner (expanded to fill remaining space)
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxBannerWidth),
              child: widget.bannerWidget,
            ),
          ),
        ),
        
        // Right slot (on tablet/desktop if ad exists)
        if (showRightAd)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: AdSlot(
              page: widget.page,
              position: AdPosition.right,
              maxWidth: widget.adMaxWidth,
              maxHeight: widget.adMaxHeight,
            ),
          )
        else if (isWide)
          // Spacer to balance when no right ad
          SizedBox(width: widget.adMaxWidth + AppSpacing.md),
      ],
    );
  }
}
