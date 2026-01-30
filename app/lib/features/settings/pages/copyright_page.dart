import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// Copyright and Intellectual Property page.
/// Last updated: January 2026
class CopyrightPage extends StatelessWidget {
  const CopyrightPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            const PageHeader(
              title: 'Copyright & IP',
              subtitle: 'Intellectual property information',
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
                        // Copyright notice card
                        _buildCopyrightCard(currentYear),
                        const SizedBox(height: AppSpacing.xl),
                        
                        _buildSection(
                          'Trademark Notice',
                          'The Skinning Shed™ name, logo, and all associated branding elements are trademarks of The Skinning Shed. These marks may not be used without prior written permission.\n\n'
                          'Our brand assets include but are not limited to:\n'
                          '• The Skinning Shed name and wordmark\n'
                          '• The antler/crest logo\n'
                          '• App icons and graphics\n'
                          '• Marketing materials and imagery',
                        ),
                        
                        _buildSection(
                          'Protected Content',
                          'The following are protected by copyright:\n\n'
                          '• The Skinning Shed application source code\n'
                          '• User interface designs and layouts\n'
                          '• Original graphics and illustrations\n'
                          '• Documentation and written content\n'
                          '• Database schemas and data structures\n\n'
                          'Unauthorized copying, modification, or distribution of these materials is prohibited.',
                        ),
                        
                        _buildSection(
                          'User Content Ownership',
                          'Users retain full ownership of the content they create and post on The Skinning Shed, including:\n\n'
                          '• Photos and images\n'
                          '• Trophy posts and descriptions\n'
                          '• Listings and text content\n'
                          '• Comments and messages\n\n'
                          'By posting content, you grant us a license to display it within the Service as described in our Terms of Service. You may delete your content at any time.',
                        ),
                        
                        _buildSection(
                          'Prohibited Uses',
                          'Without explicit written permission, you may NOT:\n\n'
                          '• Use our trademarks or branding in any commercial context\n'
                          '• Create derivative works based on our brand assets\n'
                          '• Scrape, crawl, or automatically collect data from the Service\n'
                          '• Reverse engineer or decompile the application\n'
                          '• Copy or redistribute our source code or designs\n'
                          '• Use our name to imply endorsement or affiliation\n'
                          '• Create competing products using our intellectual property',
                        ),
                        
                        _buildSection(
                          'DMCA / Takedown Requests',
                          'We respect intellectual property rights and respond to valid takedown requests.\n\n'
                          'If you believe content on The Skinning Shed infringes your copyright, please submit a notice including:\n\n'
                          '1. Identification of the copyrighted work\n'
                          '2. Identification of the infringing material with location (URL/description)\n'
                          '3. Your contact information (name, address, email, phone)\n'
                          '4. A statement that you have a good faith belief the use is unauthorized\n'
                          '5. A statement, under penalty of perjury, that the information is accurate and you are authorized to act\n'
                          '6. Your physical or electronic signature\n\n'
                          'Send takedown notices to: dmca@theskinningshed.com',
                        ),
                        
                        _buildSection(
                          'Counter-Notification',
                          'If you believe your content was removed in error, you may submit a counter-notification including:\n\n'
                          '1. Identification of the removed material and its previous location\n'
                          '2. A statement under penalty of perjury that you have a good faith belief the material was removed due to mistake or misidentification\n'
                          '3. Your name, address, and phone number\n'
                          '4. Consent to jurisdiction of federal court in your district\n'
                          '5. Your physical or electronic signature\n\n'
                          'Send counter-notices to: dmca@theskinningshed.com',
                        ),
                        
                        _buildSection(
                          'Reporting Infringement',
                          'If you see content on The Skinning Shed that infringes your intellectual property or violates our policies, you can:\n\n'
                          '• Use the in-app Report feature on the content\n'
                          '• Email us at support@theskinningshed.com\n'
                          '• For copyright issues, use dmca@theskinningshed.com\n\n'
                          'We review all reports and take appropriate action, which may include removing content and suspending accounts.',
                        ),
                        
                        _buildSection(
                          'Third-Party Content',
                          'The Skinning Shed may contain links to third-party websites or display third-party content. We do not claim ownership of third-party content and are not responsible for third-party intellectual property claims.\n\n'
                          'State wildlife agency links and information are provided for convenience and remain the property of their respective owners.',
                        ),
                        
                        _buildSection(
                          'Open Source',
                          'The Skinning Shed may use open source software components. These components are subject to their respective licenses. A list of open source components and their licenses is available upon request.',
                        ),
                        
                        _buildSection(
                          'Contact',
                          'For intellectual property inquiries:\n\n'
                          'General: support@theskinningshed.com\n'
                          'DMCA/Copyright: dmca@theskinningshed.com\n'
                          'Trademark inquiries: legal@theskinningshed.com',
                        ),
                        
                        const SizedBox(height: AppSpacing.xxxl),
                        _buildFooterCopyright(currentYear),
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

  Widget _buildCopyrightCard(int year) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(
            Icons.copyright_rounded,
            size: 48,
            color: AppColors.accent,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '© $year The Skinning Shed',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'All rights reserved.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              'The Skinning Shed™',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.accent,
              ),
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

  Widget _buildFooterCopyright(int year) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Text(
            '© $year The Skinning Shed. All rights reserved.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The Skinning Shed™ is a trademark. Unauthorized use is prohibited.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
