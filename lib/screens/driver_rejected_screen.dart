import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_routes.dart';
import '../core/theme.dart';
import '../core/widgets/narrow_body.dart';
import '../data/auth_provider.dart';
import '../data/driver_model.dart';

class DriverRejectedScreen extends ConsumerWidget {
  const DriverRejectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myDriverProfileProvider);

    // Auto-redirect if somehow approved after landing here
    profileAsync.whenData((driver) {
      if (driver?.status == DriverStatus.approved) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.go(AppRoutes.driverHome));
      }
    });

    final isSuspended = profileAsync.valueOrNull?.status == DriverStatus.suspended;
    final rejectionReason = profileAsync.valueOrNull?.rejectionReason;

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
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  isSuspended
                      ? Icons.block_rounded
                      : Icons.cancel_rounded,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                isSuspended ? 'Account Suspended' : 'Application Declined',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSuspended
                    ? 'Your driver account has been suspended. Please contact support for more information.'
                    : 'Unfortunately your application was not approved at this time.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.creamMuted,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reason',
                          style: GoogleFonts.inter(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      Text(rejectionReason,
                          style: GoogleFonts.inter(
                              color: AppColors.cream,
                              fontSize: 13,
                              height: 1.5)),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (!isSuspended) ...[
                GestureDetector(
                  onTap: () => context.go(AppRoutes.driverApply),
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Edit & Reapply',
                      style: GoogleFonts.inter(
                        color: AppColors.background,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: () async {
                  await AuthService.signOut();
                  if (context.mounted) context.go(AppRoutes.auth);
                },
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Sign Out',
                    style: GoogleFonts.inter(
                      color: AppColors.creamMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
