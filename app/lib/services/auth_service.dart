import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Authentication service wrapping Supabase Auth.
class AuthService {
  AuthService(this._client);
  
  final SupabaseClient? _client;
  
  /// Sign up with email and password.
  Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
    if (_client == null) {
      return AuthResult.error('Supabase not initialized');
    }
    
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        return AuthResult.success(response.user!);
      } else {
        return AuthResult.error('Sign up failed');
      }
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }
  
  /// Sign in with email and password.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (_client == null) {
      return AuthResult.error('Supabase not initialized');
    }
    
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        return AuthResult.success(response.user!);
      } else {
        return AuthResult.error('Sign in failed');
      }
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }
  
  /// Sign in with magic link (passwordless).
  Future<AuthResult> signInWithMagicLink({required String email}) async {
    if (_client == null) {
      return AuthResult.error('Supabase not initialized');
    }
    
    try {
      await _client.auth.signInWithOtp(email: email);
      return AuthResult.success(null, message: 'Check your email for the magic link!');
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }
  
  /// Sign out current user.
  Future<void> signOut() async {
    await _client?.auth.signOut();
  }
  
  /// Reset password (send reset email).
  Future<AuthResult> resetPassword({required String email}) async {
    if (_client == null) {
      return AuthResult.error('Supabase not initialized');
    }
    
    try {
      await _client.auth.resetPasswordForEmail(email);
      return AuthResult.success(null, message: 'Check your email for reset instructions');
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }
}

/// Result of an auth operation.
class AuthResult {
  AuthResult.success(this.user, {this.message}) : error = null;
  AuthResult.error(this.error) : user = null, message = null;
  
  final User? user;
  final String? error;
  final String? message;
  
  bool get isSuccess => error == null;
  bool get isError => error != null;
}

/// Provider for auth service.
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthService(client);
});

/// Auth state notifier for managing auth UI state.
class AuthStateNotifier extends StateNotifier<AuthUiState> {
  AuthStateNotifier(this._authService) : super(const AuthUiState());
  
  final AuthService _authService;
  
  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _authService.signUp(email: email, password: password);
    
    if (result.isSuccess) {
      state = state.copyWith(isLoading: false, message: 'Account created successfully!');
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
      return false;
    }
  }
  
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _authService.signIn(email: email, password: password);
    
    if (result.isSuccess) {
      state = state.copyWith(isLoading: false);
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
      return false;
    }
  }
  
  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthUiState();
  }
  
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// UI state for auth screens.
class AuthUiState {
  const AuthUiState({
    this.isLoading = false,
    this.error,
    this.message,
  });
  
  final bool isLoading;
  final String? error;
  final String? message;
  
  AuthUiState copyWith({
    bool? isLoading,
    String? error,
    String? message,
  }) {
    return AuthUiState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      message: message,
    );
  }
}

/// Provider for auth state notifier.
final authStateNotifierProvider = StateNotifierProvider<AuthStateNotifier, AuthUiState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthStateNotifier(authService);
});
