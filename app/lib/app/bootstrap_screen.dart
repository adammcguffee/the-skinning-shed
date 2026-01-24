import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  bool get _isConfigError {
    return message.contains('SUPABASE_URL') ||
           message.contains('credentials') ||
           message.contains('dart-define');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(
                    color: _isConfigError 
                        ? AppColors.warning.withOpacity(0.3)
                        : AppColors.error.withOpacity(0.3),
                  ),
                  boxShadow: AppColors.shadowElevated,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _isConfigError
                            ? AppColors.warning.withOpacity(0.15)
                            : AppColors.errorLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isConfigError
                            ? Icons.settings_outlined
                            : Icons.warning_amber_rounded,
                        size: 32,
                        color: _isConfigError ? AppColors.warning : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Title
                    Text(
                      _isConfigError ? 'Configuration Required' : 'Initialization Failed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Subtitle for config errors
                    if (_isConfigError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: Text(
                          'Supabase credentials must be provided via dart-define flags.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Error message / instructions
                    _ConfigMessageCard(message: message),
                    const SizedBox(height: AppSpacing.xl),

                    // Copyable command for config errors
                    if (_isConfigError) ...[
                      _CopyableCommand(),
                      const SizedBox(height: AppSpacing.xl),
                    ],

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
                    
                    // Debug mode indicator
                    if (kDebugMode) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundAlt,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          'Debug Build',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
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

/// Card showing the error/config message.
class _ConfigMessageCard extends StatelessWidget {
  const _ConfigMessageCard({required this.message});
  
  final String message;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: SelectableText(
        message,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontFamily: 'monospace',
          height: 1.6,
        ),
      ),
    );
  }
}

/// Copyable command snippet for configuration.
class _CopyableCommand extends StatefulWidget {
  @override
  State<_CopyableCommand> createState() => _CopyableCommandState();
}

class _CopyableCommandState extends State<_CopyableCommand> {
  bool _copied = false;
  
  static const String _command = '''flutter run -d chrome \\
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \\
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \\
  --dart-define=DEV_BYPASS_AUTH=true''';
  
  void _copyCommand() async {
    await Clipboard.setData(const ClipboardData(text: _command));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Example command:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _copyCommand,
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 14,
              ),
              label: Text(_copied ? 'Copied!' : 'Copy'),
              style: TextButton.styleFrom(
                foregroundColor: _copied ? AppColors.success : AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: SelectableText(
            _command,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9CDCFE),
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
