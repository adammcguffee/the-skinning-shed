import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_preferences.dart';

/// Supabase client singleton.
/// 
/// Credentials are provided via --dart-define at build/run time:
/// - SUPABASE_URL
/// - SUPABASE_ANON_KEY
/// 
/// NEVER hardcode credentials or use SERVICE_ROLE in client.
class SupabaseService {
  SupabaseService._();
  
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  
  bool _initialized = false;
  
  /// Initialize Supabase client.
  /// Call once at app startup from main.dart.
  Future<void> initialize() async {
    if (_initialized) return;
    
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );
    
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      // In development without credentials, log warning but don't crash
      print('⚠️ Supabase credentials not provided via --dart-define');
      print('   Run with: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...');
      return;
    }
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    final keepSignedIn = await AuthPreferences.getKeepSignedIn();
    if (!keepSignedIn) {
      final client = Supabase.instance.client;
      if (client.auth.currentSession != null) {
        await client.auth.signOut();
      }
    }
    
    _initialized = true;
  }
  
  /// Get Supabase client instance.
  /// Returns null if not initialized.
  SupabaseClient? get client {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }
  
  /// Check if Supabase is initialized.
  bool get isInitialized => _initialized;
  
  /// Get current user (null if not authenticated).
  User? get currentUser => client?.auth.currentUser;
  
  /// Get current session.
  Session? get currentSession => client?.auth.currentSession;
  
  /// Check if user is authenticated.
  bool get isAuthenticated => currentUser != null;
  
  /// Auth state stream.
  Stream<AuthState>? get authStateChanges => client?.auth.onAuthStateChange;
}

/// Provider for Supabase service.
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService.instance;
});

/// Provider for Supabase client (nullable).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  return ref.watch(supabaseServiceProvider).client;
});

/// Provider for current user (nullable).
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseServiceProvider).currentUser;
});

/// Provider for authentication state.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final stream = service.authStateChanges;
  if (stream == null) {
    return const Stream.empty();
  }
  return stream;
});

/// Provider for checking if user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
