import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/places_service.dart';
import '../../core/theme.dart';

/// Small pill overlaying a map, showing a route's ETA and distance.
class RouteEtaPill extends StatelessWidget {
  const RouteEtaPill({super.key, required this.route});
  final RouteResult route;

  @override
  Widget build(BuildContext context) {
    final minutes = (route.durationSeconds / 60).round();
    final km = route.distanceMeters / 1000;
    final distanceLabel = km >= 10 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_rounded, color: AppColors.gold, size: 16),
          const SizedBox(width: 6),
          Text(
            '$minutes min',
            style: GoogleFonts.inter(
              color: AppColors.cream,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: AppColors.divider),
          const SizedBox(width: 8),
          Text(
            distanceLabel,
            style: GoogleFonts.inter(
              color: AppColors.creamMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
