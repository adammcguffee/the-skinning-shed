import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// Content Disclaimer page - Important disclaimers for legal safety.
class ContentDisclaimerPage extends StatelessWidget {
  const ContentDisclaimerPage({super.key});

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
              title: 'Content Disclaimer',
              subtitle: 'Important notices',
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
                        _buildWarningCard(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildSection(
                          'Official Links & Regulations',
                          'The Official Links feature provides direct links to state wildlife agency websites. '
                          'We do not summarize, interpret, or provide advice about hunting and fishing regulations.\n\n'
                          '• Links go directly to official state agency portals\n'
                          '• Regulations may change at any time\n'
                          '• Always verify current regulations before hunting or fishing\n'
                          '• We are not affiliated with any state wildlife agency\n'
                          '• We do not provide legal or regulatory advice',
                        ),
                        _buildSection(
                          'User-Generated Content',
                          'Trophy posts, swap shop listings, land listings, and other user content are '
                          'created by community members, not by The Skinning Shed.\n\n'
                          '• We do not verify the accuracy of user posts\n'
                          '• We do not endorse any user content\n'
                          '• Users are responsible for their own content\n'
                          '• Report suspicious or inappropriate content',
                        ),
                        _buildSection(
                          'Marketplace Transactions',
                          'The Swap Shop is a platform for connecting buyers and sellers. '
                          'The Skinning Shed is not a party to any transaction.\n\n'
                          '• We do not verify item condition or authenticity\n'
                          '• We do not guarantee delivery or payment\n'
                          '• We are not responsible for disputes between users\n'
                          '• All transactions are at your own risk\n'
                          '• Firearms transactions must comply with all applicable laws',
                        ),
                        _buildSection(
                          'Land Listings',
                          'Land listings are provided by users for informational purposes.\n\n'
                          '• We do not verify property ownership\n'
                          '• We do not verify listing accuracy\n'
                          '• We are not a licensed real estate broker\n'
                          '• Conduct your own due diligence before any transaction',
                        ),
                        _buildSection(
                          'Weather & Tools',
                          'Weather data is provided by third-party services for informational purposes.\n\n'
                          '• Weather forecasts are estimates, not guarantees\n'
                          '• Always check official weather sources for critical decisions\n'
                          '• Solunar data is for reference only\n'
                          '• Use your own judgment when planning outdoor activities',
                        ),
                        _buildSection(
                          'No Professional Advice',
                          'Nothing in The Skinning Shed constitutes professional advice.\n\n'
                          '• We do not provide legal advice\n'
                          '• We do not provide regulatory advice\n'
                          '• We do not provide real estate advice\n'
                          '• Consult appropriate professionals for specific guidance',
                        ),
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

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Notice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'The Skinning Shed is a community platform. We do not provide legal, '
                  'regulatory, or professional advice. Always verify information from '
                  'official sources before taking action.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
