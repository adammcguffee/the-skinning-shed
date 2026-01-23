import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/widgets.dart';

/// Trophy Wall - user's profile showing their trophies.
class TrophyWallScreen extends StatelessWidget {
  const TrophyWallScreen({
    super.key,
    this.userId,
  });

  /// User ID to display. Null = current user.
  final String? userId;

  bool get _isCurrentUser => userId == null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCurrentUser ? 'My Trophy Wall' : 'Trophy Wall'),
        actions: [
          if (_isCurrentUser)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.go('/settings'),
            ),
        ],
      ),
      body: ListView(
        children: [
          // Profile header
          _ProfileHeader(isCurrentUser: _isCurrentUser),
          
          // Stats summary
          _StatsSummary(),
          
          const Divider(height: 32),
          
          // Season tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Text(
              '2025-26 Season',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Trophy list placeholder
          _buildPlaceholderTrophy(
            context,
            species: 'Deer',
            icon: '🦌',
            date: 'Jan 15, 2026',
            location: 'Texas • Travis County',
          ),
          _buildPlaceholderTrophy(
            context,
            species: 'Turkey',
            icon: '🦃',
            date: 'Jan 12, 2026',
            location: 'Alabama • Jefferson County',
          ),
          
          // Empty state for no more trophies
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(
              child: Text(
                'Start posting trophies to build your Trophy Wall!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isCurrentUser
          ? PremiumFAB(
              icon: Icons.add,
              label: 'Post Trophy',
              isExtended: true,
              onPressed: () => context.push('/post'),
            )
          : null,
    );
  }

  Widget _buildPlaceholderTrophy(
    BuildContext context, {
    required String species,
    required String icon,
    required String date,
    required String location,
  }) {
    return PremiumCard(
      placeholder: Container(
        color: AppColors.surfaceAlt,
        child: Center(
          child: Text(icon, style: const TextStyle(fontSize: 48)),
        ),
      ),
      aspectRatio: 16 / 9,
      title: '$icon $species',
      subtitle: location,
      metadata: StatsStrip(
        items: [
          StatsStripItem(label: date, icon: Icons.calendar_today),
        ],
      ),
      onTap: () {
        // TODO: Navigate to trophy detail
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.isCurrentUser});
  
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primaryContainer.withOpacity(0.2),
            child: const Icon(
              Icons.person,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? 'Your Name' : 'User Name',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Member since Jan 2026',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          // Edit button for current user
          if (isCurrentUser)
            OutlinedButton(
              onPressed: () {
                // TODO: Edit profile
              },
              child: const Text('Edit'),
            ),
        ],
      ),
    );
  }
}

class _StatsSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Row(
        children: [
          _StatItem(label: 'Trophies', value: '5'),
          const SizedBox(width: AppSpacing.lg),
          _StatItem(label: 'Deer', value: '2'),
          const SizedBox(width: AppSpacing.lg),
          _StatItem(label: 'Turkey', value: '2'),
          const SizedBox(width: AppSpacing.lg),
          _StatItem(label: 'Bass', value: '1'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
