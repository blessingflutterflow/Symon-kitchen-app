import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

enum DriverStatus { incomplete, pendingReview, approved, rejected, suspended }

DriverStatus _statusFromString(String? v) => switch (v) {
  'pending_review' => DriverStatus.pendingReview,
  'approved' => DriverStatus.approved,
  'rejected' => DriverStatus.rejected,
  'suspended' => DriverStatus.suspended,
  _ => DriverStatus.incomplete,
};

String _statusToString(DriverStatus s) => switch (s) {
  DriverStatus.incomplete => 'incomplete',
  DriverStatus.pendingReview => 'pending_review',
  DriverStatus.approved => 'approved',
  DriverStatus.rejected => 'rejected',
  DriverStatus.suspended => 'suspended',
};

class DriverModel {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String idNumber;
  final String licenceNumber;
  final String vehicleType;
  final String vehicleReg;
  final DriverStatus status;
  final String? rejectionReason;
  final bool isOnline;
  final String? bankName;
  final String? bankCode;
  final String? bankAccountNumber;
  final String? paystackRecipientCode;

  const DriverModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.idNumber,
    required this.licenceNumber,
    required this.vehicleType,
    required this.vehicleReg,
    required this.status,
    this.rejectionReason,
    this.isOnline = false,
    this.bankName,
    this.bankCode,
    this.bankAccountNumber,
    this.paystackRecipientCode,
  });

  bool get hasBankAccount => paystackRecipientCode != null && paystackRecipientCode!.isNotEmpty;

  factory DriverModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DriverModel(
      uid: doc.id,
      name: d['name'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      email: d['email'] as String? ?? '',
      idNumber: d['idNumber'] as String? ?? '',
      licenceNumber: d['licenceNumber'] as String? ?? '',
      vehicleType: d['vehicleType'] as String? ?? '',
      vehicleReg: d['vehicleReg'] as String? ?? '',
      status: _statusFromString(d['status'] as String?),
      rejectionReason: d['rejectionReason'] as String?,
      isOnline: d['isOnline'] as bool? ?? false,
      bankName: d['bankName'] as String?,
      bankCode: d['bankCode'] as String?,
      bankAccountNumber: d['bankAccountNumber'] as String?,
      paystackRecipientCode: d['paystackRecipientCode'] as String?,
    );
  }
}

final _db = FirebaseFirestore.instance;

/// Streams the signed-in driver's profile document.
final myDriverProfileProvider = StreamProvider<DriverModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return _db
      .collection('drivers')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? DriverModel.fromDoc(doc) : null);
});

/// A single automatic payout sent to the driver after a completed delivery.
class DriverPayout {
  final String id;
  final double amountRands;
  final String status; // success | pending | failed | recipient_missing
  final String? orderId;
  final DateTime? createdAt;

  const DriverPayout({
    required this.id,
    required this.amountRands,
    required this.status,
    this.orderId,
    this.createdAt,
  });

  factory DriverPayout.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DriverPayout(
      id: doc.id,
      amountRands: (d['amountRands'] as num?)?.toDouble() ?? 0,
      status: d['status'] as String? ?? 'pending',
      orderId: d['orderId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Streams the signed-in driver's payout history, most recent first.
final myPayoutsProvider = StreamProvider<List<DriverPayout>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return _db
      .collection('payouts')
      .where('driverId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(DriverPayout.fromDoc).toList();
        list.sort((a, b) {
          final at = a.createdAt, bt = b.createdAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
        return list;
      });
});

class DriverService {
  DriverService._();

  /// Submits a driver application — creates/overwrites the drivers doc.
  static Future<void> submitApplication({
    required String name,
    required String phone,
    required String email,
    required String idNumber,
    required String licenceNumber,
    required String vehicleType,
    required String vehicleReg,
  }) async {
    final user =
        FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance.authStateChanges().first;
    final uid = user?.uid;
    if (uid == null) throw StateError('Not signed in.');
    await _db.collection('drivers').doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'idNumber': idNumber.trim(),
      'licenceNumber': licenceNumber.trim(),
      'vehicleType': vehicleType.trim(),
      'vehicleReg': vehicleReg.trim(),
      'status': _statusToString(DriverStatus.pendingReview),
      'isOnline': false,
      'rejectionReason': null,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reapplies after rejection — resets status to pending_review.
  static Future<void> reapply() async {
    final user =
        FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance.authStateChanges().first;
    final uid = user?.uid;
    if (uid == null) return;
    await _db.collection('drivers').doc(uid).update({
      'status': _statusToString(DriverStatus.pendingReview),
      'rejectionReason': FieldValue.delete(),
      'reappliedAt': FieldValue.serverTimestamp(),
    });
  }

  static final _functions = FirebaseFunctions.instanceFor(region: 'africa-south1');

  /// Validates a bank account with Paystack and returns the registered
  /// account-holder name. Throws if the account can't be resolved.
  static Future<String> resolveBankAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    final result = await _functions.httpsCallable('resolveBankAccount').call({
      'accountNumber': accountNumber,
      'bankCode': bankCode,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['accountName'] as String;
  }

  /// Registers the driver's (already-validated) bank account with Paystack and
  /// stores the recipient code, used for automatic per-delivery payouts.
  static Future<void> registerBankAccount({
    required String accountNumber,
    required String bankCode,
    required String bankName,
    required String accountName,
  }) async {
    await _functions.httpsCallable('registerPaystackRecipient').call({
      'accountNumber': accountNumber,
      'bankCode': bankCode,
      'bankName': bankName,
      'accountName': accountName,
    });
  }

  /// Toggles the driver's online/offline state.
  static Future<void> setOnline(String uid, bool online) =>
      _db.collection('drivers').doc(uid).update({'isOnline': online});

  /// Updates the driver's editable profile fields.
  static Future<void> updateProfile({
    required String uid,
    required String name,
    required String phone,
    required String email,
    required String vehicleType,
    required String vehicleReg,
  }) => _db.collection('drivers').doc(uid).update({
    'name': name.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'vehicleType': vehicleType.trim(),
    'vehicleReg': vehicleReg.trim(),
  });
}
