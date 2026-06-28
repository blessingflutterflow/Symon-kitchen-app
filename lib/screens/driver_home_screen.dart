import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../core/constants/app_routes.dart';
import '../core/services/fcm_service.dart';
import '../core/services/location_service.dart';
import '../core/services/places_service.dart';
import '../core/theme.dart';
import '../core/widgets/narrow_body.dart';
import '../data/auth_provider.dart';
import '../data/driver_model.dart';
import '../data/order_provider.dart';
import '../data/tracking_provider.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _togglingOnline = false;
  bool _trackingStarted = false;
  bool _cardCollapsed = false; // tap the handle to minimise the card and see the map
  bool _ringing = false;
  bool _ringMuted = false; // driver muted the current batch of requests

  @override
  void dispose() {
    if (_ringing && !kIsWeb) FlutterRingtonePlayer().stop();
    super.dispose();
  }

  // Rings (looping alarm) while the driver is online with unaccepted delivery
  // requests waiting — like Uber/inDrive — and stops once they act.
  void _startRing() {
    if (_ringing || kIsWeb) return;
    _ringing = true;
    FlutterRingtonePlayer().playAlarm(volume: 1.0, looping: true, asAlarm: true);
  }

  void _stopRing() {
    if (!_ringing) return;
    _ringing = false;
    if (!kIsWeb) FlutterRingtonePlayer().stop();
  }

  void _updateRing() {
    // The app is in the foreground here, so the background full-screen call
    // notification (if any) is redundant — clear it; in-app ringing takes over.
    FcmService.cancelDeliveryCall();
    final online = ref.read(myDriverProfileProvider).valueOrNull?.isOnline ?? false;
    final hasActive = ref.read(myActiveDeliveryProvider).valueOrNull != null;
    final orders = ref.read(availableOrdersProvider).valueOrNull ?? const <FoodOrder>[];
    if (orders.isEmpty) _ringMuted = false; // reset mute for the next request
    final shouldRing = online && !hasActive && orders.isNotEmpty && !_ringMuted;
    if (shouldRing) {
      _startRing();
    } else {
      _stopRing();
    }
  }

  Future<void> _toggleOnline(DriverModel driver) async {
    if (_togglingOnline) return;
    setState(() => _togglingOnline = true);
    final goingOnline = !driver.isOnline;
    await DriverService.setOnline(driver.uid, goingOnline);
    if (goingOnline) {
      _trackingStarted = true;
      await TrackingService.start(driver.uid, driver.name);
    } else {
      _trackingStarted = false;
      await TrackingService.stop(driver.uid);
    }
    if (mounted) setState(() => _togglingOnline = false);
  }

  /// If the driver was already online from a previous session, resume
  /// streaming their location now that the screen (and permissions) are live.
  void _ensureTrackingStarted(DriverModel driver) {
    if (!driver.isOnline || _trackingStarted) return;
    _trackingStarted = true;
    TrackingService.start(driver.uid, driver.name);
  }

  Future<void> _signOut() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await TrackingService.stop(uid);
      await DriverService.setOnline(uid, false);
    }
    await AuthService.signOut();
    if (mounted) context.go(AppRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    // Manage the new-delivery ring whenever orders / active delivery / online
    // status change.
    ref.listen(availableOrdersProvider, (_, _) => _updateRing());
    ref.listen(myActiveDeliveryProvider, (_, _) => _updateRing());
    ref.listen(myDriverProfileProvider, (_, _) => _updateRing());

    final profileAsync = ref.watch(myDriverProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const NarrowBody(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        ),
        error: (err, _) =>
            NarrowBody(child: SafeArea(child: _buildError(err.toString()))),
        data: (driver) {
          if (driver == null) {
            // UID is null or driver doc missing — go back to apply
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => context.go(AppRoutes.driverApply),
            );
            return const NarrowBody(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            );
          }
          return _buildMain(driver);
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: GoogleFonts.inter(
              color: AppColors.cream,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.creamMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => ref.refresh(myDriverProfileProvider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.inter(
                  color: AppColors.background,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _signOut,
            child: Text(
              'Sign out',
              style: GoogleFonts.inter(
                color: AppColors.creamMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMain(DriverModel driver) {
    _ensureTrackingStarted(driver);
    final activeOrder = ref.watch(myActiveDeliveryProvider).valueOrNull;
    LatLng? destination;
    if (activeOrder != null &&
        activeOrder.deliveryLat != null &&
        activeOrder.deliveryLng != null) {
      destination = LatLng(activeOrder.deliveryLat!, activeOrder.deliveryLng!);
    }
    // Full-screen map with a compact floating card at the bottom (mirrors
    // Tolta). The card has margins on all sides so it never reaches the screen
    // edges — combined with PointerInterceptor, this keeps taps reliable on web
    // (no cursor ambiguity between the map and the card's buttons).
    return NarrowBody(
      child: Stack(
        children: [
          Positioned.fill(child: _DriverMap(destination: destination)),
          _buildTopBar(driver),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: _buildBottomCard(driver)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(DriverModel driver) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: PointerInterceptor(
        child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.driverProfile),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 10),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                            color: AppColors.gold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                driver.name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppColors.cream,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: driver.isOnline
                                          ? Colors.greenAccent
                                          : AppColors.creamMuted,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    driver.isOnline ? 'Online' : 'Offline',
                                    style: GoogleFonts.inter(
                                      color: driver.isOnline
                                          ? Colors.greenAccent
                                          : AppColors.creamMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _signOut,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 10),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.creamMuted,
                    size: 20,
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

  Widget _buildBottomCard(DriverModel driver) {
    // PointerInterceptor: on web, ensures taps on the card (Accept, online
    // toggle, etc.) reach Flutter instead of being swallowed by the Google
    // Map's DOM element underneath. No-op on mobile.
    return PointerInterceptor(
      child: Container(
        margin: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tappable handle — collapses/expands the card so the driver can
            // see the full map underneath.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _cardCollapsed = !_cardCollapsed),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Icon(
                      _cardCollapsed
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.creamMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (!_cardCollapsed) Flexible(child: _buildSheetContent(driver)),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetContent(DriverModel driver) {
    // Active delivery takes absolute priority
    final activeOrder = ref.watch(myActiveDeliveryProvider).valueOrNull;
    if (activeOrder != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _ActiveDeliveryCard(order: activeOrder),
      );
    }

    if (!driver.isOnline) {
      return _idleContent(
        isOnline: false,
        onToggle: () => _toggleOnline(driver),
        subtitle: 'Go online to start receiving delivery requests.',
      );
    }

    final availableAsync = ref.watch(availableOrdersProvider);
    return availableAsync.when(
      loading: () => _idleContent(
        isOnline: true,
        onToggle: () => _toggleOnline(driver),
        subtitle: 'Looking for delivery requests near you…',
        showPulse: true,
      ),
      error: (err, _) => _idleContent(
        isOnline: true,
        onToggle: () => _toggleOnline(driver),
        subtitle: err.toString(),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return _idleContent(
            isOnline: true,
            onToggle: () => _toggleOnline(driver),
            subtitle: 'You\'ll see incoming delivery requests here. Hang tight!',
            showPulse: true,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      orders.length > 1
                          ? 'New delivery requests (${orders.length})'
                          : 'New delivery request',
                      style: GoogleFonts.inter(
                        color: AppColors.cream,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _ringMuted = !_ringMuted;
                      _updateRing();
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        _ringMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: _ringMuted ? AppColors.creamMuted : AppColors.gold,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                itemCount: orders.length,
                separatorBuilder: (context, i) => const SizedBox(height: 14),
                itemBuilder: (context, i) =>
                    _IncomingOrderCard(order: orders[i], driverId: driver.uid),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _idleContent({
    required bool isOnline,
    required VoidCallback onToggle,
    required String subtitle,
    bool showPulse = false,
  }) {
    return SingleChildScrollView(
      child: _IdleSheet(
        isOnline: isOnline,
        togglingOnline: _togglingOnline,
        onToggle: onToggle,
        subtitle: subtitle,
        showPulse: showPulse,
      ),
    );
  }
}

// ── Driver location map (full screen) ─────────────────────────────────────

class _DriverMap extends StatefulWidget {
  const _DriverMap({this.destination});

  /// The active delivery's drop-off point, if any.
  final LatLng? destination;

  @override
  State<_DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<_DriverMap> {
  GoogleMapController? _controller;
  LatLng? _position;
  bool _loading = true;
  bool _denied = false;
  RouteResult? _route;
  bool _fetchingRoute = false;
  LatLng? _routeOrigin;
  StreamSubscription<dynamic>? _positionSub;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  @override
  void didUpdateWidget(covariant _DriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination) {
      _route = null;
      _routeOrigin = null;
      _fitCamera();
      _maybeFetchRoute();
    }
  }

  Future<void> _loadPosition() async {
    setState(() {
      _loading = true;
      _denied = false;
    });
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }
    setState(() {
      _position = LatLng(position.latitude, position.longitude);
      _loading = false;
    });
    _fitCamera();
    _maybeFetchRoute();

    _positionSub = LocationService.getPositionStream().listen((pos) {
      if (!mounted) return;
      setState(() => _position = LatLng(pos.latitude, pos.longitude));
      _maybeFetchRoute();
    });
  }

  /// Fits the camera to show both the driver and the active delivery's
  /// drop-off point — so the driver can immediately see where to go.
  void _fitCamera() {
    final controller = _controller;
    final position = _position;
    final destination = widget.destination;
    if (controller == null || position == null || destination == null) return;
    final sw = LatLng(
      min(position.latitude, destination.latitude) - 0.005,
      min(position.longitude, destination.longitude) - 0.005,
    );
    final ne = LatLng(
      max(position.latitude, destination.latitude) + 0.005,
      max(position.longitude, destination.longitude) + 0.005,
    );
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 64),
    );
  }

  Future<void> _maybeFetchRoute() async {
    final position = _position;
    final destination = widget.destination;
    if (position == null || destination == null || _fetchingRoute) return;

    final last = _routeOrigin;
    if (last != null && PlacesService.distanceMeters(last, position) < 100) return;

    _fetchingRoute = true;
    _routeOrigin = position;
    final route = await PlacesService.getRoute(position, destination);
    _fetchingRoute = false;
    if (!mounted || route == null) return;
    setState(() => _route = route);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.gold),
      );
    }

    final position = _position;
    if (_denied || position == null) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_rounded,
                color: AppColors.creamMuted,
                size: 36,
              ),
              const SizedBox(height: 14),
              Text(
                'Enable location access to see the map',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.creamMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _loadPosition,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Try again',
                    style: GoogleFonts.inter(
                      color: AppColors.background,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final destination = widget.destination;
    final markers = <Marker>{
      if (destination != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Delivery address'),
        ),
    };
    final polylines = <Polyline>{
      if (_route != null)
        Polyline(
          polylineId: const PolylineId('route'),
          points: _route!.points,
          color: AppColors.gold,
          width: 6,
        ),
    };

    final map = GoogleMap(
      initialCameraPosition: CameraPosition(target: position, zoom: 15),
      onMapCreated: (controller) {
        _controller = controller;
        _fitCamera();
      },
      myLocationEnabled: true,
      // Native recenter button on mobile (correctly positioned by the SDK);
      // hidden on web where map gestures are disabled anyway.
      myLocationButtonEnabled: !kIsWeb,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      zoomGesturesEnabled: !kIsWeb,
      scrollGesturesEnabled: !kIsWeb,
      rotateGesturesEnabled: !kIsWeb,
      tiltGesturesEnabled: !kIsWeb,
      markers: markers,
      polylines: polylines,
    );

    return Stack(
      children: [
        // ClipRect + IgnorePointer: web-only fix. google_maps_flutter_web's
        // internal drag-handler div renders at 100% of an unclipped ancestor
        // (i.e. the whole screen) and swallows clicks meant for the bottom
        // sheet below it. Skipped on mobile — clipping a native platform
        // view can break its touch forwarding, and the bug doesn't occur
        // there, so the map stays fully interactive.
        kIsWeb ? ClipRect(child: IgnorePointer(child: map)) : map,
      ],
    );
  }
}

// ── Idle / online-status bottom sheet content ─────────────────────────────

class _IdleSheet extends StatelessWidget {
  const _IdleSheet({
    required this.isOnline,
    required this.togglingOnline,
    required this.onToggle,
    required this.subtitle,
    this.showPulse = false,
  });

  final bool isOnline;
  final bool togglingOnline;
  final VoidCallback onToggle;
  final String subtitle;
  final bool showPulse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.greenAccent : AppColors.creamMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isOnline ? "You're online" : "You're offline",
                style: GoogleFonts.inter(
                  color: AppColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppColors.creamMuted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: togglingOnline ? null : onToggle,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.surfaceLight : AppColors.gold,
                borderRadius: BorderRadius.circular(14),
                border: isOnline
                    ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5))
                    : null,
              ),
              alignment: Alignment.center,
              child: togglingOnline
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: isOnline
                            ? Colors.redAccent
                            : AppColors.background,
                      ),
                    )
                  : Text(
                      isOnline ? 'Go Offline' : 'Go Online',
                      style: GoogleFonts.inter(
                        color: isOnline
                            ? Colors.redAccent
                            : AppColors.background,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          if (showPulse) ...[
            const SizedBox(height: 20),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Incoming order card (with 30-second countdown) ────────────────────────────

class _IncomingOrderCard extends StatefulWidget {
  const _IncomingOrderCard({required this.order, required this.driverId});

  final FoodOrder order;
  final String driverId;

  @override
  State<_IncomingOrderCard> createState() => _IncomingOrderCardState();
}

class _IncomingOrderCardState extends State<_IncomingOrderCard> {
  static const _countdownSeconds = 30;
  int _secondsLeft = _countdownSeconds;
  Timer? _timer;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_IncomingOrderCard old) {
    super.didUpdateWidget(old);
    if (old.order.id != widget.order.id) {
      _timer?.cancel();
      _secondsLeft = _countdownSeconds;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    debugPrint('[accept] tapped, order=${widget.order.id}, accepting=$_accepting');
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await OrderService.acceptDelivery(widget.order.id, widget.driverId);
      debugPrint('[accept] success, order=${widget.order.id}');
    } catch (e, st) {
      debugPrint('[accept] FAILED: $e\n$st');
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / _countdownSeconds;
    final urgent = _secondsLeft <= 10;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent ? Colors.redAccent : AppColors.gold,
          width: urgent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'New Order',
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.divider,
                      color: urgent ? Colors.redAccent : AppColors.gold,
                      strokeWidth: 3,
                    ),
                    Text(
                      '$_secondsLeft',
                      style: GoogleFonts.inter(
                        color: urgent ? Colors.redAccent : AppColors.cream,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.order.restaurantName,
            style: GoogleFonts.inter(
              color: AppColors.cream,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if ((widget.order.deliveryAddress ?? '').isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.creamMuted,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.order.deliveryAddress!,
                    style: GoogleFonts.inter(
                      color: AppColors.creamMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            widget.order.items
                .map((i) => '${i.quantity}× ${i.name}')
                .join(', '),
            style: GoogleFonts.inter(
              color: AppColors.creamMuted,
              fontSize: 12,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery fee',
                    style: GoogleFonts.inter(
                      color: AppColors.creamMuted,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'R ${widget.order.deliveryFee.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _secondsLeft > 0 && !_accepting ? _accept : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _secondsLeft > 0
                        ? AppColors.gold
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _accepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : Text(
                          _secondsLeft > 0 ? 'Accept' : 'Expired',
                          style: GoogleFonts.inter(
                            color: AppColors.background,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Active delivery card ──────────────────────────────────────────────────────

class _ActiveDeliveryCard extends ConsumerStatefulWidget {
  const _ActiveDeliveryCard({required this.order});
  final FoodOrder order;

  @override
  ConsumerState<_ActiveDeliveryCard> createState() =>
      _ActiveDeliveryCardState();
}

class _ActiveDeliveryCardState extends ConsumerState<_ActiveDeliveryCard> {
  bool _loading = false;

  Future<void> _confirmPickup() async {
    if (_loading) return;
    setState(() => _loading = true);
    await OrderService.confirmPickup(widget.order.id);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirmDelivery() async {
    if (_loading) return;
    setState(() => _loading = true);
    await OrderService.confirmDelivery(widget.order.id);
    // A short chime to confirm the delivery is complete.
    if (!kIsWeb) FlutterRingtonePlayer().playNotification();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isPickedUp = order.status == 'out_for_delivery';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Delivery',
          style: GoogleFonts.inter(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isPickedUp
                      ? Colors.blue.withValues(alpha: 0.15)
                      : AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPickedUp ? 'Out for Delivery' : 'Awaiting Pickup',
                  style: GoogleFonts.inter(
                    color: isPickedUp ? Colors.lightBlueAccent : AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _InfoRow(
                icon: Icons.storefront_rounded,
                label: 'Pick up from',
                value: order.restaurantName,
              ),
              const SizedBox(height: 10),
              if ((order.deliveryAddress ?? '').isNotEmpty)
                _InfoRow(
                  icon: Icons.location_on_rounded,
                  label: 'Deliver to',
                  value: order.deliveryAddress!,
                ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.receipt_long_rounded,
                label: 'Order',
                value: order.items
                    .map((i) => '${i.quantity}× ${i.name}')
                    .join(', '),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _loading
                    ? null
                    : (isPickedUp ? _confirmDelivery : _confirmPickup),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.background,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPickedUp
                                  ? Icons.home_rounded
                                  : Icons.check_circle_rounded,
                              color: AppColors.background,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPickedUp
                                  ? 'Confirm Delivery'
                                  : 'Confirm Pickup',
                              style: GoogleFonts.inter(
                                color: AppColors.background,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.gold, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.creamMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: AppColors.cream,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
