import 'package:cloud_functions/cloud_functions.dart';

/// Handles Yoco payment integration via Firebase Cloud Functions.
class YocoService {
  YocoService._();

  static final _functions = FirebaseFunctions.instanceFor(region: 'africa-south1');

  /// Calls the `initializePayment` Cloud Function to create a Yoco checkout
  /// session and a pending order in Firestore.
  ///
  /// Returns:
  /// - `authorizationUrl` — the Yoco hosted checkout page URL
  /// - `checkoutId` — the Yoco checkout ID for later verification
  /// - `orderId` — the Firestore pending order ID
  /// - `reference` — the payment reference string
  static Future<YocoCheckoutResult> initializePayment({
    required String restaurantId,
    required String restaurantName,
    required double amountRands,
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
    required double deliveryFee,
    double? deliveryLat,
    double? deliveryLng,
    String? customerName,
  }) async {
    final callable = _functions.httpsCallable('initializePayment');
    final response = await callable.call({
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'amountRands': amountRands,
      'items': items,
      'deliveryAddress': deliveryAddress,
      'deliveryFee': deliveryFee,
      if (deliveryLat != null) 'deliveryLat': deliveryLat,
      if (deliveryLng != null) 'deliveryLng': deliveryLng,
      if (customerName != null) 'customerName': customerName,
    });

    final data = response.data as Map<String, dynamic>;
    return YocoCheckoutResult(
      authorizationUrl: data['authorizationUrl'] as String,
      checkoutId: data['checkoutId'] as String,
      orderId: data['orderId'] as String,
      reference: data['reference'] as String,
    );
  }

  /// Calls the `verifyPayment` Cloud Function to confirm a Yoco checkout
  /// was paid, then promotes the pending order to `placed`.
  static Future<VerifyResult> verifyPayment({
    required String orderId,
    required String checkoutId,
  }) async {
    final callable = _functions.httpsCallable('verifyPayment');
    final response = await callable.call({
      'orderId': orderId,
      'checkoutId': checkoutId,
    });

    final data = response.data as Map<String, dynamic>;
    return VerifyResult(
      status: data['status'] as String,
      orderId: data['orderId'] as String,
    );
  }
}

class YocoCheckoutResult {
  final String authorizationUrl;
  final String checkoutId;
  final String orderId;
  final String reference;

  const YocoCheckoutResult({
    required this.authorizationUrl,
    required this.checkoutId,
    required this.orderId,
    required this.reference,
  });
}

class VerifyResult {
  final String status;
  final String orderId;

  const VerifyResult({required this.status, required this.orderId});
}
