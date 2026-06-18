import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'cart_item.dart';
import 'restaurant_model.dart';

/// Ordered to match the steps shown on the tracking screen — index into this
/// list doubles as "how far along" the order is.
const orderStatuses = [
  'placed',
  'confirmed',
  'preparing',
  'driver_assigned',
  'out_for_delivery',
  'delivered',
];

class OrderLineItem {
  final String name;
  final double price;
  final int quantity;
  const OrderLineItem({required this.name, required this.price, required this.quantity});

  Map<String, dynamic> toMap() => {'name': name, 'price': price, 'quantity': quantity};

  factory OrderLineItem.fromMap(Map<String, dynamic> map) => OrderLineItem(
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        quantity: map['quantity'] as int,
      );
}

class FoodOrder {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final List<OrderLineItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String status;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? driverId;
  final String? customerName;
  final String? cancellationReason;
  final String? yocoCheckoutId;

  const FoodOrder({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.status,
    this.createdAt,
    this.deliveredAt,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.driverId,
    this.customerName,
    this.cancellationReason,
    this.yocoCheckoutId,
  });

  int get statusIndex {
    final index = orderStatuses.indexOf(status);
    return index < 0 ? 0 : index;
  }

  factory FoodOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final ts = data['createdAt'];
    final deliveredTs = data['deliveredAt'];
    return FoodOrder(
      id: doc.id,
      restaurantId: data['restaurantId'] as String? ?? '',
      restaurantName: data['restaurantName'] as String? ?? '',
      items: (data['items'] as List<dynamic>? ?? const [])
          .map((m) => OrderLineItem.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? orderStatuses.first,
      createdAt: ts != null ? (ts as Timestamp).toDate() : null,
      deliveredAt: deliveredTs != null ? (deliveredTs as Timestamp).toDate() : null,
      deliveryAddress: data['deliveryAddress'] as String?,
      deliveryLat: (data['deliveryLat'] as num?)?.toDouble(),
      deliveryLng: (data['deliveryLng'] as num?)?.toDouble(),
      driverId: data['driverId'] as String?,
      customerName: data['customerName'] as String?,
      cancellationReason: data['cancellationReason'] as String?,
      yocoCheckoutId: data['yocoCheckoutId'] as String?,
    );
  }
}

class OrderService {
  OrderService._();

  static final _functions = FirebaseFunctions.instanceFor(region: 'africa-south1');

  static Future<void> updateStatus(String orderId, String newStatus) =>
      FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': newStatus});

  /// Creates a new order document for the signed-in customer and returns its id.
  static Future<String> placeOrder({
    required RestaurantModel restaurant,
    required List<CartItem> items,
    required double subtotal,
    required double deliveryFee,
    required double total,
    String deliveryAddress = '',
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    // currentUser can be null on web while Firebase restores the persisted
    // session from IndexedDB — awaiting the stream guarantees it's resolved.
    final user = FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) throw StateError('You need to be signed in to place an order.');

    final ref = await FirebaseFirestore.instance.collection('orders').add({
      'customerId': user.uid,
      'customerEmail': user.email,
      'customerName': user.displayName ?? user.email ?? 'Customer',
      'restaurantId': restaurant.id,
      'restaurantName': '${restaurant.name} ${restaurant.branch}',
      'items': [
        for (final cartItem in items)
          OrderLineItem(name: cartItem.item.name, price: cartItem.item.price, quantity: cartItem.quantity)
              .toMap(),
      ],
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'status': orderStatuses.first,
      'yocoCheckoutId': null,
      'deliveryAddress': deliveryAddress,
      'deliveryLat': ?deliveryLat,
      'deliveryLng': ?deliveryLng,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Customer requests cancellation — saves reason, sets status to cancellation_requested.
  static Future<void> cancelOrder(String orderId, String reason, String previousStatus) =>
      FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'cancellation_requested',
        'cancellationReason': reason,
        'previousStatus': previousStatus,
        'cancellationRequestedAt': FieldValue.serverTimestamp(),
      });

  /// Restaurant rejects the cancellation — restores order to its previous status.
  static Future<void> rejectCancellation(String orderId, String previousStatus) =>
      FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': previousStatus,
        'cancellationReason': FieldValue.delete(),
        'previousStatus': FieldValue.delete(),
      });

  /// Restaurant confirms refund — calls Cloud Function which processes Yoco refund.
  static Future<void> processRefund(String orderId) async {
    await _functions.httpsCallable('processRefund').call({'orderId': orderId});
  }

  /// Driver claims an available order.
  static Future<void> acceptDelivery(String orderId, String driverId) =>
      FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'driverId': driverId,
      });

  /// Driver confirms they have picked up the order.
  static Future<void> confirmPickup(String orderId) =>
      FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'out_for_delivery',
      });

  /// Driver confirms delivery is complete.
  static Future<void> confirmDelivery(String orderId) =>
      FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });
}

/// Streams a single order's live status — this is what the tracking screen watches.
final orderProvider = StreamProvider.family<FoodOrder?, String>((ref, orderId) {
  return FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? FoodOrder.fromDoc(doc) : null);
});

/// Streams the signed-in customer's orders, most recent first — for order history.
final myOrdersProvider = StreamProvider<List<FoodOrder>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('orders')
      .where('customerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(FoodOrder.fromDoc).toList());
});

/// Streams orders that are ready for pickup (driver_assigned, no driver claimed yet).
final availableOrdersProvider = StreamProvider<List<FoodOrder>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'driver_assigned')
      .snapshots()
      .map((snap) => snap.docs
          .map(FoodOrder.fromDoc)
          .where((o) => o.driverId == null || o.driverId!.isEmpty)
          .toList());
});

/// Streams the signed-in driver's currently active delivery (if any).
final myActiveDeliveryProvider = StreamProvider<FoodOrder?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('orders')
      .where('driverId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
        final active = snap.docs
            .map(FoodOrder.fromDoc)
            .where((o) =>
                o.status == 'driver_assigned' || o.status == 'out_for_delivery')
            .toList();
        return active.isEmpty ? null : active.first;
      });
});

/// Streams the signed-in driver's completed deliveries, most recent first —
/// used for the wallet's earnings history.
final myDeliveryHistoryProvider = StreamProvider<List<FoodOrder>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('orders')
      .where('driverId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
        final delivered = snap.docs
            .map(FoodOrder.fromDoc)
            .where((o) => o.status == 'delivered')
            .toList();
        delivered.sort((a, b) {
          final aTime = a.deliveredAt ?? a.createdAt;
          final bTime = b.deliveredAt ?? b.createdAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        return delivered;
      });
});

/// Streams all orders for a given restaurant, sorted newest-first in Dart
/// (single-field Firestore filter — no composite index required).
final restaurantOrdersProvider =
    StreamProvider.family<List<FoodOrder>, String>((ref, restaurantId) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('restaurantId', isEqualTo: restaurantId)
      .snapshots()
      .map((snap) {
        final orders = snap.docs.map(FoodOrder.fromDoc).toList();
        orders.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        return orders;
      });
});
