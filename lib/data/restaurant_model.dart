import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

/// Days of the week, Monday-first, used as keys for [RestaurantModel.operatingHours].
const kWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const kWeekdayLabels = {
  'Mon': 'Monday',
  'Tue': 'Tuesday',
  'Wed': 'Wednesday',
  'Thu': 'Thursday',
  'Fri': 'Friday',
  'Sat': 'Saturday',
  'Sun': 'Sunday',
};

/// A restaurant's opening/closing time for a single day of the week.
/// [openTime]/[closeTime] are 24-hour "HH:mm" strings.
class DayHours {
  final bool isOpen;
  final String openTime;
  final String closeTime;

  const DayHours({this.isOpen = true, this.openTime = '09:00', this.closeTime = '21:00'});

  factory DayHours.fromMap(Map<String, dynamic> m) => DayHours(
        isOpen: m['isOpen'] as bool? ?? true,
        openTime: m['open'] as String? ?? '09:00',
        closeTime: m['close'] as String? ?? '21:00',
      );

  Map<String, dynamic> toMap() => {'isOpen': isOpen, 'open': openTime, 'close': closeTime};
}

/// Default schedule for new restaurants and any restaurant created before
/// operating hours were introduced: open every day, 9 AM-9 PM.
Map<String, DayHours> defaultOperatingHours() => {
      for (final day in kWeekdays) day: const DayHours(),
    };

class RestaurantModel {
  final String id;
  final String ownerId;
  final String name;
  final String branch;
  final String address;
  final String tags;
  final String deliveryTime;
  final String minOrder;
  final bool isOpen;
  final double rating;
  final int reviews;
  final String? coverImageUrl;
  final double? lat;
  final double? lng;
  final Map<String, DayHours> operatingHours;
  final DateTime createdAt;
  final String status;

  const RestaurantModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.branch,
    required this.address,
    required this.tags,
    required this.deliveryTime,
    required this.minOrder,
    required this.isOpen,
    required this.rating,
    required this.reviews,
    required this.createdAt,
    this.coverImageUrl,
    this.lat,
    this.lng,
    this.operatingHours = const {},
    this.status = 'active',
  });

  factory RestaurantModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final hoursData = d['operatingHours'] as Map<String, dynamic>?;
    return RestaurantModel(
      id: doc.id,
      ownerId: d['ownerId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      branch: d['branch'] as String? ?? '',
      address: d['address'] as String? ?? '',
      tags: d['tags'] as String? ?? '',
      deliveryTime: d['deliveryTime'] as String? ?? '25–35 min',
      minOrder: d['minOrder'] as String? ?? 'R80',
      isOpen: d['isOpen'] as bool? ?? true,
      rating: (d['rating'] as num?)?.toDouble() ?? 5.0,
      reviews: (d['reviews'] as num?)?.toInt() ?? 0,
      coverImageUrl: d['coverImageUrl'] as String?,
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      operatingHours: {
        for (final day in kWeekdays)
          day: hoursData != null && hoursData[day] != null
              ? DayHours.fromMap(Map<String, dynamic>.from(hoursData[day] as Map))
              : const DayHours(),
      },
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerId': ownerId,
        'name': name,
        'branch': branch,
        'address': address,
        'tags': tags,
        'deliveryTime': deliveryTime,
        'minOrder': minOrder,
        'isOpen': isOpen,
        'rating': rating,
        'reviews': reviews,
        'coverImageUrl': coverImageUrl,
        'lat': lat,
        'lng': lng,
        'operatingHours': operatingHours.map((day, hours) => MapEntry(day, hours.toMap())),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': status,
      };

  Map<String, dynamic> toUpdate() => {
        'name': name,
        'branch': branch,
        'address': address,
        'tags': tags,
        'deliveryTime': deliveryTime,
        'minOrder': minOrder,
        'isOpen': isOpen,
        'coverImageUrl': coverImageUrl,
        'lat': lat,
        'lng': lng,
        'operatingHours': operatingHours.map((day, hours) => MapEntry(day, hours.toMap())),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

final _db = FirebaseFirestore.instance;
final _storage = FirebaseStorage.instance;

/// All restaurants — what the customer home screen browses.
/// Only approved restaurants are shown; pending/suspended ones are filtered
/// out client-side (avoids needing a composite index on status + createdAt).
final restaurantsProvider = StreamProvider<List<RestaurantModel>>((ref) {
  return _db
      .collection('restaurants')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map(RestaurantModel.fromFirestore)
          .where((r) => r.status == 'active')
          .toList());
});

/// The signed-in restaurant owner's own restaurant — null if they haven't set one up yet.
final myRestaurantProvider = StreamProvider<RestaurantModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return _db
      .collection('restaurants')
      .where('ownerId', isEqualTo: uid)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isEmpty ? null : RestaurantModel.fromFirestore(snap.docs.first));
});

/// Uploads a restaurant cover photo to Storage and returns its download URL.
Future<String?> uploadRestaurantImage(Uint8List image, String ownerId) async {
  try {
    final ref = _storage
        .ref()
        .child('restaurant-covers/$ownerId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final task = await ref.putData(image, SettableMetadata(contentType: 'image/jpeg'));
    return await task.ref.getDownloadURL();
  } catch (_) {
    return null;
  }
}

class RestaurantService {
  RestaurantService._();

  /// Creates or updates the signed-in owner's restaurant profile.
  static Future<String> saveRestaurant({
    String? existingId,
    required String name,
    required String branch,
    required String address,
    required String tags,
    required String deliveryTime,
    required String minOrder,
    String? coverImageUrl,
    double? lat,
    double? lng,
    Map<String, DayHours>? operatingHours,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('You need to be signed in.');

    final data = RestaurantModel(
      id: '',
      ownerId: user.uid,
      name: name,
      branch: branch,
      address: address,
      tags: tags,
      deliveryTime: deliveryTime,
      minOrder: minOrder,
      isOpen: true,
      rating: 5.0,
      reviews: 0,
      coverImageUrl: coverImageUrl,
      lat: lat,
      lng: lng,
      operatingHours: operatingHours ?? defaultOperatingHours(),
      createdAt: DateTime.now(),
      // New restaurants require admin approval before they're visible to
      // customers; this is ignored on update since toUpdate() omits status.
      status: existingId == null ? 'pending' : 'active',
    );

    if (existingId != null) {
      await _db.collection('restaurants').doc(existingId).update(data.toUpdate());
      return existingId;
    }
    final doc = await _db.collection('restaurants').add(data.toFirestore());
    return doc.id;
  }

  static Future<void> setOpen(String id, bool isOpen) async {
    await _db.collection('restaurants').doc(id).update({
      'isOpen': isOpen,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes this restaurant, its entire menu, and any uploaded
  /// images. Existing orders are left untouched — they already store their
  /// own copy of the restaurant name and item details.
  static Future<void> deleteRestaurant(RestaurantModel restaurant) async {
    final menuItems = await _db
        .collection('menuItems')
        .where('restaurantId', isEqualTo: restaurant.id)
        .get();

    final batch = _db.batch();
    for (final doc in menuItems.docs) {
      final imageUrl = doc.data()['imageUrl'] as String?;
      if (imageUrl != null) await _deleteStorageFile(imageUrl);
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('restaurants').doc(restaurant.id));
    await batch.commit();

    if (restaurant.coverImageUrl != null) {
      await _deleteStorageFile(restaurant.coverImageUrl!);
    }
  }

  static Future<void> _deleteStorageFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
