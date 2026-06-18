import 'menu_item_model.dart';

class CartItem {
  final MenuItemModel item;
  final int quantity;

  const CartItem({required this.item, this.quantity = 1});

  CartItem copyWith({int? quantity}) =>
      CartItem(item: item, quantity: quantity ?? this.quantity);

  double get total => item.price * quantity;
}
