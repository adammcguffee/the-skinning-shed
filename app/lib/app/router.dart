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

/// Navigation shell key for preserving state
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Auth state notifier that listens to Supabase auth changes.
/// Also triggers location prefetch in background after auth succeeds.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._service) {
    _subscription = _service.authStateChanges?.listen((state) {
      final wasAuthenticated = _session != null;
      _session = state.session;
      notifyListeners();
      
      // Trigger location prefetch when user becomes authenticated
      if (!wasAuthenticated && _session != null) {
        _triggerLocationPrefetch();
      }
    });
    _session = _service.currentSession;
    
    // If already authenticated on startup, trigger prefetch
    if (_session != null) {
      _triggerLocationPrefetch();
    }
  }

  final SupabaseService _service;
  Session? _session;
  dynamic _subscription;
  bool _didPrefetch = false;

  bool get isAuthenticated => _session != null;
  Session? get session => _session;
  
  /// Trigger location prefetch in background (non-blocking).
  void _triggerLocationPrefetch() {
    if (_didPrefetch) return;
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

/// Router provider for the app
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider);
  
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated = authNotifier.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/auth';
      
      // If not authenticated and not on auth page, redirect to auth
      if (!isAuthenticated && !isAuthRoute) {
        return '/auth';
      }
      
      // If authenticated and on auth page, redirect to home
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }
      
      return null;
    },
    routes: [
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
