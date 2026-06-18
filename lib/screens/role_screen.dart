import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_routes.dart';
import '../core/theme.dart';
import '../core/widgets/narrow_body.dart';
import '../data/auth_provider.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  UserRole? _selected;
  bool _loading = false;

  Future<void> _continue() async {
    final role = _selected;
    if (role == null || _loading) return;
    setState(() => _loading = true);
    await AuthService.saveRole(role);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (role) {
      case UserRole.customer:
        context.go(AppRoutes.home);
      case UserRole.restaurantOwner:
        context.go(AppRoutes.restaurantPortal);
      case UserRole.driver:
        context.go(AppRoutes.driverEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NarrowBody(
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One last thing',
                style: GoogleFonts.inter(
                  color: AppColors.cream,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How will you be using Symon\'s Kitchin?',
                style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 14),
              ),
              const SizedBox(height: 28),
              _RoleCard(
                icon: Icons.restaurant_menu_rounded,
                title: 'I want to order food',
                subtitle: 'Browse menus, order, and track delivery to your door.',
                selected: _selected == UserRole.customer,
                onTap: () => setState(() => _selected = UserRole.customer),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.storefront_rounded,
                title: 'I run a restaurant',
                subtitle: 'List your menu, manage orders, and grow with us.',
                selected: _selected == UserRole.restaurantOwner,
                onTap: () => setState(() => _selected = UserRole.restaurantOwner),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.delivery_dining_rounded,
                title: 'I\'m a delivery driver',
                subtitle: 'Pick up and deliver orders, earn per delivery.',
                selected: _selected == UserRole.driver,
                onTap: () => setState(() => _selected = UserRole.driver),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _selected != null && !_loading ? _continue : null,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _selected != null ? AppColors.gold : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.background,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: GoogleFonts.inter(
                            color: AppColors.background,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.18)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: selected ? AppColors.gold : AppColors.creamMuted, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppColors.cream,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppColors.creamMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 22),
          ],
        ),
      ),
    );
  }
}
