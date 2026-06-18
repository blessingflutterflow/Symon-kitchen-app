import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/restaurant_model.dart';
import '../../screens/auth_screen.dart';
import '../../screens/cart_screen.dart';
import '../../screens/driver_application_screen.dart';
import '../../screens/driver_entry_screen.dart';
import '../../screens/driver_pending_screen.dart';
import '../../screens/driver_profile_screen.dart';
import '../../screens/driver_rejected_screen.dart';
import '../../screens/driver_shell.dart';
import '../../screens/home_screen.dart';
import '../../screens/restaurant_menu_management_screen.dart';
import '../../screens/restaurant_orders_screen.dart';
import '../../screens/restaurant_onboarding_screen.dart';
import '../../screens/restaurant_portal_placeholder_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/restaurant_screen.dart';
import '../../screens/role_screen.dart';
import '../../screens/setup_screen.dart';
import '../../screens/splash_screen.dart';
import '../../screens/tracking_screen.dart';
import '../constants/app_routes.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.auth,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: AppRoutes.authSetup,
      builder: (context, state) => const SetupScreen(),
    ),
    GoRoute(
      path: AppRoutes.authRole,
      builder: (context, state) => const RoleScreen(),
    ),
    GoRoute(
      path: AppRoutes.restaurantPortal,
      builder: (context, state) => const RestaurantPortalPlaceholderScreen(),
    ),
    GoRoute(
      path: AppRoutes.restaurantOnboarding,
      builder: (context, state) =>
          RestaurantOnboardingScreen(existing: state.extra as RestaurantModel?),
    ),
    GoRoute(
      path: AppRoutes.restaurantMenu,
      builder: (context, state) => RestaurantMenuManagementScreen(
        restaurant: state.extra as RestaurantModel,
      ),
    ),
    GoRoute(
      path: AppRoutes.restaurantOrders,
      builder: (context, state) =>
          RestaurantOrdersScreen(restaurantId: state.extra as String),
    ),
    GoRoute(
      path: AppRoutes.driverEntry,
      builder: (context, state) => const DriverEntryScreen(),
    ),
    GoRoute(
      path: AppRoutes.driverApply,
      builder: (context, state) => const DriverApplicationScreen(),
    ),
    GoRoute(
      path: AppRoutes.driverPending,
      builder: (context, state) => const DriverPendingScreen(),
    ),
    GoRoute(
      path: AppRoutes.driverRejected,
      builder: (context, state) => const DriverRejectedScreen(),
    ),
    GoRoute(
      path: AppRoutes.driverHome,
      builder: (context, state) => const DriverShell(),
    ),
    GoRoute(
      path: AppRoutes.driverProfile,
      builder: (context, state) => const DriverProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) =>
          _fadePage(state: state, child: const HomeScreen()),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.restaurant,
      builder: (context, state) =>
          RestaurantScreen(restaurant: state.extra as RestaurantModel),
    ),
    GoRoute(
      path: AppRoutes.cart,
      builder: (context, state) => const CartScreen(),
    ),
    GoRoute(
      path: AppRoutes.tracking,
      builder: (context, state) =>
          TrackingScreen(orderId: state.extra as String),
    ),
  ],
);

Page<void> _fadePage({required GoRouterState state, required Widget child}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 600),
  );
}
