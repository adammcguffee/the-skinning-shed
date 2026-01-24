import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_preferences.dart';

/// Initialization status for Supabase.
enum InitStatus {
  /// Not yet attempted initialization.
  idle,
  /// Currently initializing.
  loading,
  /// Successfully initialized.
  success,
  /// Failed to initialize (missing credentials or error).
  failure,
}

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
  
  InitStatus _status = InitStatus.idle;
  String? _errorMessage;
  
  /// Initialize Supabase client.
  /// Call once at app startup from main.dart.
  /// Returns true if successful, false if failed.
  Future<bool> initialize() async {
    if (_status == InitStatus.success) return true;
    if (_status == InitStatus.loading) return false;
    
    _status = InitStatus.loading;
    _errorMessage = null;
    
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );
    
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      _status = InitStatus.failure;
      _errorMessage = 'Supabase credentials not provided.\n\n'
          'Run with:\n'
          '--dart-define=SUPABASE_URL=your_url\n'
          '--dart-define=SUPABASE_ANON_KEY=your_key';
      return false;
    }
    
    try {
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
      
      _status = InitStatus.success;
      return true;
    } catch (e) {
      _status = InitStatus.failure;
      _errorMessage = 'Failed to initialize Supabase: $e';
      return false;
    }
  }
  
  /// Get Supabase client instance.
  /// Returns null if not initialized.
  SupabaseClient? get client {
    if (_status != InitStatus.success) return null;
    return Supabase.instance.client;
  }
  
  /// Current initialization status.
  InitStatus get status => _status;
  
  /// Error message if initialization failed.
  String? get errorMessage => _errorMessage;
  
  /// Check if Supabase is initialized.
  bool get isInitialized => _status == InitStatus.success;
  
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

/// Provider for checking if user is admin.
/// Fetches the is_admin flag from the profiles table.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  
  if (client == null || user == null) return false;
  
  try {
    final response = await client
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .maybeSingle();
    
    return response?['is_admin'] == true;
  } catch (e) {
    return false;
  }
});
