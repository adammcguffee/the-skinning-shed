import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// 🔬 RESEARCH SCREEN - Pattern Analysis
///
/// Aggregates trophy data to reveal hunting patterns by:
/// - Moon phase
/// - Pressure bands
/// - Temperature ranges
/// - Wind direction
/// - Time of day
///
/// Privacy: Only shows aggregates when count >= 10
class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  // Filters
  String? _selectedCategory;
  USState? _selectedState;
  String? _selectedCounty;
  DateTimeRange? _dateRange;

  // Data
  bool _loading = true;
  Map<String, int> _moonPhaseCounts = {};
  Map<String, int> _pressureCounts = {};
  Map<String, int> _tempCounts = {};
  Map<String, int> _windDirCounts = {};
  Map<String, int> _timeBucketCounts = {};
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) return;

      // Build filter query
      var query = client.from('analytics_buckets').select('*');

      if (_selectedCategory != null) {
        query = query.eq('category', _selectedCategory!);
      }
      if (_selectedState != null) {
        query = query.eq('state', _selectedState!.name);
      }
      if (_selectedCounty != null) {
        query = query.eq('county', _selectedCounty!);
      }

      final response = await query;
      final data = List<Map<String, dynamic>>.from(response);

      // Aggregate counts
      final moonCounts = <String, int>{};
      final pressureCounts = <String, int>{};
      final tempCounts = <String, int>{};
      final windCounts = <String, int>{};
      final timeCounts = <String, int>{};

      for (final row in data) {
        // Moon phase
        final moonPhase = row['moon_phase_bucket'] as String?;
        if (moonPhase != null) {
          moonCounts[moonPhase] = (moonCounts[moonPhase] ?? 0) + 1;
        }

        // Pressure bucket
        final pressure = row['pressure_bucket'] as String?;
        if (pressure != null) {
          pressureCounts[pressure] = (pressureCounts[pressure] ?? 0) + 1;
        }

        // Temp bucket
        final temp = row['temp_bucket'] as String?;
        if (temp != null) {
          tempCounts[temp] = (tempCounts[temp] ?? 0) + 1;
        }

        // Wind direction
        final windDir = row['wind_dir_bucket'] as String?;
        if (windDir != null) {
          windCounts[windDir] = (windCounts[windDir] ?? 0) + 1;
        }

        // Time of day
        final tod = row['tod_bucket'] as String?;
        if (tod != null) {
          timeCounts[tod] = (timeCounts[tod] ?? 0) + 1;
        }
      }

      setState(() {
        _moonPhaseCounts = moonCounts;
        _pressureCounts = pressureCounts;
        _tempCounts = tempCounts;
        _windDirCounts = windCounts;
        _timeBucketCounts = timeCounts;
        _totalCount = data.length;
        _loading = false;
      });
    } catch (e) {
      print('Error loading research data: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: _buildHeader(context),
        ),

        // Filters
        SliverToBoxAdapter(
          child: _FiltersSection(
            selectedCategory: _selectedCategory,
            selectedState: _selectedState,
            selectedCounty: _selectedCounty,
            onCategoryChanged: (cat) {
              setState(() => _selectedCategory = cat);
              _loadData();
            },
            onStateChanged: (state) {
              setState(() {
                _selectedState = state;
                _selectedCounty = null;
              });
              _loadData();
            },
            onCountyChanged: (county) {
              setState(() => _selectedCounty = county);
              _loadData();
            },
          ),
        ),

        // Loading or content
        if (_loading)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(64),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
            ),
          )
        else if (_totalCount < 10)
          SliverToBoxAdapter(
            child: _PrivacyNotice(),
          )
        else ...[
          // Sample size badge
          SliverToBoxAdapter(
            child: _SampleSizeBadge(totalCount: _totalCount),
          ),
          
          // Top Insights section
          SliverToBoxAdapter(
            child: _TopInsightsSection(
              moonPhaseCounts: _moonPhaseCounts,
              timeBucketCounts: _timeBucketCounts,
              tempCounts: _tempCounts,
              pressureCounts: _pressureCounts,
              windDirCounts: _windDirCounts,
              totalCount: _totalCount,
              category: _selectedCategory,
            ),
          ),
          
          // Compare mode toggle
          SliverToBoxAdapter(
            child: _CompareModeTile(
              onTap: () => _showCompareModal(context),
            ),
          ),

          // Moon phase chart
          if (_moonPhaseCounts.isNotEmpty)
            SliverToBoxAdapter(
              child: _PatternCard(
                title: 'Moon Phase',
                icon: Icons.dark_mode_outlined,
                color: AppColors.info,
                data: _moonPhaseCounts,
                totalCount: _totalCount,
              ),
            ),

          // Time of day chart
          if (_timeBucketCounts.isNotEmpty)
            SliverToBoxAdapter(
              child: _PatternCard(
                title: 'Time of Day',
                icon: Icons.schedule_outlined,
                color: AppColors.accent,
                data: _timeBucketCounts,
                totalCount: _totalCount,
              ),
            ),

          // Pressure chart
          if (_pressureCounts.isNotEmpty)
            SliverToBoxAdapter(
              child: _PatternCard(
                title: 'Barometric Pressure (inHg)',
                icon: Icons.speed_outlined,
                color: AppColors.success,
                data: _pressureCounts,
                totalCount: _totalCount,
                sortNumerically: true,
              ),
            ),

          // Temperature chart
          if (_tempCounts.isNotEmpty)
            SliverToBoxAdapter(
              child: _PatternCard(
                title: 'Temperature (°F)',
                icon: Icons.thermostat_outlined,
                color: AppColors.warning,
                data: _tempCounts,
                totalCount: _totalCount,
                sortNumerically: true,
              ),
            ),

          // Wind direction chart
          if (_windDirCounts.isNotEmpty)
            SliverToBoxAdapter(
              child: _PatternCard(
                title: 'Wind Direction',
                icon: Icons.air_rounded,
                color: AppColors.primary,
                data: _windDirCounts,
                totalCount: _totalCount,
              ),
            ),
        ],

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.md,
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: AppColors.shadowAccent,
                ),
                child: const Icon(
                  Icons.insights_rounded,
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
                      'Research & Patterns',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Discover what conditions produce harvests',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _HowItWorksButton(
                onTap: () => _showHowItWorksModal(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Data source disclaimer
          _DataSourceDisclaimer(),
        ],
      ),
    );
  }
  
  void _showHowItWorksModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true, // Ensures modal sits above entire app shell
      builder: (context) => const _HowItWorksSheet(),
    );
  }
  
  void _showCompareModal(BuildContext context) {
    showShedCenterModal(
      context: context,
      title: 'Compare Patterns',
      maxWidth: 500,
      maxHeight: 600,
      child: _CompareContent(
        selectedState: _selectedState,
        selectedCounty: _selectedCounty,
        selectedCategory: _selectedCategory,
      ),
    );
  }
}

/// Sample size badge - shows confidence level
class _SampleSizeBadge extends StatelessWidget {
  const _SampleSizeBadge({required this.totalCount});
  
  final int totalCount;
  
  @override
  Widget build(BuildContext context) {
    String confidence;
    Color color;
    IconData icon;
    
    if (totalCount >= 100) {
      confidence = 'High confidence';
      color = AppColors.success;
      icon = Icons.verified_rounded;
    } else if (totalCount >= 50) {
      confidence = 'Good confidence';
      color = AppColors.info;
      icon = Icons.check_circle_outline_rounded;
    } else if (totalCount >= 20) {
      confidence = 'Moderate confidence';
      color = AppColors.warning;
      icon = Icons.info_outline_rounded;
    } else {
      confidence = 'Limited data';
      color = AppColors.textTertiary;
      icon = Icons.hourglass_bottom_rounded;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Based on $totalCount trophies',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              confidence,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top Insights section with natural language summaries
class _TopInsightsSection extends StatelessWidget {
  const _TopInsightsSection({
    required this.moonPhaseCounts,
    required this.timeBucketCounts,
    required this.tempCounts,
    required this.pressureCounts,
    required this.windDirCounts,
    required this.totalCount,
    this.category,
  });
  
  final Map<String, int> moonPhaseCounts;
  final Map<String, int> timeBucketCounts;
  final Map<String, int> tempCounts;
  final Map<String, int> pressureCounts;
  final Map<String, int> windDirCounts;
  final int totalCount;
  final String? category;
  
  @override
  Widget build(BuildContext context) {
    final insights = _generateInsights();
    if (insights.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent.withValues(alpha: 0.15),
              AppColors.info.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Text(
                  'Top Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...insights.take(3).map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
  
  List<String> _generateInsights() {
    final insights = <String>[];
    final species = category ?? 'trophies';
    final speciesLabel = _getSpeciesLabel(category);
    
    // Time of day insight
    if (timeBucketCounts.isNotEmpty) {
      final sorted = timeBucketCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.isNotEmpty) {
        final top = sorted.first;
        final pct = (top.value / totalCount * 100).round();
        final timeLabel = _formatTimeLabel(top.key);
        insights.add('Most $speciesLabel harvests occur during $timeLabel ($pct% of posts).');
      }
    }
    
    // Moon phase insight
    if (moonPhaseCounts.isNotEmpty) {
      final sorted = moonPhaseCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.isNotEmpty) {
        final top = sorted.first;
        final pct = (top.value / totalCount * 100).round();
        insights.add('The ${top.key.toLowerCase()} moon phase shows the highest activity ($pct%).');
      }
    }
    
    // Temperature insight
    if (tempCounts.isNotEmpty) {
      final sorted = tempCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.isNotEmpty) {
        final top = sorted.first;
        final pct = (top.value / totalCount * 100).round();
        insights.add('Temperature around ${top.key}°F correlates with the most harvests ($pct%).');
      }
    }
    
    // Pressure insight
    if (pressureCounts.isNotEmpty && insights.length < 3) {
      final sorted = pressureCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.isNotEmpty) {
        final top = sorted.first;
        final pct = (top.value / totalCount * 100).round();
        insights.add('Barometric pressure around ${top.key} inHg shows peak activity ($pct%).');
      }
    }
    
    // Wind direction insight
    if (windDirCounts.isNotEmpty && insights.length < 3) {
      final sorted = windDirCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.isNotEmpty) {
        final top = sorted.first;
        final pct = (top.value / totalCount * 100).round();
        insights.add('Wind from the ${top.key} is most common during harvests ($pct%).');
      }
    }
    
    return insights;
  }
  
  String _getSpeciesLabel(String? category) {
    switch (category) {
      case 'deer': return 'deer';
      case 'turkey': return 'turkey';
      case 'bass': return 'bass';
      case 'other_game': return 'other game';
      case 'other_fishing': return 'fish';
      default: return 'trophy';
    }
  }
  
  String _formatTimeLabel(String key) {
    switch (key) {
      case 'morning': return 'the morning (6-10 AM)';
      case 'midday': return 'midday (10 AM-2 PM)';
      case 'evening': return 'the evening (2-6 PM)';
      case 'night': return 'night hours';
      default: return key;
    }
  }
}

/// Compare mode tile
class _CompareModeTile extends StatefulWidget {
  const _CompareModeTile({required this.onTap});
  
  final VoidCallback onTap;
  
  @override
  State<_CompareModeTile> createState() => _CompareModeTileState();
}

class _CompareModeTileState extends State<_CompareModeTile> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: _isHovered 
                  ? AppColors.info.withValues(alpha: 0.1)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: _isHovered 
                    ? AppColors.info.withValues(alpha: 0.3)
                    : AppColors.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.compare_arrows_rounded,
                    size: 20,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Compare Patterns',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Compare county vs state, or this season vs last',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _isHovered ? AppColors.info : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compare content modal
class _CompareContent extends ConsumerStatefulWidget {
  const _CompareContent({
    this.selectedState,
    this.selectedCounty,
    this.selectedCategory,
  });
  
  final USState? selectedState;
  final String? selectedCounty;
  final String? selectedCategory;
  
  @override
  ConsumerState<_CompareContent> createState() => _CompareContentState();
}

class _CompareContentState extends ConsumerState<_CompareContent> {
  String _compareMode = 'location'; // 'location' or 'season'
  bool _loading = false;
  
  Map<String, int> _leftData = {};
  Map<String, int> _rightData = {};
  String _leftLabel = '';
  String _rightLabel = '';
  
  @override
  void initState() {
    super.initState();
    _loadComparisonData();
  }
  
  Future<void> _loadComparisonData() async {
    setState(() => _loading = true);
    
    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) return;
      
      if (_compareMode == 'location' && widget.selectedState != null) {
        // Compare county vs state
        _leftLabel = widget.selectedCounty ?? 'County';
        _rightLabel = widget.selectedState!.name;
        
        // Left: county data
        var leftQuery = client.from('analytics_buckets').select('tod_bucket');
        if (widget.selectedCategory != null) {
          leftQuery = leftQuery.eq('category', widget.selectedCategory!);
        }
        leftQuery = leftQuery.eq('state', widget.selectedState!.name);
        if (widget.selectedCounty != null) {
          leftQuery = leftQuery.eq('county', widget.selectedCounty!);
        }
        
        final leftResponse = await leftQuery;
        _leftData = _aggregateTodBuckets(List<Map<String, dynamic>>.from(leftResponse));
        
        // Right: state data (all counties)
        var rightQuery = client.from('analytics_buckets').select('tod_bucket');
        if (widget.selectedCategory != null) {
          rightQuery = rightQuery.eq('category', widget.selectedCategory!);
        }
        rightQuery = rightQuery.eq('state', widget.selectedState!.name);
        
        final rightResponse = await rightQuery;
        _rightData = _aggregateTodBuckets(List<Map<String, dynamic>>.from(rightResponse));
        
      } else {
        // Compare this season vs last season
        final now = DateTime.now();
        final currentYear = now.year;
        final lastYear = currentYear - 1;
        
        _leftLabel = 'This Season ($currentYear)';
        _rightLabel = 'Last Season ($lastYear)';
        
        // This season
        var leftQuery = client.from('analytics_buckets').select('tod_bucket, created_at');
        if (widget.selectedCategory != null) {
          leftQuery = leftQuery.eq('category', widget.selectedCategory!);
        }
        if (widget.selectedState != null) {
          leftQuery = leftQuery.eq('state', widget.selectedState!.name);
        }
        
        final leftResponse = await leftQuery;
        final leftFiltered = List<Map<String, dynamic>>.from(leftResponse).where((row) {
          final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
          return createdAt != null && createdAt.year == currentYear;
        }).toList();
        _leftData = _aggregateTodBuckets(leftFiltered);
        
        // Last season
        final rightFiltered = List<Map<String, dynamic>>.from(leftResponse).where((row) {
          final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
          return createdAt != null && createdAt.year == lastYear;
        }).toList();
        _rightData = _aggregateTodBuckets(rightFiltered);
      }
      
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }
  
  Map<String, int> _aggregateTodBuckets(List<Map<String, dynamic>> data) {
    final counts = <String, int>{};
    for (final row in data) {
      final bucket = row['tod_bucket'] as String?;
      if (bucket != null) {
        counts[bucket] = (counts[bucket] ?? 0) + 1;
      }
    }
    return counts;
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode selector
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'By Location',
                icon: Icons.location_on_outlined,
                isSelected: _compareMode == 'location',
                onTap: () {
                  setState(() => _compareMode = 'location');
                  _loadComparisonData();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ModeButton(
                label: 'By Season',
                icon: Icons.calendar_today_outlined,
                isSelected: _compareMode == 'season',
                onTap: () {
                  setState(() => _compareMode = 'season');
                  _loadComparisonData();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        
        // Comparison chart
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_leftData.isEmpty && _rightData.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Not enough data to compare. Try broadening your filters.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          _ComparisonChart(
            leftLabel: _leftLabel,
            rightLabel: _rightLabel,
            leftData: _leftData,
            rightData: _rightData,
          ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonChart extends StatelessWidget {
  const _ComparisonChart({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftData,
    required this.rightData,
  });
  
  final String leftLabel;
  final String rightLabel;
  final Map<String, int> leftData;
  final Map<String, int> rightData;
  
  @override
  Widget build(BuildContext context) {
    // Get all buckets
    final allBuckets = {...leftData.keys, ...rightData.keys}.toList();
    allBuckets.sort((a, b) {
      const order = ['morning', 'midday', 'evening', 'night'];
      return order.indexOf(a).compareTo(order.indexOf(b));
    });
    
    // Calculate totals for percentages
    final leftTotal = leftData.values.fold<int>(0, (sum, v) => sum + v);
    final rightTotal = rightData.values.fold<int>(0, (sum, v) => sum + v);
    
    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(color: AppColors.accent, label: leftLabel),
            const SizedBox(width: AppSpacing.lg),
            _LegendItem(color: AppColors.info, label: rightLabel),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        
        // Title
        const Text(
          'Time of Day Distribution',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Bars
        ...allBuckets.map((bucket) {
          final leftCount = leftData[bucket] ?? 0;
          final rightCount = rightData[bucket] ?? 0;
          final leftPct = leftTotal > 0 ? (leftCount / leftTotal * 100) : 0.0;
          final rightPct = rightTotal > 0 ? (rightCount / rightTotal * 100) : 0.0;
          final maxPct = [leftPct, rightPct, 1.0].reduce((a, b) => a > b ? a : b);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatBucket(bucket),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                // Left bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: leftPct / maxPct,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${leftPct.round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Right bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: rightPct / maxPct,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.info,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${rightPct.round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
  
  String _formatBucket(String bucket) {
    switch (bucket) {
      case 'morning': return 'Morning (6-10 AM)';
      case 'midday': return 'Midday (10 AM-2 PM)';
      case 'evening': return 'Evening (2-6 PM)';
      case 'night': return 'Night';
      default: return bucket;
    }
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  
  final Color color;
  final String label;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// "How it works" button
class _HowItWorksButton extends StatefulWidget {
  const _HowItWorksButton({required this.onTap});
  
  final VoidCallback onTap;
  
  @override
  State<_HowItWorksButton> createState() => _HowItWorksButtonState();
}

class _HowItWorksButtonState extends State<_HowItWorksButton> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.info.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: _isHovered
                  ? AppColors.info.withValues(alpha: 0.3)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 14,
                color: _isHovered ? AppColors.info : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'How it works',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _isHovered ? AppColors.info : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data source disclaimer badge
class _DataSourceDisclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 16,
            color: AppColors.info,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Insights are based on trophies posted to The Skinning Shed (user uploads). Not statewide harvest records.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How it works bottom sheet
class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet();
  
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.info,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'How Research & Patterns Works',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              
              // Data source section
              _HowItWorksSection(
                icon: Icons.cloud_upload_outlined,
                title: 'Data from User Uploads',
                content: 'All insights are derived from trophy posts shared by hunters and anglers on The Skinning Shed. When you post a harvest, we capture weather conditions at that moment.',
              ),
              
              // Weather snapshot section
              _HowItWorksSection(
                icon: Icons.wb_sunny_outlined,
                title: 'Weather Snapshots',
                content: 'Each trophy post stores a snapshot of conditions at the time of harvest: temperature, barometric pressure, wind direction/speed, humidity, cloud cover, and moon phase.',
              ),
              
              // Privacy section
              _HowItWorksSection(
                icon: Icons.lock_outline_rounded,
                title: 'Privacy Threshold',
                content: 'To protect individual hunter privacy, patterns are only shown when at least 10 trophies match the filter criteria. This prevents identifying specific hunts.',
              ),
              
              // Patterns section
              _HowItWorksSection(
                icon: Icons.insights_outlined,
                title: 'Finding Patterns',
                content: 'We group harvests by condition buckets (temperature ranges, pressure bands, moon phases, etc.) to reveal which conditions correlate with more successful harvests.',
              ),
              
              // Disclaimer section
              _HowItWorksSection(
                icon: Icons.warning_amber_rounded,
                title: 'Not a Guarantee',
                content: 'Patterns show correlation, not causation. Favorable conditions don\'t guarantee success, and many factors beyond weather affect hunting and fishing.',
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textInverse,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
              
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection({
    required this.icon,
    required this.title,
    required this.content,
  });
  
  final IconData icon;
  final String title;
  final String content;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
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

/// Filters section for research queries.
class _FiltersSection extends StatelessWidget {
  const _FiltersSection({
    required this.selectedCategory,
    required this.selectedState,
    required this.selectedCounty,
    required this.onCategoryChanged,
    required this.onStateChanged,
    required this.onCountyChanged,
  });

  final String? selectedCategory;
  final USState? selectedState;
  final String? selectedCounty;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<USState?> onStateChanged;
  final ValueChanged<String?> onCountyChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Category filter
            const Text(
              'Species Category',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _CategoryChips(
              selected: selectedCategory,
              onChanged: onCategoryChanged,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Location filter
            LocationSelector(
              selectedState: selectedState,
              selectedCounty: selectedCounty,
              onStateChanged: onStateChanged,
              onCountyChanged: onCountyChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Category chip selector.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    const categories = [
      ('All', null),
      ('Deer', 'deer'),
      ('Turkey', 'turkey'),
      ('Bass', 'bass'),
      ('Other Game', 'other_game'),
      ('Other Fish', 'other_fishing'),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: categories.map((cat) {
        final isSelected = selected == cat.$2;
        return GestureDetector(
          onTap: () => onChanged(cat.$2),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.accent.withOpacity(0.15) : AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Text(
              cat.$1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Privacy notice when not enough data.
class _PrivacyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: const Icon(
                Icons.lock_outlined,
                size: 32,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Not Enough Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Patterns require at least 10 trophies in this filter to protect individual hunter privacy. Try broadening your filters or check back as more trophies are posted.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pattern card with horizontal bar chart.
class _PatternCard extends StatelessWidget {
  const _PatternCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.data,
    required this.totalCount,
    this.sortNumerically = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Map<String, int> data;
  final int totalCount;
  final bool sortNumerically;

  @override
  Widget build(BuildContext context) {
    // Sort entries
    var entries = data.entries.toList();
    if (sortNumerically) {
      entries.sort((a, b) {
        final aNum = double.tryParse(a.key) ?? 0;
        final bNum = double.tryParse(b.key) ?? 0;
        return aNum.compareTo(bNum);
      });
    } else {
      entries.sort((a, b) => b.value.compareTo(a.value));
    }

    // Find max for bar scaling
    final maxCount = entries.fold<int>(0, (max, e) => e.value > max ? e.value : max);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Bar chart
            ...entries.take(8).map((entry) {
              final percentage = (entry.value / totalCount * 100);
              final barWidth = maxCount > 0 ? entry.value / maxCount : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        _formatLabel(entry.key),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundAlt,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: barWidth,
                            child: Container(
                              height: 24,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${entry.value} (${percentage.toStringAsFixed(0)}%)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatLabel(String key) {
    // Pretty-print time buckets
    switch (key) {
      case 'morning':
        return 'Morning';
      case 'midday':
        return 'Midday';
      case 'evening':
        return 'Evening';
      case 'night':
        return 'Night';
      default:
        return key;
    }
  }
}
