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
  explore,
  other,
}

/// Premium Create Menu bottom sheet.
/// 
/// Shows context-aware create options with the most relevant option highlighted
/// based on which page the user is on.
Future<void> showCreateMenu({
  required BuildContext context,
  CreateContext createContext = CreateContext.other,
  bool isAuthenticated = true,
  VoidCallback? onLoginRequired,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _CreateMenuContent(
      createContext: createContext,
      isAuthenticated: isAuthenticated,
      onLoginRequired: onLoginRequired,
    ),
  );
}

class _CreateMenuContent extends StatelessWidget {
  const _CreateMenuContent({
    required this.createContext,
    required this.isAuthenticated,
    this.onLoginRequired,
  });
  
  final CreateContext createContext;
  final bool isAuthenticated;
  final VoidCallback? onLoginRequired;
  
  @override
  Widget build(BuildContext context) {
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
            
            // Create options
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
              isHighlighted: createContext == CreateContext.swapShop,
              onTap: () => _handleCreate(context, '/swap-shop/create'),
            ),
            _CreateOption(
              icon: Icons.landscape_rounded,
              iconColor: AppColors.success,
              title: 'Land Listing',
              description: 'List hunting land for lease or sale',
              isHighlighted: createContext == CreateContext.land,
              onTap: () => _handleCreate(context, '/land/create'),
            ),
            
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
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: showHighlight 
                                ? widget.iconColor 
                                : AppColors.textPrimary,
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
