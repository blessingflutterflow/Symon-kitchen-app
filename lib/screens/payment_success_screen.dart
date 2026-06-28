import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_routes.dart';
import '../core/services/yoco_service.dart';
import '../core/theme.dart';
import '../data/cart_provider.dart';

/// Handles the Yoco payment redirect on Flutter Web.
/// Yoco redirects the browser to /#/payment/success?orderId=xxx
/// This screen verifies the payment and routes to the tracking screen.
class PaymentSuccessScreen extends ConsumerStatefulWidget {
  const PaymentSuccessScreen({
    super.key,
    required this.reference,
    required this.orderId,
  });

  final String reference;
  final String orderId;

  @override
  ConsumerState<PaymentSuccessScreen> createState() =>
      _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    if (widget.orderId.isEmpty) {
      if (mounted) context.go(AppRoutes.home);
      return;
    }
    try {
      final result = await YocoService.verifyPayment(
        orderId: widget.orderId,
        reference: widget.reference,
      );
      if (!mounted) return;
      if (result.status == 'placed') {
        ref.read(cartProvider.notifier).clear();
        context.go(AppRoutes.tracking, extra: widget.orderId);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (_) {
      if (mounted) context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(height: 20),
            Text('Confirming your payment…',
                style: GoogleFonts.inter(
                    color: AppColors.creamMuted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
