import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';

import '../constants/app_routes.dart';
import '../router/app_router.dart';

/// Wraps `flutter_callkit_incoming` to ring the phone like an incoming call —
/// continuously, full-screen over the lock screen — when a driver gets a new
/// delivery or a restaurant gets a new order. Works even when the app is
/// swiped away/killed (triggered from the high-priority FCM background handler).
class CallService {
  CallService._();

  static StreamSubscription<CallEvent?>? _sub;

  /// Shows the ringing incoming-call screen. Safe to call from the background
  /// FCM isolate.
  static Future<void> showIncoming({
    required String id,
    required String title,
    required String handle,
    required Map<String, dynamic> extra,
  }) async {
    if (kIsWeb) return; // CallKit is mobile-only
    final params = CallKitParams(
      id: id,
      nameCaller: title,
      appName: "Symon's Kitchin",
      handle: handle,
      type: 0, // audio call
      duration: 45000, // ring for up to 45s
      extra: extra,
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        // Native system ringtone — plays reliably on every device (the phone's
        // own ringtone). Custom raw-mp3 ringtones fail silently via Android's
        // RingtoneManager on many OEMs, so we use the guaranteed native path.
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#1A0A00',
        actionColor: '#C8880A',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Incoming Orders',
        isShowFullLockedScreen: true,
        isImportant: true,
        // IMPORTANT: must be false. When true, the plugin just launches the call
        // Activity and NEVER runs showIncomingNotification — the only path that
        // plays the ringtone. With false, it posts a CATEGORY_CALL notification
        // that has a full-screen-intent (still shows the full call screen over
        // the lock screen) AND plays the ring. See CallkitIncomingBroadcastReceiver.
        isFullScreen: false,
        textAccept: 'Accept',
        textDecline: 'Decline',
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Ends any ringing/active call (e.g. once the user is already in the app).
  static Future<void> endAll() async {
    if (kIsWeb) return;
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}
  }

  /// Start listening for Accept taps (routes to the right screen) and handle a
  /// cold start where the app was launched by accepting the call.
  static void init() {
    if (kIsWeb) return; // CallKit is mobile-only
    _sub ??= FlutterCallkitIncoming.onEvent.listen((event) {
      if (event is CallEventActionCallAccept) {
        _route(event.callKitParams.extra);
      }
    });
    _handleColdStartAccept();
  }

  static Future<void> _handleColdStartAccept() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      for (final c in calls) {
        if (c.isAccepted == true) {
          _route(c.extra);
          break;
        }
      }
    } catch (_) {}
  }

  static void _route(Map<dynamic, dynamic>? extra) {
    final type = extra?['type']?.toString();
    if (type == 'new_delivery') {
      appRouter.go(AppRoutes.driverHome);
    } else if (type == 'new_order') {
      final restaurantId = extra?['restaurantId']?.toString();
      if (restaurantId != null && restaurantId.isNotEmpty) {
        appRouter.push(AppRoutes.restaurantOrders, extra: restaurantId);
      } else {
        appRouter.go(AppRoutes.restaurantPortal);
      }
    }
  }
}
