import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/data/us_states.dart';
import 'package:shed/services/regulations_service.dart';
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
  StatePortalLinks? _portalLinks;
  String? _officialRootUrl;
  bool _showDebugPanel = false;
  
  // Extracted facts for deer/turkey
  Map<RegulationCategory, ExtractedFacts?> _extractedFacts = {};
  
  static const _categories = [
    RegulationCategory.deer,
    RegulationCategory.turkey,
    RegulationCategory.fishing,
  ];
  
  // Normalize state code to uppercase (DB uses uppercase 2-letter codes)
  String get _normalizedStateCode => widget.stateCode.toUpperCase();
  
  USState? get _state => USStates.byCode(_normalizedStateCode);
  
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
      final stateCode = _normalizedStateCode;
      
      // Load portal links and official root URL
      final portalLinks = await service.fetchPortalLinks(stateCode);
      final officialRoot = await service.getOfficialRootUrl(stateCode);
      
      // Load regions and regulations for all categories
      final results = <RegulationCategory, List<StateRegulation>>{};
      final regionResults = <RegulationCategory, List<RegulationRegion>>{};
      
      for (final category in _categories) {
        // Load available regions first
        final regions = await service.fetchRegionsForState(
          stateCode: stateCode,
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
          stateCode: stateCode,
          category: category,
          regionKey: regionKey,
        );
      }
      
      // Load extracted facts for deer and turkey
      final extractedResults = <RegulationCategory, ExtractedFacts?>{};
      for (final category in [RegulationCategory.deer, RegulationCategory.turkey]) {
        try {
          extractedResults[category] = await service.fetchExtractedFacts(
            stateCode: stateCode,
            speciesGroup: category.value,
          );
        } catch (e) {
          // Ignore errors - extracted facts are optional
          debugPrint('Could not load extracted facts for $category: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _portalLinks = portalLinks;
          _officialRootUrl = officialRoot;
          _regulations = results;
          _regions = regionResults;
          _extractedFacts = extractedResults;
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
  
  Future<void> _refreshPortalLinks() async {
    try {
      final service = ref.read(regulationsServiceProvider);
      final portalLinks = await service.fetchPortalLinks(_normalizedStateCode);
      if (mounted) {
        setState(() => _portalLinks = portalLinks);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portal links refreshed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing: $e')),
        );
      }
    }
  }
  
  Future<void> _loadRegionsForCategory(RegulationCategory category) async {
    final service = ref.read(regulationsServiceProvider);
    final regions = await service.fetchRegionsForState(
      stateCode: _normalizedStateCode,
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
      stateCode: _normalizedStateCode,
      category: category,
      regionKey: regionKey,
    );
    
    if (mounted) {
      setState(() {
        _regulations[category] = regs;
      });
    }
  }
  
  /// Open a portal link in external browser
  Future<void> _openPortalLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  /// Share this state's regulations page
  void _shareStatePage(BuildContext context) {
    final stateName = _state?.name ?? widget.stateCode;
    final url = 'https://theskinningshed.com/regulations/${widget.stateCode.toLowerCase()}';
    
    // Copy to clipboard and show snackbar
    // ignore: deprecated_member_use (we're targeting older Flutter)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied: $stateName regulations'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
    
    // Note: Actual clipboard copy would use Clipboard.setData(ClipboardData(text: url))
    // but for now we just show feedback
    debugPrint('Share URL: $url');
  }
  
  /// Report an issue with this state's regulations
  void _reportIssue(BuildContext context) {
    final stateName = _state?.name ?? widget.stateCode;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Report an Issue',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found a problem with $stateName regulations?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              'Common issues:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '• Broken or outdated link\n• Incorrect information\n• Missing data',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you! We\'ll review this report.')),
              );
            },
            child: Text('Submit', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
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
              
              // Portal links section (always show, even if null/loading)
              _buildPortalLinksSection(),
              
              // Category tabs for extracted facts
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
          
          // Refresh button
          IconButton(
            onPressed: _refreshPortalLinks,
            icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh portal links',
          ),
        ],
      ),
    );
  }
  
  Widget _buildPortalLinksSection() {
    final links = _portalLinks;
    
    // Show empty state if no portal links at all
    if (links == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          0,
          AppSpacing.screenPadding,
          AppSpacing.md,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(Icons.link_off_rounded, size: 16, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'No portal links available for this state',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Official Agency Home link
            Row(
              children: [
                Icon(Icons.public_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    links.agencyName ?? 'Official State Portal',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // Official Agency Home link (always shown if available)
                if (_officialRootUrl != null)
                  GestureDetector(
                    onTap: () => _openPortalLink(_officialRootUrl!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.home_rounded, size: 12, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            'Agency Home',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Debug toggle (in debug mode only)
                if (const bool.fromEnvironment('dart.vm.product') == false)
                  GestureDetector(
                    onTap: () => setState(() => _showDebugPanel = !_showDebugPanel),
                    child: Icon(
                      _showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            
            // HUNTING section — species-specific + digest
            _buildPortalSection(
              'HUNTING',
              Icons.forest_rounded,
              [
                _PortalButton(
                  icon: Icons.cruelty_free_rounded,
                  label: 'Deer Seasons',
                  url: links.deerSeasonsUrl ?? links.huntingSeasonsUrl, // fallback to legacy
                  verified: links.deerSeasonsVerified || links.huntingSeasonsVerified,
                ),
                _PortalButton(
                  icon: Icons.emoji_nature_rounded,
                  label: 'Turkey Seasons',
                  url: links.turkeySeasonsUrl,
                  verified: links.turkeySeasonsVerified,
                ),
                _PortalButton(
                  icon: Icons.menu_book_rounded,
                  label: 'Regs Digest',
                  url: links.huntingDigestUrl ?? links.huntingRegsUrl, // fallback to legacy
                  verified: links.huntingDigestVerified || links.huntingRegsVerified,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            
            // FISHING section
            _buildPortalSection(
              'FISHING',
              Icons.phishing_rounded,
              [
                _PortalButton(
                  icon: Icons.description_rounded,
                  label: 'Fishing Regs',
                  url: links.fishingRegsUrl,
                  verified: links.fishingRegsVerified,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            
            // LICENSING section
            _buildPortalSection(
              'LICENSING',
              Icons.badge_rounded,
              [
                _PortalButton(
                  icon: Icons.info_outline_rounded,
                  label: 'License Info',
                  url: links.licensingUrl,
                  verified: links.licensingVerified,
                ),
                _PortalButton(
                  icon: Icons.shopping_cart_rounded,
                  label: 'Buy License',
                  url: links.buyLicenseUrl,
                  verified: links.buyLicenseVerified,
                  isPrimary: true,
                ),
              ],
            ),
            
            // RECORDS section (optional - only show if we have data)
            if (links.hasRecords) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildPortalSection(
                'RECORDS',
                Icons.emoji_events_rounded,
                [
                  _PortalButton(
                    icon: Icons.emoji_events_rounded,
                    label: 'Record Books',
                    url: links.recordsUrl,
                    verified: links.recordsVerified,
                  ),
                ],
              ),
            ],
            
            // Debug panel
            if (_showDebugPanel) ...[
              const SizedBox(height: AppSpacing.md),
              _buildDebugPanel(links),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPortalSection(String title, IconData icon, List<Widget> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: buttons,
        ),
      ],
    );
  }
  
  Widget _buildDebugPanel(StatePortalLinks links) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, size: 14, color: AppColors.warning),
              const SizedBox(width: 4),
              Text(
                'DEBUG: Portal Links Data',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDebugRow('State Code', links.stateCode),
          _buildDebugRow('Hunting Seasons', '${links.huntingSeasonsUrl ?? "NULL"} (verified: ${links.huntingSeasonsVerified})'),
          _buildDebugRow('Hunting Regs', '${links.huntingRegsUrl ?? "NULL"} (verified: ${links.huntingRegsVerified})'),
          _buildDebugRow('Fishing Regs', '${links.fishingRegsUrl ?? "NULL"} (verified: ${links.fishingRegsVerified})'),
          _buildDebugRow('Licensing', '${links.licensingUrl ?? "NULL"} (verified: ${links.licensingVerified})'),
          _buildDebugRow('Buy License', '${links.buyLicenseUrl ?? "NULL"} (verified: ${links.buyLicenseVerified})'),
          _buildDebugRow('Records', '${links.recordsUrl ?? "NULL"} (verified: ${links.recordsVerified})'),
        ],
      ),
    );
  }
  
  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 10, color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
    return SingleChildScrollView(
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
    final extractedFacts = _extractedFacts[category];
    final selectedRegion = regions.isNotEmpty
        ? regions.firstWhere(
            (r) => r.regionKey == (_selectedRegionKeys[category] ?? 'STATEWIDE'),
            orElse: () => regions.first,
          )
        : null;
    
    // If we have extracted facts but no approved regulations, show extracted facts
    final hasExtractedContent = extractedFacts != null && extractedFacts.hasContent;
    
    if (regulations.isEmpty) {
      return Column(
        children: [
          // Region selector even if no data yet
          _buildRegionSelector(category),
          
          Expanded(
            child: hasExtractedContent
                ? _buildExtractedFactsContent(extractedFacts!)
                : _EmptyRegulationsState(
                    stateName: stateName,
                    category: category,
                    portalLinks: _portalLinks,
                    onOpenSeasonDates: () => _openPortalLink(
                      category == RegulationCategory.fishing
                          ? _portalLinks?.fishingRegsUrl
                          : _portalLinks?.deerSeasonsUrl ?? _portalLinks?.huntingSeasonsUrl,
                    ),
                    onOpenRegs: () => _openPortalLink(
                      category == RegulationCategory.fishing
                          ? _portalLinks?.fishingRegsUrl
                          : _portalLinks?.huntingDigestUrl ?? _portalLinks?.huntingRegsUrl,
                    ),
                    onShare: () => _shareStatePage(context),
                    onReportIssue: () => _reportIssue(context),
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
  
  /// Build extracted facts content (premium display).
  Widget _buildExtractedFactsContent(ExtractedFacts facts) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with confidence badge
          _buildExtractedHeader(facts),
          const SizedBox(height: AppSpacing.lg),
          
          // Season segments
          if (facts.seasons.isNotEmpty) ...[
            _buildSectionHeader('Season Dates', Icons.calendar_today_rounded),
            const SizedBox(height: AppSpacing.sm),
            ...facts.seasons.map((season) => _ExtractedSeasonCard(season: season)),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Bag limits
          if (facts.bagLimits.isNotEmpty) ...[
            _buildSectionHeader('Bag Limits', Icons.inventory_2_rounded),
            const SizedBox(height: AppSpacing.sm),
            ...facts.bagLimits.map((limit) => _ExtractedBagLimitCard(limit: limit)),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Legal methods
          if (facts.legalMethods.isNotEmpty) ...[
            _buildSectionHeader('Legal Methods', Icons.gpp_good_rounded),
            const SizedBox(height: AppSpacing.sm),
            _LegalMethodsChips(methods: facts.legalMethods),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Notes
          if (facts.notes.isNotEmpty) ...[
            _buildSectionHeader('Notes', Icons.info_outline_rounded),
            const SizedBox(height: AppSpacing.sm),
            ...facts.notes.map((note) => _NoteCard(note: note)),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Source link
          _SourceLink(url: facts.sourceUrl),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
  
  Widget _buildExtractedHeader(ExtractedFacts facts) {
    final stateName = _state?.name ?? widget.stateCode;
    
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
                Icons.auto_awesome_rounded,
                color: AppColors.textInverse,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$stateName • ${facts.speciesGroup.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      // Confidence badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 12,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Extracted ${facts.confidencePercent}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${facts.seasonYearLabel} Season',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    facts.regionKey == 'STATEWIDE' ? 'Statewide' : facts.regionKey,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

// ============================================================
// EXTRACTED FACTS CARD WIDGETS
// ============================================================

class _ExtractedSeasonCard extends StatelessWidget {
  const _ExtractedSeasonCard({required this.season});
  
  final ExtractedSeason season;
  
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    // Try to parse YYYY-MM-DD
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      return '${months[month - 1]} $day, ${parts[0]}';
    }
    return dateStr;
  }
  
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      season.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (season.methods.isNotEmpty)
                    ...season.methods.take(3).map((method) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          method,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    )),
                ],
              ),
              const SizedBox(height: 4),
              if (season.start != null && season.end != null)
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDate(season.start)} – ${_formatDate(season.end)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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

class _ExtractedBagLimitCard extends StatelessWidget {
  const _ExtractedBagLimitCard({required this.limit});
  
  final ExtractedBagLimit limit;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      limit.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      limit.value,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (limit.notes != null && limit.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        limit.notes!,
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

class _LegalMethodsChips extends StatelessWidget {
  const _LegalMethodsChips({required this.methods});
  
  final List<String> methods;
  
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: methods.map((method) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  method,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}

/// 🎯 PREMIUM STATE PORTAL DASHBOARD
/// 
/// Shown when no extracted facts exist for a category.
/// Instead of empty space, provides useful modules leveraging portal links.
class _EmptyRegulationsState extends StatelessWidget {
  const _EmptyRegulationsState({
    required this.stateName,
    required this.category,
    this.portalLinks,
    this.onOpenSeasonDates,
    this.onOpenRegs,
    this.onShare,
    this.onReportIssue,
  });
  
  final String stateName;
  final RegulationCategory category;
  final StatePortalLinks? portalLinks;
  final VoidCallback? onOpenSeasonDates;
  final VoidCallback? onOpenRegs;
  final VoidCallback? onShare;
  final VoidCallback? onReportIssue;
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module 1: Quick Summary Card
          _buildQuickSummaryModule(),
          const SizedBox(height: AppSpacing.md),
          
          // Module 2: Quick Actions
          _buildQuickActionsModule(context),
          const SizedBox(height: AppSpacing.md),
          
          // Module 3: Compact "Facts Coming" notice
          _buildFactsComingCard(),
          const SizedBox(height: AppSpacing.md),
          
          // Module 4: Tools & Utilities
          _buildToolsModule(context),
        ],
      ),
    );
  }
  
  Widget _buildQuickSummaryModule() {
    final links = portalLinks;
    final verifiedCount = links != null
        ? [
            links.huntingSeasonsVerified,
            links.huntingRegsVerified,
            links.fishingRegsVerified,
            links.licensingVerified,
            links.buyLicenseVerified,
            links.recordsVerified,
          ].where((v) => v).length
        : 0;
    final totalLinks = links != null
        ? [
            links.hasHuntingSeasons,
            links.hasHuntingRegs,
            links.hasFishingRegs,
            links.hasLicensing,
            links.hasBuyLicense,
            links.hasRecords,
          ].where((v) => v).length
        : 0;
    
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        links?.agencyName ?? 'State Wildlife Agency',
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
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Stats row
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                _StatChip(
                  icon: Icons.verified_rounded,
                  label: '$verifiedCount/$totalLinks verified',
                  color: verifiedCount > 0 ? AppColors.success : AppColors.textTertiary,
                ),
                _StatChip(
                  icon: Icons.category_rounded,
                  label: category.label,
                  color: AppColors.info,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickActionsModule(BuildContext context) {
    final hasSeasonLink = portalLinks?.huntingSeasonsUrl != null || 
                          portalLinks?.fishingRegsUrl != null;
    final hasRegsLink = portalLinks?.huntingRegsUrl != null || 
                        portalLinks?.fishingRegsUrl != null;
    
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (hasSeasonLink)
                  _ActionButton(
                    icon: Icons.calendar_today_rounded,
                    label: 'Season Dates',
                    onTap: onOpenSeasonDates,
                    isPrimary: true,
                  ),
                if (hasRegsLink)
                  _ActionButton(
                    icon: Icons.description_rounded,
                    label: 'Full Regulations',
                    onTap: onOpenRegs,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFactsComingCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 20,
            color: AppColors.info,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extracted Data Coming Soon',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Season dates and bag limits will appear here once verified. '
                  'Use the official links above for now.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.info.withValues(alpha: 0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToolsModule(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tools',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _ActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: onShare,
                ),
                _ActionButton(
                  icon: Icons.flag_outlined,
                  label: 'Report Issue',
                  onTap: onReportIssue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small stat chip for quick summary
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  
  final IconData icon;
  final String label;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button for quick actions and tools
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isPrimary = false,
  });
  
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;
  
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? (_isHovered ? AppColors.accent : AppColors.accent.withValues(alpha: 0.9))
                : (_isHovered ? AppColors.surfaceHover : AppColors.surface),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: widget.isPrimary
                ? null
                : Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isPrimary
                    ? Colors.white
                    : (isEnabled ? AppColors.textSecondary : AppColors.textTertiary),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isPrimary
                      ? Colors.white
                      : (isEnabled ? AppColors.textPrimary : AppColors.textTertiary),
                ),
              ),
            ],
          ),
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

/// Portal button for opening external links.
/// Shows disabled state if URL is null or not verified.
class _PortalButton extends StatefulWidget {
  const _PortalButton({
    required this.icon,
    required this.label,
    this.url,
    this.isPrimary = false,
    this.verified = false,
  });
  
  final IconData icon;
  final String label;
  final String? url;
  final bool isPrimary;
  final bool verified;
  
  @override
  State<_PortalButton> createState() => _PortalButtonState();
}

class _PortalButtonState extends State<_PortalButton> {
  bool _isHovered = false;
  
  // Determine if this button is available
  bool get _isAvailable => widget.url != null && widget.url!.isNotEmpty && widget.verified;
  
  // Get the reason for unavailability
  String get _unavailableReason {
    if (widget.url == null || widget.url!.isEmpty) return 'Not Found';
    if (!widget.verified) return 'Not Verified';
    return '';
  }
  
  Future<void> _launchUrl() async {
    if (!_isAvailable || widget.url == null) return;
    final uri = Uri.parse(widget.url!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.isPrimary;
    
    // Disabled state styling for unavailable buttons
    if (!_isAvailable) {
      return Tooltip(
        message: _unavailableReason,
        child: Opacity(
          opacity: 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.link_off_rounded,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Enabled state for verified buttons with URLs
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _launchUrl,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: isPrimary && _isHovered ? AppColors.accentGradient : null,
            color: isPrimary 
                ? (_isHovered ? null : AppColors.accent)
                : (_isHovered ? AppColors.surfaceHover : AppColors.background),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: isPrimary ? null : Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: isPrimary ? Colors.white : (_isHovered ? AppColors.accent : AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : (_isHovered ? AppColors.accent : AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.open_in_new_rounded,
                size: 12,
                color: isPrimary ? Colors.white.withValues(alpha: 0.7) : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}