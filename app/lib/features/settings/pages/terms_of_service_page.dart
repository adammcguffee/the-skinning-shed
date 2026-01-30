import 'package:flutter/material.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// Terms of Service page - Production-ready legal content.
/// Last updated: January 2026
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
                          '1. Agreement to Terms',
                          'By accessing or using The Skinning Shed ("Service"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, you may not use the Service.\n\n'
                          'These Terms constitute a legally binding agreement between you and The Skinning Shed. We reserve the right to modify these Terms at any time. Continued use of the Service after changes constitutes acceptance of the modified Terms.',
                        ),
                        
                        _buildSection(
                          '2. Account Requirements',
                          '• You must be at least 13 years of age to create an account\n'
                          '• You must provide accurate and complete registration information\n'
                          '• You are responsible for maintaining the security and confidentiality of your login credentials\n'
                          '• You are responsible for all activities that occur under your account\n'
                          '• One account per person; do not share login credentials or create multiple accounts\n'
                          '• You must promptly notify us of any unauthorized use of your account\n'
                          '• Usernames must not impersonate others, contain offensive content, or violate trademarks',
                        ),
                        
                        _buildSection(
                          '3. User Content & License',
                          'You retain ownership of all content you post, including photos, text, and listings ("User Content").\n\n'
                          'By posting User Content, you grant The Skinning Shed a non-exclusive, worldwide, royalty-free, sublicensable license to:\n'
                          '• Host, store, and display your content within the Service\n'
                          '• Share your content with other users as intended by the Service features\n'
                          '• Create thumbnails and optimized versions for display purposes\n\n'
                          'This license exists solely to operate and improve the Service. We will not sell your content or use it for advertising outside the platform without your consent.\n\n'
                          'You represent that you own or have the rights to post all User Content and that it does not infringe on any third-party rights.',
                        ),
                        
                        _buildSection(
                          '4. Prohibited Content & Behavior',
                          'You may not post content or engage in behavior that:\n\n'
                          '• Violates any federal, state, or local law, including wildlife regulations\n'
                          '• Promotes or depicts illegal hunting, fishing, or poaching activities\n'
                          '• Harasses, threatens, bullies, or intimidates other users\n'
                          '• Contains hate speech, discrimination, or promotes violence\n'
                          '• Includes explicit, pornographic, or sexually suggestive content\n'
                          '• Doxxes or reveals private information about others without consent\n'
                          '• Shares precise GPS coordinates of private hunting locations without permission\n'
                          '• Is fraudulent, misleading, or designed to scam other users\n'
                          '• Contains malware, spam, or unauthorized commercial solicitation\n'
                          '• Infringes on intellectual property rights of others\n'
                          '• Depicts animal cruelty or graphic violence beyond typical hunting/fishing content\n'
                          '• Circumvents security features or accesses restricted areas of the Service',
                        ),
                        
                        _buildSection(
                          '5. Swap Shop Marketplace',
                          'The Skinning Shed provides a platform for users to discover and connect regarding hunting and fishing gear ("Swap Shop"). Important disclaimers:\n\n'
                          '• We are a discovery platform only—we do NOT process payments or facilitate transactions\n'
                          '• All transactions occur directly between buyers and sellers at their own risk\n'
                          '• We do not verify the identity, qualifications, or reliability of users\n'
                          '• We make no guarantees about listings, items, or transaction outcomes\n'
                          '• You are solely responsible for complying with all applicable laws, including firearms regulations\n'
                          '• Use caution when meeting strangers; consider public meeting places\n'
                          '• Report suspicious activity or potential scams immediately',
                        ),
                        
                        _buildSection(
                          '6. Land & Club Openings',
                          'Land listings and Club Openings are informational in nature:\n\n'
                          '• We do not verify property ownership, boundaries, or listing accuracy\n'
                          '• We are not a licensed real estate broker or agent\n'
                          '• Users must conduct their own due diligence before any transaction\n'
                          '• Verify all information independently before making decisions\n'
                          '• We make no representations about the quality, safety, or suitability of any property or club',
                        ),
                        
                        _buildSection(
                          '7. Clubs & Private Content',
                          'Clubs provide private spaces for members:\n\n'
                          '• Club content (posts, photos, stands, activity) is visible only to approved members\n'
                          '• Members must not share, screenshot, or distribute club content without explicit permission from content creators\n'
                          '• Club owners and admins may remove members or content at their discretion\n'
                          '• Violation of club privacy may result in removal and account suspension\n'
                          '• We are not responsible for actions of club members or administrators',
                        ),
                        
                        _buildSection(
                          '8. Direct Messages & Communications',
                          '• Direct messages are private between participants\n'
                          '• We do not actively monitor private messages but may review reported content\n'
                          '• You may not use messaging for spam, harassment, or illegal solicitation\n'
                          '• We may retain message data as required by law or for safety purposes\n'
                          '• Report inappropriate messages using the in-app reporting feature',
                        ),
                        
                        _buildSection(
                          '9. Moderation & Enforcement',
                          'We reserve the right to:\n\n'
                          '• Remove any content that violates these Terms without notice\n'
                          '• Suspend or terminate accounts for violations\n'
                          '• Report illegal activity to law enforcement\n'
                          '• Cooperate with legal investigations as required by law\n'
                          '• Ban users permanently for serious or repeated violations\n\n'
                          'Decisions regarding content removal and account actions are at our sole discretion and are final.',
                        ),
                        
                        _buildSection(
                          '10. Intellectual Property',
                          'The Skinning Shed name, logo, and all associated branding are proprietary. You may not:\n\n'
                          '• Copy, reproduce, or distribute our branding or assets\n'
                          '• Use our trademarks without written permission\n'
                          '• Reverse engineer, decompile, or attempt to extract source code\n'
                          '• Scrape, crawl, or collect data through automated means\n'
                          '• Create derivative works based on the Service\n'
                          '• Use bots or automated systems to interact with the Service',
                        ),
                        
                        _buildSection(
                          '11. Account Termination',
                          'You may delete your account at any time through Settings. Upon deletion:\n\n'
                          '• Your profile and personal data will be permanently removed\n'
                          '• Your posts and listings will be deleted\n'
                          '• Some data may be retained for legal compliance purposes\n\n'
                          'We may suspend or terminate your account if you:\n'
                          '• Violate these Terms of Service\n'
                          '• Engage in fraudulent or illegal activity\n'
                          '• Repeatedly post prohibited content\n'
                          '• Harass other users',
                        ),
                        
                        _buildSection(
                          '12. Disclaimer of Warranties',
                          'THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO:\n\n'
                          '• MERCHANTABILITY\n'
                          '• FITNESS FOR A PARTICULAR PURPOSE\n'
                          '• NON-INFRINGEMENT\n'
                          '• ACCURACY OR RELIABILITY OF CONTENT\n\n'
                          'We do not guarantee that the Service will be uninterrupted, secure, or error-free.',
                        ),
                        
                        _buildSection(
                          '13. Limitation of Liability',
                          'TO THE MAXIMUM EXTENT PERMITTED BY LAW, THE SKINNING SHED AND ITS OFFICERS, DIRECTORS, EMPLOYEES, AND AGENTS SHALL NOT BE LIABLE FOR:\n\n'
                          '• Any indirect, incidental, special, consequential, or punitive damages\n'
                          '• Any loss of profits, data, or goodwill\n'
                          '• Any damages arising from user-generated content\n'
                          '• Any damages arising from marketplace transactions between users\n'
                          '• Any damages arising from reliance on information provided through the Service\n\n'
                          'Our total liability shall not exceed the amount you paid to us (if any) in the 12 months preceding the claim.',
                        ),
                        
                        _buildSection(
                          '14. Indemnification',
                          'You agree to indemnify, defend, and hold harmless The Skinning Shed and its officers, directors, employees, and agents from any claims, damages, losses, or expenses (including reasonable attorney fees) arising from:\n\n'
                          '• Your use of the Service\n'
                          '• Your User Content\n'
                          '• Your violation of these Terms\n'
                          '• Your violation of any third-party rights',
                        ),
                        
                        _buildSection(
                          '15. Governing Law & Disputes',
                          'These Terms shall be governed by and construed in accordance with the laws of the State of Mississippi, USA, without regard to conflict of law principles.\n\n'
                          'Any disputes arising from these Terms or your use of the Service shall be resolved through binding arbitration in accordance with the rules of the American Arbitration Association. You waive any right to participate in class action lawsuits.\n\n'
                          'Notwithstanding the above, we may seek injunctive relief in any court of competent jurisdiction.',
                        ),
                        
                        _buildSection(
                          '16. Changes to Terms',
                          'We may update these Terms from time to time. We will notify you of material changes by:\n\n'
                          '• Posting the updated Terms in the app\n'
                          '• Updating the "Last updated" date\n'
                          '• Sending a notification for significant changes\n\n'
                          'Continued use of the Service after changes constitutes acceptance of the updated Terms.',
                        ),
                        
                        _buildSection(
                          '17. Contact',
                          'Questions about these Terms? Contact us:\n\n'
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
