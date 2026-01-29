import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/services/messaging_service.dart';
import 'package:shed/services/supabase_service.dart';

/// Reusable "Message Seller" button for listings.
/// Handles all edge cases: not logged in, own listing, missing seller, loading state.
class MessageSellerButton extends ConsumerStatefulWidget {
  const MessageSellerButton({
    super.key,
    required this.sellerId,
    this.sellerUsername,
    this.compact = false,
    this.showLabel = true,
  });

  /// The user ID of the seller/poster.
  final String? sellerId;
  
  /// Optional seller username for display purposes.
  final String? sellerUsername;
  
  /// If true, shows only an icon button. If false, shows full button with label.
  final bool compact;
  
  /// Whether to show the "Message" label (only applies when compact=false).
  final bool showLabel;

  @override
  ConsumerState<MessageSellerButton> createState() => _MessageSellerButtonState();
}

class _MessageSellerButtonState extends ConsumerState<MessageSellerButton> {
  bool _isLoading = false;

  Future<void> _onTap() async {
    // Check if seller ID is provided
    if (widget.sellerId == null || widget.sellerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller information unavailable'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Check if user is authenticated
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to message sellers')),
      );
      context.push('/auth');
      return;
    }

    // Check if trying to message self
    final currentUserId = ref.read(currentUserProvider)?.id;
    if (currentUserId == widget.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is your listing'),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final messagingService = ref.read(messagingServiceProvider);
      final threadId = await messagingService.getOrCreateDM(
        otherUserId: widget.sellerId!,
      );

      if (mounted) {
        context.push('/messages/$threadId');
      }
    } catch (e) {
      if (mounted) {
        String message = 'Unable to start conversation';
        if (e.toString().contains('Cannot message yourself')) {
          message = 'This is your listing';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isOwnListing = currentUserId != null && currentUserId == widget.sellerId;
    final isDisabled = widget.sellerId == null || isOwnListing;

    if (widget.compact) {
      return _CompactButton(
        isLoading: _isLoading,
        isDisabled: isDisabled,
        isOwnListing: isOwnListing,
        onTap: _onTap,
      );
    }

    return _FullButton(
      isLoading: _isLoading,
      isDisabled: isDisabled,
      isOwnListing: isOwnListing,
      showLabel: widget.showLabel,
      onTap: _onTap,
    );
  }
}

class _CompactButton extends StatefulWidget {
  const _CompactButton({
    required this.isLoading,
    required this.isDisabled,
    required this.isOwnListing,
    required this.onTap,
  });

  final bool isLoading;
  final bool isDisabled;
  final bool isOwnListing;
  final VoidCallback onTap;

  @override
  State<_CompactButton> createState() => _CompactButtonState();
}

class _CompactButtonState extends State<_CompactButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: Tooltip(
        message: widget.isOwnListing ? 'Your listing' : 'Message seller',
        child: GestureDetector(
          onTap: widget.isDisabled ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isDisabled
                  ? AppColors.surface
                  : (_isHovered ? AppColors.accent : AppColors.accent.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: widget.isDisabled
                  ? Border.all(color: AppColors.borderSubtle)
                  : (_isHovered ? null : Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
            ),
            child: widget.isLoading
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.accent),
                      ),
                    ),
                  )
                : Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: widget.isDisabled
                        ? AppColors.textTertiary
                        : (_isHovered ? Colors.white : AppColors.accent),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FullButton extends StatefulWidget {
  const _FullButton({
    required this.isLoading,
    required this.isDisabled,
    required this.isOwnListing,
    required this.showLabel,
    required this.onTap,
  });

  final bool isLoading;
  final bool isDisabled;
  final bool isOwnListing;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  State<_FullButton> createState() => _FullButtonState();
}

class _FullButtonState extends State<_FullButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: Tooltip(
        message: widget.isOwnListing ? 'Your listing' : 'Message seller',
        child: GestureDetector(
          onTap: widget.isDisabled ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: widget.showLabel ? AppSpacing.md : AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: widget.isDisabled
                  ? AppColors.surface
                  : (_isHovered ? AppColors.accent : AppColors.accent.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: widget.isDisabled
                  ? Border.all(color: AppColors.borderSubtle)
                  : (_isHovered ? null : Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        widget.isDisabled ? AppColors.textTertiary : AppColors.accent,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: widget.isDisabled
                        ? AppColors.textTertiary
                        : (_isHovered ? Colors.white : AppColors.accent),
                  ),
                if (widget.showLabel) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.isOwnListing ? 'Your listing' : 'Message',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isDisabled
                          ? AppColors.textTertiary
                          : (_isHovered ? Colors.white : AppColors.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small inline message button for listing cards.
class MessageSellerIconButton extends ConsumerStatefulWidget {
  const MessageSellerIconButton({
    super.key,
    required this.sellerId,
  });

  final String? sellerId;

  @override
  ConsumerState<MessageSellerIconButton> createState() => _MessageSellerIconButtonState();
}

class _MessageSellerIconButtonState extends ConsumerState<MessageSellerIconButton> {
  bool _isLoading = false;
  bool _isHovered = false;

  Future<void> _onTap() async {
    if (widget.sellerId == null) return;

    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to message sellers')),
      );
      context.push('/auth');
      return;
    }

    final currentUserId = ref.read(currentUserProvider)?.id;
    if (currentUserId == widget.sellerId) {
      // Silently ignore - it's their own listing
      return;
    }

    setState(() => _isLoading = true);

    try {
      final messagingService = ref.read(messagingServiceProvider);
      final threadId = await messagingService.getOrCreateDM(
        otherUserId: widget.sellerId!,
      );

      if (mounted) {
        context.push('/messages/$threadId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start conversation')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isOwnListing = currentUserId != null && currentUserId == widget.sellerId;

    // Don't show button for own listings
    if (isOwnListing || widget.sellerId == null) {
      return const SizedBox.shrink();
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isLoading ? null : _onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.accent
                : AppColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                )
              : Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 14,
                  color: _isHovered ? Colors.white : AppColors.accent,
                ),
        ),
      ),
    );
  }
}
