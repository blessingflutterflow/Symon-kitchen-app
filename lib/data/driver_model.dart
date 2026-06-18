import 'package:cloud_firestore/cloud_firestore.dart';
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
  });

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
