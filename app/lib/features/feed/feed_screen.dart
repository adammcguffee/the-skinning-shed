import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/us_counties.dart';
import '../../data/us_states.dart';
import '../../shared/branding_assets.dart';
import '../../shared/widgets/widgets.dart';

/// Main feed showing latest trophies.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String? _selectedCategory;
  // Demo mode: show empty state or sample data
  final bool _showSampleData = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _buildAppBarTitle(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: Search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showFilters(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: _showSampleData ? _buildFeedContent() : _buildEmptyState(),
      ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show horizontal logo on wide screens, icon on narrow
        if (isWide)
          Image.asset(
            BrandingAssets.horizontal,
            height: 36,
            fit: BoxFit.contain,
          )
        else ...[
          Image.asset(
            BrandingAssets.icon,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          const Text('The Skinning Shed'),
        ],
      ],
    );
  }

  Widget _buildFeedContent() {
    return CustomScrollView(
      slivers: [
        // Category chips
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _CategoryChip(
                  label: 'All',
                  isSelected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                _CategoryChip(
                  label: 'Deer',
                  icon: '🦌',
                  isSelected: _selectedCategory == 'deer',
                  onTap: () => setState(() => _selectedCategory = 'deer'),
                ),
                _CategoryChip(
                  label: 'Turkey',
                  icon: '🦃',
                  isSelected: _selectedCategory == 'turkey',
                  onTap: () => setState(() => _selectedCategory = 'turkey'),
                ),
                _CategoryChip(
                  label: 'Bass',
                  icon: '🐟',
                  isSelected: _selectedCategory == 'bass',
                  onTap: () => setState(() => _selectedCategory = 'bass'),
                ),
                _CategoryChip(
                  label: 'Other Game',
                  isSelected: _selectedCategory == 'other_game',
                  onTap: () => setState(() => _selectedCategory = 'other_game'),
                ),
                _CategoryChip(
                  label: 'Other Fishing',
                  isSelected: _selectedCategory == 'other_fishing',
                  onTap: () => setState(() => _selectedCategory = 'other_fishing'),
                ),
              ],
            ),
          ),
        ),
        
        // Trophy cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _TrophyCard(
                species: 'Whitetail Deer',
                speciesIcon: '🦌',
                category: 'Deer',
                location: 'Texas • Travis County',
                date: 'Jan 15, 2026',
                stats: '142" • Rifle • 8pt',
                userName: 'Hunter_TX',
                temp: '52°F',
                wind: 'NW 8mph',
                reactionCount: 24,
                commentCount: 5,
                onTap: () => context.push('/trophy/demo-1'),
              ),
              _TrophyCard(
                species: 'Eastern Wild Turkey',
                speciesIcon: '🦃',
                category: 'Turkey',
                location: 'Alabama • Jefferson County',
                date: 'Jan 12, 2026',
                stats: '22 lbs • 10" beard',
                userName: 'GobblerGetter',
                temp: '58°F',
                wind: 'S 5mph',
                reactionCount: 18,
                commentCount: 3,
                onTap: () => context.push('/trophy/demo-2'),
              ),
              _TrophyCard(
                species: 'Largemouth Bass',
                speciesIcon: '🐟',
                category: 'Bass',
                location: 'Florida • Lake County',
                date: 'Jan 10, 2026',
                stats: '8.2 lbs • 22"',
                userName: 'BassChaser',
                temp: '72°F',
                wind: 'E 3mph',
                reactionCount: 31,
                commentCount: 8,
                onTap: () => context.push('/trophy/demo-3'),
              ),
            ]),
          ),
        ),
        
        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Trophies Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share your hunting or fishing trophy with the community!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 32),
            PremiumButton(
              label: 'Post Your First Trophy',
              icon: Icons.add_rounded,
              onPressed: () => context.push('/post'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FilterSheet(),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              icon != null ? '$icon $label' : label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrophyCard extends StatelessWidget {
  const _TrophyCard({
    required this.species,
    required this.speciesIcon,
    required this.category,
    required this.location,
    required this.date,
    required this.stats,
    required this.userName,
    required this.temp,
    required this.wind,
    required this.reactionCount,
    required this.commentCount,
    required this.onTap,
  });

  final String species;
  final String speciesIcon;
  final String category;
  final String location;
  final String date;
  final String stats;
  final String userName;
  final String temp;
  final String wind;
  final int reactionCount;
  final int commentCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo placeholder
              Container(
                height: 200,
                width: double.infinity,
                color: AppColors.surfaceAlt,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(speciesIcon, style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & user
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            species,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '@$userName',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Stats row
                    Row(
                      children: [
                        _StatChip(icon: Icons.calendar_today_rounded, label: date),
                        const SizedBox(width: 8),
                        _StatChip(icon: Icons.thermostat_rounded, label: temp),
                        const SizedBox(width: 8),
                        _StatChip(icon: Icons.air_rounded, label: wind),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Trophy stats
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.straighten_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            stats,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Actions
                    Row(
                      children: [
                        _ActionButton(
                          icon: Icons.favorite_border_rounded,
                          label: '$reactionCount',
                          onTap: () {},
                        ),
                        const SizedBox(width: 16),
                        _ActionButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: '$commentCount',
                          onTap: () {},
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.share_outlined),
                          iconSize: 20,
                          onPressed: () {},
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  USState? _selectedState;
  String? _selectedCounty;
  String? _selectedSpecies;

  List<String> get _counties {
    if (_selectedState == null) return [];
    return USCounties.forState(_selectedState!.code);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
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
              const SizedBox(height: AppSpacing.lg),
              
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              
              // State dropdown with search
              _buildStateSelector(),
              const SizedBox(height: AppSpacing.lg),
              
              // County dropdown with search
              _buildCountySelector(),
              const SizedBox(height: AppSpacing.lg),
              
              PremiumDropdown<String>(
                label: 'Species',
                items: const ['Deer', 'Turkey', 'Bass', 'Other Game', 'Other Fishing'],
                value: _selectedSpecies,
                onChanged: (value) => setState(() => _selectedSpecies = value),
                itemLabel: (item) => item,
                allOptionLabel: 'All Species',
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedState = null;
                          _selectedCounty = null;
                          _selectedSpecies = null;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: PremiumButton(
                      label: 'Apply Filters',
                      onPressed: () => Navigator.pop(context),
                      isExpanded: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('State', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showStateSelector,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedState?.name ?? 'All States',
                    style: TextStyle(
                      color: _selectedState == null
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showStateSelector() async {
    final result = await showModalBottomSheet<USState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StateSearchSheet(selected: _selectedState),
    );
    if (result != null || result == null) {
      setState(() {
        _selectedState = result;
        _selectedCounty = null;
      });
    }
  }

  Widget _buildCountySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('County', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectedState == null ? null : _showCountySelector,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _selectedState == null ? AppColors.surfaceAlt : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedState == null
                        ? 'Select state first'
                        : (_selectedCounty ?? 'All Counties'),
                    style: TextStyle(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCountySelector() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountySearchSheet(
        counties: _counties,
        selected: _selectedCounty,
        stateName: _selectedState?.name ?? '',
      ),
    );
    if (result != null) {
      setState(() => _selectedCounty = result);
    }
  }
}

class _StateSearchSheet extends StatefulWidget {
  const _StateSearchSheet({this.selected});
  final USState? selected;

  @override
  State<_StateSearchSheet> createState() => _StateSearchSheetState();
}

class _StateSearchSheetState extends State<_StateSearchSheet> {
  final _controller = TextEditingController();
  List<USState> _filtered = USStates.all;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Search states...',
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() => _filtered = USStates.search(value));
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final state = _filtered[index];
                    return ListTile(
                      title: Text(state.name),
                      subtitle: Text(state.code),
                      trailing: state == widget.selected
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, state),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountySearchSheet extends StatefulWidget {
  const _CountySearchSheet({
    required this.counties,
    this.selected,
    required this.stateName,
  });
  
  final List<String> counties;
  final String? selected;
  final String stateName;

  @override
  State<_CountySearchSheet> createState() => _CountySearchSheetState();
}

class _CountySearchSheetState extends State<_CountySearchSheet> {
  final _controller = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.counties;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      widget.stateName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Search counties...',
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filtered = widget.counties
                              .where((c) => c.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final county = _filtered[index];
                    return ListTile(
                      title: Text(county),
                      trailing: county == widget.selected
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, county),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
