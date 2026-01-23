import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Primary action button with premium styling.
class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.variant = PremiumButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final PremiumButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final button = switch (variant) {
      PremiumButtonVariant.primary => _buildPrimaryButton(context),
      PremiumButtonVariant.secondary => _buildSecondaryButton(context),
      PremiumButtonVariant.text => _buildTextButton(context),
    };

    if (isExpanded) {
      return SizedBox(
        width: double.infinity,
        height: AppSpacing.buttonHeight,
        child: button,
      );
    }
    return button;
  }

  Widget _buildPrimaryButton(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.bone,
        disabledBackgroundColor: AppColors.forestLight,
        disabledForegroundColor: AppColors.bone.withOpacity(0.7),
      ),
      child: _buildContent(AppColors.bone),
    );
  }

  Widget _buildSecondaryButton(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.forest,
        side: const BorderSide(color: AppColors.forest, width: 1.5),
      ),
      child: _buildContent(AppColors.forest),
    );
  }

  Widget _buildTextButton(BuildContext context) {
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.forest,
      ),
      child: _buildContent(AppColors.forest),
    );
  }

  Widget _buildContent(Color color) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }

    return Text(label);
  }
}

enum PremiumButtonVariant {
  primary,
  secondary,
  text,
}

/// A floating action button styled for the app.
class PremiumFAB extends StatelessWidget {
  const PremiumFAB({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.isExtended = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    if (isExtended && label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.bone,
        icon: Icon(icon),
        label: Text(label!),
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.forest,
      foregroundColor: AppColors.bone,
      child: Icon(icon),
    );
  }
}
