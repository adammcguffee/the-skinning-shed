import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../shared/widgets/premium_button.dart';

/// Authentication screen (Sign In / Sign Up).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }
    
    final authNotifier = ref.read(authStateNotifierProvider.notifier);
    bool success;
    
    if (_isSignUp) {
      success = await authNotifier.signUp(email, password);
    } else {
      success = await authNotifier.signIn(email, password);
    }
    
    if (success && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);
    final isSupabaseInitialized = ref.watch(supabaseServiceProvider).isInitialized;
    
    // Show error snackbar if there's an auth error
    ref.listen<AuthUiState>(authStateNotifierProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
      if (next.message != null && previous?.message != next.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message!),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Title
                  const Icon(
                    Icons.emoji_events,
                    size: 64,
                    color: AppColors.forest,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'The Skinning Shed',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _isSignUp ? 'Create your account' : 'Welcome back',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.charcoalLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  
                  // Warning if Supabase not initialized
                  if (!isSupabaseInitialized) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: AppColors.warning),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Running without Supabase. Auth is simulated.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  
                  // Email field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !authState.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Password field
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !authState.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  
                  // Submit button
                  PremiumButton(
                    label: _isSignUp ? 'Create Account' : 'Sign In',
                    onPressed: authState.isLoading ? null : _submit,
                    isLoading: authState.isLoading,
                    isExpanded: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Toggle sign up / sign in
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () {
                            setState(() => _isSignUp = !_isSignUp);
                            ref.read(authStateNotifierProvider.notifier).clearError();
                          },
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign In'
                          : "Don't have an account? Sign Up",
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xxl),
                  
                  // Skip for now (dev only)
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(color: AppColors.charcoalLight),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
