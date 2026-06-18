import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_routes.dart';
import '../core/theme.dart';
import '../core/widgets/narrow_body.dart';
import '../data/auth_provider.dart';
import '../data/driver_model.dart';

class DriverPendingScreen extends ConsumerWidget {
  const DriverPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myDriverProfileProvider);

    profileAsync.whenData((driver) {
      if (driver == null) return;
      if (driver.status == DriverStatus.approved) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.go(AppRoutes.driverHome));
      } else if (driver.status == DriverStatus.rejected ||
          driver.status == DriverStatus.suspended) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.go(AppRoutes.driverRejected));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NarrowBody(
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await AuthService.signOut();
                      if (context.mounted) context.go(AppRoutes.auth);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: AppColors.creamMuted, size: 20),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.hourglass_top_rounded,
                    color: AppColors.gold, size: 40),
              ),
              const SizedBox(height: 28),
              Text(
                'Application Under Review',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We\'re reviewing your application. This usually takes 1–2 business days. We\'ll update this screen as soon as a decision is made.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.creamMuted,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              // ── Status dots ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _StatusRow(
                      icon: Icons.check_circle_rounded,
                      color: AppColors.gold,
                      label: 'Application submitted',
                      done: true,
                    ),
                    _Divider(),
                    _StatusRow(
                      icon: Icons.manage_search_rounded,
                      color: AppColors.creamMuted,
                      label: 'Under review',
                      done: false,
                      active: true,
                    ),
                    _Divider(),
                    _StatusRow(
                      icon: Icons.verified_rounded,
                      color: AppColors.creamMuted,
                      label: 'Approved — start delivering',
                      done: false,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'This page updates automatically. No need to restart the app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.creamMuted, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 8),
              profileAsync.isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold),
                    )
                  : const SizedBox(height: 16),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.done,
      this.active = false});

  final IconData icon;
  final Color color;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            color: done ? AppColors.gold : (active ? AppColors.cream : color),
            size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: done
                  ? AppColors.cream
                  : (active ? AppColors.cream : AppColors.creamMuted),
              fontSize: 13,
              fontWeight:
                  active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('In progress',
                style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      height: 1,
      color: AppColors.divider,
    );
  }
}
