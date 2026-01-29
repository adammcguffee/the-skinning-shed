import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../services/clubs_service.dart';
import '../../services/stands_service.dart';
import '../../services/supabase_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// CLUB DETAIL SCREEN - PREMIUM
// ════════════════════════════════════════════════════════════════════════════

class ClubDetailScreen extends ConsumerStatefulWidget {
  const ClubDetailScreen({super.key, required this.clubId});
  
  final String clubId;

  @override
  ConsumerState<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends ConsumerState<ClubDetailScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  Timer? _standsRefreshTimer;
  DateTime? _lastRefresh;
  
  @override
  void dispose() {
    _standsRefreshTimer?.cancel();
    super.dispose();
  }
  
  void _onTabChanged(int index) {
    setState(() => _selectedTab = index);
    HapticFeedback.selectionClick();
    
    // Start/stop polling when on Stands tab
    if (index == 1) {
      _startStandsPolling();
    } else {
      _standsRefreshTimer?.cancel();
    }
  }
  
  void _startStandsPolling() {
    _standsRefreshTimer?.cancel();
    _lastRefresh = DateTime.now();
    _standsRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        ref.invalidate(clubStandsProvider(widget.clubId));
        ref.invalidate(myActiveSigninProvider(widget.clubId));
        setState(() => _lastRefresh = DateTime.now());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final clubAsync = ref.watch(clubProvider(widget.clubId));
    final membershipAsync = ref.watch(myClubMembershipProvider(widget.clubId));
    final membersAsync = ref.watch(clubMembersProvider(widget.clubId));
    
    return clubAsync.when(
      loading: () => const _LoadingShell(),
      error: (e, _) => _ErrorShell(onRetry: () => ref.invalidate(clubProvider(widget.clubId))),
      data: (club) {
        if (club == null) {
          return const _NotFoundShell();
        }
        
        final membership = membershipAsync.valueOrNull;
        final isAdmin = membership?.isAdmin ?? false;
        final memberCount = membersAsync.valueOrNull?.length ?? 0;
        
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Premium Header
                _PremiumHeader(
                  club: club,
                  memberCount: memberCount,
                  isAdmin: isAdmin,
                  onBack: () => context.pop(),
                ),
                
                // Premium Tab Bar
                _PremiumTabBar(
                  selectedIndex: _selectedTab,
                  onSelected: _onTabChanged,
                  tabs: const ['News', 'Stands', 'Members'],
                ),
                
                // Tab Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildTabContent(club, isAdmin),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildTabContent(Club club, bool isAdmin) {
    switch (_selectedTab) {
      case 0:
        return _PremiumNewsTab(
          key: const ValueKey('news'),
          clubId: widget.clubId,
          isAdmin: isAdmin,
        );
      case 1:
        return _PremiumStandsTab(
          key: const ValueKey('stands'),
          clubId: widget.clubId,
          club: club,
          isAdmin: isAdmin,
          lastRefresh: _lastRefresh,
          onRefresh: () {
            ref.invalidate(clubStandsProvider(widget.clubId));
            ref.invalidate(myActiveSigninProvider(widget.clubId));
            setState(() => _lastRefresh = DateTime.now());
          },
        );
      case 2:
        return _PremiumMembersTab(
          key: const ValueKey('members'),
          clubId: widget.clubId,
          isAdmin: isAdmin,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM HEADER
// ════════════════════════════════════════════════════════════════════════════

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
    required this.club,
    required this.memberCount,
    required this.isAdmin,
    required this.onBack,
  });
  
  final Club club;
  final int memberCount;
  final bool isAdmin;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 4),
          
          // Club avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          
          // Club info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$memberCount member${memberCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PrivacyBadge(isDiscoverable: club.isDiscoverable),
                  ],
                ),
              ],
            ),
          ),
          
          // Admin menu
          if (isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
              color: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                // Handle admin actions
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'invite',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_rounded, size: 18, color: AppColors.textSecondary),
                      SizedBox(width: 12),
                      Text('Invite Members'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, size: 18, color: AppColors.textSecondary),
                      SizedBox(width: 12),
                      Text('Club Settings'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.isDiscoverable});
  
  final bool isDiscoverable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDiscoverable 
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.textTertiary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDiscoverable ? Icons.public_rounded : Icons.lock_rounded,
            size: 10,
            color: isDiscoverable ? AppColors.success : AppColors.textTertiary,
          ),
          const SizedBox(width: 3),
          Text(
            isDiscoverable ? 'Public' : 'Private',
            style: TextStyle(
              color: isDiscoverable ? AppColors.success : AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM TAB BAR
// ════════════════════════════════════════════════════════════════════════════

class _PremiumTabBar extends StatelessWidget {
  const _PremiumTabBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.tabs,
  });
  
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = selectedIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tabs[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM STANDS TAB - THE LIVE BOARD
// ════════════════════════════════════════════════════════════════════════════

class _PremiumStandsTab extends ConsumerWidget {
  const _PremiumStandsTab({
    super.key,
    required this.clubId,
    required this.club,
    required this.isAdmin,
    required this.lastRefresh,
    required this.onRefresh,
  });
  
  final String clubId;
  final Club club;
  final bool isAdmin;
  final DateTime? lastRefresh;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standsAsync = ref.watch(clubStandsProvider(clubId));
    final mySigninAsync = ref.watch(myActiveSigninProvider(clubId));
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(clubStandsProvider(clubId));
        ref.invalidate(myActiveSigninProvider(clubId));
        onRefresh();
      },
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // My Hunt Card
          SliverToBoxAdapter(
            child: mySigninAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (signin) => _MyHuntCard(
                signin: signin,
                stands: standsAsync.valueOrNull ?? [],
                onSignOut: signin != null 
                    ? () => _showSignOutSheet(context, ref, signin)
                    : null,
              ),
            ),
          ),
          
          // Live Status Row
          SliverToBoxAdapter(
            child: _LiveStatusRow(
              lastRefresh: lastRefresh,
              standCount: standsAsync.valueOrNull?.length ?? 0,
              isAdmin: isAdmin,
              onAddStand: () => _showAddStandSheet(context, ref),
            ),
          ),
          
          // Stands List
          standsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: _PremiumLoader()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                message: 'Could not load stands',
                onRetry: () => ref.invalidate(clubStandsProvider(clubId)),
              ),
            ),
            data: (stands) {
              if (stands.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyStandsState(
                    isAdmin: isAdmin,
                    onAddStand: () => _showAddStandSheet(context, ref),
                  ),
                );
              }
              
              final mySignin = mySigninAsync.valueOrNull;
              
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: stands.length,
                  itemBuilder: (context, index) => _PremiumStandCard(
                    stand: stands[index],
                    isMySignin: mySignin?.standId == stands[index].id,
                    hasActiveSignin: mySignin != null,
                    ttlHours: club.settings.signInTtlHours,
                    isAdmin: isAdmin,
                    onSignIn: () => _showSignInSheet(context, ref, stands[index]),
                    onSignOut: mySignin != null 
                        ? () => _showSignOutSheet(context, ref, mySignin)
                        : null,
                    onDelete: () => _deleteStand(context, ref, stands[index]),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _showAddStandSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PremiumBottomSheet(
        title: 'Add Stand',
        icon: Icons.add_location_alt_rounded,
        child: Column(
          children: [
            _PremiumTextField(
              controller: controller,
              label: 'Stand Name',
              hint: 'e.g., North Tower, Stand 12',
              autofocus: true,
            ),
            const SizedBox(height: 24),
            _PremiumPrimaryButton(
              label: 'Add Stand',
              onPressed: () => Navigator.pop(context, controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    
    if (result != null && result.isNotEmpty && context.mounted) {
      HapticFeedback.mediumImpact();
      final service = ref.read(standsServiceProvider);
      final success = await service.createStand(clubId, result);
      if (success) {
        ref.invalidate(clubStandsProvider(clubId));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add stand')),
        );
      }
    }
  }
  
  Future<void> _showSignInSheet(BuildContext context, WidgetRef ref, ClubStand stand) async {
    final noteController = TextEditingController();
    
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PremiumBottomSheet(
        title: 'Sign In',
        subtitle: stand.name,
        icon: Icons.login_rounded,
        child: Column(
          children: [
            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your session will expire in ${club.settings.signInTtlHours} hours',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _PremiumTextField(
              controller: noteController,
              label: 'Note (optional)',
              hint: 'e.g., Bow hunting, arrived from south',
              maxLength: 80,
            ),
            const SizedBox(height: 24),
            _PremiumPrimaryButton(
              label: 'Confirm Sign In',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    
    if (result == true && context.mounted) {
      HapticFeedback.mediumImpact();
      final service = ref.read(standsServiceProvider);
      final signInResult = await service.signIn(
        clubId,
        stand.id,
        club.settings.signInTtlHours,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        standName: stand.name,
      );
      
      if (context.mounted) {
        if (signInResult.isSuccess) {
          ref.invalidate(clubStandsProvider(clubId));
          ref.invalidate(myActiveSigninProvider(clubId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed in to ${stand.name}'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (signInResult.isStandTaken) {
          ref.invalidate(clubStandsProvider(clubId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stand was just taken! Refreshing...'),
              backgroundColor: AppColors.warning,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(signInResult.error ?? 'Failed to sign in')),
          );
        }
      }
    }
  }
  
  Future<void> _showSignOutSheet(BuildContext context, WidgetRef ref, StandSignin signin) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PremiumBottomSheet(
        title: 'Sign Out',
        icon: Icons.logout_rounded,
        child: Column(
          children: [
            Text(
              'End your session at this stand?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _PremiumSecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PremiumPrimaryButton(
                    label: 'Sign Out',
                    isDestructive: true,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    
    if (result == true && context.mounted) {
      HapticFeedback.mediumImpact();
      final service = ref.read(standsServiceProvider);
      final success = await service.signOut(signin.id);
      if (success) {
        ref.invalidate(clubStandsProvider(clubId));
        ref.invalidate(myActiveSigninProvider(clubId));
      }
    }
  }
  
  Future<void> _deleteStand(BuildContext context, WidgetRef ref, ClubStand stand) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Stand?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete "${stand.name}" and all its history?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final service = ref.read(standsServiceProvider);
      await service.deleteStand(stand.id);
      ref.invalidate(clubStandsProvider(clubId));
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MY HUNT CARD - STICKY STATUS
// ════════════════════════════════════════════════════════════════════════════

class _MyHuntCard extends StatelessWidget {
  const _MyHuntCard({
    required this.signin,
    required this.stands,
    required this.onSignOut,
  });
  
  final StandSignin? signin;
  final List<ClubStand> stands;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    if (signin == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chair_alt_rounded,
                  color: AppColors.textTertiary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Not signed in',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Select a stand below to check in',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
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
    
    // Find stand name
    final stand = stands.where((s) => s.id == signin!.standId).firstOrNull;
    final standName = stand?.name ?? 'Unknown Stand';
    final signedInAgo = timeago.format(signin!.signedInAt);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.primary.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Active indicator
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_pin_circle_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Your Hunt',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    standName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Signed in $signedInAgo',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${signin!.timeRemainingFormatted} left',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Sign out button
            if (onSignOut != null)
              TextButton(
                onPressed: onSignOut,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('End'),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LIVE STATUS ROW
// ════════════════════════════════════════════════════════════════════════════

class _LiveStatusRow extends StatelessWidget {
  const _LiveStatusRow({
    required this.lastRefresh,
    required this.standCount,
    required this.isAdmin,
    required this.onAddStand,
  });
  
  final DateTime? lastRefresh;
  final int standCount;
  final bool isAdmin;
  final VoidCallback onAddStand;

  @override
  Widget build(BuildContext context) {
    final refreshText = lastRefresh != null
        ? 'Updated ${_formatRefreshTime(lastRefresh!)}'
        : 'Updating...';
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          Text(
            refreshText,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
          
          const Spacer(),
          
          // Stand count
          Text(
            '$standCount stand${standCount == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          
          // Admin add button
          if (isAdmin) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAddStand,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _formatRefreshTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM STAND CARD
// ════════════════════════════════════════════════════════════════════════════

class _PremiumStandCard extends StatelessWidget {
  const _PremiumStandCard({
    required this.stand,
    required this.isMySignin,
    required this.hasActiveSignin,
    required this.ttlHours,
    required this.isAdmin,
    required this.onSignIn,
    required this.onSignOut,
    required this.onDelete,
  });
  
  final ClubStand stand;
  final bool isMySignin;
  final bool hasActiveSignin;
  final int ttlHours;
  final bool isAdmin;
  final VoidCallback onSignIn;
  final VoidCallback? onSignOut;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final signin = stand.activeSignin;
    final isOccupied = stand.isOccupied;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMySignin
              ? AppColors.primary
              : isOccupied
                  ? AppColors.warning.withValues(alpha: 0.3)
                  : AppColors.success.withValues(alpha: 0.3),
          width: isMySignin ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status indicator
            _StatusIndicator(
              isOccupied: isOccupied,
              isMySignin: isMySignin,
              signin: signin,
            ),
            const SizedBox(width: 14),
            
            // Stand info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stand.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isOccupied && signin != null)
                    _OccupiedInfo(signin: signin, isMySignin: isMySignin)
                  else
                    const _AvailableInfo(),
                ],
              ),
            ),
            
            // Action
            _StandAction(
              isOccupied: isOccupied,
              isMySignin: isMySignin,
              hasActiveSignin: hasActiveSignin,
              isAdmin: isAdmin,
              onSignIn: onSignIn,
              onSignOut: onSignOut,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.isOccupied,
    required this.isMySignin,
    required this.signin,
  });
  
  final bool isOccupied;
  final bool isMySignin;
  final StandSignin? signin;

  @override
  Widget build(BuildContext context) {
    if (isOccupied && signin != null) {
      // Show avatar/initials
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isMySignin 
              ? AppColors.primary 
              : AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            signin!.userName.isNotEmpty 
                ? signin!.userName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: isMySignin ? Colors.white : AppColors.warning,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      );
    }
    
    // Available indicator
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Icon(
        Icons.chair_outlined,
        color: AppColors.success,
        size: 22,
      ),
    );
  }
}

class _OccupiedInfo extends StatelessWidget {
  const _OccupiedInfo({required this.signin, required this.isMySignin});
  
  final StandSignin signin;
  final bool isMySignin;

  @override
  Widget build(BuildContext context) {
    final signedInAgo = timeago.format(signin.signedInAt);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isMySignin ? 'You' : signin.userName,
              style: TextStyle(
                color: isMySignin ? AppColors.primary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMySignin 
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${signin.timeRemainingFormatted} left',
                style: TextStyle(
                  color: isMySignin ? AppColors.primary : AppColors.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Signed in $signedInAgo • ${signin.signedInAtFormatted}',
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
        if (signin.note != null && signin.note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '"${signin.note}"',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _AvailableInfo extends StatelessWidget {
  const _AvailableInfo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Available',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StandAction extends StatelessWidget {
  const _StandAction({
    required this.isOccupied,
    required this.isMySignin,
    required this.hasActiveSignin,
    required this.isAdmin,
    required this.onSignIn,
    required this.onSignOut,
    required this.onDelete,
  });
  
  final bool isOccupied;
  final bool isMySignin;
  final bool hasActiveSignin;
  final bool isAdmin;
  final VoidCallback onSignIn;
  final VoidCallback? onSignOut;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // My signin - Sign out
    if (isMySignin && onSignOut != null) {
      return ElevatedButton(
        onPressed: onSignOut,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error.withValues(alpha: 0.1),
          foregroundColor: AppColors.error,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)),
      );
    }
    
    // Available and no current signin - Sign in
    if (!isOccupied && !hasActiveSignin) {
      return ElevatedButton(
        onPressed: onSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w600)),
      );
    }
    
    // Available but signed in elsewhere
    if (!isOccupied && hasActiveSignin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'In use\nelsewhere',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
          ),
        ),
      );
    }
    
    // Occupied by someone else
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'In Use',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 20),
            padding: EdgeInsets.zero,
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (v) {
              if (v == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM MEMBERS TAB
// ════════════════════════════════════════════════════════════════════════════

class _PremiumMembersTab extends ConsumerStatefulWidget {
  const _PremiumMembersTab({
    super.key,
    required this.clubId,
    required this.isAdmin,
  });
  
  final String clubId;
  final bool isAdmin;

  @override
  ConsumerState<_PremiumMembersTab> createState() => _PremiumMembersTabState();
}

class _PremiumMembersTabState extends ConsumerState<_PremiumMembersTab> {
  String _searchQuery = '';
  
  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(clubMembersProvider(widget.clubId));
    final requestsAsync = widget.isAdmin 
        ? ref.watch(clubJoinRequestsProvider(widget.clubId))
        : null;
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(clubMembersProvider(widget.clubId));
        if (widget.isAdmin) {
          ref.invalidate(clubJoinRequestsProvider(widget.clubId));
        }
      },
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // Search + Invite row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // Search
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search members...',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                          prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  
                  // Invite button (admin)
                  if (widget.isAdmin) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _createInviteLink,
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Invite',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Join requests section (admin)
          if (widget.isAdmin && requestsAsync != null)
            requestsAsync.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (requests) {
                if (requests.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Join Requests',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${requests.length}',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...requests.map((req) => _PremiumRequestCard(
                          request: req,
                          onApprove: () => _approveRequest(req.id),
                          onReject: () => _rejectRequest(req.id),
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),
          
          // Members section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'Members',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          // Members list
          membersAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: _PremiumLoader()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                message: 'Could not load members',
                onRetry: () => ref.invalidate(clubMembersProvider(widget.clubId)),
              ),
            ),
            data: (members) {
              final filtered = _searchQuery.isEmpty
                  ? members
                  : members.where((m) => 
                      m.name.toLowerCase().contains(_searchQuery) ||
                      (m.username?.toLowerCase().contains(_searchQuery) ?? false)
                    ).toList();
              
              if (filtered.isEmpty) {
                if (_searchQuery.isNotEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          Text(
                            'No members match "$_searchQuery"',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverFillRemaining(
                  child: _EmptyMembersState(
                    isAdmin: widget.isAdmin,
                    onInvite: _createInviteLink,
                  ),
                );
              }
              
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _PremiumMemberCard(
                    member: filtered[index],
                    isAdmin: widget.isAdmin,
                    onPromote: filtered[index].role == 'member' 
                        ? () => _updateRole(filtered[index], 'admin')
                        : null,
                    onDemote: filtered[index].role == 'admin'
                        ? () => _updateRole(filtered[index], 'member')
                        : null,
                    onRemove: filtered[index].role != 'owner'
                        ? () => _removeMember(filtered[index])
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _createInviteLink() async {
    HapticFeedback.mediumImpact();
    final service = ref.read(clubsServiceProvider);
    final token = await service.createInviteLink(widget.clubId);
    
    if (token != null && mounted) {
      final url = 'https://www.theskinningshed.com/clubs/join/$token';
      
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _PremiumBottomSheet(
          title: 'Invite Link',
          icon: Icons.link_rounded,
          child: Column(
            children: [
              const Text(
                'Share this link to invite members',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(
                  url,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Expires in 7 days • Up to 5 uses',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _PremiumSecondaryButton(
                      label: 'Copy Link',
                      icon: Icons.copy_rounded,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied!')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PremiumPrimaryButton(
                      label: 'Done',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create invite')),
      );
    }
  }
  
  Future<void> _approveRequest(String requestId) async {
    HapticFeedback.mediumImpact();
    final service = ref.read(clubsServiceProvider);
    final success = await service.approveRequest(requestId);
    if (mounted) {
      ref.invalidate(clubJoinRequestsProvider(widget.clubId));
      ref.invalidate(clubMembersProvider(widget.clubId));
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request approved'), backgroundColor: AppColors.success),
        );
      }
    }
  }
  
  Future<void> _rejectRequest(String requestId) async {
    HapticFeedback.mediumImpact();
    final service = ref.read(clubsServiceProvider);
    await service.rejectRequest(requestId);
    if (mounted) {
      ref.invalidate(clubJoinRequestsProvider(widget.clubId));
    }
  }
  
  Future<void> _updateRole(ClubMember member, String newRole) async {
    final service = ref.read(clubsServiceProvider);
    final success = await service.updateMemberRole(widget.clubId, member.userId, newRole);
    if (mounted) {
      ref.invalidate(clubMembersProvider(widget.clubId));
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update role')),
        );
      }
    }
  }
  
  Future<void> _removeMember(ClubMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Remove ${member.name} from the club?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final service = ref.read(clubsServiceProvider);
      await service.removeMember(widget.clubId, member.userId);
      if (mounted) {
        ref.invalidate(clubMembersProvider(widget.clubId));
      }
    }
  }
}

class _PremiumRequestCard extends StatelessWidget {
  const _PremiumRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });
  
  final ClubJoinRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.warning.withValues(alpha: 0.15),
            child: Text(
              request.name.isNotEmpty ? request.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  'Requested ${timeago.format(request.createdAt)}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SmallButton(
                icon: Icons.close_rounded,
                color: AppColors.error,
                onTap: onReject,
              ),
              const SizedBox(width: 8),
              _SmallButton(
                icon: Icons.check_rounded,
                color: AppColors.success,
                onTap: onApprove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _PremiumMemberCard extends StatelessWidget {
  const _PremiumMemberCard({
    required this.member,
    required this.isAdmin,
    this.onPromote,
    this.onDemote,
    this.onRemove,
  });
  
  final ClubMember member;
  final bool isAdmin;
  final VoidCallback? onPromote;
  final VoidCallback? onDemote;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _getRoleColor(member.role).withValues(alpha: 0.15),
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: _getRoleColor(member.role),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (member.handle.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        member.handle,
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                _PremiumRoleBadge(role: member.role),
              ],
            ),
          ),
          if (isAdmin && member.role != 'owner')
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 20),
              color: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (v) {
                if (v == 'promote') onPromote?.call();
                if (v == 'demote') onDemote?.call();
                if (v == 'remove') onRemove?.call();
              },
              itemBuilder: (context) => [
                if (onPromote != null)
                  const PopupMenuItem(value: 'promote', child: Text('Make Admin')),
                if (onDemote != null)
                  const PopupMenuItem(value: 'demote', child: Text('Remove Admin')),
                if (onRemove != null)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove', style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
  
  Color _getRoleColor(String role) {
    return switch (role) {
      'owner' => AppColors.accent,
      'admin' => AppColors.warning,
      _ => AppColors.primary,
    };
  }
}

class _PremiumRoleBadge extends StatelessWidget {
  const _PremiumRoleBadge({required this.role});
  
  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'owner' => AppColors.accent,
      'admin' => AppColors.warning,
      _ => AppColors.textTertiary,
    };
    
    final icon = switch (role) {
      'owner' => Icons.workspace_premium_rounded,
      'admin' => Icons.shield_rounded,
      _ => Icons.person_rounded,
    };
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            role[0].toUpperCase() + role.substring(1),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM NEWS TAB
// ════════════════════════════════════════════════════════════════════════════

class _PremiumNewsTab extends ConsumerStatefulWidget {
  const _PremiumNewsTab({
    super.key,
    required this.clubId,
    required this.isAdmin,
  });
  
  final String clubId;
  final bool isAdmin;

  @override
  ConsumerState<_PremiumNewsTab> createState() => _PremiumNewsTabState();
}

class _PremiumNewsTabState extends ConsumerState<_PremiumNewsTab> {
  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(clubPostsProvider(widget.clubId));
    
    return Column(
      children: [
        // New post button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GestureDetector(
            onTap: _showPostComposer,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Share an update with the club...',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Posts list
        Expanded(
          child: postsAsync.when(
            loading: () => const Center(child: _PremiumLoader()),
            error: (e, _) => _ErrorState(
              message: 'Could not load posts',
              onRetry: () => ref.invalidate(clubPostsProvider(widget.clubId)),
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return _EmptyNewsState(onPost: _showPostComposer);
              }
              
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(clubPostsProvider(widget.clubId)),
                color: AppColors.primary,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => _PremiumPostCard(
                    post: posts[index],
                    isAdmin: widget.isAdmin,
                    onDelete: () => _deletePost(posts[index].id),
                    onTogglePin: () => _togglePin(posts[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Future<void> _showPostComposer() async {
    final controller = TextEditingController();
    
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PremiumBottomSheet(
        title: 'New Post',
        icon: Icons.campaign_rounded,
        child: Column(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                maxLines: null,
                maxLength: 500,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Share something with your club...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                  counterStyle: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _PremiumPrimaryButton(
              label: 'Post',
              icon: Icons.send_rounded,
              onPressed: () => Navigator.pop(context, controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    
    if (result != null && result.isNotEmpty && mounted) {
      HapticFeedback.mediumImpact();
      final service = ref.read(clubsServiceProvider);
      final success = await service.createPost(widget.clubId, result);
      if (success) {
        ref.invalidate(clubPostsProvider(widget.clubId));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post')),
        );
      }
    }
  }
  
  Future<void> _deletePost(String postId) async {
    final service = ref.read(clubsServiceProvider);
    await service.deletePost(postId);
    ref.invalidate(clubPostsProvider(widget.clubId));
  }
  
  Future<void> _togglePin(ClubPost post) async {
    final service = ref.read(clubsServiceProvider);
    await service.togglePinPost(post.id, !post.pinned);
    ref.invalidate(clubPostsProvider(widget.clubId));
  }
}

class _PremiumPostCard extends StatelessWidget {
  const _PremiumPostCard({
    required this.post,
    required this.isAdmin,
    required this.onDelete,
    required this.onTogglePin,
  });
  
  final ClubPost post;
  final bool isAdmin;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.instance.client?.auth.currentUser?.id;
    final isAuthor = post.authorId == currentUserId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: post.pinned ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
          width: post.pinned ? 1 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        timeago.format(post.createdAt),
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (post.pinned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded, size: 10, color: AppColors.accent),
                        SizedBox(width: 3),
                        Text('Pinned', style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                if (isAuthor || isAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
                    color: AppColors.surfaceElevated,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                      if (value == 'pin') onTogglePin();
                    },
                    itemBuilder: (context) => [
                      if (isAdmin)
                        PopupMenuItem(
                          value: 'pin',
                          child: Text(post.pinned ? 'Unpin' : 'Pin'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Content
            Text(
              post.content,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ════════════════════════════════════════════════════════════════════════════

class _PremiumBottomSheet extends StatelessWidget {
  const _PremiumBottomSheet({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });
  
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Header
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
              const SizedBox(height: 24),
              
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.autofocus = false,
    this.maxLength,
  });
  
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool autofocus;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            maxLength: maxLength,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
              counterStyle: const TextStyle(color: AppColors.textTertiary),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumPrimaryButton extends StatelessWidget {
  const _PremiumPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isDestructive = false,
  });
  
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PremiumSecondaryButton extends StatelessWidget {
  const _PremiumSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });
  
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PremiumLoader extends StatelessWidget {
  const _PremiumLoader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Loading...',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EMPTY & ERROR STATES
// ════════════════════════════════════════════════════════════════════════════

class _EmptyStandsState extends StatelessWidget {
  const _EmptyStandsState({required this.isAdmin, required this.onAddStand});
  
  final bool isAdmin;
  final VoidCallback onAddStand;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.chair_alt_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No stands yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAdmin 
                  ? 'Add stands for members to check into'
                  : 'Ask an admin to add stands',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              _PremiumPrimaryButton(
                label: 'Add First Stand',
                icon: Icons.add_rounded,
                onPressed: onAddStand,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyMembersState extends StatelessWidget {
  const _EmptyMembersState({required this.isAdmin, required this.onInvite});
  
  final bool isAdmin;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.group_add_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Invite your crew',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share an invite link to grow your club',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              _PremiumPrimaryButton(
                label: 'Create Invite Link',
                icon: Icons.link_rounded,
                onPressed: onInvite,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyNewsState extends StatelessWidget {
  const _EmptyNewsState({required this.onPost});
  
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No posts yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to share an update',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _PremiumPrimaryButton(
              label: 'Create First Post',
              icon: Icons.edit_rounded,
              onPressed: onPost,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHELL STATES (Loading, Error, NotFound)
// ════════════════════════════════════════════════════════════════════════════

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: _PremiumLoader()),
    );
  }
}

class _ErrorShell extends StatelessWidget {
  const _ErrorShell({required this.onRetry});
  
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: _ErrorState(
        message: 'Could not load club',
        onRetry: onRetry,
      ),
    );
  }
}

class _NotFoundShell extends StatelessWidget {
  const _NotFoundShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AppColors.textTertiary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Club not found',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
