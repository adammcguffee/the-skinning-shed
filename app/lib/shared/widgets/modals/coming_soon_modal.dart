import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import 'shed_modal.dart';

/// Show a premium "Coming Soon" modal for unimplemented features.
/// 
/// Use this instead of dead/no-op clicks to maintain premium UX.
/// 
/// Example:
/// ```dart
/// showComingSoonModal(
///   context: context,
///   feature: 'Share Trophy',
///   description: 'Share your trophies directly to social media and messaging apps.',
///   icon: Icons.share_rounded,
/// );
/// ```
Future<void> showComingSoonModal({
  required BuildContext context,
  required String feature,
  String? description,
  IconData? icon,
}) {
  return showShedModal(
    context: context,
    maxWidth: 380,
    child: _ComingSoonContent(
      feature: feature,
      description: description,
      icon: icon,
    ),
  );
}

class _ComingSoonContent extends StatelessWidget {
  const _ComingSoonContent({
    required this.feature,
    this.description,
    this.icon,
  });
  
  final String feature;
  final String? description;
  final IconData? icon;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon with gradient background
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent.withOpacity(0.2),
                AppColors.primary.withOpacity(0.15),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon ?? Icons.construction_rounded,
            size: 32,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        
        // "Coming Soon" label
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.3),
            ),
          ),
          child: const Text(
            'COMING SOON',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        
        // Feature name
        Text(
          feature,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        
        if (description != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            description!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        
        const SizedBox(height: AppSpacing.xxl),
        
        // Dismiss button
        SizedBox(
          width: double.infinity,
          child: _GradientButton(
            label: 'Got it',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
  });
  
  final String label;
  final VoidCallback onPressed;
  
  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: _isHovered ? AppColors.accentGradient : null,
            color: _isHovered ? null : AppColors.accent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: _isHovered ? AppColors.shadowAccent : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textInverse,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to show coming soon as a simple snackbar (for less prominent features).
void showComingSoonSnackbar(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.construction_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$feature coming soon!',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}
