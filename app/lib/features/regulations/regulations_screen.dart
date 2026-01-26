import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/regulations_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🦌 REGULATIONS SCREEN - 2025 PREMIUM
/// 
/// Browse hunting and fishing regulations by state.
/// Features US map with clickable states (large tap targets).
class RegulationsScreen extends ConsumerStatefulWidget {
  const RegulationsScreen({super.key});

  @override
  ConsumerState<RegulationsScreen> createState() => _RegulationsScreenState();
}

class _RegulationsScreenState extends ConsumerState<RegulationsScreen> {
  String? _selectedStateCode;
  bool _isLoadingStates = true;
  Map<String, StateReadiness> _statesReadiness = {};
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadStatesReadiness();
  }
  
  Future<void> _loadStatesReadiness() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final readiness = await service.fetchAllStatesReadiness();
      if (mounted) {
        setState(() {
          _statesReadiness = readiness;
          _isLoadingStates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStates = false;
        });
      }
    }
  }
  
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
            subtitle: 'Official portal + state record highlights',
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
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Official portal + state record highlights',
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
                
                // Info card
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.info,
                            size: 20,
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Regulations are provided as a reference. Check your state wildlife agency for official rules.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
    final crossAxisCount = isWide ? 6 : 3;
    
    // Filter states by search query
    final states = USStates.all.where((state) {
      if (_searchQuery.isEmpty) return true;
      return state.name.toLowerCase().contains(_searchQuery) ||
             state.code.toLowerCase().contains(_searchQuery);
    }).toList();
    
    if (_isLoadingStates) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.2,
        ),
        itemCount: 12,
        itemBuilder: (context, index) => AppCardSkeleton(aspectRatio: 1.2),
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.1,
      ),
      itemCount: states.length,
      itemBuilder: (context, index) {
        final state = states[index];
        final readiness = _statesReadiness[state.code];
        
        return _StateCard(
          stateCode: state.code,
          stateName: state.name,
          readiness: readiness,
          isSelected: _selectedStateCode == state.code,
          onTap: () => _onStateSelected(state.code),
        );
      },
    );
  }
}

class _StateCard extends StatefulWidget {
  const _StateCard({
    required this.stateCode,
    required this.stateName,
    required this.readiness,
    required this.isSelected,
    required this.onTap,
  });

  final String stateCode;
  final String stateName;
  final StateReadiness? readiness;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_StateCard> createState() => _StateCardState();
}

class _StateCardState extends State<_StateCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final showHighlight = widget.isSelected || _isHovered;
    final readiness = widget.readiness;
    final isReady = readiness?.isReady ?? false;
    final needsVerify = readiness?.needsVerification ?? false;
    final hasAnyLinks = readiness != null && readiness.totalLinks > 0;
    
    // Determine status color
    Color statusColor;
    if (isReady) {
      statusColor = AppColors.success;
    } else if (needsVerify) {
      statusColor = AppColors.warning;
    } else {
      statusColor = AppColors.textTertiary;
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use LayoutBuilder to safely constrain content
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isReady
                    ? (showHighlight
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.surface)
                    : AppColors.surface.withValues(alpha: hasAnyLinks ? 0.8 : 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: showHighlight && isReady
                      ? AppColors.accent.withValues(alpha: 0.4)
                      : AppColors.borderSubtle,
                ),
                boxShadow: showHighlight && isReady
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              // ClipRRect prevents any internal overflow from showing
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // State code - primary text
                      Flexible(
                        flex: 0,
                        child: Text(
                          widget.stateCode,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isReady
                                ? (showHighlight ? AppColors.accent : AppColors.textPrimary)
                                : hasAnyLinks ? AppColors.textSecondary : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      // State name - constrained
                      Flexible(
                        flex: 0,
                        child: Text(
                          widget.stateName,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                            color: isReady ? AppColors.textSecondary : AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Status pill - constrained width
                      Flexible(
                        flex: 0,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth - 8),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            readiness?.statusLabel ?? 'N/A',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
