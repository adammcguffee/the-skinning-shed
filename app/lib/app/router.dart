import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/post/post_screen.dart';
import '../features/trophy_wall/trophy_wall_screen.dart';
import '../features/trophy_wall/trophy_detail_screen.dart';
import '../features/land/land_screen.dart';
import '../features/land/land_detail_screen.dart';
import '../features/swap_shop/swap_shop_screen.dart';
import '../features/weather/weather_screen.dart';
import '../features/settings/settings_screen.dart';
import '../shared/widgets/app_scaffold.dart';

/// Navigation shell key for preserving state
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router provider for the app
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // Auth route (outside shell)
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      
      // Main shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppScaffold(child: child),
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
        ],
      ),
      
      // Post trophy (modal / full screen)
      GoRoute(
        path: '/post',
        builder: (context, state) => const PostScreen(),
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
          return LandDetailScreen(listingId: id);
        },
      ),
    ],
  );
});
