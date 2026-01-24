import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';

/// Bootstrap screen that gates app startup.
///
/// Shows loading spinner during Supabase initialization,
/// then either shows an error panel or passes through to the child.
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({
    super.key,
    required this.child,
  });

  /// The child widget to show once initialization succeeds.
  final Widget child;

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final service = SupabaseService.instance;
    
    // If already initialized, skip
    if (service.isInitialized) {
      setState(() => _isLoading = false);
      return;
    }

    final success = await service.initialize();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _hasError = !success;
      _errorMessage = service.errorMessage;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    await _initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _LoadingView();
    }

    if (_hasError) {
      return _ErrorView(
        message: _errorMessage ?? 'Unknown error',
        onRetry: _retry,
      );
    }

    return widget.child;
  }
}

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loading spinner with accent color
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  boxShadow: AppColors.shadowElevated,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Error icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 32,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Title
                    Text(
                      'Initialization Failed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Error message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Retry button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        icon: Icon(Icons.refresh_rounded, size: 18),
                        label: Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                            horizontal: AppSpacing.xl,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
