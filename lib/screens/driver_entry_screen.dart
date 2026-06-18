import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_routes.dart';
import '../core/theme.dart';
import '../data/driver_model.dart';

/// Checks the driver's application status and routes accordingly.
/// Acts as a gatekeeper — drivers always land here first.
class DriverEntryScreen extends ConsumerWidget {
  const DriverEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myDriverProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      ),
      error: (e, st) => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      ),
      data: (driver) {
        if (driver == null || driver.status == DriverStatus.incomplete) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => context.go(AppRoutes.driverApply));
        } else {
          switch (driver.status) {
            case DriverStatus.pendingReview:
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => context.go(AppRoutes.driverPending));
            case DriverStatus.approved:
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => context.go(AppRoutes.driverHome));
            case DriverStatus.rejected:
            case DriverStatus.suspended:
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => context.go(AppRoutes.driverRejected));
            case DriverStatus.incomplete:
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => context.go(AppRoutes.driverApply));
          }
        }
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
        );
      },
    );
  }
}
