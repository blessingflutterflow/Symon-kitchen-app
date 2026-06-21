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

  /// Adds a fully-configured [line] (with its chosen size/sides/extras) from
  /// [restaurant]. If an identical configuration is already in the cart, its
  /// quantity is increased instead of adding a duplicate line. Callers must
  /// resolve restaurant conflicts (via [CartState.conflictsWith]) first.
  void addConfigured(RestaurantModel restaurant, CartItem line) {
    final items = state.restaurant?.id == restaurant.id ? state.items : const <CartItem>[];
    final index = items.indexWhere((c) => c.configKey == line.configKey);
    final updated = index >= 0
        ? [
            for (var i = 0; i < items.length; i++)
              if (i == index)
                items[i].copyWith(quantity: items[i].quantity + line.quantity)
              else
                items[i],
          ]
        : [...items, line];
    state = CartState(restaurant: restaurant, items: updated);
  }

  /// Quick add for a simple dish with no size/sides/extras.
  void add(RestaurantModel restaurant, MenuItemModel item) {
    addConfigured(restaurant, CartItem(item: item));
  }

  void updateQuantityAt(int index, int quantity) {
    if (index < 0 || index >= state.items.length) return;
    if (quantity <= 0) {
      removeAt(index);
      return;
    }
    state = CartState(
      restaurant: state.restaurant,
      items: [
        for (var i = 0; i < state.items.length; i++)
          if (i == index) state.items[i].copyWith(quantity: quantity) else state.items[i],
      ],
    );
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.items.length) return;
    final items = [...state.items]..removeAt(index);
    state = CartState(restaurant: items.isEmpty ? null : state.restaurant, items: items);
  }

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).items.fold(0, (sum, i) => sum + i.quantity);
});

/// Applies the admin-set commission markup to a base price, rounded to the
/// nearest cent so displayed prices and charged amounts always agree.
/// Commission is a markup on the *product* price only — never the delivery fee.
double applyCommission(double base, double percent) {
  final marked = base * (1 + percent / 100);
  return (marked * 100).roundToDouble() / 100;
}

/// The commission markup percentage, configurable by admins via
/// `settings/commission` → `percent`. Defaults to 0 (no markup) while loading
/// or if never set.
final commissionProvider = StreamProvider<double>((ref) {
  return _db
      .collection('settings')
      .doc('commission')
      .snapshots()
      .map((snap) => (snap.data()?['percent'] as num?)?.toDouble() ?? 0.0);
});

/// Cart subtotal with the commission markup baked into each line, so it matches
/// the marked-up prices the customer sees on the menu.
final cartSubtotalProvider = Provider<double>((ref) {
  final percent = ref.watch(commissionProvider).valueOrNull ?? 0.0;
  return ref.watch(cartProvider).items.fold(
        0.0,
        (sum, i) => sum + applyCommission(i.unitPrice, percent) * i.quantity,
      );
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
