import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/app/theme/background_theme.dart';
import 'package:shed/services/background_theme_provider.dart';
import 'package:shed/services/background_theme_store.dart';
import 'package:shed/shared/widgets/app_background.dart';
import 'package:shed/shared/widgets/pattern_overlay_painter.dart';

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

class _BackgroundThemeSelectorSheet extends ConsumerStatefulWidget {
  const _BackgroundThemeSelectorSheet();

  @override
  ConsumerState<_BackgroundThemeSelectorSheet> createState() => _BackgroundThemeSelectorSheetState();
}

class _BackgroundThemeSelectorSheetState extends ConsumerState<_BackgroundThemeSelectorSheet> {
  @override
  Widget build(BuildContext context) {
    final currentThemeId = ref.watch(backgroundThemeIdProvider);
    final favoritesAsync = ref.watch(backgroundThemeFavoritesProvider);
    final includeMinimalAsync = ref.watch(includeMinimalInRandomProvider);

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

            // Random button and include minimal toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final includeMinimal = includeMinimalAsync.value ?? false;
                        final notifier = ref.read(backgroundThemeIdProvider.notifier);
                        await notifier.setRandomTheme(includeMinimal);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.shuffle_rounded, size: 18),
                      label: const Text('Random'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textInverse,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  includeMinimalAsync.when(
                    data: (includeMinimal) => Row(
                      children: [
                        Text(
                          'Include minimal',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: includeMinimal,
                          onChanged: (value) async {
                            await BackgroundThemeStore.setIncludeMinimalInRandom(value);
                            ref.invalidate(includeMinimalInRandomProvider);
                          },
                          activeColor: AppColors.accent,
                        ),
                      ],
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Theme list with sections
            Flexible(
              child: favoritesAsync.when(
                data: (favorites) {
                  final allThemes = BackgroundThemes.all;
                  final favoriteThemes = allThemes.where((t) => favorites.contains(t.id)).toList();
                  final otherThemes = allThemes.where((t) => !favorites.contains(t.id)).toList();

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    itemCount: _calculateItemCount(favoriteThemes, otherThemes),
                    itemBuilder: (context, index) {
                      return _buildThemeItem(
                        context,
                        index,
                        favoriteThemes,
                        otherThemes,
                        currentThemeId,
                        favorites,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  int _calculateItemCount(List<BackgroundThemeSpec> favorites, List<BackgroundThemeSpec> others) {
    int count = 0;
    
    // Favorites section header + themes
    if (favorites.isNotEmpty) {
      count += 1 + favorites.length; // Header + themes
    }
    
    // Group others by category
    final categories = BackgroundThemeCategory.values;
    for (final category in categories) {
      final categoryThemes = others.where((t) => t.category == category).toList();
      if (categoryThemes.isNotEmpty) {
        count += 1 + categoryThemes.length; // Header + themes
      }
    }
    
    return count;
  }

  Widget _buildThemeItem(
    BuildContext context,
    int index,
    List<BackgroundThemeSpec> favorites,
    List<BackgroundThemeSpec> others,
    BackgroundThemeId currentThemeId,
    Set<BackgroundThemeId> favoriteIds,
  ) {
    int currentIndex = 0;
    
    // Favorites section
    if (favorites.isNotEmpty) {
      if (index == currentIndex) {
        return _SectionHeader(title: 'Favorites');
      }
      currentIndex++;
      
      for (final theme in favorites) {
        if (index == currentIndex) {
          return _ThemeOption(
            theme: theme,
            isSelected: theme.id == currentThemeId,
            isFavorite: true,
            onTap: () async {
              final notifier = ref.read(backgroundThemeIdProvider.notifier);
              await notifier.setTheme(theme.id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            onFavoriteToggle: () async {
              await BackgroundThemeStore.toggleFavorite(theme.id);
              ref.invalidate(backgroundThemeFavoritesProvider);
            },
          );
        }
        currentIndex++;
      }
    }
    
    // Category sections
    final categories = BackgroundThemeCategory.values;
    for (final category in categories) {
      final categoryThemes = others.where((t) => t.category == category).toList();
      if (categoryThemes.isEmpty) continue;
      
      if (index == currentIndex) {
        return _SectionHeader(title: BackgroundThemes.getCategoryName(category));
      }
      currentIndex++;
      
      for (final theme in categoryThemes) {
        if (index == currentIndex) {
          return _ThemeOption(
            theme: theme,
            isSelected: theme.id == currentThemeId,
            isFavorite: favoriteIds.contains(theme.id),
            onTap: () async {
              final notifier = ref.read(backgroundThemeIdProvider.notifier);
              await notifier.setTheme(theme.id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            onFavoriteToggle: () async {
              await BackgroundThemeStore.toggleFavorite(theme.id);
              ref.invalidate(backgroundThemeFavoritesProvider);
            },
          );
        }
        currentIndex++;
      }
    }
    
    return const SizedBox.shrink();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.theme,
    required this.isSelected,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  final BackgroundThemeSpec theme;
  final bool isSelected;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

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

                // Favorite button
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFavorite ? AppColors.accent : AppColors.textTertiary,
                    size: 24,
                  ),
                  onPressed: onFavoriteToggle,
                  tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
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

        // Pattern overlay (if any)
        if (theme.patternOverlay != PatternOverlayType.none)
          Positioned.fill(
            child: CustomPaint(
              painter: _getPreviewPatternPainter(theme.patternOverlay, theme.patternOpacityMain * 0.6),
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

  CustomPainter _getPreviewPatternPainter(PatternOverlayType type, double opacity) {
    switch (type) {
      case PatternOverlayType.antler:
        return AntlerPatternPainter(opacity: opacity);
      case PatternOverlayType.topo:
        return TopoLinesPainter(opacity: opacity);
      case PatternOverlayType.leatherBrass:
        return LeatherTexturePainter(opacity: opacity);
      case PatternOverlayType.none:
        return _EmptyPreviewPainter();
    }
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

/// Empty painter for preview
class _EmptyPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(_EmptyPreviewPainter oldDelegate) => false;
}
