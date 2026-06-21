import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../data/cart_item.dart';
import '../data/cart_provider.dart';
import '../data/menu_item_model.dart';
import '../data/restaurant_model.dart';

/// Lets a customer configure a dish — pick a size, choose the free sides, add
/// paid extras, set quantity — then add the configured line to the cart.
class DishDetailScreen extends ConsumerStatefulWidget {
  const DishDetailScreen({super.key, required this.restaurant, required this.item});

  final RestaurantModel restaurant;
  final MenuItemModel item;

  @override
  ConsumerState<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends ConsumerState<DishDetailScreen> {
  int _quantity = 1;
  int _variantIndex = 0;
  final Set<String> _sides = {};
  final Set<String> _extras = {};

  MenuItemModel get _item => widget.item;

  double get _basePrice =>
      _item.hasVariants ? _item.variants[_variantIndex].price : _item.price;

  double get _extrasTotal => _item.extras
      .where((e) => _extras.contains(e.name))
      .fold(0.0, (sum, e) => sum + e.price);

  bool get _sidesSatisfied =>
      !_item.hasSides || _sides.length == _item.sidesAllowed;

  Future<void> _addToCart() async {
    final notifier = ref.read(cartProvider.notifier);
    final cart = ref.read(cartProvider);

    if (cart.conflictsWith(widget.restaurant)) {
      final confirmed = await _confirmReplace(cart.restaurant!);
      if (confirmed != true) return;
      notifier.clear();
    }

    final line = CartItem(
      item: _item,
      quantity: _quantity,
      variantLabel: _item.hasVariants ? _item.variants[_variantIndex].label : null,
      unitBasePrice: _basePrice,
      sides: _sides.toList(),
      extras: _item.extras.where((e) => _extras.contains(e.name)).toList(),
    );
    notifier.addConfigured(widget.restaurant, line);
    if (mounted) context.pop();
  }

  Future<bool?> _confirmReplace(RestaurantModel current) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Start a new order?',
            style: GoogleFonts.inter(color: AppColors.cream, fontWeight: FontWeight.w700)),
        content: Text(
          'Your cart has items from ${current.name} ${current.branch}. Adding from '
          '${widget.restaurant.name} ${widget.restaurant.branch} will clear it.',
          style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.creamMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Clear & Continue',
                style: GoogleFonts.inter(color: AppColors.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commission = ref.watch(commissionProvider).valueOrNull ?? 0.0;
    final unitPrice = applyCommission(_basePrice + _extrasTotal, commission);
    final total = unitPrice * _quantity;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(commission),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_item.description.isNotEmpty) ...[
                          Text(_item.description,
                              style: GoogleFonts.inter(
                                  color: AppColors.creamMuted, fontSize: 13, height: 1.5)),
                          const SizedBox(height: 20),
                        ],
                        if (_item.hasVariants) _buildSizes(commission),
                        if (_item.hasSides) _buildSides(),
                        if (_item.hasExtras) _buildExtras(commission),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildAddBar(total),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double commission) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: _item.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: _item.imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.surface,
                    alignment: Alignment.center,
                    child: const Icon(Icons.fastfood_rounded, color: AppColors.creamMuted, size: 40),
                  ),
                )
              : Container(
                  color: AppColors.surface,
                  alignment: Alignment.center,
                  child: const Icon(Icons.fastfood_rounded, color: AppColors.creamMuted, size: 40),
                ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: AppColors.cream, size: 22),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_item.name,
                  style: GoogleFonts.inter(
                    color: AppColors.cream,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSizes(double commission) {
    return _section(
      'Choose a size',
      Column(
        children: List.generate(_item.variants.length, (i) {
          final v = _item.variants[i];
          final selected = _variantIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _variantIndex = i),
            child: _optionRow(
              selected: selected,
              isRadio: true,
              label: v.label,
              trailing: 'R ${applyCommission(v.price, commission).toStringAsFixed(2)}',
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSides() {
    return _section(
      'Selection of any ${_item.sidesAllowed} side${_item.sidesAllowed > 1 ? 's' : ''}'
      '   (${_sides.length}/${_item.sidesAllowed})',
      Column(
        children: _item.sideOptions.map((side) {
          final selected = _sides.contains(side);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) {
                _sides.remove(side);
              } else if (_sides.length < _item.sidesAllowed) {
                _sides.add(side);
              }
            }),
            child: _optionRow(selected: selected, isRadio: false, label: side, trailing: 'Free'),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExtras(double commission) {
    return _section(
      'Add additional extras',
      Column(
        children: _item.extras.map((e) {
          final selected = _extras.contains(e.name);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) {
                _extras.remove(e.name);
              } else {
                _extras.add(e.name);
              }
            }),
            child: _optionRow(
              selected: selected,
              isRadio: false,
              label: e.name,
              trailing: '+R ${applyCommission(e.price, commission).toStringAsFixed(2)}',
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
                color: AppColors.cream, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        child,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _optionRow({
    required bool selected,
    required bool isRadio,
    required String label,
    required String trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isRadio
                ? (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded)
                : (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded),
            color: selected ? AppColors.gold : AppColors.creamMuted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14)),
          ),
          Text(trailing,
              style: GoogleFonts.inter(
                  color: trailing == 'Free' ? AppColors.creamMuted : AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAddBar(double total) {
    final canAdd = _sidesSatisfied;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Row(
        children: [
          // Quantity stepper
          Row(
            children: [
              _qtyBtn(Icons.remove_rounded, () {
                if (_quantity > 1) setState(() => _quantity--);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$_quantity',
                    style: GoogleFonts.inter(
                        color: AppColors.cream, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              _qtyBtn(Icons.add_rounded, () => setState(() => _quantity++)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: canAdd ? _addToCart : null,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: canAdd ? AppColors.gold : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  canAdd
                      ? 'Add to Cart  ·  R ${total.toStringAsFixed(2)}'
                      : 'Choose ${_item.sidesAllowed} side${_item.sidesAllowed > 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    color: canAdd ? AppColors.background : AppColors.creamMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.cream, size: 18),
      ),
    );
  }
}
