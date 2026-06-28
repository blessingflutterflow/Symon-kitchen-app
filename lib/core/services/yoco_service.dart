import 'package:cloud_functions/cloud_functions.dart';

/// Handles Yoco payment integration via Firebase Cloud Functions.
/// Symon's Kitchin runs on Yoco for customer payments and refunds. (Driver
/// payouts are settled manually by the business — Yoco has no transfers API.)
class YocoService {
  YocoService._();

  static final _functions = FirebaseFunctions.instanceFor(region: 'africa-south1');

  /// Calls `initializePayment` to create a Yoco checkout + a pending order in
  /// Firestore. Returns the hosted checkout URL and the checkout id (reference).
  static Future<YocoInitResult> initializePayment({
    required String restaurantId,
    required String restaurantName,
    required double amountRands,
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
    required double deliveryFee,
    double? deliveryLat,
    double? deliveryLng,
    String? customerName,
    String? successBaseUrl,
  }) async {
    final response = await _functions.httpsCallable('initializePayment').call({
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'amountRands': amountRands,
      'items': items,
      'deliveryAddress': deliveryAddress,
      'deliveryFee': deliveryFee,
      if (deliveryLat != null) 'deliveryLat': deliveryLat,
      if (deliveryLng != null) 'deliveryLng': deliveryLng,
      if (customerName != null) 'customerName': customerName,
      if (successBaseUrl != null) 'successBaseUrl': successBaseUrl,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return YocoInitResult(
      authorizationUrl: data['authorizationUrl'] as String,
      reference: data['reference'] as String,
      orderId: data['orderId'] as String,
    );
  }

  /// Calls `verifyPayment` to confirm the Yoco checkout completed, then promotes
  /// the pending order to `placed`.
  static Future<VerifyResult> verifyPayment({
    required String orderId,
    String? reference,
  }) async {
    final response = await _functions.httpsCallable('verifyPayment').call({
      'orderId': orderId,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return VerifyResult(
      status: data['status'] as String,
      orderId: data['orderId'] as String,
    );
  }
}

class YocoInitResult {
  final String authorizationUrl;
  final String reference;
  final String orderId;

  const YocoInitResult({
    required this.authorizationUrl,
    required this.reference,
    required this.orderId,
  });
}

class VerifyResult {
  final String status;
  final String orderId;

  const VerifyResult({required this.status, required this.orderId});
}
