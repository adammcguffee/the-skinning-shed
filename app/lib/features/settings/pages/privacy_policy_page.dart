import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// Privacy Policy page - Production-ready legal content.
/// Last updated: January 2026
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
                          '1. Overview',
                          'The Skinning Shed ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, share, and protect your personal information when you use our mobile application and web service (collectively, the "Service").\n\n'
                          'By using the Service, you consent to the practices described in this Privacy Policy.',
                        ),
                        
                        _buildSection(
                          '2. Information We Collect',
                          'We collect information in several ways:',
                        ),
                        
                        _buildSubSection(
                          'Account Information',
                          '• Email address (for authentication only)\n'
                          '• Username (public, chosen by you)\n'
                          '• Display name (optional, public)\n'
                          '• Profile bio (optional, public)\n'
                          '• Avatar/profile photo (optional, public)',
                        ),
                        
                        _buildSubSection(
                          'Profile Preferences',
                          '• Home state and county (optional)\n'
                          '• Favorite hunting/fishing species\n'
                          '• Notification preferences',
                        ),
                        
                        _buildSubSection(
                          'User Content',
                          '• Trophy posts including photos, descriptions, species, and harvest details\n'
                          '• Swap Shop listings and photos\n'
                          '• Land listings\n'
                          '• Club posts, photos, and stand activity\n'
                          '• Comments and interactions\n'
                          '• Direct messages',
                        ),
                        
                        _buildSubSection(
                          'Location Data',
                          '• State and county selections only\n'
                          '• We do NOT collect precise GPS coordinates\n'
                          '• We do NOT track your real-time location\n'
                          '• Weather features use coarse county-level location only',
                        ),
                        
                        _buildSubSection(
                          'Technical Information',
                          '• Device type and operating system\n'
                          '• App version\n'
                          '• Basic usage analytics (pages viewed, features used)\n'
                          '• Error logs for debugging\n'
                          '• Push notification tokens (if notifications enabled)',
                        ),
                        
                        _buildSection(
                          '3. How We Use Your Information',
                          '• To provide and maintain the Service\n'
                          '• To display your public profile and content to other users\n'
                          '• To enable features like weather by county and local listings\n'
                          '• To personalize your feed and recommendations\n'
                          '• To facilitate communication between users\n'
                          '• To send important service updates and notifications\n'
                          '• To detect and prevent fraud, abuse, and violations\n'
                          '• To respond to support requests\n'
                          '• To improve and develop new features\n'
                          '• To comply with legal obligations',
                        ),
                        
                        _buildSection(
                          '4. What We Do NOT Do',
                          '• We do NOT sell your personal information to third parties\n'
                          '• We do NOT share your email address with advertisers\n'
                          '• We do NOT track your precise GPS location\n'
                          '• We do NOT use your photos for advertising without consent\n'
                          '• We do NOT read your private messages except when investigating reports\n'
                          '• We do NOT share your data with data brokers',
                        ),
                        
                        _buildSection(
                          '5. Information Sharing',
                          'We share information in limited circumstances:',
                        ),
                        
                        _buildSubSection(
                          'With Other Users',
                          '• Your public profile (username, display name, avatar, bio)\n'
                          '• Your public posts, listings, and comments\n'
                          '• Club content is shared only with club members\n'
                          '• Direct messages are shared only with conversation participants',
                        ),
                        
                        _buildSubSection(
                          'With Service Providers',
                          '• Supabase (database and authentication)\n'
                          '• Vercel (web hosting)\n'
                          '• Open-Meteo (weather data—no personal data shared)\n'
                          '• Firebase (push notifications)\n'
                          '• Analytics providers (aggregated, non-identifying data only)',
                        ),
                        
                        _buildSubSection(
                          'For Legal Purposes',
                          '• To comply with legal obligations or court orders\n'
                          '• To protect our rights and safety\n'
                          '• To prevent fraud or illegal activity\n'
                          '• To cooperate with law enforcement when required',
                        ),
                        
                        _buildSection(
                          '6. Public vs. Private Content',
                          'Understanding what is visible to others:',
                        ),
                        
                        _buildBulletList([
                          'Trophy posts, Swap Shop listings, and Land listings are PUBLIC by default',
                          'Your profile information (username, display name, bio, avatar) is PUBLIC',
                          'Your email address is NEVER publicly displayed',
                          'Direct messages are PRIVATE between participants',
                          'Club content is PRIVATE to club members only',
                          'Stand locations and activity are visible only to club members',
                        ]),
                        
                        _buildSection(
                          '7. Data Storage & Security',
                          'We take security seriously:\n\n'
                          '• All data is transmitted using TLS/SSL encryption\n'
                          '• Passwords are hashed and never stored in plain text\n'
                          '• Database access is protected by row-level security policies\n'
                          '• Photos are stored in secure cloud storage\n'
                          '• We use Supabase for authentication and data management, which provides enterprise-grade security\n'
                          '• Regular security audits and monitoring\n\n'
                          'While we implement robust security measures, no system is 100% secure. Please use strong, unique passwords and report any suspicious activity.',
                        ),
                        
                        _buildSection(
                          '8. Data Retention',
                          '• Active account data is retained while your account exists\n'
                          '• When you delete your account, we delete your personal data within 30 days\n'
                          '• Some data may be retained for legal compliance (e.g., transaction records, reports)\n'
                          '• Anonymized or aggregated data may be retained for analytics\n'
                          '• Backup data is purged according to our backup rotation schedule',
                        ),
                        
                        _buildSection(
                          '9. Cookies & Local Storage',
                          'On web browsers, we use:\n\n'
                          '• Essential cookies for authentication and session management\n'
                          '• Local storage for app preferences and offline functionality\n'
                          '• We do NOT use third-party tracking cookies\n'
                          '• We do NOT use cookies for advertising purposes\n\n'
                          'You can clear cookies and local storage through your browser settings, though this may require you to log in again.',
                        ),
                        
                        _buildSection(
                          '10. Your Rights',
                          'You have the right to:\n\n'
                          '• Access your personal data\n'
                          '• Correct inaccurate information\n'
                          '• Delete your account and associated data\n'
                          '• Export your data (coming soon)\n'
                          '• Opt out of marketing communications\n'
                          '• Disable push notifications\n\n'
                          'To exercise these rights, use the in-app settings or contact us at support@theskinningshed.com.',
                        ),
                        
                        _buildSection(
                          '11. Children\'s Privacy',
                          'The Skinning Shed is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we discover that a child under 13 has provided us with personal information, we will delete it promptly.\n\n'
                          'If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately.',
                        ),
                        
                        _buildSection(
                          '12. California Privacy Rights',
                          'If you are a California resident, you have additional rights under the California Consumer Privacy Act (CCPA):\n\n'
                          '• Right to know what personal information is collected\n'
                          '• Right to know if personal information is sold or disclosed\n'
                          '• Right to opt out of sale of personal information (we do not sell your data)\n'
                          '• Right to non-discrimination for exercising your rights\n\n'
                          'To exercise these rights, contact us at support@theskinningshed.com.',
                        ),
                        
                        _buildSection(
                          '13. International Users',
                          'The Service is operated in the United States. If you are accessing the Service from outside the United States, please be aware that your information may be transferred to, stored, and processed in the United States where our servers are located.\n\n'
                          'By using the Service, you consent to the transfer of your information to the United States.',
                        ),
                        
                        _buildSection(
                          '14. Third-Party Links',
                          'The Service may contain links to third-party websites (e.g., state wildlife agency portals). We are not responsible for the privacy practices of these external sites. We encourage you to review their privacy policies.',
                        ),
                        
                        _buildSection(
                          '15. Changes to This Policy',
                          'We may update this Privacy Policy from time to time. We will notify you of significant changes by:\n\n'
                          '• Posting the updated policy in the app\n'
                          '• Updating the "Last updated" date\n'
                          '• Sending a notification for material changes\n\n'
                          'Continued use of the Service after changes constitutes acceptance of the updated policy.',
                        ),
                        
                        _buildSection(
                          '16. Contact Us',
                          'Questions about this Privacy Policy or your data? Contact us:\n\n'
                          'Email: support@theskinningshed.com\n\n'
                          'Or use the in-app Feedback feature.',
                        ),
                        
                        const SizedBox(height: AppSpacing.xxxl),
                        _buildFooterNotice(),
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
            'Last updated: January 29, 2026',
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

  Widget _buildSubSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
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

  Widget _buildBulletList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildFooterNotice() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'This document is provided for informational purposes and does not constitute legal advice. If you have specific legal questions, please consult a qualified attorney.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textTertiary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
