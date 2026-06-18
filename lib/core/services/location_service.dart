import 'package:geolocator/geolocator.dart';

/// Thin wrapper around `geolocator` for getting the device's current position.
class LocationService {
  LocationService._();

  /// Returns the current position, requesting permission if needed.
  /// Returns null if location services are disabled or permission is denied.
  static Future<Position?> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Continuous position stream. Only emits when the device moves at least
  /// [distanceFilter] metres, avoiding floods of updates while stationary.
  static Stream<Position> getPositionStream({int distanceFilter = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
