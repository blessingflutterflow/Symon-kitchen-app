import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/services/places_service.dart';
import '../core/theme.dart';
import '../data/order_provider.dart';
import '../data/tracking_provider.dart';
import 'widgets/route_eta_pill.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.orderId});
  final String orderId;

  static const _steps = [
    _Step(Icons.receipt_long_rounded, 'Order Placed',
        'Your order has been sent to the restaurant.'),
    _Step(Icons.check_circle_outline_rounded, 'Confirmed by Restaurant',
        'The kitchen has accepted your order.'),
    _Step(Icons.outdoor_grill_rounded, 'Being Prepared',
        'Your food is being freshly prepared.'),
    _Step(Icons.delivery_dining_rounded, 'Driver Assigned',
        'A driver is on their way to pick up your order.'),
    _Step(Icons.electric_moped_rounded, 'Out for Delivery',
        'Your order is on its way to you!'),
    _Step(Icons.home_rounded, 'Delivered',
        'Enjoy your meal! Rate your experience below.'),
  ];

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen>
    with TickerProviderStateMixin {
  LatLng? _destLatLng;
  bool _geocoding = false;
  bool _hasCenteredOnDriver = false;
  GoogleMapController? _mapController;
  RouteResult? _route;
  LatLng? _routeOrigin;
  bool _fetchingRoute = false;

  // Smoothly glides the driver marker between Firestore position updates
  // instead of letting it jump straight to each new fix.
  late final AnimationController _markerController = AnimationController(
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  )..addListener(() {
      final tween = _markerTween;
      if (tween == null) return;
      setState(() => _animatedDriverPos = tween.evaluate(_markerController));
    });
  _LatLngTween? _markerTween;
  LatLng? _animatedDriverPos;
  LatLng? _lastDriverPos;

  @override
  void dispose() {
    _mapController?.dispose();
    _markerController.dispose();
    super.dispose();
  }

  /// Updates the position used to render the driver marker. The first fix
  /// is shown immediately; subsequent fixes glide from the last displayed
  /// position to the new one over [_markerController]'s duration.
  void _updateDriverMarker(LatLng newPos) {
    if (_animatedDriverPos == null) {
      _animatedDriverPos = newPos;
      _lastDriverPos = newPos;
      return;
    }
    if (_lastDriverPos == newPos) return;

    _markerTween = _LatLngTween(begin: _animatedDriverPos!, end: newPos);
    _lastDriverPos = newPos;
    _markerController.forward(from: 0);
  }

  /// Resolves the delivery destination once the order goes out for delivery,
  /// so it can be pinned on the live map. Prefers the lat/lng captured at
  /// checkout; falls back to geocoding the address for older orders that
  /// were placed before coordinates were stored.
  void _maybeGeocode(FoodOrder order) {
    if (_destLatLng != null) return;
    if (order.status != 'out_for_delivery') return;

    final lat = order.deliveryLat;
    final lng = order.deliveryLng;
    if (lat != null && lng != null) {
      _destLatLng = LatLng(lat, lng);
      return;
    }

    final address = order.deliveryAddress;
    if (_geocoding || address == null || address.trim().isEmpty) return;

    _geocoding = true;
    PlacesService.geocode(address).then((details) {
      if (!mounted) return;
      setState(() {
        _geocoding = false;
        if (details != null) {
          _destLatLng = LatLng(details.lat, details.lng);
        }
      });
    });
  }

  void _fitCamera(LatLng? driverPos) {
    final controller = _mapController;
    final dest = _destLatLng;
    if (controller == null) return;

    if (driverPos != null && dest != null) {
      final sw = LatLng(
        min(driverPos.latitude, dest.latitude) - 0.005,
        min(driverPos.longitude, dest.longitude) - 0.005,
      );
      final ne = LatLng(
        max(driverPos.latitude, dest.latitude) + 0.005,
        max(driverPos.longitude, dest.longitude) + 0.005,
      );
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 64),
      );
    } else if (driverPos != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(driverPos, 15));
    } else if (dest != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(dest, 15));
    }
  }

  void _maybeCenterOnDriver(LatLng? driverPos) {
    if (driverPos == null || _hasCenteredOnDriver || _mapController == null) return;
    _hasCenteredOnDriver = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera(driverPos));
  }

  /// Fetches the driving route (and ETA) from the driver to the delivery
  /// address, refreshing it as the driver moves a meaningful distance.
  void _maybeFetchRoute(LatLng? driverPos) {
    final dest = _destLatLng;
    if (driverPos == null || dest == null || _fetchingRoute) return;

    final last = _routeOrigin;
    if (last != null && PlacesService.distanceMeters(last, driverPos) < 100) return;

    _fetchingRoute = true;
    _routeOrigin = driverPos;
    PlacesService.getRoute(driverPos, dest).then((route) {
      _fetchingRoute = false;
      if (!mounted || route == null) return;
      setState(() => _route = route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text(
          'Order Tracking',
          style: GoogleFonts.inter(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
        error: (_, _) => _buildMessage(
          icon: Icons.error_outline_rounded,
          title: 'Couldn\'t load this order',
          body: 'Please check your connection and try again.',
        ),
        data: (order) {
          if (order == null) {
            return _buildMessage(
              icon: Icons.search_off_rounded,
              title: 'Order not found',
              body: 'This order may have been removed.',
            );
          }
          _maybeGeocode(order);
          return _buildContent(order);
        },
      ),
    );
  }

  Widget _buildMessage({required IconData icon, required String title, required String body}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.creamMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(color: AppColors.cream, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  static _BannerInfo _bannerFor(FoodOrder order) {
    switch (order.status) {
      case 'placed':
        return const _BannerInfo(Icons.receipt_long_rounded, 'Order Placed!',
            'Your order has been sent to the restaurant.');
      case 'confirmed':
        return const _BannerInfo(Icons.check_rounded, 'Order Confirmed!',
            'The kitchen has accepted your order.');
      case 'preparing':
        return const _BannerInfo(Icons.outdoor_grill_rounded, 'Being Prepared',
            'Your food is being freshly prepared.');
      case 'driver_assigned':
        return const _BannerInfo(Icons.delivery_dining_rounded, 'Driver Assigned',
            'A driver is heading to pick up your order.');
      case 'out_for_delivery':
        return const _BannerInfo(Icons.electric_moped_rounded, 'Out for Delivery!',
            'Your order is on its way to you!');
      case 'delivered':
        return const _BannerInfo(Icons.home_rounded, 'Delivered!',
            'Enjoy your meal!');
      case 'cancellation_requested':
        return const _BannerInfo(Icons.hourglass_top_rounded, 'Cancellation Requested',
            'Waiting for the restaurant to confirm your refund.');
      case 'cancelled':
        return const _BannerInfo(Icons.cancel_outlined, 'Order Cancelled',
            'Your refund is on the way — allow 3–5 business days.');
      default:
        return const _BannerInfo(Icons.receipt_long_rounded, 'Order Placed!',
            'Your order has been sent to the restaurant.');
    }
  }

  Widget _buildContent(FoodOrder order) {
    final driverId = order.driverId;
    final isLiveTracking = order.status == 'out_for_delivery' &&
        driverId != null &&
        driverId.isNotEmpty;

    if (isLiveTracking) {
      final driverLoc = ref.watch(driverTrackingProvider(driverId)).valueOrNull;
      return _buildLiveView(order, driverLoc);
    }
    return _buildStatusView(order);
  }

  Future<void> _showCancelSheet(FoodOrder order) async {
    final reasons = [
      'Restaurant took too long',
      'Item not available / out of stock',
      'Restaurant did not respond',
      'Ordered by mistake',
      'Other',
    ];
    String selected = reasons.first;
    final otherController = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cancel Order',
                  style: GoogleFonts.inter(
                      color: AppColors.cream,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Please tell us why you\'re cancelling.',
                  style: GoogleFonts.inter(
                      color: AppColors.creamMuted, fontSize: 13)),
              const SizedBox(height: 20),
              ...reasons.map((r) => RadioListTile<String>(
                    value: r,
                    groupValue: selected,
                    onChanged: (v) => setSheet(() => selected = v!),
                    activeColor: AppColors.gold,
                    title: Text(r,
                        style: GoogleFonts.inter(
                            color: AppColors.cream, fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
              if (selected == 'Other') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: otherController,
                  style: GoogleFonts.inter(color: AppColors.cream, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Describe your reason…',
                    hintStyle:
                        GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.divider)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.divider)),
                  ),
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setSheet(() => submitting = true);
                          final reason = selected == 'Other'
                              ? otherController.text.trim().isEmpty
                                  ? 'Other'
                                  : otherController.text.trim()
                              : selected;
                          await OrderService.cancelOrder(
                              order.id, reason, order.status);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5252),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Submit Cancellation',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    otherController.dispose();
  }

  Widget _buildStatusView(FoodOrder order) {
    final banner = _bannerFor(order);
    final isCancelled =
        order.status == 'cancelled' || order.status == 'cancellation_requested';
    final canCancel =
        order.status == 'placed' || order.status == 'confirmed';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCancelled
                    ? const Color(0xFFFF5252).withValues(alpha: 0.3)
                    : AppColors.gold.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isCancelled ? const Color(0xFFFF5252) : AppColors.gold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isCancelled ? const Color(0xFFFF5252) : AppColors.gold)
                            .withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Icon(banner.icon, color: AppColors.background, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  banner.title,
                  style: GoogleFonts.inter(
                    color: AppColors.cream,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  banner.subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.creamMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.restaurantName,
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: R ${order.total.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: AppColors.creamMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          if (canCancel) ...[
            GestureDetector(
              onTap: () => _showCancelSheet(order),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel_outlined,
                        color: Color(0xFFFF5252), size: 18),
                    const SizedBox(width: 8),
                    Text('Cancel Order',
                        style: GoogleFonts.inter(
                            color: const Color(0xFFFF5252),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (!isCancelled) ...[
            Text(
              'Live Order Status',
              style: GoogleFonts.inter(
                color: AppColors.cream,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 20),

            ...List.generate(TrackingScreen._steps.length, (index) {
              final isActive = index <= order.statusIndex;
              final isLast = index == TrackingScreen._steps.length - 1;
              return _buildStep(TrackingScreen._steps[index], isActive, isLast);
            }),
          ],

          const SizedBox(height: 32),

          // Estimated time card — hidden for cancelled/requested
          if (!isCancelled) Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
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
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.access_time_rounded, color: AppColors.gold, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Delivery Time',
                      style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '30 – 45 minutes',
                      style: GoogleFonts.inter(
                        color: AppColors.cream,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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

  /// Full-screen live tracking view shown while the order is out for
  /// delivery — mirrors Tolta's `_LiveView` (big map up top, driver/order
  /// info panel below) instead of the step-by-step status view.
  Widget _buildLiveView(FoodOrder order, DriverLocation? driverLoc) {
    final markers = <Marker>{};
    LatLng? driverPos;
    var isLive = false;
    var driverName = 'Your driver';

    final loc = driverLoc;
    if (loc != null && loc.isActive) {
      isLive = true;
      driverName = loc.driverName;
      driverPos = LatLng(loc.lat, loc.lng);
      _updateDriverMarker(driverPos);
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _animatedDriverPos ?? driverPos,
        rotation: loc.bearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: loc.driverName),
      ));
    }
    if (_destLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Delivery address'),
      ));
    }

    final initialTarget = driverPos ?? _destLatLng ?? const LatLng(-26.2041, 28.0473);
    _maybeCenterOnDriver(driverPos);
    _maybeFetchRoute(driverPos);

    final polylines = <Polyline>{
      if (_route != null)
        Polyline(
          polylineId: const PolylineId('route'),
          points: _route!.points,
          color: AppColors.gold,
          width: 4,
        ),
    };

    final mapHeight = (MediaQuery.sizeOf(context).height * 0.48).clamp(280.0, 440.0);

    final map = GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
      markers: markers,
      polylines: polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      zoomGesturesEnabled: !kIsWeb,
      scrollGesturesEnabled: !kIsWeb,
      rotateGesturesEnabled: !kIsWeb,
      tiltGesturesEnabled: !kIsWeb,
      onMapCreated: (controller) {
        _mapController = controller;
        _maybeCenterOnDriver(driverPos);
      },
    );

    return Column(
      children: [
        SizedBox(
          height: mapHeight,
          width: double.infinity,
          child: Stack(
            children: [
              // ClipRect + IgnorePointer: web-only fix. google_maps_flutter_web's
              // internal drag-handler div renders at 100% of an unclipped
              // ancestor (i.e. the whole screen) and swallows clicks meant for
              // the overlay widgets above it. Skipped on mobile — clipping a
              // native platform view can break its touch forwarding, and the
              // bug doesn't occur there, so the map stays fully interactive.
              kIsWeb ? ClipRect(child: IgnorePointer(child: map)) : map,
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isLive ? const Color(0xFF2ECC71) : AppColors.creamMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isLive ? '$driverName is on the way' : 'Connecting to your driver…',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppColors.cream,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_route != null) ...[
                        const SizedBox(height: 8),
                        RouteEtaPill(route: _route!),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: GestureDetector(
                  onTap: () => _fitCamera(driverPos),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 8),
                      ],
                    ),
                    child: const Icon(
                      Icons.center_focus_strong_rounded,
                      color: AppColors.gold,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driver card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          color: AppColors.background,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName,
                              style: GoogleFonts.inter(
                                color: AppColors.cream,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Heading to your location',
                              style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Order summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.restaurantName,
                        style: GoogleFonts.inter(
                          color: AppColors.cream,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total: R ${order.total.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_rounded, color: AppColors.gold, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            order.deliveryAddress!,
                            style: GoogleFonts.inter(
                              color: AppColors.creamMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(_Step step, bool isActive, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive ? AppColors.gold : AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AppColors.gold : AppColors.divider,
                  width: isActive ? 0 : 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                step.icon,
                color: isActive ? AppColors.background : AppColors.creamMuted,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isActive ? AppColors.gold.withValues(alpha: 0.4) : AppColors.divider,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: GoogleFonts.inter(
                    color: isActive ? AppColors.cream : AppColors.creamMuted,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.description,
                  style: GoogleFonts.inter(
                    color: AppColors.creamMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Step {
  final IconData icon;
  final String label;
  final String description;
  const _Step(this.icon, this.label, this.description);
}

class _BannerInfo {
  final IconData icon;
  final String title;
  final String subtitle;
  const _BannerInfo(this.icon, this.title, this.subtitle);
}

/// Linearly interpolates between two map coordinates, used to animate the
/// driver marker gliding from its last known position to a new one.
class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required LatLng begin, required LatLng end})
      : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    final from = begin!;
    final to = end!;
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }
}
