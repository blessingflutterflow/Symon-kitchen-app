import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A portion-size option for a menu item, e.g. "Small Plate" / "Large Plate".
class MenuItemVariant {
  final String label;
  final double price;

  const MenuItemVariant({required this.label, required this.price});

  Map<String, dynamic> toMap() => {'label': label, 'price': price};

  factory MenuItemVariant.fromMap(Map<String, dynamic> m) => MenuItemVariant(
        label: m['label'] as String? ?? '',
        price: (m['price'] as num?)?.toDouble() ?? 0.0,
      );
}

/// A priced add-on for a menu item, e.g. "Beans +R30", "Atchar +R25".
class MenuItemExtra {
  final String name;
  final double price;

  const MenuItemExtra({required this.name, required this.price});

  Map<String, dynamic> toMap() => {'name': name, 'price': price};

  factory MenuItemExtra.fromMap(Map<String, dynamic> m) => MenuItemExtra(
        name: m['name'] as String? ?? '',
        price: (m['price'] as num?)?.toDouble() ?? 0.0,
      );
}

class MenuItemModel {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final String category;
  final double price;
  final bool isAvailable;
  final String? imageUrl;
  final List<MenuItemVariant> variants;
  // Free "choose N sides" selection (e.g. choose any 2 of Chomolia/Cabbage/…).
  final List<String> sideOptions;
  final int sidesAllowed; // how many free sides the customer must pick; 0 = none
  // Priced add-ons the customer can optionally add.
  final List<MenuItemExtra> extras;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MenuItemModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.variants = const [],
    this.sideOptions = const [],
    this.sidesAllowed = 0,
    this.extras = const [],
  });

  bool get hasVariants => variants.isNotEmpty;
  bool get hasSides => sidesAllowed > 0 && sideOptions.isNotEmpty;
  bool get hasExtras => extras.isNotEmpty;

  factory MenuItemModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return MenuItemModel(
      id: doc.id,
      restaurantId: d['restaurantId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: d['category'] as String? ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0.0,
      isAvailable: d['isAvailable'] as bool? ?? true,
      imageUrl: d['imageUrl'] as String?,
      variants: (d['variants'] as List<dynamic>? ?? const [])
          .map((v) => MenuItemVariant.fromMap(Map<String, dynamic>.from(v as Map)))
          .toList(),
      sideOptions: (d['sideOptions'] as List<dynamic>? ?? const [])
          .map((s) => s as String)
          .toList(),
      sidesAllowed: (d['sidesAllowed'] as num?)?.toInt() ?? 0,
      extras: (d['extras'] as List<dynamic>? ?? const [])
          .map((e) => MenuItemExtra.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'restaurantId': restaurantId,
        'name': name,
        'description': description,
        'category': category,
        'price': price,
        'isAvailable': isAvailable,
        'imageUrl': imageUrl,
        'variants': variants.map((v) => v.toMap()).toList(),
        'sideOptions': sideOptions,
        'sidesAllowed': sidesAllowed,
        'extras': extras.map((e) => e.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdate() => {
        'name': name,
        'description': description,
        'category': category,
        'price': price,
        'isAvailable': isAvailable,
        'imageUrl': imageUrl,
        'variants': variants.map((v) => v.toMap()).toList(),
        'sideOptions': sideOptions,
        'sidesAllowed': sidesAllowed,
        'extras': extras.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

const kMenuItemCategories = [
  'Light Meals',
  'Main Meals',
  'Grills',
  'Combos',
  'Platters',
  'Beverages',
  'Extras',
  'Cuts Per Gram',
];

final _db = FirebaseFirestore.instance;
final _storage = FirebaseStorage.instance;

/// Streams a restaurant's available menu items — what customers browse.
final restaurantMenuProvider =
    StreamProvider.family<List<MenuItemModel>, String>((ref, restaurantId) {
  return _db
      .collection('menuItems')
      .where('restaurantId', isEqualTo: restaurantId)
      .where('isAvailable', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.map(MenuItemModel.fromFirestore).toList());
});

/// Streams every menu item belonging to the signed-in owner's restaurant —
/// including unavailable ones, for the management screen.
final myMenuItemsProvider =
    StreamProvider.family<List<MenuItemModel>, String>((ref, restaurantId) {
  return _db
      .collection('menuItems')
      .where('restaurantId', isEqualTo: restaurantId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(MenuItemModel.fromFirestore).toList());
});

/// Uploads a menu item photo to Storage and returns its download URL.
Future<String?> uploadMenuItemImage(Uint8List image, String restaurantId) async {
  try {
    final ref = _storage
        .ref()
        .child('menu-items/$restaurantId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final task = await ref.putData(image, SettableMetadata(contentType: 'image/jpeg'));
    return await task.ref.getDownloadURL();
  } catch (_) {
    return null;
  }
}

class MenuItemService {
  MenuItemService._();

  static Future<String> addItem(MenuItemModel item) async {
    final doc = await _db.collection('menuItems').add(item.toFirestore());
    return doc.id;
  }

  static Future<void> updateItem(String id, MenuItemModel item) async {
    await _db.collection('menuItems').doc(id).update(item.toUpdate());
  }

  static Future<void> toggleAvailability(String id, bool current) async {
    await _db.collection('menuItems').doc(id).update({
      'isAvailable': !current,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteItem(String id) async {
    await _db.collection('menuItems').doc(id).delete();
  }
}
