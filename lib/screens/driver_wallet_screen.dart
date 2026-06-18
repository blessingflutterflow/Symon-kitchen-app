import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../core/widgets/narrow_body.dart';
import '../data/order_provider.dart';

class DriverWalletScreen extends ConsumerWidget {
  const DriverWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(myDeliveryHistoryProvider);
    final activeAsync = ref.watch(myActiveDeliveryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NarrowBody(
        child: SafeArea(
          child: historyAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(err.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppColors.creamMuted)),
              ),
            ),
            data: (history) {
              final totalEarned =
                  history.fold<double>(0, (sum, o) => sum + o.deliveryFee);
              final pending = activeAsync.valueOrNull?.deliveryFee ?? 0;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              color: AppColors.gold, size: 26),
                          const SizedBox(width: 12),
                          Text('My Wallet',
                              style: GoogleFonts.inter(
                                color: AppColors.cream,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              )),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _BalanceCard(
                        totalEarned: totalEarned,
                        deliveries: history.length,
                        pending: pending,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Earnings History',
                              style: GoogleFonts.inter(
                                color: AppColors.cream,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              )),
                          if (history.isNotEmpty)
                            Text('${history.length} transactions',
                                style: GoogleFonts.inter(
                                    color: AppColors.creamMuted,
                                    fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  if (history.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyEarnings(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverList.separated(
                        itemCount: history.length,
                        separatorBuilder: (context, i) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _EarningRow(order: history[i]),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.totalEarned,
    required this.deliveries,
    required this.pending,
  });

  final double totalEarned;
  final int deliveries;
  final double pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gold, AppColors.goldLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Earned',
              style: GoogleFonts.inter(
                color: AppColors.background.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          Text('R ${totalEarned.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                color: AppColors.background,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  icon: Icons.local_shipping_rounded,
                  label: 'Deliveries',
                  value: '$deliveries',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  icon: Icons.access_time_rounded,
                  label: 'Pending',
                  value: 'R ${pending.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.background.withValues(alpha: 0.7), size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.inter(
                color: AppColors.background,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              )),
          Text(label,
              style: GoogleFonts.inter(
                color: AppColors.background.withValues(alpha: 0.7),
                fontSize: 11,
              )),
        ],
      ),
    );
  }
}

class _EarningRow extends StatelessWidget {
  const _EarningRow({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final date = order.deliveredAt ?? order.createdAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.delivery_dining_rounded,
                color: Colors.greenAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery Fee',
                    style: GoogleFonts.inter(
                      color: AppColors.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(date != null ? _formatDate(date) : '—',
                    style: GoogleFonts.inter(
                        color: AppColors.creamMuted, fontSize: 12)),
                Text('Order #${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}',
                    style: GoogleFonts.inter(
                        color: AppColors.creamMuted.withValues(alpha: 0.7),
                        fontSize: 11)),
              ],
            ),
          ),
          Text('+R ${order.deliveryFee.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                color: Colors.greenAccent,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_months[local.month - 1]} ${local.day}, $hour:$minute';
}

class _EmptyEarnings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.creamMuted, size: 32),
            ),
            const SizedBox(height: 20),
            Text('No earnings yet',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Complete deliveries to start earning',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.creamMuted, fontSize: 13, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
