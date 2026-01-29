import 'package:flutter/foundation.dart';

/// 🧭 CENTRAL ROUTE DEFINITIONS - SINGLE SOURCE OF TRUTH
/// 
/// All route paths and navigation indices are defined here.
/// Do NOT hardcode route strings elsewhere in the app.

class AppRoutes {
  AppRoutes._();
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ROUTE PATHS (strings used in GoRouter and context.go())
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const String auth = '/auth';
  static const String chooseUsername = '/choose-username';
  static const String feed = '/';
  static const String explore = '/explore';
  static const String discover = '/discover';
  static const String trophyWall = '/trophy-wall';
  static const String land = '/land';
  static const String messages = '/messages';
  static const String swapShop = '/swap-shop';
  static const String clubs = '/clubs';
  static const String openings = '/openings';
  static const String weather = '/weather';
  static const String research = '/research';
  static const String officialLinks = '/official-links';
  static const String settings = '/settings';
  
  // Detail/Create routes
  static const String post = '/post';
  static const String swapShopCreate = '/swap-shop/create';
  static const String landCreate = '/land/create';
  static const String profileEdit = '/profile/edit';
  static const String adminOfficialLinks = '/admin/official-links';
  
  // Clubs routes
  static const String clubsCreate = '/clubs/create';
  static String clubDetail(String id) => '/clubs/$id';
  static String clubJoin(String token) => '/clubs/join/$token';
  
  // Openings routes
  static const String openingsCreate = '/openings/create';
  static String openingDetail(String id) => '/openings/$id';
  
  // Notifications
  static const String notifications = '/notifications';
  
  // Settings sub-pages
  static const String settingsPrivacy = '/settings/privacy';
  static const String settingsTerms = '/settings/terms';
  static const String settingsDisclaimer = '/settings/disclaimer';
  static const String settingsHelp = '/settings/help';
  static const String settingsAbout = '/settings/about';
  static const String settingsFeedback = '/settings/feedback';
  static const String settingsNotifications = '/settings/notifications';
  
  // Admin pages
  static const String adminReports = '/admin/reports';
  
  // Parameterized routes (use these with string interpolation)
  static String conversation(String id) => '/messages/$id';
  static String swapShopDetail(String id) => '/swap-shop/detail/$id';
  static String swapShopEdit(String id) => '/swap-shop/$id/edit';
  static String trophyDetail(String id) => '/trophy/$id';
  static String trophyEdit(String id) => '/trophy/$id/edit';
  static String userProfile(String id) => '/user/$id';
  static String landDetail(String id) => '/land/$id';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION INDICES (must match _destinationsBase order in app_scaffold.dart)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Navigation rail/bottom nav indices.
  /// These MUST match the order in AppScaffold._destinationsBase exactly.
  static const int indexFeed = 0;
  static const int indexExplore = 1;
  static const int indexDiscover = 2;
  static const int indexTrophyWall = 3;
  static const int indexLand = 4;
  static const int indexMessages = 5;
  static const int indexSwapShop = 6;
  static const int indexClubs = 7;
  static const int indexOpenings = 8;
  static const int indexWeather = 9;
  static const int indexResearch = 10;
  static const int indexOfficialLinks = 11;
  static const int indexSettings = 12;
  
  /// Get the route path for a given navigation index.
  static String pathForIndex(int index) {
    switch (index) {
      case indexFeed: return feed;
      case indexExplore: return explore;
      case indexDiscover: return discover;
      case indexTrophyWall: return trophyWall;
      case indexLand: return land;
      case indexMessages: return messages;
      case indexSwapShop: return swapShop;
      case indexClubs: return clubs;
      case indexOpenings: return openings;
      case indexWeather: return weather;
      case indexResearch: return research;
      case indexOfficialLinks: return officialLinks;
      case indexSettings: return settings;
      default: return feed;
    }
  }
  
  /// Get the navigation index for a given location path.
  static int indexForLocation(String location) {
    if (location.startsWith(explore)) return indexExplore;
    if (location.startsWith(discover)) return indexDiscover;
    if (location.startsWith(trophyWall) || location.startsWith('/profile') || location.startsWith('/user/')) return indexTrophyWall;
    if (location.startsWith(land)) return indexLand;
    if (location.startsWith(messages)) return indexMessages;
    if (location.startsWith(swapShop)) return indexSwapShop;
    if (location.startsWith(clubs)) return indexClubs;
    if (location.startsWith(openings)) return indexOpenings;
    if (location.startsWith(weather)) return indexWeather;
    if (location.startsWith(research)) return indexResearch;
    if (location.startsWith(officialLinks)) return indexOfficialLinks;
    if (location.startsWith(settings)) return indexSettings;
    return indexFeed; // Default
  }
  
  /// Get the label for a navigation index (for debugging).
  static String labelForIndex(int index) {
    switch (index) {
      case indexFeed: return 'Feed';
      case indexExplore: return 'Explore';
      case indexDiscover: return 'Discover';
      case indexTrophyWall: return 'Trophy Wall';
      case indexLand: return 'Land';
      case indexMessages: return 'Messages';
      case indexSwapShop: return 'Swap Shop';
      case indexClubs: return 'Clubs';
      case indexOpenings: return 'Openings';
      case indexWeather: return 'Weather';
      case indexResearch: return 'Research';
      case indexOfficialLinks: return 'Official Links';
      case indexSettings: return 'Settings';
      default: return 'Unknown';
    }
  }
}

/// Debug logging for navigation events.
/// Enable/disable with this flag.
const bool kRouteDebugLogging = kDebugMode;

void logNavTap(String label, String path) {
  if (kRouteDebugLogging) {
    debugPrint('NAV_TAP: $label -> $path');
  }
}

void logRouteChange(String location) {
  if (kRouteDebugLogging) {
    debugPrint('ROUTE_NOW: $location');
  }
}
