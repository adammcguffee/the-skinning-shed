import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_screen.dart';
import '../features/auth/choose_username_screen.dart';
import '../navigation/app_routes.dart';
import '../services/location_prefetch_service.dart';
import '../features/discover/discover_screen.dart';
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
import '../features/settings/pages/privacy_policy_page.dart';
import '../features/settings/pages/terms_of_service_page.dart';
import '../features/settings/pages/content_disclaimer_page.dart';
import '../features/settings/pages/help_center_page.dart';
import '../features/settings/pages/about_page.dart';
import '../features/settings/pages/feedback_page.dart';
import '../features/settings/pages/admin_reports_page.dart';
import '../features/swap_shop/swap_shop_create_screen.dart';
import '../features/swap_shop/swap_shop_detail_screen.dart';
import '../features/swap_shop/swap_shop_screen.dart';
import '../features/trophy_wall/profile_edit_screen.dart';
import '../features/trophy_wall/trophy_detail_screen.dart';
import '../features/trophy_wall/trophy_edit_screen.dart';
import '../features/trophy_wall/trophy_wall_screen.dart';
import '../features/swap_shop/swap_shop_edit_screen.dart';
import '../features/clubs/clubs_home_screen.dart';
import '../features/clubs/create_club_screen.dart';
import '../features/clubs/club_detail_screen.dart';
import '../features/clubs/club_join_screen.dart';
import '../features/clubs/club_preview_screen.dart';
import '../features/clubs/club_settings_screen.dart';
import '../features/openings/openings_screen.dart';
import '../features/openings/opening_detail_screen.dart';
import '../features/openings/create_opening_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/settings/pages/notifications_settings_page.dart';
import '../features/weather/weather_screen.dart';
import '../services/supabase_service.dart';
import '../shared/widgets/app_scaffold.dart';

/// Navigation shell key for preserving state
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Auth state notifier that listens to Supabase auth changes.
/// Also triggers location prefetch in background after auth succeeds.
/// Tracks whether user needs to choose a username.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._service) {
    _subscription = _service.authStateChanges?.listen((state) {
      final wasAuthenticated = _session != null;
      _session = state.session;
      
      // Reset username check on auth change
      if (wasAuthenticated != (_session != null)) {
        _hasCheckedUsername = false;
        _needsUsername = false;
      }
      
      notifyListeners();
      
      // Trigger location prefetch when user becomes authenticated
      if (!wasAuthenticated && _session != null) {
        _triggerLocationPrefetch();
        _checkUsernameNeeded();
      }
    });
    _session = _service.currentSession;
    
    // If already authenticated on startup, trigger prefetch and username check
    if (_session != null) {
      _triggerLocationPrefetch();
      _checkUsernameNeeded();
    }
  }

  final SupabaseService _service;
  Session? _session;
  dynamic _subscription;
  bool _didPrefetch = false;
  
  /// Username tracking
  bool _hasCheckedUsername = false;
  bool _needsUsername = false;

  bool get isAuthenticated => _session != null;
  Session? get session => _session;
  
  /// Whether we've checked if username is needed.
  bool get hasCheckedUsername => _hasCheckedUsername;
  
  /// Whether the user needs to choose a username.
  bool get needsUsername => _needsUsername;
  
  /// Check if the user needs to set a username.
  Future<void> _checkUsernameNeeded() async {
    if (_hasCheckedUsername) return;
    
    final client = _service.client;
    if (client == null) return;
    
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    
    try {
      final response = await client
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .maybeSingle();
      
      final username = response?['username'] as String?;
      _hasCheckedUsername = true;
      _needsUsername = username == null || username.isEmpty;
      
      if (kDebugMode) {
        debugPrint('[AuthNotifier] Username check: needsUsername=$_needsUsername');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthNotifier] Error checking username: $e');
      }
      // On error, assume we don't need username to avoid blocking
      _hasCheckedUsername = true;
      _needsUsername = false;
      notifyListeners();
    }
  }
  
  /// Force re-check username (call after username is set).
  void markUsernameSet() {
    _hasCheckedUsername = true;
    _needsUsername = false;
    notifyListeners();
  }
  
  /// Force refresh username check.
  Future<void> refreshUsernameCheck() async {
    _hasCheckedUsername = false;
    await _checkUsernameNeeded();
  }
  
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
/// Uses centralized AppRoutes for single source of truth.
int _getIndexFromLocation(String location) {
  return AppRoutes.indexForLocation(location);
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
    initialLocation: AppRoutes.feed,
    refreshListenable: authNotifier,
    debugLogDiagnostics: kDebugMode, // Log route changes in debug mode
    redirect: (context, state) {
      // Log route changes for debugging
      logRouteChange(state.matchedLocation);
      
      final isAuthenticated = authNotifier.isAuthenticated;
      final isAuthRoute = state.matchedLocation == AppRoutes.auth;
      final isChooseUsernameRoute = state.matchedLocation == AppRoutes.chooseUsername;
      
      // If not authenticated and not on auth page, redirect to auth
      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.auth;
      }
      
      // If authenticated and on auth page, redirect to home (or choose-username if needed)
      if (isAuthenticated && isAuthRoute) {
        if (authNotifier.hasCheckedUsername && authNotifier.needsUsername) {
          return AppRoutes.chooseUsername;
        }
        return AppRoutes.feed;
      }
      
      // If authenticated, username check complete, and username is needed
      // Redirect to choose-username (unless already there)
      if (isAuthenticated && 
          authNotifier.hasCheckedUsername && 
          authNotifier.needsUsername && 
          !isChooseUsernameRoute) {
        return AppRoutes.chooseUsername;
      }
      
      return null;
    },
    routes: [
      // Auth route (outside shell)
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      
      // Choose username route (outside shell - required flow)
      GoRoute(
        path: AppRoutes.chooseUsername,
        builder: (context, state) => const ChooseUsernameScreen(),
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
          // Feed (Home) - supports ?category= query param
          GoRoute(
            path: AppRoutes.feed,
            pageBuilder: (context, state) {
              final category = state.uri.queryParameters['category'];
              return NoTransitionPage(
                child: FeedScreen(initialCategory: category),
              );
            },
          ),
          
          // Explore
          GoRoute(
            path: AppRoutes.explore,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExploreScreen(),
            ),
          ),
          
          // Discover (People)
          GoRoute(
            path: AppRoutes.discover,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DiscoverScreen(),
            ),
          ),
          
          // Weather & Tools
          GoRoute(
            path: AppRoutes.weather,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WeatherScreen(),
            ),
          ),
          
          // Trophy Wall (Profile)
          GoRoute(
            path: AppRoutes.trophyWall,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TrophyWallScreen(),
            ),
          ),
          
          // Land listings
          GoRoute(
            path: AppRoutes.land,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LandScreen(),
            ),
          ),
          
          // Swap Shop
          GoRoute(
            path: AppRoutes.swapShop,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SwapShopScreen(),
            ),
          ),
          
          // Clubs
          GoRoute(
            path: AppRoutes.clubs,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ClubsHomeScreen(),
            ),
          ),
          
          // Openings
          GoRoute(
            path: AppRoutes.openings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OpeningsScreen(),
            ),
          ),
          
          // Settings
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
          
          // Research / Patterns
          GoRoute(
            path: AppRoutes.research,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ResearchScreen(),
            ),
          ),
          
          // Official Links (State Wildlife Portals)
          GoRoute(
            path: AppRoutes.officialLinks,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RegulationsScreen(),
            ),
          ),
          
          // Messages Inbox
          GoRoute(
            path: AppRoutes.messages,
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
      
      // Official links admin (admin only - protected)
      GoRoute(
        path: AppRoutes.adminOfficialLinks,
        builder: (context, state) => const RegulationsAdminScreen(),
        redirect: (context, state) async {
          // Check admin status before allowing access
          final client = SupabaseService.instance.client;
          if (client == null) return AppRoutes.feed;
          
          final userId = client.auth.currentUser?.id;
          if (userId == null) return AppRoutes.feed;
          
          try {
            final response = await client
                .from('profiles')
                .select('is_admin')
                .eq('id', userId)
                .maybeSingle();
            
            final isAdmin = response?['is_admin'] == true;
            if (!isAdmin) {
              return AppRoutes.feed; // Redirect non-admins to home
            }
          } catch (e) {
            return AppRoutes.feed; // On error, redirect to home
          }
          
          return null; // Allow access
        },
      ),
      
      // Admin reports (admin only - protected)
      GoRoute(
        path: AppRoutes.adminReports,
        builder: (context, state) => const AdminReportsPage(),
        redirect: (context, state) async {
          // Check admin status before allowing access
          final client = SupabaseService.instance.client;
          if (client == null) return AppRoutes.feed;
          
          final userId = client.auth.currentUser?.id;
          if (userId == null) return AppRoutes.feed;
          
          try {
            final response = await client
                .from('profiles')
                .select('is_admin')
                .eq('id', userId)
                .maybeSingle();
            
            final isAdmin = response?['is_admin'] == true;
            if (!isAdmin) {
              return AppRoutes.feed; // Redirect non-admins to home
            }
          } catch (e) {
            return AppRoutes.feed; // On error, redirect to home
          }
          
          return null; // Allow access
        },
      ),
      
      // Post trophy (modal / full screen)
      GoRoute(
        path: AppRoutes.post,
        builder: (context, state) => const PostScreen(),
      ),
      
      // Swap Shop create/detail (outside shell - full screen)
      GoRoute(
        path: AppRoutes.swapShopCreate,
        builder: (context, state) => const SwapShopCreateScreen(),
      ),
      GoRoute(
        path: '/swap-shop/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SwapShopDetailScreen(listingId: id);
        },
      ),
      
      // Swap Shop edit (owner only)
      GoRoute(
        path: '/swap-shop/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SwapShopEditScreen(listingId: id);
        },
      ),
      
      // Clubs routes (outside shell - full screen)
      GoRoute(
        path: AppRoutes.clubsCreate,
        builder: (context, state) => const CreateClubScreen(),
      ),
      GoRoute(
        path: '/clubs/preview/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClubPreviewScreen(clubId: id);
        },
      ),
      GoRoute(
        path: '/clubs/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClubDetailScreen(clubId: id);
        },
      ),
      GoRoute(
        path: '/clubs/join/:token',
        builder: (context, state) {
          final token = state.pathParameters['token']!;
          return ClubJoinScreen(token: token);
        },
      ),
      GoRoute(
        path: '/clubs/:id/settings',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClubSettingsScreen(clubId: id);
        },
      ),
      
      // Openings routes
      GoRoute(
        path: AppRoutes.openingsCreate,
        builder: (context, state) => const CreateOpeningScreen(),
      ),
      GoRoute(
        path: '/openings/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OpeningDetailScreen(openingId: id);
        },
      ),
      
      // Land create (supports ?mode=lease|sale query param)
      GoRoute(
        path: AppRoutes.landCreate,
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
      
      // Trophy edit (owner only)
      GoRoute(
        path: '/trophy/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TrophyEditScreen(trophyId: id);
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
        path: AppRoutes.profileEdit,
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
      
      // Settings pages
      GoRoute(
        path: AppRoutes.settingsPrivacy,
        builder: (context, state) => const PrivacyPolicyPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsTerms,
        builder: (context, state) => const TermsOfServicePage(),
      ),
      GoRoute(
        path: AppRoutes.settingsDisclaimer,
        builder: (context, state) => const ContentDisclaimerPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsHelp,
        builder: (context, state) => const HelpCenterPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsAbout,
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsFeedback,
        builder: (context, state) => const FeedbackPage(),
      ),
      
      // Notifications
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsNotifications,
        builder: (context, state) => const NotificationsSettingsPage(),
      ),
    ],
  );
});
