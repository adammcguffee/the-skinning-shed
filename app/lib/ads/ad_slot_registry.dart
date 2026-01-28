/// Ad Slot Registry — Single source of truth for all ad slot keys.
///
/// This file defines all valid page/position combinations used for ad targeting.
/// Use these constants in:
/// - Ad slot widgets
/// - Seeding scripts
/// - Debug overlays
/// - Analytics

import '../services/ad_service.dart';

/// Represents a single ad slot location.
class AdSlotKey {
  const AdSlotKey(this.page, this.position);

  final String page;
  final String position;

  String get key => '$page:$position';

  @override
  String toString() => key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdSlotKey &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          position == other.position;

  @override
  int get hashCode => page.hashCode ^ position.hashCode;
}

/// All ad slot keys used in the app.
/// Each page has left and right positions for header ads.
abstract final class AdSlotRegistry {
  // Feed page slots
  static const feedLeft = AdSlotKey(AdPages.feed, AdPosition.left);
  static const feedRight = AdSlotKey(AdPages.feed, AdPosition.right);

  // Explore page slots
  static const exploreLeft = AdSlotKey(AdPages.explore, AdPosition.left);
  static const exploreRight = AdSlotKey(AdPages.explore, AdPosition.right);

  // Trophy Wall page slots
  static const trophyWallLeft = AdSlotKey(AdPages.trophyWall, AdPosition.left);
  static const trophyWallRight = AdSlotKey(AdPages.trophyWall, AdPosition.right);

  // Land page slots
  static const landLeft = AdSlotKey(AdPages.land, AdPosition.left);
  static const landRight = AdSlotKey(AdPages.land, AdPosition.right);

  // Messages page slots
  static const messagesLeft = AdSlotKey(AdPages.messages, AdPosition.left);
  static const messagesRight = AdSlotKey(AdPages.messages, AdPosition.right);

  // Weather page slots
  static const weatherLeft = AdSlotKey(AdPages.weather, AdPosition.left);
  static const weatherRight = AdSlotKey(AdPages.weather, AdPosition.right);

  // Research page slots
  static const researchLeft = AdSlotKey(AdPages.research, AdPosition.left);
  static const researchRight = AdSlotKey(AdPages.research, AdPosition.right);

  // Official Links page slots
  static const officialLinksLeft = AdSlotKey(AdPages.officialLinks, AdPosition.left);
  static const officialLinksRight = AdSlotKey(AdPages.officialLinks, AdPosition.right);

  // Settings page slots
  static const settingsLeft = AdSlotKey(AdPages.settings, AdPosition.left);
  static const settingsRight = AdSlotKey(AdPages.settings, AdPosition.right);

  // Swap Shop page slots
  static const swapShopLeft = AdSlotKey(AdPages.swapShop, AdPosition.left);
  static const swapShopRight = AdSlotKey(AdPages.swapShop, AdPosition.right);

  /// All defined ad slots in the app.
  static const List<AdSlotKey> all = [
    feedLeft,
    feedRight,
    exploreLeft,
    exploreRight,
    trophyWallLeft,
    trophyWallRight,
    landLeft,
    landRight,
    messagesLeft,
    messagesRight,
    weatherLeft,
    weatherRight,
    researchLeft,
    researchRight,
    officialLinksLeft,
    officialLinksRight,
    settingsLeft,
    settingsRight,
    swapShopLeft,
    swapShopRight,
  ];

  /// All unique pages.
  static const List<String> allPages = [
    AdPages.feed,
    AdPages.explore,
    AdPages.trophyWall,
    AdPages.land,
    AdPages.messages,
    AdPages.weather,
    AdPages.research,
    AdPages.officialLinks,
    AdPages.settings,
    AdPages.swapShop,
  ];

  /// Get slots for a specific page.
  static List<AdSlotKey> forPage(String page) {
    return all.where((slot) => slot.page == page).toList();
  }
}
