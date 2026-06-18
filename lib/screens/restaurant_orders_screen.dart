import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../data/order_provider.dart';

class RestaurantOrdersScreen extends ConsumerStatefulWidget {
  const RestaurantOrdersScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  ConsumerState<RestaurantOrdersScreen> createState() =>
      _RestaurantOrdersScreenState();
}

class _RestaurantOrdersScreenState extends ConsumerState<RestaurantOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _activeStatuses = [
    'confirmed',
    'preparing',
    'driver_assigned',
    'out_for_delivery',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<FoodOrder> _filterTab(List<FoodOrder> all, int tab) {
    switch (tab) {
      case 0:
        return all.where((o) => o.status == 'placed' || o.status == 'cancellation_requested').toList();
      case 1:
        return all.where((o) => _activeStatuses.contains(o.status)).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(restaurantOrdersProvider(widget.restaurantId));

    final newCount =
        ordersAsync.valueOrNull?.where((o) => o.status == 'placed' || o.status == 'cancellation_requested').length ?? 0;
    final activeCount = ordersAsync.valueOrNull
            ?.where((o) => _activeStatuses.contains(o.status))
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.cream, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Incoming Orders',
          style: GoogleFonts.inter(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: TabBar(
            controller: _tabs,
            indicatorColor: AppColors.gold,
            indicatorWeight: 2.5,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.creamMuted,
            labelStyle:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: [
              _TabItem(label: 'New', count: newCount),
              _TabItem(label: 'Active', count: activeCount),
              const Tab(text: 'All'),
            ],
          ),
        ),
      ),
      body: ordersAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: GoogleFonts.inter(color: AppColors.creamMuted)),
        ),
        data: (all) => TabBarView(
          controller: _tabs,
          children: List.generate(
            3,
            (i) => _OrdersList(orders: _filterTab(all, i)),
          ),
        ),
      ),
    );
  }
}

// ── Tab label with count badge ────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  color: AppColors.background,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Orders list ───────────────────────────────────────────────────────────────

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders});

  final List<FoodOrder> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(32),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.receipt_long_outlined,
                  color: AppColors.creamMuted, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'No orders here',
              style: GoogleFonts.inter(
                  color: AppColors.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'New orders will appear here.',
              style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _OrderCard(order: orders[i]),
      ),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatefulWidget {
  const _OrderCard({required this.order});

  final FoodOrder order;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  late String _status;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
  }

  @override
  void didUpdateWidget(_OrderCard old) {
    super.didUpdateWidget(old);
    _status = widget.order.status;
  }

  Color get _badgeColor {
    switch (_status) {
      case 'placed':
        return AppColors.gold;
      case 'confirmed':
        return const Color(0xFF4A9EFF);
      case 'preparing':
        return const Color(0xFFFF9B21);
      case 'driver_assigned':
        return const Color(0xFF52C988);
      case 'out_for_delivery':
        return const Color(0xFF4A9EFF);
      case 'delivered':
        return AppColors.creamMuted;
      case 'cancellation_requested':
        return const Color(0xFFFF9B21);
      case 'cancelled':
        return const Color(0xFFFF5252);
      default:
        return AppColors.creamMuted;
    }
  }

  String get _badgeLabel {
    switch (_status) {
      case 'placed':
        return 'New';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'driver_assigned':
        return 'Ready';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancellation_requested':
        return 'Cancel Request';
      case 'cancelled':
        return 'Cancelled';
      default:
        return _status;
    }
  }

  String get _nextStatus {
    switch (_status) {
      case 'placed':
        return 'confirmed';
      case 'confirmed':
        return 'preparing';
      case 'preparing':
        return 'driver_assigned';
      default:
        return '';
    }
  }

  String get _actionLabel {
    switch (_status) {
      case 'placed':
        return 'Accept';
      case 'confirmed':
        return 'Start Preparing';
      case 'preparing':
        return 'Ready for Pickup';
      default:
        return '';
    }
  }

  Future<void> _advance() async {
    final next = _nextStatus;
    if (next.isEmpty || _updating) return;
    setState(() => _updating = true);
    await OrderService.updateStatus(widget.order.id, next);
    if (mounted) setState(() { _status = next; _updating = false; });
  }

  Future<void> _decline() async {
    if (_updating) return;
    setState(() => _updating = true);
    await OrderService.updateStatus(widget.order.id, 'cancelled');
    if (mounted) setState(() { _status = 'cancelled'; _updating = false; });
  }

  Future<void> _confirmRefund() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await OrderService.processRefund(widget.order.id);
      if (mounted) setState(() { _status = 'cancelled'; _updating = false; });
    } catch (_) {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _rejectCancellation() async {
    if (_updating) return;
    final previous = widget.order.cancellationReason != null ? 'confirmed' : 'placed';
    setState(() => _updating = true);
    await OrderService.rejectCancellation(widget.order.id, previous);
    if (mounted) setState(() { _status = previous; _updating = false; });
  }

  String get _relativeTime {
    final dt = widget.order.createdAt;
    if (dt == null) return 'just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }

  String get _shortId => widget.order.id.substring(0, 8).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final isNew = _status == 'placed';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isNew ? AppColors.gold.withValues(alpha: 0.5) : AppColors.divider,
          width: isNew ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#$_shortId',
                            style: GoogleFonts.inter(
                              color: AppColors.cream,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(
                              label: _badgeLabel, color: _badgeColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _relativeTime,
                            style: GoogleFonts.inter(
                                color: AppColors.creamMuted, fontSize: 11.5),
                          ),
                          if (widget.order.customerName != null &&
                              widget.order.customerName!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.person_outline_rounded,
                                color: AppColors.creamMuted, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              widget.order.customerName!,
                              style: GoogleFonts.inter(
                                  color: AppColors.creamMuted, fontSize: 11.5),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  'R ${widget.order.total.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          // ── Items ─────────────────────────────────────────────────────────
          if (widget.order.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: widget.order.items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                '${item.quantity}×  ${item.name}',
                                style: GoogleFonts.inter(
                                    color: AppColors.cream, fontSize: 12.5),
                              ),
                              const Spacer(),
                              Text(
                                'R ${(item.price * item.quantity).toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  color: AppColors.creamMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          // ── Cancellation request ──────────────────────────────────────────
          if (_status == 'cancellation_requested') ...[
            Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFFF9B21), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Customer Cancellation Request',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFF9B21),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (widget.order.cancellationReason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Reason: ${widget.order.cancellationReason}',
                      style: GoogleFonts.inter(
                          color: AppColors.creamMuted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Reject',
                          color: AppColors.surface,
                          textColor: AppColors.creamMuted,
                          bordered: true,
                          loading: false,
                          onTap: _rejectCancellation,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _ActionButton(
                          label: 'Confirm Refund',
                          color: const Color(0xFFFF5252),
                          textColor: Colors.white,
                          loading: _updating,
                          onTap: _confirmRefund,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // ── Action row ────────────────────────────────────────────────────
          if (_nextStatus.isNotEmpty) ...[
            Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_status == 'placed') ...[
                    Expanded(
                      child: _ActionButton(
                        label: 'Decline',
                        color: AppColors.surface,
                        textColor: AppColors.creamMuted,
                        bordered: true,
                        loading: false,
                        onTap: _decline,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: _status == 'placed' ? 2 : 1,
                    child: _ActionButton(
                      label: _actionLabel,
                      color: AppColors.gold,
                      textColor: AppColors.background,
                      loading: _updating,
                      onTap: _advance,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_status == 'driver_assigned') ...[
            Divider(height: 1, color: AppColors.divider),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.delivery_dining_rounded,
                      color: AppColors.creamMuted, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Waiting for driver to pick up',
                    style: GoogleFonts.inter(
                        color: AppColors.creamMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ] else if (_status == 'out_for_delivery') ...[
            Divider(height: 1, color: AppColors.divider),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.delivery_dining_rounded,
                      color: Color(0xFF52C988), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Driver on the way to customer',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF52C988), fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.loading = false,
    this.bordered = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final bool loading;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: bordered ? Border.all(color: AppColors.divider) : null,
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
