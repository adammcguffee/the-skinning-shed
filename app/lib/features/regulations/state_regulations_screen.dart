import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/regulations_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🦌 STATE REGULATIONS SCREEN - 2025 PREMIUM
/// 
/// View hunting and fishing regulations for a specific state.
/// Tabs: Deer / Turkey / Fishing
class StateRegulationsScreen extends ConsumerStatefulWidget {
  const StateRegulationsScreen({
    super.key,
    required this.stateCode,
  });

  final String stateCode;

  @override
  ConsumerState<StateRegulationsScreen> createState() => _StateRegulationsScreenState();
}

class _StateRegulationsScreenState extends ConsumerState<StateRegulationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  Map<RegulationCategory, List<StateRegulation>> _regulations = {};
  Map<RegulationCategory, List<RegulationRegion>> _regions = {};
  Map<RegulationCategory, String> _selectedRegionKeys = {};
  
  static const _categories = [
    RegulationCategory.deer,
    RegulationCategory.turkey,
    RegulationCategory.fishing,
  ];
  
  USState? get _state => USStates.byCode(widget.stateCode);
  
  RegulationCategory get _currentCategory => _categories[_tabController.index];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadRegulations();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
  
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Reload when tab changes if we don't have data for this category
    final category = _currentCategory;
    if (!_regions.containsKey(category)) {
      _loadRegionsForCategory(category);
    }
  }
  
  Future<void> _loadRegulations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final service = ref.read(regulationsServiceProvider);
      
      // Load regions and regulations for all categories
      final results = <RegulationCategory, List<StateRegulation>>{};
      final regionResults = <RegulationCategory, List<RegulationRegion>>{};
      
      for (final category in _categories) {
        // Load available regions first
        final regions = await service.fetchRegionsForState(
          stateCode: widget.stateCode,
          category: category,
        );
        regionResults[category] = regions;
        
        // Default to STATEWIDE or first region
        String regionKey = 'STATEWIDE';
        if (regions.isNotEmpty) {
          regionKey = regions.first.regionKey;
        }
        _selectedRegionKeys[category] = regionKey;
        
        // Load regulations for selected region
        results[category] = await service.fetchRegulations(
          stateCode: widget.stateCode,
          category: category,
          regionKey: regionKey,
        );
      }
      
      if (mounted) {
        setState(() {
          _regulations = results;
          _regions = regionResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadRegionsForCategory(RegulationCategory category) async {
    final service = ref.read(regulationsServiceProvider);
    final regions = await service.fetchRegionsForState(
      stateCode: widget.stateCode,
      category: category,
    );
    
    if (mounted) {
      setState(() {
        _regions[category] = regions;
        if (regions.isNotEmpty && !_selectedRegionKeys.containsKey(category)) {
          _selectedRegionKeys[category] = regions.first.regionKey;
        }
      });
    }
  }
  
  Future<void> _onRegionChanged(RegulationCategory category, String regionKey) async {
    setState(() {
      _selectedRegionKeys[category] = regionKey;
    });
    
    // Reload regulations for new region
    final service = ref.read(regulationsServiceProvider);
    final regs = await service.fetchRegulations(
      stateCode: widget.stateCode,
      category: category,
      regionKey: regionKey,
    );
    
    if (mounted) {
      setState(() {
        _regulations[category] = regs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateName = _state?.name ?? widget.stateCode;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context, stateName),
              
              // Category tabs
              _buildCategoryTabs(),
              
              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                        ? AppErrorState(
                            message: _error!,
                            onRetry: _loadRegulations,
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: _categories.map((category) {
                              return _buildCategoryContent(category);
                            }).toList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context, String stateName) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Row(
        children: [
          // Back button
          _BackButton(onTap: () => context.pop()),
          const SizedBox(width: AppSpacing.md),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stateName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Hunting & Fishing Regulations',
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
    );
  }
  
  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          boxShadow: AppColors.shadowCard,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: _categories.map((c) => Tab(text: c.label)).toList(),
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCardSkeleton(aspectRatio: 3),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRegionSelector(RegulationCategory category) {
    final regions = _regions[category] ?? [];
    if (regions.length <= 1) return const SizedBox.shrink();
    
    final selectedKey = _selectedRegionKeys[category] ?? 'STATEWIDE';
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(
                Icons.map_outlined,
                color: AppColors.info,
                size: 16,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Text(
              'Region / Zone:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedKey,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    items: regions.map((region) {
                      return DropdownMenuItem<String>(
                        value: region.regionKey,
                        child: Text(region.regionLabel),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _onRegionChanged(category, value);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildZoneDisclosure(RegulationCategory category) {
    final regions = _regions[category] ?? [];
    final hasMultipleRegions = regions.length > 1;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: AppColors.info,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                hasMultipleRegions
                    ? 'This state has different seasons by zone/unit. Select your region above.'
                    : 'Statewide overview. Some special units may differ. Always verify with official sources.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.info,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryContent(RegulationCategory category) {
    final regulations = _regulations[category] ?? [];
    final stateName = _state?.name ?? widget.stateCode;
    final regions = _regions[category] ?? [];
    final selectedRegion = regions.isNotEmpty
        ? regions.firstWhere(
            (r) => r.regionKey == (_selectedRegionKeys[category] ?? 'STATEWIDE'),
            orElse: () => regions.first,
          )
        : null;
    
    if (regulations.isEmpty) {
      return Column(
        children: [
          // Region selector even if no data yet
          _buildRegionSelector(category),
          
          Expanded(
            child: _EmptyRegulationsState(
              stateName: stateName,
              category: category,
            ),
          ),
        ],
      );
    }
    
    // Show the most recent regulation
    final regulation = regulations.first;
    
    return Column(
      children: [
        // Region selector
        _buildRegionSelector(category),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Season header with region info
                _buildSeasonHeader(regulation, selectedRegion),
                const SizedBox(height: AppSpacing.md),
                
                // Zone disclosure
                _buildZoneDisclosure(category),
                const SizedBox(height: AppSpacing.lg),
                
                // Seasons section
                if (regulation.summary.seasons.isNotEmpty) ...[
                  _buildSectionHeader('Season Dates', Icons.calendar_today_rounded),
                  const SizedBox(height: AppSpacing.sm),
                  ...regulation.summary.seasons.map((season) => _SeasonDateCard(season: season)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                
                // Bag limits section
                if (regulation.summary.bagLimits.isNotEmpty) ...[
                  _buildSectionHeader('Bag Limits', Icons.inventory_2_rounded),
                  const SizedBox(height: AppSpacing.sm),
                  ...regulation.summary.bagLimits.map((limit) => _BagLimitCard(bagLimit: limit)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                
                // Weapons section
                if (regulation.summary.weapons.isNotEmpty) ...[
                  _buildSectionHeader('Legal Methods', Icons.gpp_good_rounded),
                  const SizedBox(height: AppSpacing.sm),
                  _WeaponsCard(weapons: regulation.summary.weapons),
                  const SizedBox(height: AppSpacing.lg),
                ],
                
                // Notes section
                if (regulation.summary.notes.isNotEmpty) ...[
                  _buildSectionHeader('Important Notes', Icons.info_outline_rounded),
                  const SizedBox(height: AppSpacing.sm),
                  ...regulation.summary.notes.map((note) => _NoteCard(note: note)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                
                // Source link
                if (regulation.sourceUrl != null) ...[
                  _SourceLink(url: regulation.sourceUrl!),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSeasonHeader(StateRegulation regulation, RegulationRegion? selectedRegion) {
    final stateName = _state?.name ?? widget.stateCode;
    final regionLabel = selectedRegion?.regionLabel ?? 'Statewide';
    final showRegion = selectedRegion != null && !selectedRegion.isStatewide;
    
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.textInverse,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with state, category, region + approval badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          showRegion
                              ? '$stateName • ${regulation.category.label} • $regionLabel'
                              : '$stateName • ${regulation.category.label}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      _ApprovalBadge(isAuto: regulation.isAutoApproved),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${regulation.seasonYearLabel} Season',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Show last checked and approval info
                  Row(
                    children: [
                      if (regulation.approvedAt != null)
                        Text(
                          'Updated ${_formatDate(regulation.approvedAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (regulation.lastCheckedAt != null) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(
                          'Checked ${_formatDate(regulation.lastCheckedAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _BackButton extends StatefulWidget {
  const _BackButton({required this.onTap});
  
  final VoidCallback onTap;
  
  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SeasonDateCard extends StatelessWidget {
  const _SeasonDateCard({required this.season});
  
  final SeasonDateRange season;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                season.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              if (season.startDate != null && season.endDate != null)
                Text(
                  '${season.startDate} – ${season.endDate}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (season.notes != null && season.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  season.notes!,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BagLimitCard extends StatelessWidget {
  const _BagLimitCard({required this.bagLimit});
  
  final BagLimit bagLimit;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bagLimit.species,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSpacing.md,
                      children: [
                        if (bagLimit.daily != null)
                          _LimitChip(label: 'Daily', value: bagLimit.daily!),
                        if (bagLimit.possession != null)
                          _LimitChip(label: 'Possession', value: bagLimit.possession!),
                        if (bagLimit.season != null)
                          _LimitChip(label: 'Season', value: bagLimit.season!),
                      ],
                    ),
                    if (bagLimit.notes != null && bagLimit.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bagLimit.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({required this.label, required this.value});
  
  final String label;
  final String value;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeaponsCard extends StatelessWidget {
  const _WeaponsCard({required this.weapons});
  
  final List<WeaponMethod> weapons;
  
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: weapons.map((weapon) {
            final isAllowed = weapon.allowed ?? true;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isAllowed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 18,
                    color: isAllowed ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weapon.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (weapon.restrictions != null && weapon.restrictions!.isNotEmpty)
                          Text(
                            weapon.restrictions!,
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
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});
  
  final String note;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  note,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium empty state for missing regulations
class _EmptyRegulationsState extends ConsumerWidget {
  const _EmptyRegulationsState({
    required this.stateName,
    required this.category,
  });
  
  final String stateName;
  final RegulationCategory category;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if user is admin (AsyncValue from FutureProvider)
    final isAdminAsync = ref.watch(isAdminProvider);
    final isAdmin = isAdminAsync.valueOrNull ?? false;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 40,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            // Title
            Text(
              'No Approved Regulations Yet',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            
            // Description
            Text(
              'We don\'t have ${category.label.toLowerCase()} regulations for $stateName yet. '
              'Regulations are reviewed and approved by our team to ensure accuracy.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            
            // Admin action
            if (isAdmin) ...[
              // Automation hint for admins
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.info),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'Automation checks sources weekly. High-confidence updates auto-approve.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppButtonPrimary(
                label: 'Open Admin',
                icon: Icons.admin_panel_settings_outlined,
                onPressed: () => context.push('/admin/regulations'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            
            // Always show "Request regs" hint
            Text(
              'Know the official source? Let us know in Settings → Feedback.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceLink extends StatefulWidget {
  const _SourceLink({required this.url});
  
  final String url;
  
  @override
  State<_SourceLink> createState() => _SourceLinkState();
}

class _SourceLinkState extends State<_SourceLink> {
  bool _isHovered = false;
  
  Future<void> _launchUrl() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _launchUrl,
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
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
                        'Official Source',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isHovered ? AppColors.info : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.url,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
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

/// Badge showing if regulation was auto-approved or manually approved.
class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.isAuto});
  
  final bool isAuto;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAuto 
            ? AppColors.info.withValues(alpha: 0.15)
            : AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAuto ? Icons.auto_awesome_rounded : Icons.verified_user_rounded,
            size: 10,
            color: isAuto ? AppColors.info : AppColors.success,
          ),
          const SizedBox(width: 3),
          Text(
            isAuto ? 'Auto' : 'Verified',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isAuto ? AppColors.info : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}