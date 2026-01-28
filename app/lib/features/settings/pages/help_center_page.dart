import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// Help Center page - User-friendly help content.
class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            const PageHeader(
              title: 'Help Center',
              subtitle: 'Learn how to use The Skinning Shed',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HelpTopic(
                          icon: Icons.info_outline_rounded,
                          title: 'What is The Skinning Shed?',
                          content: 'The Skinning Shed is a community platform for hunters and anglers. '
                              'Share your trophies, connect with fellow outdoorsmen, browse gear in the '
                              'Swap Shop, find land listings, and access official state wildlife portals.',
                        ),
                        _HelpTopic(
                          icon: Icons.link_rounded,
                          title: 'How Official Links Work',
                          content: 'Official Links provides direct access to state wildlife agency websites. '
                              'Simply tap on any state tile to open that state\'s official portal in your browser.\n\n'
                              'Important: We link directly to official sources. We do not summarize or interpret regulations. '
                              'Always verify current rules before hunting or fishing.',
                        ),
                        _HelpTopic(
                          icon: Icons.emoji_events_outlined,
                          title: 'Posting Trophies',
                          content: 'Share your hunting and fishing successes with the community:\n\n'
                              '1. Tap the + button and select "Post a Trophy"\n'
                              '2. Upload a photo of your harvest\n'
                              '3. Select the species, add details like weight or score\n'
                              '4. Choose the state and county where it was harvested\n'
                              '5. Add an optional story or caption\n'
                              '6. Submit and share with the community!\n\n'
                              'Your trophies appear on your Trophy Wall profile.',
                        ),
                        _HelpTopic(
                          icon: Icons.storefront_outlined,
                          title: 'Swap Shop Rules',
                          content: 'Buy, sell, and trade hunting and fishing gear:\n\n'
                              '• Be honest and accurate in your listings\n'
                              '• Upload clear photos of actual items\n'
                              '• Price items fairly\n'
                              '• Respond promptly to inquiries\n'
                              '• Meet in safe, public locations for transactions\n'
                              '• Firearms must comply with all applicable laws\n\n'
                              'The Skinning Shed is a platform only. We do not verify listings or guarantee transactions.',
                        ),
                        _HelpTopic(
                          icon: Icons.landscape_outlined,
                          title: 'Land Listings',
                          content: 'Find hunting and fishing land for lease or sale:\n\n'
                              '• Browse listings by location, size, and features\n'
                              '• Contact landowners directly through the app\n'
                              '• Always conduct your own due diligence\n'
                              '• We do not verify property ownership or listing accuracy',
                        ),
                        _HelpTopic(
                          icon: Icons.cloud_outlined,
                          title: 'Weather & Tools',
                          content: 'Get weather forecasts and hunting tools by county:\n\n'
                              '• Select your state and county to see local weather\n'
                              '• View hourly and daily forecasts\n'
                              '• Check wind speed, direction, and gusts\n'
                              '• View solunar data for best hunting/fishing times\n'
                              '• Save favorite locations for quick access',
                        ),
                        _HelpTopic(
                          icon: Icons.flag_outlined,
                          title: 'Reporting Issues',
                          content: 'Help keep The Skinning Shed a great community:\n\n'
                              '• Use the Report feature on any content that violates our Terms\n'
                              '• Report suspicious listings, inappropriate content, or harassment\n'
                              '• Provide details to help us investigate\n'
                              '• We review all reports and take appropriate action',
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _buildContactCard(context),
                        const SizedBox(height: AppSpacing.xxxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Need More Help?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Can\'t find what you\'re looking for? Send us feedback or report a problem.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButtonSecondary(
                  label: 'Send Feedback',
                  icon: Icons.feedback_outlined,
                  onPressed: () => context.push('/settings/feedback'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HelpTopic extends StatefulWidget {
  const _HelpTopic({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  State<_HelpTopic> createState() => _HelpTopicState();
}

class _HelpTopicState extends State<_HelpTopic> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            // Header (always visible)
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Icon(
                        widget.icon,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content (expandable)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardPadding,
                  0,
                  AppSpacing.cardPadding,
                  AppSpacing.cardPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.content,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}
