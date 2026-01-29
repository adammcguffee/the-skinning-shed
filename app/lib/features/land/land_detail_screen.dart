import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/land_listing_service.dart';
import 'package:shed/services/messaging_service.dart';
import 'package:shed/services/supabase_service.dart';
import 'package:shed/shared/widgets/widgets.dart';
import 'package:shed/utils/navigation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🏞️ LAND DETAIL SCREEN - 2025 PREMIUM
class LandDetailScreen extends ConsumerStatefulWidget {
  const LandDetailScreen({super.key, required this.landId});

  final String landId;

  @override
  ConsumerState<LandDetailScreen> createState() => _LandDetailScreenState();
}

class _LandDetailScreenState extends ConsumerState<LandDetailScreen> {
  LandListing? _listing;
  bool _isLoading = true;
  String? _error;
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  Future<void> _loadListing() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(landListingServiceProvider);
      final listing = await service.fetchListing(widget.landId);

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

  Future<void> _contactOwner() async {
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

  Future<void> _messageOwner() async {
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
        subjectType: 'land',
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
            PageHeader(title: 'Loading...', subtitle: 'Land Listing'),
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
            PageHeader(title: 'Error', subtitle: 'Land Listing'),
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
    final service = ref.read(landListingServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Image header
          SliverAppBar(
            expandedHeight: 300,
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
                  final url = 'https://theskinningshed.com/land/${listing.id}';
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
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
                          Icons.landscape_outlined,
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
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type and price badges
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.textTertiary,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Text(
                                listing.type == 'lease' ? 'FOR LEASE' : 'FOR SALE',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                              ),
                              child: Text(
                                listing.priceDisplay,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.textInverse,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Title
                        Text(
                          listing.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Location
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
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Quick stats grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          if (listing.acreage != null)
                            Expanded(
                              child: _AttributeItem(
                                icon: Icons.straighten_outlined,
                                label: 'Acreage',
                                value: '${listing.acreage!.toStringAsFixed(0)} acres',
                              ),
                            ),
                          if (listing.pricePerAcre != null) ...[
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.borderSubtle,
                            ),
                            Expanded(
                              child: _AttributeItem(
                                icon: Icons.attach_money_rounded,
                                label: 'Per Acre',
                                value: '\$${listing.pricePerAcre!.toStringAsFixed(0)}',
                              ),
                            ),
                          ],
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.borderSubtle,
                          ),
                          Expanded(
                            child: _AttributeItem(
                              icon: Icons.calendar_today_outlined,
                              label: 'Listed',
                              value: _formatDateShort(listing.createdAt),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Game available
                  if (listing.speciesTags != null && listing.speciesTags!.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Game Available',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: listing.speciesTags!
                                .map((tag) => AppChip(label: tag))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                  if (listing.speciesTags != null && listing.speciesTags!.isNotEmpty)
                    const SizedBox(height: AppSpacing.xxl),

                  // Description
                  if (listing.description != null && listing.description!.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
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

                  // Owner section with profile link
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding),
                    child: AppSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Property Owner',
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
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(AppSpacing.radiusMd),
                                  ),
                                  child: listing.ownerAvatarPath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusMd),
                                          child: Image.network(
                                            service.getPhotoUrl(listing.ownerAvatarPath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(
                                                (listing.ownerName ?? 'O')[0].toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            (listing.ownerName ?? 'O')[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.success,
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
                                        listing.ownerName ?? 'Property Owner',
                                        style: Theme.of(context).textTheme.titleSmall,
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
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.priceDisplay,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (listing.acreage != null)
                    Text(
                      '${listing.acreage!.toStringAsFixed(0)} acres',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            
            // Message button
            AppButtonSecondary(
              label: 'Message',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: _messageOwner,
              size: AppButtonSize.medium,
            ),
            const SizedBox(width: AppSpacing.sm),
            
            AppButtonPrimary(
              label: listing.contactMethod == 'email' ? 'Email' : 'Call',
              icon: listing.contactMethod == 'email'
                  ? Icons.email_outlined
                  : Icons.phone_outlined,
              onPressed: _contactOwner,
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

  String _formatDateShort(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      final months = (diff.inDays / 30).floor();
      return '${months}mo ago';
    }
  }
}

class _AttributeItem extends StatelessWidget {
  const _AttributeItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.success,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
