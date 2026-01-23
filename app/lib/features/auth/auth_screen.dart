import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../shared/branding_assets.dart';

/// Professional auth screen with sign in / sign up.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    final authService = ref.read(authServiceProvider);
    AuthResult result;
    
    if (_isSignUp) {
      result = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      result = await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
    
    if (!mounted) return;
    
    setState(() => _isLoading = false);
    
    if (result.isError) {
      setState(() => _error = result.error);
    } else if (result.isSuccess) {
      // Router will automatically redirect to home
      if (_isSignUp && result.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message!),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSupabaseInitialized = ref.watch(supabaseServiceProvider).isInitialized;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bone,
              Color(0xFFF5F3EE),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo & Branding
                    _buildHeader(),
                    const SizedBox(height: AppSpacing.xxxl),
                    
                    // Auth Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Title
                            Text(
                              _isSignUp ? 'Create Account' : 'Welcome Back',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _isSignUp 
                                  ? 'Join the community' 
                                  : 'Sign in to continue',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.charcoalLight,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            
                            // Dev mode warning
                            if (!isSupabaseInitialized) ...[
                              _buildDevModeWarning(),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            
                            // Error message
                            if (_error != null) ...[
                              _buildErrorBanner(),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            
                            // Email field
                            _buildEmailField(),
                            const SizedBox(height: AppSpacing.lg),
                            
                            // Password field
                            _buildPasswordField(),
                            
                            // Confirm password (sign up only)
                            if (_isSignUp) ...[
                              const SizedBox(height: AppSpacing.lg),
                              _buildConfirmPasswordField(),
                            ],
                            
                            const SizedBox(height: AppSpacing.xl),
                            
                            // Submit button
                            _buildSubmitButton(),
                            
                            const SizedBox(height: AppSpacing.lg),
                            
                            // Toggle sign in / sign up
                            _buildToggleButton(),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Skip link (dev only)
                    if (!isSupabaseInitialized)
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: Text(
                          'Continue without account (Dev Mode)',
                          style: TextStyle(
                            color: AppColors.charcoalLight,
                            fontSize: 13,
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

  Widget _buildHeader() {
    return Column(
      children: [
        // Primary logo with illustration
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 220),
          child: Image.asset(
            BrandingAssets.primary,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Your hunting & fishing trophy journal',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.charcoalLight,
          ),
        ),
      ],
    );
  }

  Widget _buildDevModeWarning() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Dev mode: Auth simulated without Supabase',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'you@example.com',
        prefixIcon: Icon(
          Icons.email_outlined,
          color: AppColors.charcoalLight,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Email is required';
        }
        if (!value.contains('@') || !value.contains('.')) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(
          Icons.lock_outlined,
          color: AppColors.charcoalLight,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword 
                ? Icons.visibility_outlined 
                : Icons.visibility_off_outlined,
            color: AppColors.charcoalLight,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
      ),
      onFieldSubmitted: _isSignUp ? null : (_) => _submit(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password is required';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        prefixIcon: Icon(
          Icons.lock_outlined,
          color: AppColors.charcoalLight,
        ),
      ),
      onFieldSubmitted: (_) => _submit(),
      validator: (value) {
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                _isSignUp ? 'Create Account' : 'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildToggleButton() {
    return TextButton(
      onPressed: _isLoading
          ? null
          : () {
              setState(() {
                _isSignUp = !_isSignUp;
                _error = null;
                _confirmPasswordController.clear();
              });
            },
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 14),
          children: [
            TextSpan(
              text: _isSignUp
                  ? 'Already have an account? '
                  : "Don't have an account? ",
              style: TextStyle(color: AppColors.charcoalLight),
            ),
            TextSpan(
              text: _isSignUp ? 'Sign In' : 'Sign Up',
              style: TextStyle(
                color: AppColors.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
