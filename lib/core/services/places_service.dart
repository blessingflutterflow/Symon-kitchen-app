import 'dart:convert';
import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromMap(Map<String, dynamic> map) {
    final structured = map['structured_formatting'] as Map<String, dynamic>? ?? {};
    return PlacePrediction(
      placeId: map['place_id'] as String,
      description: map['description'] as String,
      mainText: structured['main_text'] as String? ?? map['description'] as String,
      secondaryText: structured['secondary_text'] as String? ?? '',
    );
  }
}

class PlaceDetails {
  final String formattedAddress;
  final double lat;
  final double lng;

  const PlaceDetails({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });

  factory PlaceDetails.fromMap(Map<String, dynamic> map) {
    final loc = map['geometry']['location'] as Map<String, dynamic>;
    return PlaceDetails(
      formattedAddress: map['formatted_address'] as String,
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
    );
  }
}

/// Wraps the Google Places Autocomplete + Details REST APIs, restricted to
/// South African addresses (matches where Symon's Kitchin operates).
class PlacesService {
  static const _apiKey = 'AIzaSyB4wHFe2xOgiBKAXmoENZbHwfa-bMQaE-U';
  static const _baseUrl = 'https://maps.googleapis.com/maps/api';

  static Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$_baseUrl/place/autocomplete/json').replace(queryParameters: {
        'input': input,
        'components': 'country:za',
        'types': 'address',
        'key': _apiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        return (data['predictions'] as List)
            .map((p) => PlacePrediction.fromMap(p as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      return [];
    }
    return [];
  }

  static Future<PlaceDetails?> getDetails(String placeId) async {
    try {
      final uri = Uri.parse('$_baseUrl/place/details/json').replace(queryParameters: {
        'place_id': placeId,
        'fields': 'geometry,formatted_address',
        'key': _apiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        return PlaceDetails.fromMap(data['result'] as Map<String, dynamic>);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Resolves a free-text address to a lat/lng via the Geocoding API.
  static Future<PlaceDetails?> geocode(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final uri = Uri.parse('$_baseUrl/geocode/json').replace(queryParameters: {
        'address': address,
        'key': _apiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          return PlaceDetails.fromMap(results.first as Map<String, dynamic>);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Resolves a lat/lng to a human-readable formatted address (reverse geocoding).
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse('$_baseUrl/geocode/json').replace(queryParameters: {
        'latlng': '$lat,$lng',
        'key': _apiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          return results.first['formatted_address'] as String;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Fetches a driving route between two points via the Directions API,
  /// returning the decoded polyline plus ETA/distance for the leg.
  static Future<RouteResult?> getRoute(LatLng origin, LatLng destination) async {
    try {
      final uri = Uri.parse('$_baseUrl/directions/json').replace(queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': _apiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        final routes = data['routes'] as List;
        if (routes.isEmpty) return null;
        final route = routes.first as Map<String, dynamic>;
        final legs = route['legs'] as List;
        if (legs.isEmpty) return null;
        final leg = legs.first as Map<String, dynamic>;
        final overview = route['overview_polyline'] as Map<String, dynamic>;
        return RouteResult(
          points: _decodePolyline(overview['points'] as String),
          durationSeconds: (leg['duration'] as Map<String, dynamic>)['value'] as int,
          distanceMeters: (leg['distance'] as Map<String, dynamic>)['value'] as int,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Straight-line distance between two points, in meters (haversine).
  static double distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  /// Decodes a Google-encoded polyline string into a list of [LatLng] points.
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

/// A driving route between two points: the polyline to render plus the ETA
/// and distance for the leg, as returned by the Directions API.
class RouteResult {
  final List<LatLng> points;
  final int durationSeconds;
  final int distanceMeters;

  const RouteResult({
    required this.points,
    required this.durationSeconds,
    required this.distanceMeters,
  });
}
