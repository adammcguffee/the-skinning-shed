import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/app/theme/background_theme.dart';
import 'package:shed/services/background_theme_provider.dart';
import 'package:shed/shared/widgets/app_background.dart';

/// Show background theme selector modal
void showBackgroundThemeSelector(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => const _BackgroundThemeSelectorSheet(),
  );
}

class _BackgroundThemeSelectorSheet extends ConsumerWidget {
  const _BackgroundThemeSelectorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeId = ref.watch(backgroundThemeIdProvider);
    final themes = BackgroundThemes.all;

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

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Text(
                'Background Theme',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Text(
                'Choose a background theme for the entire app',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Theme list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                itemCount: themes.length,
                itemBuilder: (context, index) {
                  final theme = themes[index];
                  final isSelected = theme.id == currentThemeId;

                  return _ThemeOption(
                    theme: theme,
                    isSelected: isSelected,
                    onTap: () async {
                      final notifier = ref.read(backgroundThemeIdProvider.notifier);
                      await notifier.setTheme(theme.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  final BackgroundThemeSpec theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.4)
                    : AppColors.borderSubtle,
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Preview thumbnail
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _ThemePreview(theme: theme),
                ),
                const SizedBox(width: AppSpacing.md),

                // Title and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? AppColors.accent : AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theme.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                // Checkmark
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mini preview of theme (renders same background layers)
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme});

  final BackgroundThemeSpec theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: theme.baseGradient,
            ),
          ),
        ),

        // Camo pattern (simplified for preview)
        Positioned.fill(
          child: CustomPaint(
            painter: _PreviewCamoPainter(
              opacity: theme.patternOpacityMain * 0.8,
            ),
          ),
        ),

        // Leaf litter overlay
        if (theme.leafLitterGradient != null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: theme.leafLitterGradient!,
              ),
            ),
          ),

        // Overlay gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: theme.overlayGradient,
            ),
          ),
        ),

        // Vignette
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  AppColors.background.withValues(
                    alpha: theme.vignetteStrength * 0.4,
                  ),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simplified camo painter for preview
class _PreviewCamoPainter extends CustomPainter {
  _PreviewCamoPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final random = math.Random(42);
    final colors = [
      const Color(0xFF1A2E20),
      const Color(0xFF2A4030),
      const Color(0xFF2A2A1E),
      const Color(0xFF3A3A28),
    ];

    // Draw simplified patches
    for (int i = 0; i < 8; i++) {
      final color = colors[random.nextInt(colors.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * (0.4 + random.nextDouble() * 0.4))
        ..style = PaintingStyle.fill;

      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 8 + random.nextDouble() * 12;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PreviewCamoPainter oldDelegate) => opacity != oldDelegate.opacity;
}
