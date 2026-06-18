import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_routes.dart';
import '../core/services/places_service.dart';
import '../core/services/yoco_service.dart';
import '../core/theme.dart';
import '../data/auth_provider.dart';
import '../data/cart_item.dart';
import '../data/cart_provider.dart';
import 'widgets/address_picker_sheet.dart';
import 'widgets/places_autocomplete_field.dart';
import 'payment_webview_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider).items;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppColors.cream, size: 20),
          ),
        ),
        title: Text(
          'Your Cart',
          style: GoogleFonts.inter(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: cart.isEmpty
          ? _buildEmptyCart(context)
          : Column(
              children: [
                Expanded(child: _buildItemList(context, ref, cart)),
                _buildSummary(context, ref),
              ],
            ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_bag_outlined,
              color: AppColors.creamMuted, size: 56),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: GoogleFonts.inter(
                color: AppColors.cream,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items from the menu to get started',
            style: GoogleFonts.inter(
                color: AppColors.creamMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Browse Menu',
                style: GoogleFonts.inter(
                    color: AppColors.background,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(BuildContext context, WidgetRef ref, List<CartItem> cart) {
    final notifier = ref.read(cartProvider.notifier);
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: cart.length,
      separatorBuilder: (context, index) =>
          Container(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final item = cart[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: item.item.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.item.imageUrl!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          width: 64,
                          height: 64,
                          color: AppColors.surface,
                          alignment: Alignment.center,
                          child: const Icon(Icons.fastfood_rounded,
                              color: AppColors.creamMuted, size: 22),
                        ),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: const Icon(Icons.fastfood_rounded,
                            color: AppColors.creamMuted, size: 22),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.item.name,
                      style: GoogleFonts.inter(
                        color: AppColors.cream,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'R ${item.item.price.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        color: AppColors.creamMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Quantity controls
              Row(
                children: [
                  _QtyButton(
                    icon: Icons.remove_rounded,
                    onTap: () =>
                        notifier.updateQuantity(item.item, item.quantity - 1),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${item.quantity}',
                    style: GoogleFonts.inter(
                      color: AppColors.cream,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QtyButton(
                    icon: Icons.add_rounded,
                    onTap: () =>
                        notifier.updateQuantity(item.item, item.quantity + 1),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(BuildContext context, WidgetRef ref) {
    final subtotal = ref.watch(cartSubtotalProvider);
    final total = ref.watch(cartTotalProvider);
    final deliveryFee = ref.watch(deliveryFeeProvider).valueOrNull ?? kDefaultDeliveryFee;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
          _SummaryRow('Subtotal', 'R ${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _SummaryRow('Delivery fee', 'R ${deliveryFee.toStringAsFixed(2)}'),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Total',
                style: GoogleFonts.inter(
                  color: AppColors.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'R ${total.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  color: AppColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PlaceOrderButton(subtotal: subtotal, total: total),
        ],
      ),
    );
  }
}

class _PlaceOrderButton extends ConsumerStatefulWidget {
  const _PlaceOrderButton({required this.subtotal, required this.total});
  final double subtotal;
  final double total;

  @override
  ConsumerState<_PlaceOrderButton> createState() => _PlaceOrderButtonState();
}

class _PlaceOrderButtonState extends ConsumerState<_PlaceOrderButton> {
  bool _placing = false;
  String? _error;
  final _addressCtrl = TextEditingController();
  double? _lat;
  double? _lng;
  bool _prefilledFromProfile = false;

  @override
  void initState() {
    super.initState();
    _addressCtrl.addListener(_onAddressEdited);
  }

  @override
  void dispose() {
    _addressCtrl.removeListener(_onAddressEdited);
    _addressCtrl.dispose();
    super.dispose();
  }

  /// Free-typed edits invalidate any coordinates we had — they get
  /// re-resolved (via autocomplete selection or geocoding at submit time).
  void _onAddressEdited() {
    if (_lat != null || _lng != null) {
      setState(() {
        _lat = null;
        _lng = null;
      });
    }
  }

  void _onPlaceSelected(PlaceDetails details) {
    setState(() {
      _lat = details.lat;
      _lng = details.lng;
      _error = null;
    });
  }

  Future<void> _changeAddress() async {
    final result = await showAddressPickerSheet(context, initialAddress: _addressCtrl.text.trim());
    if (result == null) return;
    _addressCtrl.text = result.address;
    setState(() {
      _lat = result.lat;
      _lng = result.lng;
      _error = null;
    });
  }

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    final restaurant = cart.restaurant;
    if (restaurant == null || cart.items.isEmpty || _placing) return;
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Please enter a delivery address.');
      return;
    }

    setState(() {
      _placing = true;
      _error = null;
    });

    try {
      var lat = _lat;
      var lng = _lng;
      if (lat == null || lng == null) {
        final details = await PlacesService.geocode(address);
        if (details == null) {
          if (mounted) {
            setState(() {
              _placing = false;
              _error = 'Could not locate that address — try selecting a suggestion.';
            });
          }
          return;
        }
        lat = details.lat;
        lng = details.lng;
      }

      // Keep the customer's one saved home address in sync with whatever
      // they just ordered to.
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile?.homeAddress != address || profile?.homeLat != lat || profile?.homeLng != lng) {
        await AuthService.saveHomeAddress(address, lat, lng);
      }

      final deliveryFee = ref.read(deliveryFeeProvider).valueOrNull ?? kDefaultDeliveryFee;

      // 1. Create Yoco checkout + pending order
      final checkoutResult = await YocoService.initializePayment(
        restaurantId: restaurant.id,
        restaurantName: '${restaurant.name} ${restaurant.branch}',
        amountRands: widget.total,
        items: cart.items.map((c) => {
          'name': c.item.name,
          'quantity': c.quantity,
          'price': c.item.price,
        }).toList(),
        deliveryAddress: address,
        deliveryFee: deliveryFee,
        deliveryLat: lat,
        deliveryLng: lng,
        customerName: profile?.name,
      );

      // 2. Open Yoco hosted checkout in WebView
      if (!mounted) return;
      final result = await Navigator.of(context).push<PaymentResult>(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            authorizationUrl: checkoutResult.authorizationUrl,
            checkoutId: checkoutResult.checkoutId,
          ),
        ),
      );

      if (!mounted) return;

      if (result == null || result.isCancelled) {
        setState(() => _placing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment was cancelled.')),
        );
        return;
      }

      // 3. Verify payment with Cloud Function
      final verifyResult = await YocoService.verifyPayment(
        orderId: checkoutResult.orderId,
        checkoutId: checkoutResult.checkoutId,
      );

      if (!mounted) return;

      if (verifyResult.status == 'placed') {
        ref.read(cartProvider.notifier).clear();
        context.push(AppRoutes.tracking, extra: checkoutResult.orderId);
      } else {
        setState(() {
          _placing = false;
          _error = 'Payment not confirmed. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (!_prefilledFromProfile && profile != null) {
      final homeAddress = profile.homeAddress;
      if (homeAddress != null && homeAddress.isNotEmpty) {
        _addressCtrl.text = homeAddress;
        _lat = profile.homeLat;
        _lng = profile.homeLng;
        _prefilledFromProfile = true;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Delivery Address',
                style: GoogleFonts.inter(
                    color: AppColors.creamMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: _changeAddress,
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: AppColors.gold, size: 14),
                  const SizedBox(width: 4),
                  Text('Change',
                      style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PlacesAutocompleteField(
          controller: _addressCtrl,
          hint: 'Enter your delivery address',
          onPlaceSelected: _onPlaceSelected,
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(
            _error!,
            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12),
          ),
          const SizedBox(height: 10),
        ],
        GestureDetector(
          onTap: _placing ? null : _placeOrder,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _placing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.background,
                    ),
                  )
                : Text(
                    'Pay & Place Order',
                    style: GoogleFonts.inter(
                      color: AppColors.background,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.cream, size: 16),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.creamMuted, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.inter(
                color: AppColors.cream,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
