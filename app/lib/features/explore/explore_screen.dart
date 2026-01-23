import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// 🔍 MODERN EXPLORE SCREEN
/// 
/// Features:
/// - Species hubs with hover/press states
/// - Strong visual hierarchy
/// - Quick links with modern card design
/// - State browser with chips
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Explore',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Species Hubs
                _SectionHeader(
                  title: 'Species Hubs',
                  subtitle: 'Browse trophies by category',
                ),
                const SizedBox(height: 16),
                _buildSpeciesGrid(context, isWide),
                const SizedBox(height: 32),

                // Quick Links
                _SectionHeader(
                  title: 'Discover',
                  subtitle: 'More ways to explore',
                ),
                const SizedBox(height: 16),
                _DiscoverCard(
                  icon: Icons.terrain_rounded,
                  title: 'Land for Lease',
                  subtitle: 'Find hunting properties',
                  color: AppColors.categoryOtherGame,
                  onTap: () => context.go('/land'),
                ),
                _DiscoverCard(
                  icon: Icons.sell_rounded,
                  title: 'Land for Sale',
                  subtitle: 'Own your hunting ground',
                  color: AppColors.accent,
                  onTap: () => context.go('/land'),
                ),
                _DiscoverCard(
                  icon: Icons.swap_horiz_rounded,
                  title: 'The Swap Shop',
                  subtitle: 'Gear marketplace',
                  color: AppColors.primary,
                  onTap: () => context.go('/swap-shop'),
                ),
                const SizedBox(height: 32),

                // Browse by State
                _SectionHeader(
                  title: 'Browse by State',
                  subtitle: 'Regional trophy feeds',
                ),
                const SizedBox(height: 16),
                _buildStateChips(context),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('View all 50 states'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesGrid(BuildContext context, bool isWide) {
    final hubs = [
      _SpeciesData('🦌', 'Deer', AppColors.categoryDeer, '1.2k trophies'),
      _SpeciesData('🦃', 'Turkey', AppColors.categoryTurkey, '847 trophies'),
      _SpeciesData('🐟', 'Bass', AppColors.categoryBass, '956 trophies'),
      _SpeciesData('🎯', 'Other Game', AppColors.categoryOtherGame, '324 trophies'),
      _SpeciesData('🎣', 'Other Fishing', AppColors.categoryOtherFishing, '512 trophies'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 5 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: isWide ? 1.0 : 1.3,
      ),
      itemCount: hubs.length,
      itemBuilder: (context, index) => _SpeciesHubCard(data: hubs[index]),
    );
  }

  Widget _buildStateChips(BuildContext context) {
    final states = [
      'Texas', 'Alabama', 'Florida', 'Georgia', 'Tennessee',
      'Arkansas', 'Louisiana', 'Mississippi', 'Oklahoma', 'Missouri',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: states.map((state) => _StateChip(label: state)).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPECIES HUB CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _SpeciesData {
  const _SpeciesData(this.emoji, this.label, this.color, this.count);
  final String emoji;
  final String label;
  final Color color;
  final String count;
}

class _SpeciesHubCard extends StatefulWidget {
  const _SpeciesHubCard({required this.data});
  final _SpeciesData data;

  @override
  State<_SpeciesHubCard> createState() => _SpeciesHubCardState();
}

class _SpeciesHubCardState extends State<_SpeciesHubCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Navigate to species feed
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered 
                ? widget.data.color.withOpacity(0.15)
                : widget.data.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered 
                  ? widget.data.color.withOpacity(0.4)
                  : widget.data.color.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.data.color.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.data.emoji,
                style: TextStyle(fontSize: _isHovered ? 36 : 32),
              ),
              const SizedBox(height: 8),
              Text(
                widget.data.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.data.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.data.count,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISCOVER CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _DiscoverCard extends StatefulWidget {
  const _DiscoverCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_DiscoverCard> createState() => _DiscoverCardState();
}

class _DiscoverCardState extends State<_DiscoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isHovered 
                    ? widget.color.withOpacity(0.3) 
                    : AppColors.border.withOpacity(0.5),
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(_isHovered ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _isHovered ? widget.color : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE CHIP
// ═══════════════════════════════════════════════════════════════════════════════

class _StateChip extends StatefulWidget {
  const _StateChip({required this.label});
  final String label;

  @override
  State<_StateChip> createState() => _StateChipState();
}

class _StateChipState extends State<_StateChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Navigate to state feed
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _isHovered ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
