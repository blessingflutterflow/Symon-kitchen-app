import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_routes.dart';

enum UserRole { customer, restaurantOwner, driver }

UserRole? roleFromString(String? value) => switch (value) {
      'customer' => UserRole.customer,
      'restaurant_owner' => UserRole.restaurantOwner,
      'driver' => UserRole.driver,
      _ => null,
    };

String roleToString(UserRole role) => switch (role) {
      UserRole.customer => 'customer',
      UserRole.restaurantOwner => 'restaurant_owner',
      UserRole.driver => 'driver',
    };

class UserProfile {
  final String uid;
  final String name;
  final UserRole? role;
  final String? homeAddress;
  final double? homeLat;
  final double? homeLng;
  const UserProfile({
    required this.uid,
    required this.name,
    this.role,
    this.homeAddress,
    this.homeLat,
    this.homeLng,
  });

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return UserProfile(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      role: roleFromString(data['role'] as String?),
      homeAddress: data['homeAddress'] as String?,
      homeLat: (data['homeLat'] as num?)?.toDouble(),
      homeLng: (data['homeLng'] as num?)?.toDouble(),
    );
  }
}

/// Streams the current Firebase auth user — null when signed out.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

/// Streams the signed-in user's profile document (name + role) from Firestore.
/// Emits null when signed out or before the profile document has been created.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? UserProfile.fromDoc(doc) : null);
});

/// Decides which screen a signed-in (or signed-out) user should land on,
/// based on their auth state and how far they've gotten through onboarding
/// (profile created? name set? role chosen?). Used by both the splash screen
/// (cold start) and the auth screen (right after sign-in) so the decision
/// lives in exactly one place.
Future<String> resolvePostAuthRoute() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return AppRoutes.auth;

  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (!doc.exists || data?['name'] == null) return AppRoutes.authSetup;

    final role = roleFromString(data?['role'] as String?);
    if (role == null) return AppRoutes.authRole;
    switch (role) {
      case UserRole.customer:
        return AppRoutes.home;
      case UserRole.restaurantOwner:
        return AppRoutes.restaurantPortal;
      case UserRole.driver:
        return AppRoutes.driverEntry;
    }
  } catch (_) {
    return AppRoutes.auth;
  }
}

class AuthService {
  AuthService._();

  static Future<String?> signUp(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not create your account.';
    }
  }

  static Future<String?> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not sign you in.';
    }
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();

  static Future<void> saveName(String name) async {
    final user = FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': name.trim(),
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveRole(UserRole role) async {
    final user = FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'role': roleToString(role),
    }, SetOptions(merge: true));
  }

  /// Saves the customer's single home/delivery address + coordinates —
  /// the address shown on the home screen and pre-filled at checkout.
  static Future<void> saveHomeAddress(String address, double lat, double lng) async {
    final user = FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'homeAddress': address,
      'homeLat': lat,
      'homeLng': lng,
    }, SetOptions(merge: true));
  }
}
