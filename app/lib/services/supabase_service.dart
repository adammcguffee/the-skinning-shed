import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Auth readiness state.
enum AuthReadyState {
  /// Still recovering session from storage.
  recovering,
  /// Authenticated (session present).
  authenticated,
  /// Not authenticated (no session after recovery).
  unauthenticated,
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
  
  /// Completes when auth session recovery finishes.
  final Completer<void> _authReadyCompleter = Completer<void>();
  
  /// Current auth ready state.
  AuthReadyState _authReadyState = AuthReadyState.recovering;
  
  /// Whether auth recovery has completed.
  bool get isAuthReady => _authReadyCompleter.isCompleted;
  
  /// Current auth ready state.
  AuthReadyState get authReadyState => _authReadyState;
  
  /// Future that completes when auth is ready.
  Future<void> get authReady => _authReadyCompleter.future;
  
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
          autoRefreshToken: true,
          // Required for web: handle OAuth callback URLs
          // Required for all: persist session to storage
        ),
      );
      
      _status = InitStatus.success;
      
      // Wait for auth recovery to complete.
      // Supabase SDK recovers session from storage asynchronously after initialize().
      // We listen for the first auth state change to know when recovery is done.
      _waitForAuthRecovery();
      
      return true;
    } catch (e) {
      _status = InitStatus.failure;
      _errorMessage = 'Failed to initialize Supabase: $e';
      return false;
    }
  }
  
  /// Wait for auth session recovery from storage.
  /// Called immediately after Supabase.initialize() succeeds.
  void _waitForAuthRecovery() {
    final client = Supabase.instance.client;
    
    // Check if we already have a session (happens on some platforms)
    if (client.auth.currentSession != null) {
      _authReadyState = AuthReadyState.authenticated;
      if (!_authReadyCompleter.isCompleted) {
        _authReadyCompleter.complete();
      }
      if (kDebugMode) {
        debugPrint('[SupabaseService] Auth ready: already authenticated');
      }
      return;
    }
    
    // Listen for the first auth state change.
    // On web, Supabase SDK emits INITIAL_SESSION or SIGNED_IN after recovery.
    StreamSubscription<AuthState>? subscription;
    Timer? timeout;
    
    void complete(AuthReadyState state) {
      subscription?.cancel();
      timeout?.cancel();
      _authReadyState = state;
      if (!_authReadyCompleter.isCompleted) {
        _authReadyCompleter.complete();
      }
      if (kDebugMode) {
        debugPrint('[SupabaseService] Auth ready: $state');
      }
    }
    
    subscription = client.auth.onAuthStateChange.listen((state) {
      final event = state.event;
      final session = state.session;
      
      if (kDebugMode) {
        debugPrint('[SupabaseService] Auth event: $event, hasSession: ${session != null}');
      }
      
      // INITIAL_SESSION: SDK has finished loading session from storage
      // SIGNED_IN: User authenticated (fresh login or recovered)
      // SIGNED_OUT: No session found
      // TOKEN_REFRESHED: Session was refreshed (still authenticated)
      if (event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.tokenRefreshed) {
        complete(session != null
            ? AuthReadyState.authenticated
            : AuthReadyState.unauthenticated);
      }
    });
    
    // Timeout: if no auth event within 5 seconds, consider recovery done.
    // This handles edge cases where no event is emitted.
    timeout = Timer(const Duration(seconds: 5), () {
      if (!_authReadyCompleter.isCompleted) {
        final hasSession = client.auth.currentSession != null;
        if (kDebugMode) {
          debugPrint('[SupabaseService] Auth recovery timeout, hasSession: $hasSession');
        }
        complete(hasSession
            ? AuthReadyState.authenticated
            : AuthReadyState.unauthenticated);
      }
    });
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

/// Provider for authentication state stream.
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

/// Provider for auth ready state.
/// Use this to wait for auth recovery before showing login screen.
final authReadyStateProvider = StateNotifierProvider<AuthReadyNotifier, AuthReadyState>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return AuthReadyNotifier(service);
});

/// Notifier that tracks auth ready state.
class AuthReadyNotifier extends StateNotifier<AuthReadyState> {
  AuthReadyNotifier(this._service) : super(AuthReadyState.recovering) {
    _init();
  }
  
  final SupabaseService _service;
  StreamSubscription<AuthState>? _subscription;
  
  void _init() {
    // If auth is already ready, update state immediately
    if (_service.isAuthReady) {
      state = _service.authReadyState;
    } else {
      // Wait for auth ready, then start listening
      _service.authReady.then((_) {
        if (!mounted) return;
        state = _service.authReadyState;
        _startListening();
      });
    }
    
    // Also start listening for ongoing auth changes
    _startListening();
  }
  
  void _startListening() {
    _subscription?.cancel();
    _subscription = _service.authStateChanges?.listen((authState) {
      if (!mounted) return;
      final hasSession = authState.session != null;
      state = hasSession
          ? AuthReadyState.authenticated
          : AuthReadyState.unauthenticated;
    });
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

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
