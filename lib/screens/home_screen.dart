import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_routes.dart';
import '../core/services/location_service.dart';
import '../core/services/places_service.dart';
import '../core/theme.dart';
import '../data/auth_provider.dart';
import '../data/restaurant_model.dart';
import 'widgets/address_picker_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedCategory = 0;
  bool _detectingLocation = false;

  final _categories = [
    'All', 'Grills', 'Main Meals', 'Light Meals', 'Combos', 'Platters', 'Beverages',
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    _maybeAutoDetectAddress();
  }

  /// On first launch, before the customer has ever set a home address,
  /// auto-detect their current location and use it as the address —
  /// mirrors Tolta's "auto pick of address when customer gets in the app".
  Future<void> _maybeAutoDetectAddress() async {
    final profile = await ref.read(userProfileProvider.future);
    if (!mounted) return;
    final existing = profile?.homeAddress;
    if (existing != null && existing.isNotEmpty) return;

    setState(() => _detectingLocation = true);
    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      if (mounted) setState(() => _detectingLocation = false);
      return;
    }
    final address = await PlacesService.reverseGeocode(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() => _detectingLocation = false);
    if (address != null) {
      await AuthService.saveHomeAddress(address, position.latitude, position.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildPromoBanner(),
              _buildCategories(),
              _buildRestaurantsSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAddress(String? currentAddress) async {
    final result = await showAddressPickerSheet(context, initialAddress: currentAddress);
    if (result == null) return;
    await AuthService.saveHomeAddress(result.address, result.lat, result.lng);
  }

  Widget _buildHeader() {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final address = profile?.homeAddress;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: GoogleFonts.inter(
                    color: AppColors.creamMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _pickAddress(address),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.gold, size: 15),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _detectingLocation
                              ? 'Detecting your location…'
                              : (address == null || address.isEmpty)
                                  ? 'Set delivery address'
                                  : address,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AppColors.cream,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_detectingLocation) ...[
                        const SizedBox(width: 6),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.gold),
                        ),
                      ] else
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.creamMuted, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  color: AppColors.cream, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, color: AppColors.creamMuted, size: 21),
            const SizedBox(width: 10),
            Text(
              'Search restaurants or dishes...',
              style: GoogleFonts.inter(
                color: AppColors.creamMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF3D1E0C), Color(0xFF5C3020)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: -10,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'LIMITED OFFER',
                      style: GoogleFonts.inter(
                        color: AppColors.background,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Free delivery on\nyour first order!',
                    style: GoogleFonts.inter(
                      color: AppColors.cream,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
          child: Text(
            'What are you craving?',
            style: GoogleFonts.inter(
              color: AppColors.cream,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = _selectedCategory == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.gold : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.gold : AppColors.divider,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _categories[index],
                    style: GoogleFonts.inter(
                      color: selected ? AppColors.background : AppColors.creamMuted,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantsSection() {
    final restaurantsAsync = ref.watch(restaurantsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: Row(
            children: [
              Text(
                'Restaurants Near You',
                style: GoogleFonts.inter(
                  color: AppColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${restaurantsAsync.valueOrNull?.where((r) => r.isOpen).length ?? 0} open',
                style: GoogleFonts.inter(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        restaurantsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
          ),
          error: (error, stack) {
            debugPrint('[restaurants] failed to load: $error\n$stack');
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Text(
                'Could not load restaurants. Please check your connection.',
                style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
              ),
            );
          },
          data: (restaurants) => restaurants.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: Text(
                    'No restaurants yet — check back soon!',
                    style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
                  ),
                )
              : Column(
                  children: restaurants
                      .map(
                        (r) => _RestaurantCard(
                          restaurant: r,
                          onTap: () => context.push(AppRoutes.restaurant, extra: r),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant, required this.onTap});
  final RestaurantModel restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: restaurant.coverImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: restaurant.coverImageUrl!,
                          height: 185,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 185,
                            color: AppColors.surface,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(color: AppColors.gold),
                          ),
                          errorWidget: (context, url, error) {
                            debugPrint('[image] restaurant "${restaurant.name}" cover failed to load "$url": $error');
                            return Container(
                              height: 185,
                              color: AppColors.surface,
                              alignment: Alignment.center,
                              child: const Icon(Icons.restaurant_rounded,
                                  color: AppColors.creamMuted, size: 36),
                            );
                          },
                        )
                      : Container(
                          height: 185,
                          color: AppColors.surface,
                          alignment: Alignment.center,
                          child: const Icon(Icons.restaurant_rounded,
                              color: AppColors.creamMuted, size: 36),
                        ),
                ),
                // Open / Closed badge overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: (restaurant.isOpen ? Colors.green : Colors.redAccent)
                              .withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: restaurant.isOpen ? Colors.green : Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          restaurant.isOpen ? 'Open' : 'Closed',
                          style: GoogleFonts.inter(
                            color: restaurant.isOpen ? Colors.green : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurant.name,
                              style: GoogleFonts.inter(
                                color: AppColors.cream,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              restaurant.branch,
                              style: GoogleFonts.inter(
                                color: AppColors.gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: AppColors.gold, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              restaurant.rating.toString(),
                              style: GoogleFonts.inter(
                                color: AppColors.gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              ' (${restaurant.reviews})',
                              style: GoogleFonts.inter(
                                color: AppColors.creamMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    restaurant.tags,
                    style: GoogleFonts.inter(
                      color: AppColors.creamMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppColors.divider),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: AppColors.creamMuted, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.deliveryTime,
                        style: GoogleFonts.inter(
                            color: AppColors.creamMuted, fontSize: 12),
                      ),
                      const SizedBox(width: 18),
                      const Icon(Icons.shopping_bag_outlined,
                          color: AppColors.creamMuted, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${restaurant.minOrder} min order',
                        style: GoogleFonts.inter(
                            color: AppColors.creamMuted, fontSize: 12),
                      ),
                      const SizedBox(width: 18),
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.creamMuted, size: 14),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          restaurant.address,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: AppColors.creamMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
