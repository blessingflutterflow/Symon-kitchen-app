import 'menu_item_model.dart';

/// A single configured line in the cart: a dish plus the customer's chosen
/// size (variant), free sides, and paid extras. Two lines of the same dish
/// with different choices are kept separate (see [configKey]).
class CartItem {
  final MenuItemModel item;
  final int quantity;

  /// Chosen size label (e.g. "Large Plate"), null if the dish has no sizes.
  final String? variantLabel;

  /// The base unit price (the dish price, or the chosen variant's price),
  /// BEFORE commission and BEFORE extras.
  final double unitBasePrice;

  /// Free sides the customer selected (no charge).
  final List<String> sides;

  /// Paid extras the customer added.
  final List<MenuItemExtra> extras;

  CartItem({
    required this.item,
    this.quantity = 1,
    this.variantLabel,
    double? unitBasePrice,
    this.sides = const [],
    this.extras = const [],
  }) : unitBasePrice = unitBasePrice ?? item.price;

  double get extrasTotal => extras.fold(0.0, (sum, e) => sum + e.price);

  /// Unit price before commission, including extras.
  double get unitPrice => unitBasePrice + extrasTotal;

  /// Line total before commission.
  double get total => unitPrice * quantity;

  /// Identity for deduping identical configurations in the cart.
  String get configKey {
    final s = [...sides]..sort();
    final e = [for (final x in extras) x.name]..sort();
    return [item.id, variantLabel ?? '', s.join(','), e.join(',')].join('|');
  }

  CartItem copyWith({int? quantity}) => CartItem(
        item: item,
        quantity: quantity ?? this.quantity,
        variantLabel: variantLabel,
        unitBasePrice: unitBasePrice,
        sides: sides,
        extras: extras,
      );
}
