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

/// Club detail screen with tabs: News, Stands, Members, Settings
class ClubDetailScreen extends ConsumerStatefulWidget {
  const ClubDetailScreen({super.key, required this.clubId});
  
  final String clubId;

  @override
  ConsumerState<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends ConsumerState<ClubDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _standsRefreshTimer;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }
  
  @override
  void dispose() {
    _standsRefreshTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
  
  void _onTabChanged() {
    // Start/stop polling when on Stands tab
    if (_tabController.index == 1) {
      _startStandsPolling();
    } else {
      _standsRefreshTimer?.cancel();
    }
  }
  
  void _startStandsPolling() {
    _standsRefreshTimer?.cancel();
    _standsRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        ref.invalidate(clubStandsProvider(widget.clubId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final clubAsync = ref.watch(clubProvider(widget.clubId));
    final membershipAsync = ref.watch(myClubMembershipProvider(widget.clubId));
    
    return clubAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Error loading club',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (club) {
        if (club == null) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(
              child: Text('Club not found', style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        
        final membership = membershipAsync.valueOrNull;
        final isAdmin = membership?.isAdmin ?? false;
        
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              club.name,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                const Tab(text: 'News'),
                const Tab(text: 'Stands'),
                const Tab(text: 'Members'),
                if (isAdmin) const Tab(text: 'Settings'),
              ].take(isAdmin ? 4 : 3).toList(),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _NewsTab(clubId: widget.clubId, isAdmin: isAdmin),
              _StandsTab(clubId: widget.clubId, club: club, isAdmin: isAdmin),
              _MembersTab(clubId: widget.clubId, isAdmin: isAdmin),
              if (isAdmin) _SettingsTab(club: club),
            ].take(isAdmin ? 4 : 3).toList(),
          ),
        );
      },
    );
  }
}

// =====================
// NEWS TAB
// =====================
class _NewsTab extends ConsumerStatefulWidget {
  const _NewsTab({required this.clubId, required this.isAdmin});
  
  final String clubId;
  final bool isAdmin;

  @override
  ConsumerState<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends ConsumerState<_NewsTab> {
  final _postController = TextEditingController();
  bool _isPosting = false;
  
  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }
  
  Future<void> _createPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;
    
    setState(() => _isPosting = true);
    
    final service = ref.read(clubsServiceProvider);
    final success = await service.createPost(widget.clubId, content);
    
    if (mounted) {
      setState(() => _isPosting = false);
      if (success) {
        _postController.clear();
        ref.invalidate(clubPostsProvider(widget.clubId));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(clubPostsProvider(widget.clubId));
    
    return Column(
      children: [
        // New post input
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _postController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Share an update with the club...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: _isPosting ? null : _createPost,
                icon: _isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: AppColors.primary),
              ),
            ],
          ),
        ),
        
        // Posts list
        Expanded(
          child: postsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error loading posts', style: TextStyle(color: AppColors.error)),
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined, size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No posts yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Be the first to share an update!',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }
              
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(clubPostsProvider(widget.clubId));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => _PostCard(
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
  
  Future<void> _deletePost(String postId) async {
    final service = ref.read(clubsServiceProvider);
    final success = await service.deletePost(postId);
    if (success) {
      ref.invalidate(clubPostsProvider(widget.clubId));
    }
  }
  
  Future<void> _togglePin(ClubPost post) async {
    final service = ref.read(clubsServiceProvider);
    final success = await service.togglePinPost(post.id, !post.pinned);
    if (success) {
      ref.invalidate(clubPostsProvider(widget.clubId));
    }
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
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
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: post.pinned ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      timeago.format(post.createdAt),
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.pinned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin_rounded, size: 12, color: AppColors.primary),
                      SizedBox(width: 2),
                      Text(
                        'Pinned',
                        style: TextStyle(color: AppColors.primary, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              if (isAuthor || isAdmin)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            post.content,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// =====================
// STANDS TAB
// =====================
class _StandsTab extends ConsumerStatefulWidget {
  const _StandsTab({
    required this.clubId,
    required this.club,
    required this.isAdmin,
  });
  
  final String clubId;
  final Club club;
  final bool isAdmin;

  @override
  ConsumerState<_StandsTab> createState() => _StandsTabState();
}

class _StandsTabState extends ConsumerState<_StandsTab> {
  @override
  Widget build(BuildContext context) {
    final standsAsync = ref.watch(clubStandsProvider(widget.clubId));
    final mySigninAsync = ref.watch(myActiveSigninProvider(widget.clubId));
    
    return Column(
      children: [
        // My status bar
        mySigninAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (signin) {
            if (signin == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                border: const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_circle_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You\'re signed in',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Expires in ${signin.timeRemainingFormatted}',
                          style: TextStyle(
                            color: AppColors.primary.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _signOut(signin.id),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );
          },
        ),
        
        // Admin actions
        if (widget.isAdmin)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAddStandDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Stand'),
                  ),
                ),
              ],
            ),
          ),
        
        // Stands list
        Expanded(
          child: standsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error loading stands', style: TextStyle(color: AppColors.error)),
            ),
            data: (stands) {
              if (stands.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chair_outlined, size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: AppSpacing.sm),
                      Text('No stands yet', style: TextStyle(color: AppColors.textSecondary)),
                      if (widget.isAdmin) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _showAddStandDialog,
                          child: const Text('Add your first stand'),
                        ),
                      ],
                    ],
                  ),
                );
              }
              
              final mySignin = mySigninAsync.valueOrNull;
              
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(clubStandsProvider(widget.clubId));
                  ref.invalidate(myActiveSigninProvider(widget.clubId));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: stands.length,
                  itemBuilder: (context, index) => _StandCard(
                    stand: stands[index],
                    ttlHours: widget.club.settings.signInTtlHours,
                    myActiveSigninStandId: mySignin?.standId,
                    onSignIn: () => _signIn(stands[index]),
                    onSignOut: mySignin != null ? () => _signOut(mySignin.id) : null,
                    isAdmin: widget.isAdmin,
                    onDelete: () => _deleteStand(stands[index].id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Future<void> _showAddStandDialog() async {
    final nameController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Add Stand', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Stand Name',
            hintText: 'e.g., Stand 1, North Tower',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      final service = ref.read(standsServiceProvider);
      final success = await service.createStand(widget.clubId, result);
      if (success && mounted) {
        ref.invalidate(clubStandsProvider(widget.clubId));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add stand (name may already exist)')),
        );
      }
    }
  }
  
  Future<void> _signIn(ClubStand stand) async {
    final noteController = TextEditingController();
    
    final shouldSignIn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          'Sign in to ${stand.name}',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your sign-in will expire in ${widget.club.settings.signInTtlHours} hours.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: noteController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g., Bow, coming from south',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
    
    if (shouldSignIn == true) {
      final service = ref.read(standsServiceProvider);
      final result = await service.signIn(
        widget.clubId,
        stand.id,
        widget.club.settings.signInTtlHours,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        standName: stand.name,
      );
      
      if (mounted) {
        if (result.isSuccess) {
          ref.invalidate(clubStandsProvider(widget.clubId));
          ref.invalidate(myActiveSigninProvider(widget.clubId));
        } else if (result.isStandTaken) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stand was just taken by someone else!')),
          );
          ref.invalidate(clubStandsProvider(widget.clubId));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Failed to sign in')),
          );
        }
      }
    }
  }
  
  Future<void> _signOut(String signinId) async {
    final service = ref.read(standsServiceProvider);
    final success = await service.signOut(signinId);
    if (mounted) {
      ref.invalidate(clubStandsProvider(widget.clubId));
      ref.invalidate(myActiveSigninProvider(widget.clubId));
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign out')),
        );
      }
    }
  }
  
  Future<void> _deleteStand(String standId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Delete Stand?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will remove the stand and all its sign-in history.',
          style: TextStyle(color: AppColors.textSecondary),
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
      await service.deleteStand(standId);
      if (mounted) {
        ref.invalidate(clubStandsProvider(widget.clubId));
      }
    }
  }
}

class _StandCard extends StatelessWidget {
  const _StandCard({
    required this.stand,
    required this.ttlHours,
    required this.myActiveSigninStandId,
    required this.onSignIn,
    required this.onSignOut,
    required this.isAdmin,
    required this.onDelete,
  });
  
  final ClubStand stand;
  final int ttlHours;
  final String? myActiveSigninStandId;
  final VoidCallback onSignIn;
  final VoidCallback? onSignOut;
  final bool isAdmin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final signin = stand.activeSignin;
    final isOccupied = stand.isOccupied;
    final isMySignin = myActiveSigninStandId == stand.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMySignin
              ? AppColors.primary
              : isOccupied
                  ? AppColors.error.withValues(alpha: 0.3)
                  : AppColors.success.withValues(alpha: 0.3),
          width: isMySignin ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOccupied
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOccupied ? Icons.person_rounded : Icons.chair_outlined,
              color: isOccupied ? AppColors.error : AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          
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
                  ),
                ),
                const SizedBox(height: 2),
                if (isOccupied && signin != null) ...[
                  Row(
                    children: [
                      Text(
                        signin.userName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMySignin 
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${signin.timeRemainingFormatted} left',
                          style: TextStyle(
                            color: isMySignin ? AppColors.primary : AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Signed in at ${signin.signedInAtFormatted}',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  if (signin.note != null && signin.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '"${signin.note}"',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ] else
                  Row(
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
                      Text(
                        'Available',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Action buttons
          if (isMySignin && onSignOut != null)
            // My signin - show Sign Out
            ElevatedButton(
              onPressed: onSignOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withValues(alpha: 0.1),
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 0,
              ),
              child: const Text('Sign Out'),
            )
          else if (!isOccupied && myActiveSigninStandId == null)
            // Available and I have no signin - allow sign in
            ElevatedButton(
              onPressed: onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Sign In'),
            )
          else if (!isOccupied && myActiveSigninStandId != null)
            // Available but I'm signed in elsewhere - show disabled
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Signed in\nelsewhere',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            )
          else if (isOccupied && !isMySignin)
            // Occupied by someone else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'In Use',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: AppColors.textTertiary),
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Stand', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
              ],
            )
          else if (isAdmin)
            // Admin menu for empty stands
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: AppColors.textTertiary),
              onSelected: (v) {
                if (v == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Stand', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// =====================
// MEMBERS TAB
// =====================
class _MembersTab extends ConsumerStatefulWidget {
  const _MembersTab({required this.clubId, required this.isAdmin});
  
  final String clubId;
  final bool isAdmin;

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
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
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Invite button (admin only)
          if (widget.isAdmin) ...[
            OutlinedButton.icon(
              onPressed: _createInviteLink,
              icon: const Icon(Icons.link_rounded),
              label: const Text('Create Invite Link'),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Pending requests (admin only)
          if (widget.isAdmin && requestsAsync != null)
            requestsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (requests) {
                if (requests.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join Requests (${requests.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...requests.map((req) => _RequestCard(
                      request: req,
                      onApprove: () => _approveRequest(req.id),
                      onReject: () => _rejectRequest(req.id),
                    )),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                );
              },
            ),
          
          // Members list
          Text(
            'Members',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error', style: TextStyle(color: AppColors.error)),
            data: (members) {
              if (members.isEmpty) {
                return const Text('No members', style: TextStyle(color: AppColors.textSecondary));
              }
              
              return Column(
                children: members.map((m) => _MemberCard(
                  member: m,
                  isAdmin: widget.isAdmin,
                  onPromote: m.role == 'member' ? () => _updateRole(m, 'admin') : null,
                  onDemote: m.role == 'admin' ? () => _updateRole(m, 'member') : null,
                  onRemove: m.role != 'owner' ? () => _removeMember(m) : null,
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _createInviteLink() async {
    final service = ref.read(clubsServiceProvider);
    final token = await service.createInviteLink(widget.clubId);
    
    if (token != null && mounted) {
      final url = 'https://www.theskinningshed.com/clubs/join/$token';
      
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: const Text('Invite Link Created', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share this link with others to invite them:',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  url,
                  style: const TextStyle(color: AppColors.primary, fontSize: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Expires in 7 days • Up to 5 uses',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied!')),
                );
              },
              child: const Text('Copy Link'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create invite')),
      );
    }
  }
  
  Future<void> _approveRequest(String requestId) async {
    final service = ref.read(clubsServiceProvider);
    final success = await service.approveRequest(requestId);
    if (mounted) {
      ref.invalidate(clubJoinRequestsProvider(widget.clubId));
      ref.invalidate(clubMembersProvider(widget.clubId));
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to approve')),
        );
      }
    }
  }
  
  Future<void> _rejectRequest(String requestId) async {
    final service = ref.read(clubsServiceProvider);
    final success = await service.rejectRequest(requestId);
    if (mounted) {
      ref.invalidate(clubJoinRequestsProvider(widget.clubId));
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reject')),
        );
      }
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
        title: const Text('Remove Member?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Remove ${member.name} from the club?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final service = ref.read(clubsServiceProvider);
      final success = await service.removeMember(widget.clubId, member.userId);
      if (mounted) {
        ref.invalidate(clubMembersProvider(widget.clubId));
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove member')),
          );
        }
      }
    }
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.warning.withValues(alpha: 0.2),
            child: Text(
              request.name.isNotEmpty ? request.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Requested ${timeago.format(request.createdAt)}',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onReject,
            icon: const Icon(Icons.close_rounded, color: AppColors.error),
            tooltip: 'Reject',
          ),
          IconButton(
            onPressed: onApprove,
            icon: const Icon(Icons.check_rounded, color: AppColors.success),
            tooltip: 'Approve',
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (member.handle.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        member.handle,
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                _RoleBadge(role: member.role),
              ],
            ),
          ),
          if (isAdmin && member.role != 'owner')
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: AppColors.textTertiary),
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
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  
  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'owner' => AppColors.primary,
      'admin' => AppColors.warning,
      _ => AppColors.textTertiary,
    };
    
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// =====================
// SETTINGS TAB
// =====================
class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({required this.club});
  
  final Club club;

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  late bool _isDiscoverable;
  late bool _requireApproval;
  late int _signInTtlHours;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _isDiscoverable = widget.club.isDiscoverable;
    _requireApproval = widget.club.requireApproval;
    _signInTtlHours = widget.club.settings.signInTtlHours;
  }
  
  Future<void> _save() async {
    setState(() => _isSaving = true);
    
    final service = ref.read(clubsServiceProvider);
    final success = await service.updateClub(
      widget.club.id,
      isDiscoverable: _isDiscoverable,
      requireApproval: _requireApproval,
      settings: ClubSettings(signInTtlHours: _signInTtlHours),
    );
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ref.invalidate(clubProvider(widget.club.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Visibility settings
        Text(
          'Visibility',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: _isDiscoverable,
                onChanged: (v) => setState(() => _isDiscoverable = v),
                title: const Text('Discoverable', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Allow others to find this club', style: TextStyle(fontSize: 12)),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              if (_isDiscoverable) ...[
                const Divider(height: 1),
                SwitchListTile(
                  value: _requireApproval,
                  onChanged: (v) => setState(() => _requireApproval = v),
                  title: const Text('Require Approval', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Admins must approve join requests', style: TextStyle(fontSize: 12)),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: AppSpacing.lg),
        
        // Stand settings
        Text(
          'Stand Sign-In',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-Expire', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Sign-ins expire after...', style: TextStyle(fontSize: 12)),
            trailing: DropdownButton<int>(
              value: _signInTtlHours,
              dropdownColor: AppColors.surfaceElevated,
              items: [2, 4, 6, 8, 12, 24].map((h) {
                return DropdownMenuItem(value: h, child: Text('${h}h'));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _signInTtlHours = v);
              },
            ),
          ),
        ),
        
        const SizedBox(height: AppSpacing.xl),
        
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Settings'),
        ),
      ],
    );
  }
}
