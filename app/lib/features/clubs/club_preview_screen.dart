import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../services/clubs_service.dart';

/// Club Preview Screen - Shows club info to non-members before joining
class ClubPreviewScreen extends ConsumerStatefulWidget {
  const ClubPreviewScreen({super.key, required this.clubId});
  
  final String clubId;

  @override
  ConsumerState<ClubPreviewScreen> createState() => _ClubPreviewScreenState();
}

class _ClubPreviewScreenState extends ConsumerState<ClubPreviewScreen> {
  bool _isRequesting = false;
  bool _hasRequested = false;
  
  @override
  Widget build(BuildContext context) {
    final clubAsync = ref.watch(clubProvider(widget.clubId));
    final membershipAsync = ref.watch(myClubMembershipProvider(widget.clubId));
    
    return clubAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textPrimary,
            onPressed: () => _goBack(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textPrimary,
            onPressed: () => _goBack(context),
          ),
        ),
        body: const Center(child: Text('Club not found')),
      ),
      data: (club) {
        if (club == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.textPrimary,
                onPressed: () => _goBack(context),
              ),
            ),
            body: const Center(child: Text('Club not found')),
          );
        }
        
        // If user is already a member, redirect to club detail
        final membership = membershipAsync.valueOrNull;
        if (membership != null && membership.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/clubs/${widget.clubId}');
          });
          return const SizedBox.shrink();
        }
        
        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                backgroundColor: AppColors.surface,
                pinned: true,
                expandedHeight: 200,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.textPrimary,
                  onPressed: () => _goBack(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.3),
                          AppColors.surface,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Content
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Club name
                    Text(
                      club.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // Privacy badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: club.isDiscoverable 
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.textTertiary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                club.isDiscoverable ? Icons.public_rounded : Icons.lock_rounded,
                                size: 14,
                                color: club.isDiscoverable ? AppColors.success : AppColors.textTertiary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                club.isDiscoverable ? 'Public Club' : 'Private Club',
                                style: TextStyle(
                                  color: club.isDiscoverable ? AppColors.success : AppColors.textTertiary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Stats row
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            icon: Icons.group_rounded,
                            value: '${club.memberCount ?? 0}',
                            label: 'Members',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.border,
                          ),
                          _StatItem(
                            icon: Icons.location_on_rounded,
                            value: club.stateCode ?? 'N/A',
                            label: 'State',
                          ),
                          if (club.county != null) ...[
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.border,
                            ),
                            _StatItem(
                              icon: Icons.map_rounded,
                              value: club.county!,
                              label: 'County',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Description
                    if (club.description != null && club.description!.isNotEmpty) ...[
                      const Text(
                        'About',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Text(
                          club.description!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Join section
                    if (club.isDiscoverable) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _hasRequested ? Icons.check_circle_rounded : Icons.waving_hand_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _hasRequested 
                                  ? 'Request Sent!'
                                  : 'Want to Join?',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _hasRequested
                                  ? 'Your request has been sent to the club admins. You\'ll be notified when they respond.'
                                  : club.requireApproval
                                      ? 'Send a request to join. Admins will review and approve your request.'
                                      : 'Request to join this club and start connecting with other hunters.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (!_hasRequested) ...[
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isRequesting ? null : () => _requestToJoin(club),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isRequesting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Request to Join',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      // Private club - invite only
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              color: AppColors.textTertiary,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Invite Only',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This is a private club. You need an invite link from a club member to join.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => _showInviteCodeDialog(),
                              icon: const Icon(Icons.link_rounded, size: 18),
                              label: const Text('Enter Invite Code'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _goBack(BuildContext context) {
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/clubs');
    }
  }
  
  Future<void> _requestToJoin(Club club) async {
    setState(() => _isRequesting = true);
    HapticFeedback.mediumImpact();
    
    final service = ref.read(clubsServiceProvider);
    final success = await service.requestToJoin(club.id);
    
    if (mounted) {
      if (success) {
        setState(() {
          _isRequesting = false;
          _hasRequested = true;
        });
        HapticFeedback.mediumImpact();
      } else {
        setState(() => _isRequesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send request. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  
  Future<void> _showInviteCodeDialog() async {
    final controller = TextEditingController();
    
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Enter Invite Code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Paste invite code or link',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    
    if (code != null && code.isNotEmpty && mounted) {
      // Extract token from URL or use as-is
      String token = code;
      if (code.contains('/clubs/join/')) {
        final parts = code.split('/clubs/join/');
        if (parts.length > 1) {
          token = parts.last.split('?').first.split('/').first;
        }
      }
      
      context.push('/clubs/join/$token');
    }
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });
  
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
