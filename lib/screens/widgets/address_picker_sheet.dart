import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/location_service.dart';
import '../../core/services/places_service.dart';
import '../../core/theme.dart';
import 'places_autocomplete_field.dart';

/// Result of picking an address: a formatted address plus its coordinates.
class AddressPickResult {
  final String address;
  final double lat;
  final double lng;
  const AddressPickResult({required this.address, required this.lat, required this.lng});
}

/// Opens a bottom sheet for the customer to set their delivery address —
/// either via GPS ("use my current location") or by searching for one.
/// Returns the picked address, or null if dismissed without saving.
Future<AddressPickResult?> showAddressPickerSheet(
  BuildContext context, {
  String? initialAddress,
}) {
  return showModalBottomSheet<AddressPickResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddressPickerSheet(initialAddress: initialAddress),
  );
}

class _AddressPickerSheet extends StatefulWidget {
  const _AddressPickerSheet({this.initialAddress});
  final String? initialAddress;

  @override
  State<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<_AddressPickerSheet> {
  late final TextEditingController _controller;
  double? _lat;
  double? _lng;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAddress ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not get your location. Check location permissions.';
        });
      }
      return;
    }
    final address = await PlacesService.reverseGeocode(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (address != null) {
        _controller.text = address;
        _lat = position.latitude;
        _lng = position.longitude;
      } else {
        _error = 'Could not determine your address from your location.';
      }
    });
  }

  void _onPlaceSelected(PlaceDetails details) {
    setState(() {
      _controller.text = details.formattedAddress;
      _lat = details.lat;
      _lng = details.lng;
      _error = null;
    });
  }

  Future<void> _save() async {
    final address = _controller.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Please enter your delivery address.');
      return;
    }

    var lat = _lat;
    var lng = _lng;
    if (lat == null || lng == null) {
      setState(() {
        _busy = true;
        _error = null;
      });
      final details = await PlacesService.geocode(address);
      if (!mounted) return;
      if (details == null) {
        setState(() {
          _busy = false;
          _error = 'Could not locate that address — try selecting a suggestion.';
        });
        return;
      }
      lat = details.lat;
      lng = details.lng;
    }

    if (!mounted) return;
    Navigator.of(context).pop(AddressPickResult(address: address, lat: lat, lng: lng));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Delivery address',
                  style: GoogleFonts.inter(
                    color: AppColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This is the one address used for all your orders.',
                  style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _busy ? null : _useCurrentLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location_rounded, color: AppColors.gold, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Use my current location',
                          style: GoogleFonts.inter(
                            color: AppColors.gold,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_busy) ...[
                          const Spacer(),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PlacesAutocompleteField(
                  controller: _controller,
                  label: 'Or search for an address',
                  hint: 'Street, suburb, city…',
                  onPlaceSelected: _onPlaceSelected,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _busy ? null : _save,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Save address',
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
          ),
        ),
      ),
    );
  }
}
