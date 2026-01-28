import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// Terms of Service page - Production-ready legal content.
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

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
              title: 'Terms of Service',
              subtitle: 'Rules for using The Skinning Shed',
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
                        _buildLastUpdated(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildSection(
                          'Agreement',
                          'By using The Skinning Shed, you agree to these Terms of Service. '
                          'If you do not agree, please do not use the app.',
                        ),
                        _buildSection(
                          'User Accounts',
                          '• You must be at least 13 years old to use The Skinning Shed\n'
                          '• You are responsible for maintaining the security of your account\n'
                          '• You are responsible for all activity under your account\n'
                          '• One account per person; do not share login credentials',
                        ),
                        _buildSection(
                          'User-Generated Content',
                          '• You retain ownership of content you post (photos, text, listings)\n'
                          '• By posting, you grant us a license to display your content on the platform\n'
                          '• You are solely responsible for the accuracy and legality of your content\n'
                          '• We may remove content that violates these terms',
                        ),
                        _buildSection(
                          'Prohibited Content',
                          'You may not post content that:\n\n'
                          '• Violates wildlife laws or promotes illegal hunting/fishing\n'
                          '• Contains graphic violence, gore, or animal cruelty\n'
                          '• Harasses, threatens, or bullies other users\n'
                          '• Is fraudulent, misleading, or deceptive\n'
                          '• Infringes on others\' intellectual property rights\n'
                          '• Contains malware, spam, or unauthorized advertising',
                        ),
                        _buildSection(
                          'Swap Shop Marketplace',
                          '• The Skinning Shed is a platform for connecting buyers and sellers\n'
                          '• We are not a party to any transaction between users\n'
                          '• We do not verify listings or guarantee items\n'
                          '• Buyers and sellers are responsible for complying with all applicable laws\n'
                          '• Use caution when meeting strangers for transactions\n'
                          '• Firearms transactions must comply with federal, state, and local laws',
                        ),
                        _buildSection(
                          'Land Listings',
                          '• Land listings are for informational purposes\n'
                          '• We do not verify property ownership or listing accuracy\n'
                          '• Users must conduct their own due diligence\n'
                          '• We are not a licensed real estate broker',
                        ),
                        _buildSection(
                          'Account Termination',
                          'We reserve the right to suspend or terminate accounts that:\n\n'
                          '• Violate these Terms of Service\n'
                          '• Post prohibited content repeatedly\n'
                          '• Engage in fraudulent activity\n'
                          '• Harass other users\n\n'
                          'You may delete your account at any time through Settings.',
                        ),
                        _buildSection(
                          'Limitation of Liability',
                          'The Skinning Shed is provided "as is" without warranties. '
                          'We are not liable for any damages arising from your use of the app, '
                          'including but not limited to user-generated content, marketplace transactions, '
                          'or reliance on information provided through the platform.',
                        ),
                        _buildSection(
                          'Changes to Terms',
                          'We may update these Terms of Service from time to time. '
                          'Continued use of the app after changes constitutes acceptance '
                          'of the updated terms.',
                        ),
                        _buildSection(
                          'Contact',
                          'Questions about these Terms? Contact us at support@theskinningshed.com.',
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

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.update_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Last updated: January 2026',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
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
