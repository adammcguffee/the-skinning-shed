import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shed/app/theme/app_colors.dart';
import 'package:shed/app/theme/app_spacing.dart';
import 'package:shed/shared/widgets/widgets.dart';

/// Build version info - injected at build time via --dart-define
/// These are replaced by GitHub Actions during the build process.
class BuildInfo {
  BuildInfo._();
  
  /// App version (e.g. "1.0.0")
  static const String version = String.fromEnvironment(
    'BUILD_VERSION',
    defaultValue: '1.0.0',
  );
  
  /// Build number (e.g. "42")
  static const String buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: 'dev',
  );
  
  /// Build timestamp (e.g. "2026-01-25T12:34:56Z")
  static const String buildTime = String.fromEnvironment(
    'BUILD_TIME',
    defaultValue: 'local',
  );
  
  /// Git commit SHA (short, e.g. "abc1234")
  static const String gitSha = String.fromEnvironment(
    'GIT_SHA',
    defaultValue: 'local',
  );
  
  /// Full version string for display
  static String get fullVersion {
    if (gitSha == 'local') {
      return '$version (local dev)';
    }
    return '$version ($buildNumber · $gitSha)';
  }
}

/// About page - App info and credits.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
              title: 'About',
              subtitle: 'The Skinning Shed',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      children: [
                        // App logo/icon
                        _buildAppIcon(),
                        const SizedBox(height: AppSpacing.lg),
                        
                        // App name and version
                        Text(
                          'The Skinning Shed',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Version ${BuildInfo.fullVersion}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (BuildInfo.buildTime != 'local') ...[
                          const SizedBox(height: 4),
                          Text(
                            'Built: ${BuildInfo.buildTime}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        
                        // Mission statement
                        _buildMissionCard(),
                        const SizedBox(height: AppSpacing.xl),
                        
                        // Credits / Attribution
                        _buildCreditsSection(),
                        const SizedBox(height: AppSpacing.xl),
                        
                        // Contact
                        _buildContactSection(context),
                        const SizedBox(height: AppSpacing.xl),
                        
                        // Legal links
                        _buildLegalLinks(context),
                        const SizedBox(height: AppSpacing.xxxl),
                        
                        // Copyright
                        Text(
                          '© 2026 The Skinning Shed. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
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

  Widget _buildAppIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.shadowAccent,
      ),
      child: const Icon(
        Icons.forest_rounded,
        size: 48,
        color: AppColors.textInverse,
      ),
    );
  }

  Widget _buildMissionCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_nature_rounded,
            size: 32,
            color: AppColors.accent,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Our Mission',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The Skinning Shed is built for hunters and anglers who value community, '
            'conservation, and the outdoors tradition. We connect sportsmen and women '
            'to share their harvests, find gear, discover land, and access the information '
            'they need to enjoy the outdoors responsibly.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsSection() {
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
              Icon(
                Icons.attribution_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Credits & Attribution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCreditItem(
            'Weather Data',
            'Open-Meteo API',
          ),
          _buildCreditItem(
            'County Data',
            'US Census Bureau TIGER/Gazetteer',
          ),
          _buildCreditItem(
            'Official Links',
            'State wildlife agency portals',
          ),
          _buildCreditItem(
            'Icons',
            'Material Design Icons',
          ),
        ],
      ),
    );
  }

  Widget _buildCreditItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
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
              Icon(
                Icons.email_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Contact',
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
            'Have questions, feedback, or need support?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            'support@theskinningshed.com',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalLinks(BuildContext context) {
    return Column(
      children: [
        _LegalLinkButton(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          onTap: () => context.push('/settings/privacy'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LegalLinkButton(
          icon: Icons.article_outlined,
          label: 'Terms of Service',
          onTap: () => context.push('/settings/terms'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LegalLinkButton(
          icon: Icons.warning_amber_outlined,
          label: 'Content Disclaimer',
          onTap: () => context.push('/settings/disclaimer'),
        ),
      ],
    );
  }
}

class _LegalLinkButton extends StatefulWidget {
  const _LegalLinkButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_LegalLinkButton> createState() => _LegalLinkButtonState();
}

class _LegalLinkButtonState extends State<_LegalLinkButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
