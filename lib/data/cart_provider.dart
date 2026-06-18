import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cart_item.dart';
import 'menu_item_model.dart';
import 'restaurant_model.dart';

final _db = FirebaseFirestore.instance;

/// A cart belongs to a single restaurant at a time — orders can't mix items
/// from two different kitchens. [restaurant] is null only when the cart is empty.
class CartState {
  final RestaurantModel? restaurant;
  final List<CartItem> items;

  const CartState({this.restaurant, this.items = const []});

  bool get isEmpty => items.isEmpty;

  /// Whether adding an item from [other] would conflict with what's already
  /// in the cart (i.e. the cart has items from a different restaurant).
  bool conflictsWith(RestaurantModel other) =>
      items.isNotEmpty && restaurant?.id != other.id;
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Adds [item] from [restaurant] to the cart, assuming no conflict.
  /// Callers must resolve restaurant conflicts (via [CartState.conflictsWith])
  /// before calling this — typically by clearing the cart first.
  void add(RestaurantModel restaurant, MenuItemModel item) {
    final items = state.restaurant?.id == restaurant.id ? state.items : const <CartItem>[];
    final index = items.indexWhere((c) => c.item.id == item.id);
    final updated = index >= 0
        ? [
            for (var i = 0; i < items.length; i++)
              if (i == index) items[i].copyWith(quantity: items[i].quantity + 1) else items[i],
          ]
        : [...items, CartItem(item: item)];
    state = CartState(restaurant: restaurant, items: updated);
  }

  void updateQuantity(MenuItemModel item, int quantity) {
    if (quantity <= 0) {
      remove(item);
      return;
    }
    final index = state.items.indexWhere((c) => c.item.name == item.name);
    if (index < 0) return;
    state = CartState(
      restaurant: state.restaurant,
      items: [
        for (var i = 0; i < state.items.length; i++)
          if (i == index) state.items[i].copyWith(quantity: quantity) else state.items[i],
      ],
    );
  }

  void remove(MenuItemModel item) {
    final items = state.items.where((c) => c.item.id != item.id).toList();
    state = CartState(restaurant: items.isEmpty ? null : state.restaurant, items: items);
  }

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).items.fold(0, (sum, i) => sum + i.quantity);
});

final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).items.fold(0.0, (sum, i) => sum + i.total);
});

/// Fallback delivery fee, used until `settings/delivery` loads (or if it's
/// never set up) — keeps the admin-configurable value optional.
const kDefaultDeliveryFee = 35.0;

/// The flat delivery fee, configurable by admins via `settings/delivery` →
/// `flatFee`. Falls back to [kDefaultDeliveryFee] while loading or if unset.
final deliveryFeeProvider = StreamProvider<double>((ref) {
  return _db
      .collection('settings')
      .doc('delivery')
      .snapshots()
      .map((snap) => (snap.data()?['flatFee'] as num?)?.toDouble() ?? kDefaultDeliveryFee);
});

final cartTotalProvider = Provider<double>((ref) {
  final deliveryFee = ref.watch(deliveryFeeProvider).valueOrNull ?? kDefaultDeliveryFee;
  return ref.watch(cartSubtotalProvider) + deliveryFee;
});
