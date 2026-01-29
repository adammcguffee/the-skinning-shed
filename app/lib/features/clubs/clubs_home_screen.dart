import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../navigation/app_routes.dart';
import '../../services/clubs_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../data/us_states.dart';

/// Clubs home screen - shows My Clubs and Search Clubs sections
class ClubsHomeScreen extends ConsumerStatefulWidget {
  const ClubsHomeScreen({super.key});

  @override
  ConsumerState<ClubsHomeScreen> createState() => _ClubsHomeScreenState();
}

class _ClubsHomeScreenState extends ConsumerState<ClubsHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= AppSpacing.breakpointTablet;

    return Column(
      children: [
        if (isWide)
          const AppTopBar(
            title: 'Hunting Clubs',
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myClubsProvider);
            },
            child: CustomScrollView(
              slivers: [
                if (!isWide)
                  const SliverToBoxAdapter(
                    child: AppPageHeader(
                      title: 'Hunting Clubs',
                    ),
                  ),
                
                // Create Club CTA
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _CreateClubCard(
                      onTap: () => context.push(AppRoutes.clubsCreate),
                    ),
                  ),
                ),
                
                // My Clubs section
                const SliverToBoxAdapter(
                  child: _SectionHeader(title: 'My Clubs'),
                ),
                _MyClubsList(),
                
                // Search Clubs section
                const SliverToBoxAdapter(
                  child: _SectionHeader(title: 'Search Hunting Clubs'),
                ),
                const SliverToBoxAdapter(
                  child: _SearchClubsSection(),
                ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CreateClubCard extends StatelessWidget {
  const _CreateClubCard({required this.onTap});
  
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.2),
              AppColors.primary.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a Hunting Club',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Organize your hunting crew with shared stands and news',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MyClubsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(myClubsProvider);
    
    return clubsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Error loading clubs',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (clubs) {
        if (clubs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No clubs yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create one or search for clubs to join',
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
        
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ClubCard(
                club: clubs[index],
                onTap: () => context.push(AppRoutes.clubDetail(clubs[index].id)),
              ),
              childCount: clubs.length,
            ),
          ),
        );
      },
    );
  }
}

/// Search Clubs Section with state/county filters
class _SearchClubsSection extends ConsumerStatefulWidget {
  const _SearchClubsSection();

  @override
  ConsumerState<_SearchClubsSection> createState() => _SearchClubsSectionState();
}

class _SearchClubsSectionState extends ConsumerState<_SearchClubsSection> {
  final _searchController = TextEditingController();
  String? _selectedState;
  String? _selectedCounty;
  List<Club> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  List<String> _availableCounties = [];
  final Map<String, bool> _pendingRequests = {};
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    
    final service = ref.read(clubsServiceProvider);
    final results = await service.searchClubs(
      query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      stateCode: _selectedState,
      county: _selectedCounty,
    );
    
    // Filter out clubs user is already a member of
    final myClubs = ref.read(myClubsProvider).valueOrNull ?? [];
    final myClubIds = myClubs.map((c) => c.id).toSet();
    
    setState(() {
      _searchResults = results.where((c) => !myClubIds.contains(c.id)).toList();
      _isLoading = false;
    });
  }
  
  Future<void> _loadCounties(String stateCode) async {
    final service = ref.read(clubsServiceProvider);
    final counties = await service.getClubCounties(stateCode);
    setState(() {
      _availableCounties = counties;
    });
  }
  
  Future<void> _requestJoin(Club club) async {
    setState(() => _pendingRequests[club.id] = true);
    
    final service = ref.read(clubsServiceProvider);
    
    // Check if already has pending request
    final hasPending = await service.hasPendingRequest(club.id);
    if (hasPending) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have a pending request')),
        );
      }
      return;
    }
    
    final success = await service.requestToJoin(club.id);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request sent!')),
        );
      } else {
        setState(() => _pendingRequests[club.id] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by club name...',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // State and County filters
          Row(
            children: [
              // State dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedState,
                      hint: Text(
                        'All States',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                      dropdownColor: AppColors.surfaceElevated,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All States'),
                        ),
                        ...USStates.all.map((state) => DropdownMenuItem(
                          value: state.code,
                          child: Text(state.name),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedState = value;
                          _selectedCounty = null;
                          _availableCounties = [];
                        });
                        if (value != null) {
                          _loadCounties(value);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              
              // County dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCounty,
                      hint: Text(
                        _selectedState == null ? 'Select state first' : 'All Counties',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                      dropdownColor: AppColors.surfaceElevated,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                      items: _selectedState == null 
                          ? []
                          : [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Counties'),
                              ),
                              ..._availableCounties.map((county) => DropdownMenuItem(
                                value: county,
                                child: Text(county),
                              )),
                            ],
                      onChanged: _selectedState == null ? null : (value) {
                        setState(() {
                          _selectedCounty = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Search button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _search,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(_isLoading ? 'Searching...' : 'Search Clubs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Results
          if (_hasSearched) ...[
            if (_searchResults.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No clubs found',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try adjusting your filters or create your own club',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_searchResults.length, (index) {
                final club = _searchResults[index];
                return _SearchResultCard(
                  club: club,
                  isPending: _pendingRequests[club.id] ?? false,
                  onRequestJoin: () => _requestJoin(club),
                );
              }),
          ] else
            // Initial state - show hint
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Icon(
                      Icons.travel_explore_rounded,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Find clubs near you',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Filter by state or county to find local hunting clubs',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club, required this.onTap});
  
  final Club club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (club.description != null && club.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        club.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (club.locationDisplay != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 2),
                          Text(
                            club.locationDisplay!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.club,
    required this.isPending,
    required this.onRequestJoin,
  });
  
  final Club club;
  final bool isPending;
  final VoidCallback onRequestJoin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.groups_outlined,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (club.description != null && club.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      club.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (club.locationDisplay != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 2),
                        Text(
                          club.locationDisplay!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (isPending)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Pending',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ElevatedButton(
                onPressed: onRequestJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(club.requireApproval ? 'Request' : 'Join'),
              ),
          ],
        ),
      ),
    );
  }
}
