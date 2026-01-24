import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

/// Context hint for highlighting the most relevant create option.
enum CreateContext {
  feed,
  trophyWall,
  swapShop,
  land,
  landLease,
  landSale,
  explore,
  other,
}

/// Premium Create Menu bottom sheet.
/// 
/// Shows context-aware create options with the most relevant option highlighted
/// based on which page the user is on.
/// 
/// [landMode] can be 'lease' or 'sale' to pre-select the land listing type.
Future<void> showCreateMenu({
  required BuildContext context,
  CreateContext createContext = CreateContext.other,
  bool isAuthenticated = true,
  VoidCallback? onLoginRequired,
  String? landMode,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true, // Ensures modal sits above entire app shell
    builder: (context) => _CreateMenuContent(
      createContext: createContext,
      isAuthenticated: isAuthenticated,
      onLoginRequired: onLoginRequired,
      landMode: landMode,
    ),
  );
}

class _CreateMenuContent extends StatelessWidget {
  const _CreateMenuContent({
    required this.createContext,
    required this.isAuthenticated,
    this.onLoginRequired,
    this.landMode,
  });
  
  final CreateContext createContext;
  final bool isAuthenticated;
  final VoidCallback? onLoginRequired;
  final String? landMode;
  
  /// Get the land route with mode if specified
  String get _landRoute {
    if (landMode != null) {
      return '/land/create?mode=$landMode';
    }
    // Use context to determine default mode
    if (createContext == CreateContext.landLease) {
      return '/land/create?mode=lease';
    }
    if (createContext == CreateContext.landSale) {
      return '/land/create?mode=sale';
    }
    return '/land/create';
  }
  
  /// Get land listing description based on context
  String get _landDescription {
    if (createContext == CreateContext.landLease || landMode == 'lease') {
      return 'List hunting land for lease';
    }
    if (createContext == CreateContext.landSale || landMode == 'sale') {
      return 'List hunting land for sale';
    }
    return 'List hunting land for lease or sale';
  }
  
  /// Get land listing title based on context
  String get _landTitle {
    if (createContext == CreateContext.landLease || landMode == 'lease') {
      return 'Land Lease Listing';
    }
    if (createContext == CreateContext.landSale || landMode == 'sale') {
      return 'Land For Sale Listing';
    }
    return 'Land Listing';
  }
  
  @override
  Widget build(BuildContext context) {
    final isLandContext = createContext == CreateContext.land ||
        createContext == CreateContext.landLease ||
        createContext == CreateContext.landSale;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
        boxShadow: AppColors.shadowElevated,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      boxShadow: AppColors.shadowAccent,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: AppColors.textInverse,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'What would you like to share?',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            // Create options - order based on context
            if (isLandContext) ...[
              // Land options first when on Land page - show both lease and sale
              _CreateOption(
                icon: Icons.calendar_month_outlined,
                iconColor: AppColors.success,
                title: 'Land For Lease',
                description: 'List hunting land for seasonal lease',
                isHighlighted: createContext == CreateContext.landLease || 
                              (createContext == CreateContext.land && landMode != 'sale'),
                onTap: () => _handleCreate(context, '/land/create?mode=lease'),
              ),
              _CreateOption(
                icon: Icons.sell_outlined,
                iconColor: AppColors.success,
                title: 'Land For Sale',
                description: 'List hunting land for sale',
                isHighlighted: createContext == CreateContext.landSale || landMode == 'sale',
                onTap: () => _handleCreate(context, '/land/create?mode=sale'),
              ),
              _CreateOption(
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.accent,
                title: 'Trophy Post',
                description: 'Share your harvest with the community',
                isHighlighted: false,
                onTap: () => _handleCreate(context, '/post'),
              ),
              _CreateOption(
                icon: Icons.storefront_rounded,
                iconColor: AppColors.primary,
                title: 'Swap Shop Listing',
                description: 'Sell or trade hunting & fishing gear',
                isHighlighted: false,
                onTap: () => _handleCreate(context, '/swap-shop/create'),
              ),
            ] else if (createContext == CreateContext.swapShop) ...[
              // Swap Shop first when on Swap Shop page
              _CreateOption(
                icon: Icons.storefront_rounded,
                iconColor: AppColors.primary,
                title: 'Swap Shop Listing',
                description: 'Sell or trade hunting & fishing gear',
                isHighlighted: true,
                onTap: () => _handleCreate(context, '/swap-shop/create'),
              ),
              _CreateOption(
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.accent,
                title: 'Trophy Post',
                description: 'Share your harvest with the community',
                isHighlighted: false,
                onTap: () => _handleCreate(context, '/post'),
              ),
              _CreateOption(
                icon: Icons.landscape_rounded,
                iconColor: AppColors.success,
                title: 'Land Listing',
                description: 'List hunting land for lease or sale',
                isHighlighted: false,
                onTap: () => _handleCreate(context, _landRoute),
              ),
            ] else ...[
              // Default: Trophy first
              _CreateOption(
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.accent,
                title: 'Trophy Post',
                description: 'Share your harvest with the community',
                isHighlighted: createContext == CreateContext.feed || 
                              createContext == CreateContext.trophyWall ||
                              createContext == CreateContext.explore,
                onTap: () => _handleCreate(context, '/post'),
              ),
              _CreateOption(
                icon: Icons.storefront_rounded,
                iconColor: AppColors.primary,
                title: 'Swap Shop Listing',
                description: 'Sell or trade hunting & fishing gear',
                isHighlighted: false,
                onTap: () => _handleCreate(context, '/swap-shop/create'),
              ),
              _CreateOption(
                icon: Icons.landscape_rounded,
                iconColor: AppColors.success,
                title: 'Land Listing',
                description: 'List hunting land for lease or sale',
                isHighlighted: false,
                onTap: () => _handleCreate(context, _landRoute),
              ),
            ],
            
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
  
  void _handleCreate(BuildContext context, String route) {
    Navigator.pop(context);
    
    if (!isAuthenticated) {
      // Show login prompt
      onLoginRequired?.call();
      return;
    }
    
    context.push(route);
  }
}

class _CreateOption extends StatefulWidget {
  const _CreateOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isHighlighted,
    required this.onTap,
  });
  
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isHighlighted;
  final VoidCallback onTap;
  
  @override
  State<_CreateOption> createState() => _CreateOptionState();
}

class _CreateOptionState extends State<_CreateOption> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    final showHighlight = widget.isHighlighted || _isHovered;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: showHighlight 
                ? widget.iconColor.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: showHighlight 
                  ? widget.iconColor.withValues(alpha: 0.3)
                  : AppColors.borderSubtle,
              width: showHighlight ? 1.5 : 1,
            ),
            boxShadow: showHighlight 
                ? [
                    BoxShadow(
                      color: widget.iconColor.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: showHighlight 
                                  ? widget.iconColor 
                                  : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isHighlighted) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.iconColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            ),
                            child: Text(
                              'Suggested',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: widget.iconColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.chevron_right_rounded,
                color: showHighlight ? widget.iconColor : AppColors.textTertiary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
