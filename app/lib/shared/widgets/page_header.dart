import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/utils/navigation.dart';

/// 🧭 PREMIUM PAGE HEADER - 2026
/// 
/// Reusable header with Back + Home buttons for navigation safety.
/// Ensures users are never trapped on any page.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = true,
    this.showHome = true,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final bool showHome;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button (if can pop and enabled)
          if (showBack && canPop)
            GestureDetector(
              onTap: onBack ?? () => context.pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (showBack && canPop) const SizedBox(width: AppSpacing.md),
          
          // Home button (always visible if enabled)
          if (showHome)
            GestureDetector(
              onTap: () => goHome(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (showHome) const SizedBox(width: AppSpacing.md),
          
          // Title section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          
          // Actions
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
