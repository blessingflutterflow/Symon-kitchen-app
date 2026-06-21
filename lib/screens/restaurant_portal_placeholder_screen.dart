import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/constants/app_routes.dart';
import '../core/theme.dart';
import '../data/auth_provider.dart';
import '../data/restaurant_model.dart';

/// Landing screen for restaurant owners. Shows a "create your restaurant"
/// prompt until they've set one up, then becomes the management home.
class RestaurantPortalPlaceholderScreen extends ConsumerWidget {
  const RestaurantPortalPlaceholderScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService.signOut();
    if (context.mounted) context.go(AppRoutes.auth);
  }

  void _showAccountSheet(BuildContext context, RestaurantModel restaurant) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.creamMuted),
              title: Text('Log out',
                  style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _signOut(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: Text('Delete Restaurant',
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteRestaurant(context, restaurant);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRestaurant(BuildContext context, RestaurantModel restaurant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete ${restaurant.name}?',
            style: GoogleFonts.inter(color: AppColors.cream, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'This permanently deletes your restaurant profile and its entire '
          'menu. Any orders already placed will keep their record, but you '
          'won\'t be able to manage them afterwards. This cannot be undone.',
          style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.creamMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    await RestaurantService.deleteRestaurant(restaurant);

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRestaurant = ref.watch(myRestaurantProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: myRestaurant.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (_, _) => _buildCreatePrompt(context, error: true),
          data: (restaurant) => restaurant == null
              ? _buildCreatePrompt(context)
              : _buildPortalHome(context, restaurant),
        ),
      ),
    );
  }

  Widget _buildCreatePrompt(BuildContext context, {bool error = false}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.storefront_rounded, color: AppColors.gold, size: 36),
          ),
          const SizedBox(height: 24),
          Text(
            'Set Up Your Restaurant',
            style: GoogleFonts.inter(
              color: AppColors.cream,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            error
                ? 'Something went wrong loading your restaurant. Please try again.'
                : 'Create your restaurant profile to start receiving orders — '
                  'add your name, address, photo and menu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.creamMuted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => context.push(AppRoutes.restaurantOnboarding),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Create My Restaurant',
                style: GoogleFonts.inter(
                  color: AppColors.background,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _signOut(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                'Sign out',
                style: GoogleFonts.inter(
                  color: AppColors.creamMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortalHome(BuildContext context, RestaurantModel restaurant) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Restaurant Portal',
                    style: GoogleFonts.inter(
                      color: AppColors.cream,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showAccountSheet(context, restaurant),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.more_vert_rounded, color: AppColors.creamMuted, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (restaurant.status != 'active')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _StatusBanner(status: restaurant.status),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _RestaurantCard(restaurant: restaurant),
          ),
        ),
        // Portal actions are locked until an admin approves the restaurant.
        if (restaurant.status == 'active')
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList.list(
              children: [
                _PortalAction(
                  icon: Icons.receipt_long_rounded,
                  title: 'View Orders',
                  subtitle: 'See and manage incoming orders in real time',
                  onTap: () => context.push(AppRoutes.restaurantOrders, extra: restaurant.id),
                ),
                const SizedBox(height: 12),
                _PortalAction(
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Manage Menu',
                  subtitle: 'Add, edit and remove dishes from your menu',
                  onTap: () => context.push(AppRoutes.restaurantMenu, extra: restaurant),
                ),
                const SizedBox(height: 12),
                _PortalAction(
                  icon: Icons.edit_outlined,
                  title: 'Edit Restaurant Details',
                  subtitle: 'Update your name, address, photo and delivery info',
                  onTap: () => context.push(AppRoutes.restaurantOnboarding, extra: restaurant),
                ),
                const SizedBox(height: 12),
                _PortalAction(
                  icon: restaurant.isOpen ? Icons.toggle_on_rounded : Icons.toggle_off_outlined,
                  title: restaurant.isOpen ? 'Restaurant is Open' : 'Restaurant is Closed',
                  subtitle: 'Tap to ${restaurant.isOpen ? 'close' : 'open'} for new orders',
                  onTap: () => RestaurantService.setOpen(restaurant.id, !restaurant.isOpen),
                ),
                const SizedBox(height: 32),
              ],
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: _LockedNote(),
            ),
          ),
      ],
    );
  }
}

/// Shown in place of the portal actions while the restaurant isn't approved —
/// the owner can't manage anything until an admin approves it.
class _LockedNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.creamMuted, size: 28),
          const SizedBox(height: 12),
          Text(
            'Management is locked',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: AppColors.cream, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'You\'ll be able to manage your menu and orders once an admin '
            'approves your restaurant. We\'ll notify you as soon as that happens.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: AppColors.creamMuted, fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Shown above the restaurant card when the restaurant isn't approved yet
/// (or has been suspended) — it stays hidden from customers until then.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final suspended = status == 'suspended';
    final color = suspended ? Colors.redAccent : AppColors.gold;
    final icon = suspended ? Icons.block_rounded : Icons.hourglass_top_rounded;
    final title = suspended ? 'Restaurant Suspended' : 'Pending Approval';
    final message = suspended
        ? 'Your restaurant has been suspended and is hidden from customers. '
          'Contact support for more information.'
        : 'Your restaurant is awaiting admin approval. Once approved, it '
          'becomes visible to customers and you can manage your menu and '
          'orders. We\'ll notify you as soon as it\'s approved.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(color: AppColors.cream, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(message,
                    style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 11.5, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant});

  final RestaurantModel restaurant;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: restaurant.coverImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: restaurant.coverImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: AppColors.surfaceLight),
                    errorWidget: (_, _, _) => Container(
                      color: AppColors.surfaceLight,
                      alignment: Alignment.center,
                      child: const Icon(Icons.restaurant_rounded, color: AppColors.creamMuted, size: 32),
                    ),
                  )
                : Container(
                    color: AppColors.surfaceLight,
                    alignment: Alignment.center,
                    child: const Icon(Icons.restaurant_rounded, color: AppColors.creamMuted, size: 32),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  style: GoogleFonts.inter(color: AppColors.cream, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${restaurant.branch} · ${restaurant.address}',
                  style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(text: restaurant.tags),
                    _Pill(text: restaurant.deliveryTime),
                    _Pill(text: 'Min ${restaurant.minOrder}'),
                    _Pill(
                      text: restaurant.isOpen ? 'Open' : 'Closed',
                      color: restaurant.isOpen ? AppColors.gold : AppColors.creamMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.creamMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: GoogleFonts.inter(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _PortalAction extends StatelessWidget {
  const _PortalAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 11.5, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.creamMuted),
          ],
        ),
      ),
    );
  }
}
