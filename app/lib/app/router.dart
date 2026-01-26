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
import '../features/research/research_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/swap_shop/swap_shop_create_screen.dart';
import '../features/swap_shop/swap_shop_detail_screen.dart';
import '../features/swap_shop/swap_shop_screen.dart';
import '../features/trophy_wall/profile_edit_screen.dart';
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

/// Helper to get current index from location.
/// Indices match _destinationsBase in app_scaffold.dart:
/// 0=Feed, 1=Explore, 2=TrophyWall, 3=Land, 4=Messages,
/// 5=SwapShop, 6=Weather, 7=Research, 8=OfficialLinks, 9=Settings
int _getIndexFromLocation(String location) {
  if (location.startsWith('/explore')) return 1;
  if (location.startsWith('/trophy-wall') || location.startsWith('/profile')) return 2;
  if (location.startsWith('/land')) return 3;
  if (location.startsWith('/messages')) return 4;
  if (location.startsWith('/swap-shop')) return 5;
  if (location.startsWith('/weather')) return 6;
  if (location.startsWith('/research')) return 7;
  if (location.startsWith('/official-links')) return 8;
  if (location.startsWith('/settings')) return 9;
  return 0; // Feed is default
}

/// Router provider for the app.
/// 
/// IMPORTANT: Uses ref.read (not ref.watch) for authNotifier to avoid
/// recreating the GoRouter on every auth state change. The router uses
/// refreshListenable to respond to auth changes, which triggers redirect
/// re-evaluation without rebuilding the router. Rebuilding the router with
/// the same GlobalKey navigator keys causes "Duplicate GlobalKey" crashes.
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authNotifierProvider);
  
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
          
          // Swap Shop
          GoRoute(
            path: '/swap-shop',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SwapShopScreen(),
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
          
          // Official Links (State Wildlife Portals)
          GoRoute(
            path: '/official-links',
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
      
      // Official links admin (admin only)
      GoRoute(
        path: '/admin/official-links',
        builder: (context, state) => const RegulationsAdminScreen(),
      ),
      
      // Post trophy (modal / full screen)
      GoRoute(
        path: '/post',
        builder: (context, state) => const PostScreen(),
      ),
      
      // Swap Shop create/detail (outside shell - full screen)
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
      
      // Profile edit
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditScreen(),
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
