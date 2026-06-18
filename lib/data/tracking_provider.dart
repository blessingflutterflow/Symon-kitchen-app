import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final _db = FirebaseFirestore.instance;

/// A driver's live position, mirrored from `tracking_sessions/{driverId}`.
class DriverLocation {
  final double lat;
  final double lng;
  final double bearing;
  final bool isActive;
  final String driverName;

  const DriverLocation({
    required this.lat,
    required this.lng,
    required this.bearing,
    required this.isActive,
    required this.driverName,
  });

  factory DriverLocation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DriverLocation(
      lat: (d['lat'] as num?)?.toDouble() ?? 0,
      lng: (d['lng'] as num?)?.toDouble() ?? 0,
      bearing: (d['bearing'] as num?)?.toDouble() ?? 0,
      isActive: d['isActive'] as bool? ?? false,
      driverName: d['driverName'] as String? ?? 'Driver',
    );
  }
}

/// Streams a driver's live location from `tracking_sessions/{driverId}`.
final driverTrackingProvider =
    StreamProvider.family<DriverLocation?, String>((ref, driverId) {
      return _db
          .collection('tracking_sessions')
          .doc(driverId)
          .snapshots()
          .map((doc) => doc.exists ? DriverLocation.fromDoc(doc) : null);
    });

/// Writes the signed-in driver's live GPS position to Firestore while online.
class TrackingService {
  TrackingService._();

  static StreamSubscription<Position>? _sub;

  /// Starts streaming the driver's position to `tracking_sessions/{uid}`.
  static Future<void> start(String uid, String driverName) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    await _sub?.cancel();

    await _db.collection('tracking_sessions').doc(uid).set({
      'driverId': uid,
      'driverName': driverName,
      'isActive': true,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _sub =
        Geolocator.getPositionStream(
          // `bestForNavigation` sets `setWaitForAccurateLocation(true)` on
          // Android, which can stall updates indefinitely indoors/poor GPS —
          // `high` still uses GPS but doesn't block on a "perfect" fix.
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) async {
          try {
            await _db.collection('tracking_sessions').doc(uid).set({
              'lat': position.latitude,
              'lng': position.longitude,
              'bearing': position.heading,
              'isActive': true,
              'timestamp': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}
        });
  }

  /// Stops streaming and marks the driver's tracking session inactive.
  static Future<void> stop(String uid) async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _db.collection('tracking_sessions').doc(uid).set({
        'isActive': false,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
