import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../navigation/app_routes.dart';
import '../../services/profile_service.dart';

/// Username validation rules
class UsernameValidator {
  static const int minLength = 3;
  static const int maxLength = 20;
  
  /// Regex: starts with letter, then letters/numbers/underscore only
  static final RegExp validPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');
  
  /// Validate username and return error message if invalid, null if valid.
  static String? validate(String username) {
    if (username.isEmpty) {
      return 'Username is required';
    }
    
    if (username.length < minLength) {
      return 'Username must be at least $minLength characters';
    }
    
    if (username.length > maxLength) {
      return 'Username must be at most $maxLength characters';
    }
    
    if (!RegExp(r'^[A-Za-z]').hasMatch(username)) {
      return 'Username must start with a letter';
    }
    
    if (!validPattern.hasMatch(username)) {
      return 'Only letters, numbers, and underscores allowed';
    }
    
    return null; // Valid
  }
  
  /// Check if the username format is valid (for UI enabling save button).
  static bool isValidFormat(String username) {
    return validate(username) == null;
  }
}

/// Screen for choosing a username.
/// Displayed after signup or when existing user has no username set.
class ChooseUsernameScreen extends ConsumerStatefulWidget {
  const ChooseUsernameScreen({
    super.key,
    this.isChanging = false,
  });
  
  /// If true, user is changing existing username (shows warning).
  final bool isChanging;

  @override
  ConsumerState<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends ConsumerState<ChooseUsernameScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  
  String? _validationError;
  bool _isCheckingAvailability = false;
  bool _isAvailable = false;
  bool _isSaving = false;
  String? _saveError;
  
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onUsernameChanged);
    
    // Auto-focus the input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onUsernameChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _onUsernameChanged() {
    final username = _controller.text.trim();
    
    // Reset state
    setState(() {
      _validationError = UsernameValidator.validate(username);
      _isAvailable = false;
      _saveError = null;
    });
    
    // Debounce availability check
    _debounceTimer?.cancel();
    
    if (_validationError == null && username.isNotEmpty) {
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _checkAvailability(username);
      });
    }
  }
  
  Future<void> _checkAvailability(String username) async {
    if (!mounted) return;
    
    setState(() {
      _isCheckingAvailability = true;
    });
    
    final service = ref.read(profileServiceProvider);
    final available = await service.isUsernameAvailable(username);
    
    if (!mounted) return;
    
    // Only update if the username hasn't changed
    if (_controller.text.trim() == username) {
      setState(() {
        _isCheckingAvailability = false;
        _isAvailable = available;
        if (!available) {
          _validationError = 'This username is already taken';
        }
      });
    }
  }
  
  Future<void> _saveUsername() async {
    final username = _controller.text.trim();
    
    if (!UsernameValidator.isValidFormat(username) || !_isAvailable) {
      return;
    }
    
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    
    final service = ref.read(profileServiceProvider);
    final result = await service.setUsername(username);
    
    if (!mounted) return;
    
    if (result.isSuccess) {
      // Invalidate profile cache
      ref.invalidate(currentProfileProvider);
      
      // Mark username as set in auth notifier
      ref.read(authNotifierProvider).markUsernameSet();
      
      // Navigate to feed
      if (mounted) {
        context.go(AppRoutes.feed);
      }
    } else {
      setState(() {
        _isSaving = false;
        if (result.isTaken) {
          _saveError = 'This username was just taken. Try another one.';
          _isAvailable = false;
        } else if (result.isInvalidFormat) {
          _saveError = 'Invalid username format. Please check the rules.';
        } else {
          _saveError = result.errorMessage ?? 'Failed to save. Please try again.';
        }
      });
    }
  }
  
  bool get _canSave {
    final username = _controller.text.trim();
    return UsernameValidator.isValidFormat(username) && 
           _isAvailable && 
           !_isCheckingAvailability &&
           !_isSaving;
  }

  @override
  Widget build(BuildContext context) {
    final username = _controller.text.trim();
    
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // No back button if this is required flow
        automaticallyImplyLeading: widget.isChanging,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              
              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // Title
              Center(
                child: Text(
                  widget.isChanging ? 'Change Username' : 'Choose Your Username',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: AppSpacing.sm),
              
              // Subtitle
              Center(
                child: Text(
                  'Your username will be visible to other hunters and fishermen in the community.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // Username rules
              _buildRulesCard(),
              
              const SizedBox(height: AppSpacing.lg),
              
              // Username input
              _buildUsernameInput(),
              
              const SizedBox(height: AppSpacing.sm),
              
              // Status indicator
              _buildStatusIndicator(),
              
              // Warning for changing username
              if (widget.isChanging) ...[
                const SizedBox(height: AppSpacing.md),
                _buildChangeWarning(),
              ],
              
              // Save error
              if (_saveError != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildErrorMessage(_saveError!),
              ],
              
              const SizedBox(height: AppSpacing.xl),
              
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSave ? _saveUsername : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: AppColors.surfaceElevated,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isChanging ? 'Update Username' : 'Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Username Rules',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildRule('3-20 characters'),
          _buildRule('Must start with a letter'),
          _buildRule('Letters, numbers, and underscores only'),
          _buildRule('No spaces'),
          _buildRule('Case doesn\'t matter (BuckMaster = buckmaster)'),
        ],
      ),
    );
  }
  
  Widget _buildRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUsernameInput() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
      ),
      decoration: InputDecoration(
        labelText: 'Username',
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixText: '@',
        prefixStyle: TextStyle(
          color: AppColors.primary.withValues(alpha: 0.7),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.all(16),
        suffixIcon: _buildSuffixIcon(),
      ),
      textCapitalization: TextCapitalization.none,
      autocorrect: false,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
        LengthLimitingTextInputFormatter(UsernameValidator.maxLength),
      ],
      onSubmitted: _canSave ? (_) => _saveUsername() : null,
    );
  }
  
  Widget? _buildSuffixIcon() {
    if (_isCheckingAvailability) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textTertiary,
          ),
        ),
      );
    }
    
    final username = _controller.text.trim();
    if (username.isEmpty) return null;
    
    if (_validationError != null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(
          Icons.error_outline,
          color: AppColors.error,
        ),
      );
    }
    
    if (_isAvailable) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(
          Icons.check_circle,
          color: AppColors.success,
        ),
      );
    }
    
    return null;
  }
  
  Widget _buildStatusIndicator() {
    final username = _controller.text.trim();
    
    if (username.isEmpty) {
      return const SizedBox.shrink();
    }
    
    if (_isCheckingAvailability) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Checking availability...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      );
    }
    
    if (_validationError != null) {
      return Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 14,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _validationError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      );
    }
    
    if (_isAvailable) {
      return Row(
        children: [
          const Icon(
            Icons.check_circle,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Text(
            '@$username is available!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.success,
            ),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }
  
  Widget _buildChangeWarning() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Changing your username will update how you appear everywhere in the app.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
