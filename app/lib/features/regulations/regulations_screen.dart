import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🦌 REGULATIONS & RECORDS - 2026 PREMIUM
/// 
/// Clean, confident state grid.
/// Every state is clickable and visually equal.
/// No status labels, no uncertainty messaging.
class RegulationsScreen extends ConsumerStatefulWidget {
  const RegulationsScreen({super.key});

  @override
  ConsumerState<RegulationsScreen> createState() => _RegulationsScreenState();
}

class _RegulationsScreenState extends ConsumerState<RegulationsScreen> {
  String _searchQuery = '';
  
  void _onStateSelected(String stateCode) {
    context.push('/regulations/$stateCode');
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
            title: 'Regulations & Records',
            subtitle: 'Official state portals and record trophy highlights',
          ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mobile header
                if (!isWide) ...[
                  Text(
                    'Regulations & Records',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Official state portals and record trophy highlights',
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
        return _StateCard(
          stateCode: state.code,
          stateName: state.name,
          onTap: () => _onStateSelected(state.code),
        );
      },
    );
  }
  
  Widget _buildInfoCard() {
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
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.info,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Always verify with official sources',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Links direct to official state wildlife agencies.',
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

/// Premium state tile - clean, confident, equal weight
class _StateCard extends StatefulWidget {
  const _StateCard({
    required this.stateCode,
    required this.stateName,
    required this.onTap,
  });

  final String stateCode;
  final String stateName;
  final VoidCallback onTap;

  @override
  State<_StateCard> createState() => _StateCardState();
}

class _StateCardState extends State<_StateCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, _isHovered ? -2.0 : 0.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isHovered
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
              color: _isHovered
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.borderSubtle,
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: _isHovered
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // State abbreviation (large)
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _isHovered ? AppColors.accent : AppColors.textPrimary,
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
        ),
      ),
    );
  }
}
