import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_screen.dart';
import '../services/location_prefetch_service.dart';
import '../features/explore/explore_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/messages/messages_inbox_screen.dart';
import '../features/messages/conversation_screen.dart';
import '../features/land/land_create_screen.dart';
import '../features/land/land_detail_screen.dart';
import '../features/land/land_screen.dart';
import '../features/post/post_screen.dart';
import '../features/regulations/regulations_screen.dart';
import '../features/regulations/regulations_admin_screen.dart';
import '../features/regulations/state_regulations_screen.dart';
import '../features/research/research_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/swap_shop/swap_shop_create_screen.dart';
import '../features/swap_shop/swap_shop_detail_screen.dart';
import '../features/swap_shop/swap_shop_screen.dart';
import '../features/trophy_wall/trophy_detail_screen.dart';
import '../features/trophy_wall/trophy_wall_screen.dart';
import '../features/weather/weather_screen.dart';
import '../services/supabase_service.dart';
import '../shared/widgets/app_scaffold.dart';
import 'theme/app_colors.dart';

/// Navigation shell key for preserving state
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Auth state notifier that listens to Supabase auth changes.
/// Also triggers location prefetch in background after auth succeeds.
/// 
/// This notifier now waits for auth recovery before reporting state,
/// preventing the flash-to-login problem on page refresh.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._service) {
    _init();
  }

  final SupabaseService _service;
  Session? _session;
  dynamic _subscription;
  bool _didPrefetch = false;
  
  /// Auth is still recovering from storage.
  bool _isRecovering = true;
  
  /// Whether auth is still recovering session from storage.
  bool get isRecovering => _isRecovering;

  bool get isAuthenticated => _session != null;
  Session? get session => _session;
  
  void _init() {
    // Wait for auth recovery before reading session
    _service.authReady.then((_) {
      // Only set session and prefetch if truly authenticated
      if (_service.authReadyState == AuthReadyState.authenticated) {
        _session = _service.currentSession;
        if (_session != null) {
          _triggerLocationPrefetch();
        }
      } else {
        // Ensure session is null if not authenticated
        _session = null;
      }
      _isRecovering = false;
      notifyListeners();
    });
    
    // Listen for ongoing auth changes (AFTER recovery completes)
    _subscription = _service.authStateChanges?.listen((state) {
      final wasAuthenticated = _session != null;
      _session = state.session;
      
      // Only notify and prefetch AFTER recovery is complete
      // During recovery, auth events are handled by the .then() callback above
      if (!_isRecovering) {
        notifyListeners();
        
        // Trigger location prefetch when user becomes newly authenticated
        // (not during initial recovery - that's handled above)
        if (!wasAuthenticated && _session != null) {
          _triggerLocationPrefetch();
        }
      }
    });
  }
  
  /// Trigger location prefetch in background (non-blocking).
  /// Only runs once per app session, and only when authenticated.
  void _triggerLocationPrefetch() {
    if (_didPrefetch) return;
    
    // Double-check we have a valid session before prefetching
    if (_session == null) {
      if (kDebugMode) {
        debugPrint('[AuthNotifier] Skipping prefetch - no session');
      }
      return;
    }
    
    _didPrefetch = true;
    
    // Run in background - don't await, don't block
    Future.microtask(() async {
      try {
        if (kDebugMode) {
          debugPrint('[AuthNotifier] Triggering location prefetch...');
        }
        final result = await LocationPrefetchService.instance.prefetchLocalCountyIfNeeded();
        if (kDebugMode && result != null) {
          debugPrint('[AuthNotifier] Prefetched local county: ${result.label}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthNotifier] Location prefetch error: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for auth notifier
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return AuthNotifier(service);
});

/// Screen shown while auth is recovering.
class _AuthRecoveringScreen extends StatelessWidget {
  const _AuthRecoveringScreen();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reconnecting...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to get current index from location
int _getIndexFromLocation(String location) {
  if (location.startsWith('/explore')) return 1;
  if (location.startsWith('/trophy-wall')) return 2;
  if (location.startsWith('/land')) return 3;
  if (location.startsWith('/messages')) return 4;
  if (location.startsWith('/weather')) return 5;
  if (location.startsWith('/research')) return 6;
  if (location.startsWith('/regulations')) return 7;
  if (location.startsWith('/settings')) return 8;
  return 0; // Feed is default
}

/// Router provider for the app.
/// 
/// IMPORTANT: Uses ref.read (not ref.watch) for authNotifier to avoid
/// recreating the GoRouter on every auth state change. The router uses
/// refreshListenable to respond to auth changes, which triggers redirect
/// without rebuilding the router. Rebuilding the router with the same
/// GlobalKey navigator keys causes "Duplicate GlobalKey" crashes.
final routerProvider = Provider<GoRouter>((ref) {
  // Use ref.read to get authNotifier once. The router will listen to it
  // via refreshListenable, which triggers redirect re-evaluation.
  // Do NOT use ref.watch here - it would recreate the router on every
  // auth change, causing GlobalKey conflicts.
  final authNotifier = ref.read(authNotifierProvider);
  
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isRecovering = authNotifier.isRecovering;
      final isAuthenticated = authNotifier.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/auth';
      final isRecoveringRoute = state.matchedLocation == '/recovering';
      
      // During auth recovery, show the recovering screen
      // (prevents flash-to-login on page refresh)
      if (isRecovering && !isRecoveringRoute) {
        return '/recovering';
      }
      
      // Once recovery is done, leave recovering screen
      if (!isRecovering && isRecoveringRoute) {
        return isAuthenticated ? '/' : '/auth';
      }
      
      // If not authenticated and not on auth page, redirect to auth
      if (!isRecovering && !isAuthenticated && !isAuthRoute) {
        return '/auth';
      }
      
      // If authenticated and on auth page, redirect to home
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }
      
      return null;
    },
    routes: [
      // Auth recovering route (shown during session recovery)
      GoRoute(
        path: '/recovering',
        builder: (context, state) => const _AuthRecoveringScreen(),
      ),
      
      // Auth route (outside shell)
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      
      // Main shell with navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          final currentIndex = _getIndexFromLocation(state.matchedLocation);
          return AppScaffold(
            currentIndex: currentIndex,
            child: child,
          );
        },
        routes: [
          // Feed (Home)
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FeedScreen(),
            ),
          ),
          
          // Explore
          GoRoute(
            path: '/explore',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExploreScreen(),
            ),
          ),
          
          // Weather & Tools
          GoRoute(
            path: '/weather',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WeatherScreen(),
            ),
          ),
          
          // Trophy Wall (Profile)
          GoRoute(
            path: '/trophy-wall',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TrophyWallScreen(),
            ),
          ),
          
          // Land listings
          GoRoute(
            path: '/land',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LandScreen(),
            ),
          ),
          
          // Settings
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
          
          // Research / Patterns
          GoRoute(
            path: '/research',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ResearchScreen(),
            ),
          ),
          
          // Regulations (Seasons & Limits)
          GoRoute(
            path: '/regulations',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RegulationsScreen(),
            ),
          ),
          
          // Messages Inbox
          GoRoute(
            path: '/messages',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MessagesInboxScreen(),
            ),
          ),
        ],
      ),
      
      // Conversation detail (outside shell for full screen)
      GoRoute(
        path: '/messages/:conversationId',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          return ConversationScreen(conversationId: conversationId);
        },
      ),
      
      // State regulations detail (outside shell for full screen)
      GoRoute(
        path: '/regulations/:stateCode',
        builder: (context, state) {
          final stateCode = state.pathParameters['stateCode']!;
          return StateRegulationsScreen(stateCode: stateCode);
        },
      ),
      
      // Regulations admin (admin only)
      GoRoute(
        path: '/admin/regulations',
        builder: (context, state) => const RegulationsAdminScreen(),
      ),
      
      // Post trophy (modal / full screen)
      GoRoute(
        path: '/post',
        builder: (context, state) => const PostScreen(),
      ),
      
      // Swap Shop
      GoRoute(
        path: '/swap-shop',
        builder: (context, state) => const SwapShopScreen(),
      ),
      GoRoute(
        path: '/swap-shop/create',
        builder: (context, state) => const SwapShopCreateScreen(),
      ),
      GoRoute(
        path: '/swap-shop/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SwapShopDetailScreen(listingId: id);
        },
      ),
      
      // Land create (supports ?mode=lease|sale query param)
      GoRoute(
        path: '/land/create',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return LandCreateScreen(initialMode: mode);
        },
      ),
      
      // Trophy detail
      GoRoute(
        path: '/trophy/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TrophyDetailScreen(trophyId: id);
        },
      ),
      
      // User trophy wall (other users)
      GoRoute(
        path: '/user/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TrophyWallScreen(userId: id);
        },
      ),
      
      // Land detail
      GoRoute(
        path: '/land/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return LandDetailScreen(landId: id);
        },
      ),
    ],
  );
});
