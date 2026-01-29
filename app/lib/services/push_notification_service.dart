import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Firebase imports - may fail if not configured
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'supabase_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    if (kDebugMode) {
      debugPrint('[Push] Background message: ${message.messageId}');
    }
  } catch (e) {
    // Firebase not configured - ignore
  }
}

/// Push notification service singleton
class PushNotificationService {
  PushNotificationService._();
  
  static final PushNotificationService instance = PushNotificationService._();
  
  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  
  GoRouter? _router;
  bool _initialized = false;
  String? _pendingRoute;
  
  /// Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'skinning_shed_notifications',
    'Skinning Shed Notifications',
    description: 'Push notifications from The Skinning Shed',
    importance: Importance.high,
    playSound: true,
  );
  
  /// Initialize push notifications
  Future<void> initialize({GoRouter? router}) async {
    if (_initialized) return;
    
    _router = router;
    
    // Skip on web for now
    if (kIsWeb) {
      if (kDebugMode) {
        debugPrint('[Push] Web push deferred - skipping initialization');
      }
      return;
    }
    
    try {
      // Initialize Firebase Messaging
      _messaging = FirebaseMessaging.instance;
      
      // Set up background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      
      // Initialize local notifications for foreground
      await _initializeLocalNotifications();
      
      // Listen for foreground messages
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
      // Check for initial message (cold start)
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
      
      // Listen for token refresh
      _tokenRefreshSubscription = _messaging!.onTokenRefresh.listen(_onTokenRefresh);
      
      _initialized = true;
      
      if (kDebugMode) {
        debugPrint('[Push] Service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] Initialization error: $e');
      }
    }
  }
  
  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
    
    // Create Android notification channel
    if (Platform.isAndroid) {
      await _localNotifications!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }
  
  /// Request notification permissions (iOS)
  Future<bool> requestPermission() async {
    if (_messaging == null) return false;
    
    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      
      if (kDebugMode) {
        debugPrint('[Push] Permission status: ${settings.authorizationStatus}');
      }
      
      return granted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] Permission request error: $e');
      }
      return false;
    }
  }
  
  /// Register device token with Supabase
  Future<void> registerToken() async {
    if (_messaging == null) return;
    
    final client = SupabaseService.instance.client;
    final userId = client?.auth.currentUser?.id;
    
    if (userId == null) {
      if (kDebugMode) {
        debugPrint('[Push] Cannot register token: user not logged in');
      }
      return;
    }
    
    try {
      // Get FCM token
      final token = await _messaging!.getToken();
      
      if (token == null) {
        if (kDebugMode) {
          debugPrint('[Push] Failed to get FCM token');
        }
        return;
      }
      
      // Determine platform
      final platform = Platform.isIOS ? 'ios' : 'android';
      
      // Upsert token to Supabase
      await client!.from('device_push_tokens').upsert(
        {
          'user_id': userId,
          'platform': platform,
          'token': token,
          'last_seen_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id, token',
      );
      
      if (kDebugMode) {
        debugPrint('[Push] Token registered: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] Token registration error: $e');
      }
    }
  }
  
  /// Handle token refresh
  void _onTokenRefresh(String token) {
    if (kDebugMode) {
      debugPrint('[Push] Token refreshed');
    }
    registerToken();
  }
  
  /// Handle foreground message - show local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('[Push] Foreground message: ${message.notification?.title}');
    }
    
    final notification = message.notification;
    if (notification == null || _localNotifications == null) return;
    
    // Show local notification
    await _localNotifications!.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['route'],
    );
  }
  
  /// Handle notification tap from FCM
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[Push] Notification tapped: ${message.data}');
    }
    
    final route = message.data['route'] as String?;
    if (route != null) {
      _navigateToRoute(route);
    }
  }
  
  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('[Push] Local notification tapped: ${response.payload}');
    }
    
    final route = response.payload;
    if (route != null && route.isNotEmpty) {
      _navigateToRoute(route);
    }
  }
  
  /// Navigate to a route from notification
  void _navigateToRoute(String route) {
    if (_router != null) {
      _router!.push(route);
    } else {
      // Store for later if router not ready
      _pendingRoute = route;
    }
  }
  
  /// Set router reference (call after router is ready)
  void setRouter(GoRouter router) {
    _router = router;
    
    // Handle pending route
    if (_pendingRoute != null) {
      _router!.push(_pendingRoute!);
      _pendingRoute = null;
    }
  }
  
  /// Unregister token on logout
  Future<void> unregisterToken() async {
    if (_messaging == null) return;
    
    final client = SupabaseService.instance.client;
    final userId = client?.auth.currentUser?.id;
    
    if (userId == null) return;
    
    try {
      final token = await _messaging!.getToken();
      if (token != null) {
        await client!
            .from('device_push_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('token', token);
        
        if (kDebugMode) {
          debugPrint('[Push] Token unregistered');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] Token unregister error: $e');
      }
    }
  }
  
  /// Dispose subscriptions
  void dispose() {
    _foregroundSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
  }
}

// =====================
// NOTIFICATION DATA SERVICE
// =====================

/// Notification model
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });
  
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;
  
  String? get route => data['route'] as String?;
  
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Notification preferences model
class NotificationPrefs {
  const NotificationPrefs({
    this.pushEnabled = true,
    this.clubPostPush = true,
    this.standPush = true,
    this.messagePush = true,
    this.openingsPush = true,
  });
  
  final bool pushEnabled;
  final bool clubPostPush;
  final bool standPush;
  final bool messagePush;
  final bool openingsPush;
  
  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      pushEnabled: json['push_enabled'] as bool? ?? true,
      clubPostPush: json['club_post_push'] as bool? ?? true,
      standPush: json['stand_push'] as bool? ?? true,
      messagePush: json['message_push'] as bool? ?? true,
      openingsPush: json['openings_push'] as bool? ?? true,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'push_enabled': pushEnabled,
    'club_post_push': clubPostPush,
    'stand_push': standPush,
    'message_push': messagePush,
    'openings_push': openingsPush,
    'updated_at': DateTime.now().toIso8601String(),
  };
  
  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? clubPostPush,
    bool? standPush,
    bool? messagePush,
    bool? openingsPush,
  }) {
    return NotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      clubPostPush: clubPostPush ?? this.clubPostPush,
      standPush: standPush ?? this.standPush,
      messagePush: messagePush ?? this.messagePush,
      openingsPush: openingsPush ?? this.openingsPush,
    );
  }
}

/// Notifications data service
class NotificationsService {
  NotificationsService(this._client);
  
  final SupabaseClient? _client;
  
  /// Get notifications for current user
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    if (_client == null) return [];
    
    try {
      final response = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      
      return (response as List)
          .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationsService] Error getting notifications: $e');
      }
      return [];
    }
  }
  
  /// Get unread count
  Future<int> getUnreadCount() async {
    if (_client == null) return 0;
    
    try {
      final result = await _client.rpc('get_unread_notification_count');
      return result as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }
  
  /// Mark notification as read
  Future<bool> markRead(String notificationId) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Mark multiple as read
  Future<bool> markMultipleRead(List<String> notificationIds) async {
    if (_client == null) return false;
    
    try {
      await _client.rpc('mark_notifications_read', params: {
        'p_notification_ids': notificationIds,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Mark all as read
  Future<bool> markAllRead() async {
    if (_client == null) return false;
    
    try {
      await _client.rpc('mark_all_notifications_read');
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    if (_client == null) return false;
    
    try {
      await _client
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get notification preferences
  Future<NotificationPrefs> getPreferences() async {
    if (_client == null) return const NotificationPrefs();
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const NotificationPrefs();
    
    try {
      final response = await _client
          .from('user_notification_prefs')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null) {
        return NotificationPrefs.fromJson(response);
      }
      
      // Create default prefs if not exists
      await _client.from('user_notification_prefs').insert({
        'user_id': userId,
      });
      
      return const NotificationPrefs();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationsService] Error getting prefs: $e');
      }
      return const NotificationPrefs();
    }
  }
  
  /// Update notification preferences
  Future<bool> updatePreferences(NotificationPrefs prefs) async {
    if (_client == null) return false;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      await _client
          .from('user_notification_prefs')
          .upsert({
            'user_id': userId,
            ...prefs.toJson(),
          });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationsService] Error updating prefs: $e');
      }
      return false;
    }
  }
}

// =====================
// PROVIDERS
// =====================

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NotificationsService(client);
});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final service = ref.watch(notificationsServiceProvider);
  return service.getNotifications();
});

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(notificationsServiceProvider);
  return service.getUnreadCount();
});

final notificationPrefsProvider = FutureProvider.autoDispose<NotificationPrefs>((ref) async {
  final service = ref.watch(notificationsServiceProvider);
  return service.getPreferences();
});
