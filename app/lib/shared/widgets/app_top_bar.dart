import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'app_buttons.dart';

/// A modern top bar for web layout.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onSearch,
    this.onFilter,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onSearch;
  final VoidCallback? onFilter;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          // Leading widget
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],

          // Title section
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),

          // Actions
          if (onSearch != null)
            AppIconButton(
              icon: Icons.search_rounded,
              onPressed: onSearch,
              tooltip: 'Search',
            ),
          if (onFilter != null) ...[
            const SizedBox(width: AppSpacing.xs),
            AppIconButton(
              icon: Icons.tune_rounded,
              onPressed: onFilter,
              tooltip: 'Filter',
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            ...actions,
          ],
        ],
      ),
    );
  }
}

/// A simple page header for mobile.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
