import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/messaging_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/services/swap_shop_service.dart';
import 'package:shed/shared/widgets/widgets.dart';
import 'package:shed/utils/navigation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🛒 SWAP SHOP DETAIL SCREEN - 2025 PREMIUM
class SwapShopDetailScreen extends ConsumerStatefulWidget {
  const SwapShopDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<SwapShopDetailScreen> createState() =>
      _SwapShopDetailScreenState();
}

class _SwapShopDetailScreenState extends ConsumerState<SwapShopDetailScreen> {
  SwapShopListing? _listing;
  bool _isLoading = true;
  String? _error;
  int _currentPhotoIndex = 0;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  /// Check if current user owns this listing.
  bool get _isOwner {
    final currentUserId = ref.read(currentUserProvider)?.id;
    return currentUserId != null && _listing?.userId == currentUserId;
  }

  void _showOwnerMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
                title: const Text('Edit Listing'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/swap-shop/${widget.listingId}/edit');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Delete Listing', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(asAdmin: false);
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Admin badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Admin Actions', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Remove Listing (Admin)', style: TextStyle(color: AppColors.error)),
                subtitle: const Text('This will be logged for moderation audit', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(asAdmin: true);
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete({required bool asAdmin}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(asAdmin ? 'Remove Listing as Admin?' : 'Delete Listing?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              asAdmin
                  ? 'This will permanently remove this listing for moderation purposes. This action will be logged.'
                  : 'This will permanently delete this listing and all its photos. This action cannot be undone.',
            ),
            if (asAdmin) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Admin removal logged',
                        style: TextStyle(fontSize: 12, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(asAdmin ? 'Remove' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteListing(asAdmin: asAdmin);
    }
  }

  Future<void> _deleteListing({bool asAdmin = false}) async {
    setState(() => _isDeleting = true);
    
    try {
      final service = ref.read(swapShopServiceProvider);
      await service.deleteListing(widget.listingId, asAdmin: asAdmin);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(asAdmin ? 'Listing removed (admin)' : 'Listing deleted'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/swap-shop');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
  
  /// Determine what menu to show based on ownership and admin status.
  void _showContextMenu() {
    final isAdminAsync = ref.read(isAdminProvider);
    final isAdmin = isAdminAsync.valueOrNull ?? false;
    
    if (_isOwner) {
      _showOwnerMenu();
    } else if (isAdmin) {
      _showAdminMenu();
    }
    // Non-owners/non-admins don't see menu
  }

  Future<void> _loadListing() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(swapShopServiceProvider);
      final listing = await service.fetchListing(widget.listingId);

      if (listing == null) {
        setState(() {
          _error = 'Listing not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _listing = listing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _contactSeller() async {
    if (_listing == null) return;

    final contactMethod = _listing!.contactMethod;
    final contactValue = _listing!.contactValue;

    if (contactMethod == 'email') {
      final uri = Uri(
        scheme: 'mailto',
        path: contactValue,
        query: 'subject=Interested in: ${_listing!.title}',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showContactInfo(contactValue, 'Email');
      }
    } else if (contactMethod == 'phone') {
      final uri = Uri(scheme: 'tel', path: contactValue);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showContactInfo(contactValue, 'Phone');
      }
    } else {
      _showContactInfo(contactValue, 'Contact');
    }
  }

  Future<void> _messageSeller() async {
    if (_listing == null) return;
    
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send messages')),
      );
      context.push('/auth');
      return;
    }
    
    try {
      final messagingService = ref.read(messagingServiceProvider);
      final conversationId = await messagingService.getOrCreateDM(
        otherUserId: _listing!.userId,
        subjectType: 'swap',
        subjectId: _listing!.id,
        subjectTitle: _listing!.title,
      );
      
      if (mounted) {
        context.push('/messages/$conversationId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showContactInfo(String value, String label) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true, // Ensures modal sits above entire app shell
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            PageHeader(title: 'Loading...', subtitle: 'Swap Shop'),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null || _listing == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            PageHeader(title: 'Error', subtitle: 'Swap Shop'),
            Expanded(
              child: Center(
                child: AppErrorState(
                  message: _error ?? 'Listing not found',
                  onRetry: _loadListing,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final listing = _listing!;
    final service = ref.read(swapShopServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Photo carousel in app bar
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              // Home button
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () => goHome(context),
                tooltip: 'Home',
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.share_outlined, color: Colors.white),
                ),
                onPressed: () {
                  // Copy link to clipboard
                  final url = 'https://theskinningshed.com/swap-shop/${listing.id}';
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              // More menu (owner: edit/delete, admin: remove)
              Consumer(
                builder: (context, ref, child) {
                  final isAdminAsync = ref.watch(isAdminProvider);
                  final isAdmin = isAdminAsync.valueOrNull ?? false;
                  final showMenu = _isOwner || isAdmin;
                  
                  if (!showMenu) return const SizedBox.shrink();
                  
                  return IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(Icons.more_vert_rounded, color: Colors.white),
                    ),
                    onPressed: _showContextMenu,
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: listing.photos.isEmpty
                  ? Container(
                      color: AppColors.backgroundAlt,
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 64,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        PageView.builder(
                          itemCount: listing.photos.length,
                          onPageChanged: (i) =>
                              setState(() => _currentPhotoIndex = i),
                          itemBuilder: (context, index) {
                            return Image.network(
                              service.getPhotoUrl(listing.photos[index]),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.backgroundAlt,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            );
                          },
                        ),
                        if (listing.photos.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                listing.photos.length,
                                (index) => Container(
                                  width: index == _currentPhotoIndex ? 20 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: index == _currentPhotoIndex
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price and title
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price
                        if (listing.price != null)
                          Text(
                            '\$${listing.price!.toStringAsFixed(0)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        const SizedBox(height: AppSpacing.sm),

                        // Title
                        Text(
                          listing.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Location and category
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              listing.locationDisplay,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.textTertiary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              listing.category,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),

                        // Condition
                        if (listing.condition != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppChip(
                            label: listing.condition!,
                            size: AppChipSize.small,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Description
                  if (listing.description != null &&
                      listing.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding),
                      child: AppSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Description',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              listing.description!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Seller info with profile link
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding),
                    child: AppSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seller',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          GestureDetector(
                            onTap: () => context.push('/user/${listing.userId}'),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(AppSpacing.radiusMd),
                                  ),
                                  child: listing.sellerAvatarPath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusMd),
                                          child: Image.network(
                                            service
                                                .getPhotoUrl(listing.sellerAvatarPath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(
                                                (listing.sellerName ?? 'S')[0].toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            (listing.sellerName ?? 'S')[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        listing.sellerName ?? 'Seller',
                                        style:
                                            Theme.of(context).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Listed ${_formatDate(listing.createdAt)}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),

      // Contact button
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: AppSpacing.screenPadding,
          right: AppSpacing.screenPadding,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Price display
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (listing.price != null)
                    Text(
                      '\$${listing.price!.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  Text(
                    listing.title,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Message button
            AppButtonSecondary(
              label: 'Message',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: _messageSeller,
              size: AppButtonSize.medium,
            ),
            const SizedBox(width: AppSpacing.sm),

            // Contact button
            AppButtonPrimary(
              label: listing.contactMethod == 'email' ? 'Email' : 'Call',
              icon: listing.contactMethod == 'email'
                  ? Icons.email_outlined
                  : Icons.phone_outlined,
              onPressed: _contactSeller,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      final months = (diff.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
  }
}
