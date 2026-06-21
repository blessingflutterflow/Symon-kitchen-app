import 'package:cloud_functions/cloud_functions.dart';

/// Handles Paystack payment integration via Firebase Cloud Functions.
/// Replaces the previous Yoco integration — Symon's Kitchen now runs fully
/// on Paystack for customer payments, refunds, and driver payouts.
class PaystackService {
  PaystackService._();

  static final _functions = FirebaseFunctions.instanceFor(region: 'africa-south1');

  /// Calls `initializePayment` to create a Paystack transaction + a pending
  /// order in Firestore. Returns the hosted checkout URL and our reference.
  static Future<PaystackInitResult> initializePayment({
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
    return PaystackInitResult(
      authorizationUrl: data['authorizationUrl'] as String,
      reference: data['reference'] as String,
      orderId: data['orderId'] as String,
    );
  }

  /// Calls `verifyPayment` to confirm a Paystack transaction succeeded, then
  /// promotes the pending order to `placed`.
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

class PaystackInitResult {
  final String authorizationUrl;
  final String reference;
  final String orderId;

  const PaystackInitResult({
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
