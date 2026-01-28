import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// Privacy Policy page - Production-ready legal content.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
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
                          'Overview',
                          'The Skinning Shed is a community platform for hunters and anglers. '
                          'We are committed to protecting your privacy and being transparent '
                          'about how we use your information.',
                        ),
                        _buildSection(
                          'Information We Collect',
                          '• Account Information: Email address, display name, and optional profile details (bio, home state/county, favorite species).\n\n'
                          '• User Content: Photos, trophy posts, swap shop listings, and land listings you create.\n\n'
                          '• Location Data: State and county selections only. We do not track GPS coordinates or precise location.\n\n'
                          '• Usage Data: Basic analytics to improve the app experience.',
                        ),
                        _buildSection(
                          'How We Use Your Information',
                          '• To provide and improve The Skinning Shed services\n'
                          '• To display your public profile and content to other users\n'
                          '• To enable features like weather by county and local listings\n'
                          '• To communicate important updates about the service',
                        ),
                        _buildSection(
                          'What We Don\'t Do',
                          '• We do not sell your personal information to third parties\n'
                          '• We do not track your precise GPS location\n'
                          '• We do not share your email with advertisers\n'
                          '• We do not use your photos for advertising without consent',
                        ),
                        _buildSection(
                          'Public vs. Private Content',
                          '• Trophy posts, swap shop listings, and land listings are public by default\n'
                          '• Your profile information (display name, bio) is visible to other users\n'
                          '• Your email address is never publicly displayed\n'
                          '• Direct messages are private between participants',
                        ),
                        _buildSection(
                          'Data Storage & Security',
                          'Your data is stored securely using industry-standard encryption. '
                          'Photos are stored in secure cloud storage. We use Supabase for authentication '
                          'and data management, which provides enterprise-grade security.',
                        ),
                        _buildSection(
                          'Your Rights',
                          '• You can edit or delete your profile information at any time\n'
                          '• You can delete your account and associated data\n'
                          '• You can request a copy of your data by contacting us',
                        ),
                        _buildSection(
                          'Third-Party Services',
                          '• Weather data: Open-Meteo API (no personal data shared)\n'
                          '• Official Links: Direct links to state wildlife agencies\n'
                          '• Authentication: Supabase Auth (secure, industry-standard)',
                        ),
                        _buildSection(
                          'Contact Us',
                          'If you have questions about this Privacy Policy or your data, '
                          'please contact us through the app\'s feedback feature or email '
                          'support@theskinningshed.com.',
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
