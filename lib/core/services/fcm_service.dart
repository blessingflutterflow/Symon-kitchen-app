import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_provider.dart';
import '../constants/app_routes.dart';
import '../router/app_router.dart';
import 'call_service.dart';

// ─── Background handler (must be top-level, NOT a class method) ───────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // New-delivery (driver) and new-order (restaurant) alerts arrive as data-only,
  // high-priority messages so this handler runs even when the app is swiped
  // away/killed. We ring the phone like an incoming call — continuously, over
  // the lock screen — until the user accepts or declines.
  final type = message.data['type'];
  if (type == 'new_delivery' || type == 'new_order') {
    await CallService.showIncoming(
      id: (message.data['orderId'] as String?) ?? message.messageId ?? '${message.hashCode}',
      title: type == 'new_delivery' ? '🛵 New Delivery!' : '🛎️ New Order!',
      handle: type == 'new_delivery'
          ? 'Pickup from ${message.data['restaurantName'] ?? 'a restaurant'}'
          : 'A customer just placed an order',
      extra: Map<String, dynamic>.from(message.data),
    );
  } else {
    debugPrint('[FCM] Background message: ${message.notification?.title}');
  }
}

/// Calls [FcmService.init] once the signed-in user's role is known, and
/// again whenever it changes (e.g. right after role selection).
final fcmInitProvider = Provider<void>((ref) {
  final role = ref.watch(userProfileProvider).valueOrNull?.role;
  if (role != null) FcmService.init(role);
});

class FcmService {
  FcmService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifs = FlutterLocalNotificationsPlugin();
  static bool _handlersRegistered = false;
  static String? _initializedForUid;

  static const _channelId = 'symons_kitchen_updates';
  static const _channelName = 'Order & Delivery Updates';
  static const _channelDesc = 'Notifications for order status, new orders, and deliveries';

  // Dedicated high-importance channel for the Uber-style new-delivery alert.
  // NOTE: a channel's sound is locked at creation — bump this id (…_ring, _v2…)
  // whenever the bundled sound changes, or existing installs keep the old one.
  static const _deliveryChannelId = 'new_delivery_ring';
  static const _deliveryChannelName = 'New Delivery Requests';
  static const _deliveryChannelDesc = 'Loud ringing alerts when a new delivery is available';
  // Bundled custom ringtone at android/app/src/main/res/raw/delivery_ring.mp3
  static const _deliverySound = RawResourceAndroidNotificationSound('delivery_ring');

  // Customer "your order is on the way" alert — rings with the same custom sound.
  static const _onWayChannelId = 'order_on_way_ring';
  static const _onWayChannelName = 'Order On The Way';
  static const _onWayChannelDesc = 'Rings when your order is out for delivery';

  /// Call once at app startup, before auth. Initialises the local-notification
  /// plugin and creates the Android channel used for foreground notifications.
  static Future<void> setup() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // firebase_messaging handles this
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifs.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    final android = _localNotifs
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _deliveryChannelId,
      _deliveryChannelName,
      description: _deliveryChannelDesc,
      importance: Importance.max,
      playSound: true,
      sound: _deliverySound,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _onWayChannelId,
      _onWayChannelName,
      description: _onWayChannelDesc,
      importance: Importance.high,
      playSound: true,
      sound: _deliverySound,
    ));
  }

  /// Call once the signed-in user's [role] is known. Saves the FCM token,
  /// registers handlers, and prompts for notification permission.
  static Future<void> init(UserRole role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == _initializedForUid) return;
    _initializedForUid = uid;

    // Save the FCM token FIRST — it's valid regardless of permission state.
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token, role);
      _messaging.onTokenRefresh.listen((t) => _saveToken(t, role));
    } catch (e) {
      debugPrint('[FCM] getToken failed: $e');
    }

    if (!_handlersRegistered) {
      _handlersRegistered = true;
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    }

    // Drivers subscribe to a shared topic — Cloud Functions broadcast new
    // 'driver_assigned' deliveries to it so any online driver can claim one.
    if (role == UserRole.driver) {
      try {
        await _messaging.subscribeToTopic('available_drivers');
      } catch (e) {
        debugPrint('[FCM] subscribeToTopic failed: $e');
      }
    }

    // Android 13+ POST_NOTIFICATIONS permission
    await _localNotifs
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // iOS / general FCM permission flow
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Tapped from terminated — app was closed, user taps notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  // ── Token saving ─────────────────────────────────────────────────────────
  // Always writes to users/ (needed for customer order-status updates).
  // Restaurant owners also get their token saved on their restaurant doc
  // (new-order alerts); drivers on their driver doc (new-delivery alerts).
  static Future<void> _saveToken(String token, UserRole role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );

    try {
      switch (role) {
        case UserRole.driver:
          await firestore.collection('drivers').doc(uid).set(
            {'fcmToken': token},
            SetOptions(merge: true),
          );
          break;
        case UserRole.restaurantOwner:
          final owned = await firestore
              .collection('restaurants')
              .where('ownerId', isEqualTo: uid)
              .limit(1)
              .get();
          if (owned.docs.isNotEmpty) {
            await owned.docs.first.reference.set(
              {'fcmToken': token},
              SetOptions(merge: true),
            );
          }
          break;
        case UserRole.customer:
          break;
      }
    } catch (e) {
      debugPrint('[FCM] Could not save role-specific token: $e');
    }
  }

  // ── Foreground message handler ────────────────────────────────────────────
  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    // New-delivery alerts are handled in-app by the driver screen's looping
    // ring (Phase A), so don't also pop a tray notification in the foreground.
    if (message.data['type'] == 'new_delivery') return;

    // New restaurant orders ring like an incoming call, even in the foreground.
    if (message.data['type'] == 'new_order') {
      await CallService.showIncoming(
        id: (message.data['orderId'] as String?) ?? '${message.hashCode}',
        title: '🛎️ New Order!',
        handle: 'A customer just placed an order',
        extra: Map<String, dynamic>.from(message.data),
      );
      return;
    }

    final n = message.notification;
    if (n == null) return;

    // The customer "on the way" alert rings with the custom sound; everything
    // else uses the normal updates channel.
    final isOnWay = message.data['status'] == 'out_for_delivery';

    await _localNotifs.show(
      id: message.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          isOnWay ? _onWayChannelId : _channelId,
          isOnWay ? _onWayChannelName : _channelName,
          channelDescription: isOnWay ? _onWayChannelDesc : _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          sound: isOnWay ? _deliverySound : null,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Ends any ringing incoming-call screen (once the driver is in the app with
  /// the live order card) so it doesn't keep ringing over the UI.
  static Future<void> cancelDeliveryCall() => CallService.endAll();

  // ── Local notification tap (foreground notification was tapped) ───────────
  static void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      _navigate(jsonDecode(payload) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[FCM] Could not decode notification payload: $e');
    }
  }

  // ── FCM notification tap (from background / terminated) ──────────────────
  static void _handleTap(RemoteMessage message) => _navigate(message.data);

  // ── Routing ────────────────────────────────────────────────────────────────
  static void _navigate(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final orderId = data['orderId'] as String?;
    final restaurantId = data['restaurantId'] as String?;

    switch (type) {
      case 'new_order':
        if (restaurantId != null) {
          appRouter.push(AppRoutes.restaurantOrders, extra: restaurantId);
        }
        break;
      case 'new_delivery':
        appRouter.go(AppRoutes.driverHome);
        break;
      case 'restaurant_approved':
        appRouter.go(AppRoutes.restaurantPortal);
        break;
      case 'order_update':
      case 'order_confirmed':
      default:
        if (orderId != null) {
          appRouter.push(AppRoutes.tracking, extra: orderId);
        }
        break;
    }
  }
}
