import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_routes.dart';
import '../core/theme.dart';
import '../data/cart_item.dart';
import '../data/cart_provider.dart';
import '../data/menu_item_model.dart';
import '../data/restaurant_model.dart';
import 'dish_detail_screen.dart';

class RestaurantScreen extends ConsumerStatefulWidget {
  const RestaurantScreen({super.key, required this.restaurant});
  final RestaurantModel restaurant;

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _categoryCount = -1;
  String _topGroup = 'Food'; // 'Food' | 'Beverages'

  /// (Re)builds the tab controller when the number of categories changes —
  /// the menu streams in live, so the count isn't known up front.
  void _ensureTabController(int categoryCount) {
    if (_categoryCount == categoryCount) return;
    _categoryCount = categoryCount;
    _tabController?.dispose();
    _tabController = categoryCount == 0
        ? null
        : TabController(length: categoryCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// Adds [item] to the cart. If the cart already holds items from a
  /// different restaurant, the customer is asked to confirm starting a new
  /// order — orders can only contain items from one kitchen at a time.
  Future<void> _addToCart(MenuItemModel item) async {
    // Dishes with sizes, free sides, or paid extras open the detail screen so
    // the customer can configure them; simple dishes are added directly.
    if (item.hasVariants || item.hasSides || item.hasExtras) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DishDetailScreen(restaurant: widget.restaurant, item: item),
        ),
      );
      return;
    }

    final notifier = ref.read(cartProvider.notifier);
    final cart = ref.read(cartProvider);

    if (cart.conflictsWith(widget.restaurant)) {
      final confirmed = await _confirmCartReplace(cart.restaurant!);
      if (confirmed != true) return;
      notifier.clear();
    }
    notifier.add(widget.restaurant, item);
  }

  Future<bool?> _confirmCartReplace(RestaurantModel currentCartRestaurant) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Start a new order?',
          style: GoogleFonts.inter(color: AppColors.cream, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your cart has items from ${currentCartRestaurant.name} ${currentCartRestaurant.branch}. '
          'Adding from ${widget.restaurant.name} ${widget.restaurant.branch} will clear your current cart.',
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
    final cart = ref.watch(cartProvider);
    final isThisRestaurantsCart = cart.restaurant?.id == widget.restaurant.id;
    final cartCount = isThisRestaurantsCart ? ref.watch(cartCountProvider) : 0;
    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurant.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: menuAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
              error: (_, _) => Center(
                child: Text(
                  'Could not load the menu. Please try again.',
                  style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'This restaurant hasn\'t added any menu items yet.',
                      style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
                    ),
                  );
                }

                // Top-level split: FOOD vs BEVERAGES.
                final foodItems =
                    items.where((i) => i.category != 'Beverages').toList();
                final bevItems =
                    items.where((i) => i.category == 'Beverages').toList();
                final hasFood = foodItems.isNotEmpty;
                final hasBev = bevItems.isNotEmpty;
                final showToggle = hasFood && hasBev;

                var group = _topGroup;
                if (group == 'Beverages' && !hasBev) group = 'Food';
                if (group == 'Food' && !hasFood && hasBev) group = 'Beverages';

                final groupItems = group == 'Beverages' ? bevItems : foodItems;
                final categories = _groupByCategory(groupItems);
                _ensureTabController(categories.length);

                return Column(
                  children: [
                    if (showToggle) _buildGroupToggle(group),
                    if (categories.isEmpty)
                      const Expanded(child: SizedBox())
                    else ...[
                      _buildTabBar(categories.keys.toList()),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: categories.values
                              .map((items) => _buildMenuList(
                                    items,
                                    isThisRestaurantsCart ? cart.items : const [],
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: cartCount > 0 ? _buildCartBar(cartCount) : null,
    );
  }

  /// Groups menu items by category, ordering known categories first
  /// (matching [kMenuItemCategories]) and any custom ones after.
  Map<String, List<MenuItemModel>> _groupByCategory(List<MenuItemModel> items) {
    final byCategory = <String, List<MenuItemModel>>{};
    for (final item in items) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }
    final ordered = <String, List<MenuItemModel>>{};
    for (final category in kMenuItemCategories) {
      if (byCategory.containsKey(category)) {
        ordered[category] = byCategory.remove(category)!;
      }
    }
    ordered.addAll(byCategory);
    return ordered;
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        // Cover image
        SizedBox(
          height: 220,
          width: double.infinity,
          child: widget.restaurant.coverImageUrl != null
              ? CachedNetworkImage(
                  imageUrl: widget.restaurant.coverImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.surface,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: AppColors.gold),
                  ),
                  errorWidget: (context, url, error) {
                    debugPrint('[image] cover failed to load "$url": $error');
                    return Container(
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: const Icon(Icons.restaurant_rounded,
                          color: AppColors.creamMuted, size: 48),
                    );
                  },
                )
              : Container(
                  color: AppColors.surface,
                  alignment: Alignment.center,
                  child: const Icon(Icons.restaurant_rounded,
                      color: AppColors.creamMuted, size: 48),
                ),
        ),
        // Dark gradient overlay
        Container(
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x88000000),
                Color(0xDD1A0A00),
              ],
            ),
          ),
        ),
        // Back button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
        // Restaurant info at bottom of header
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.restaurant.name,
                  style: GoogleFonts.inter(
                    color: AppColors.cream,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.restaurant.branch,
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.gold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.restaurant.rating} (${widget.restaurant.reviews} reviews)',
                      style: GoogleFonts.inter(
                          color: AppColors.creamMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time_rounded,
                        color: AppColors.creamMuted, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      widget.restaurant.deliveryTime,
                      style: GoogleFonts.inter(
                          color: AppColors.creamMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _showHoursSheet(context),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              color: AppColors.gold, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Hours',
                            style: GoogleFonts.inter(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatDayHours(DayHours? hours) {
    if (hours == null || !hours.isOpen) return 'Closed';
    final locale = MaterialLocalizations.of(context);
    return '${locale.formatTimeOfDay(_parseTime(hours.openTime))} – '
        '${locale.formatTimeOfDay(_parseTime(hours.closeTime))}';
  }

  void _showHoursSheet(BuildContext context) {
    final hours = widget.restaurant.operatingHours;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Opening Hours',
                  style: GoogleFonts.inter(color: AppColors.cream, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              for (final day in kWeekdays)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(kWeekdayLabels[day]!,
                            style: GoogleFonts.inter(
                                color: AppColors.cream, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        _formatDayHours(hours[day]),
                        style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupToggle(String group) {
    Widget seg(String label, IconData icon) {
      final selected = group == label;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _topGroup = label),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? AppColors.background : AppColors.creamMuted),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: selected ? AppColors.background : AppColors.creamMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          seg('Food', Icons.restaurant_rounded),
          seg('Beverages', Icons.local_cafe_rounded),
        ],
      ),
    );
  }

  Widget _buildTabBar(List<String> categories) {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.gold,
        indicatorWeight: 2.5,
        labelColor: AppColors.gold,
        unselectedLabelColor: AppColors.creamMuted,
        labelStyle: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w500),
        tabs: categories.map((name) => Tab(text: name)).toList(),
      ),
    );
  }

  Widget _buildMenuList(List<MenuItemModel> items, List<CartItem> cartItems) {
    int itemCount(MenuItemModel item) {
      final match = cartItems.where((c) => c.item.id == item.id);
      return match.isEmpty ? 0 : match.first.quantity;
    }

    final commission = ref.watch(commissionProvider).valueOrNull ?? 0.0;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: items.length,
      separatorBuilder: (context, index) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        color: AppColors.divider,
      ),
      itemBuilder: (context, index) => _MenuItemTile(
        item: items[index],
        count: itemCount(items[index]),
        commission: commission,
        onAdd: () => _addToCart(items[index]),
      ),
    );
  }

  Widget _buildCartBar(int cartCount) {
    final subtotal = ref.watch(cartSubtotalProvider);
    return GestureDetector(
      onTap: () => context.push(AppRoutes.cart),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '$cartCount',
                style: GoogleFonts.inter(
                  color: AppColors.background,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'View Cart',
              style: GoogleFonts.inter(
                color: AppColors.background,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'R ${subtotal.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                color: AppColors.background,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({
    required this.item,
    required this.count,
    required this.commission,
    required this.onAdd,
  });
  final MenuItemModel item;
  final int count;
  final double commission;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.inter(
                    color: AppColors.cream,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: GoogleFonts.inter(
                    color: AppColors.creamMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  item.hasVariants
                      ? item.variants
                          .map((v) => '${v.label} R ${applyCommission(v.price, commission).toStringAsFixed(2)}')
                          .join('  ·  ')
                      : 'R ${applyCommission(item.price, commission).toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: AppColors.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Image + Add button
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: item.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 88,
                          height: 88,
                          color: AppColors.surface,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.gold),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          debugPrint('[image] dish "${item.name}" failed to load "$url": $error');
                          return Container(
                            width: 88,
                            height: 88,
                            color: AppColors.surface,
                            alignment: Alignment.center,
                            child: const Icon(Icons.fastfood_rounded,
                                color: AppColors.creamMuted, size: 28),
                          );
                        },
                      )
                    : Container(
                        width: 88,
                        height: 88,
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: const Icon(Icons.fastfood_rounded,
                            color: AppColors.creamMuted, size: 28),
                      ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 88,
                  height: 32,
                  decoration: BoxDecoration(
                    color: count > 0 ? AppColors.gold : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: count > 0 ? AppColors.gold : AppColors.divider,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: count > 0
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded,
                                color: AppColors.background, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '$count added',
                              style: GoogleFonts.inter(
                                color: AppColors.background,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded,
                                color: AppColors.creamMuted, size: 16),
                            const SizedBox(width: 3),
                            Text(
                              'Add',
                              style: GoogleFonts.inter(
                                color: AppColors.creamMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
