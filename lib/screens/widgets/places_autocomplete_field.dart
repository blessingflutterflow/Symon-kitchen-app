import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/places_service.dart';
import '../../core/theme.dart';

/// Address text field with live Google Places suggestions. Selecting a
/// suggestion resolves it to a formatted address + lat/lng via [onPlaceSelected].
class PlacesAutocompleteField extends StatefulWidget {
  const PlacesAutocompleteField({
    super.key,
    required this.controller,
    required this.onPlaceSelected,
    this.label,
    this.hint,
  });

  final TextEditingController controller;
  final ValueChanged<PlaceDetails> onPlaceSelected;
  final String? label;
  final String? hint;

  @override
  State<PlacesAutocompleteField> createState() => _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  final _focusNode = FocusNode();

  List<PlacePrediction> _predictions = [];
  bool _loading = false;
  bool _showDropdown = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showDropdown = false);
        });
      }
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _showDropdown = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final results = await PlacesService.autocomplete(query);
    if (!mounted) return;
    setState(() {
      _predictions = results;
      _loading = false;
      _showDropdown = results.isNotEmpty;
    });
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    setState(() {
      _showDropdown = false;
      _loading = true;
    });
    widget.controller.text = prediction.description;
    _focusNode.unfocus();

    final details = await PlacesService.getDetails(prediction.placeId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (details != null) widget.onPlaceSelected(details);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Google Places REST API doesn't send CORS headers — browsers block it.
    // On web, fall back to a plain text field so the user can type manually.
    if (kIsWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(widget.label!,
                style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: widget.controller,
            style: GoogleFonts.inter(color: AppColors.cream, fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hint ?? 'Type your address…',
              hintStyle: GoogleFonts.inter(color: AppColors.creamMuted),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.creamMuted, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!,
              style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          style: GoogleFonts.inter(color: AppColors.cream, fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.hint ?? 'Search address…',
            hintStyle: GoogleFonts.inter(color: AppColors.creamMuted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.creamMuted, size: 20),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
          ),
        ),
        if (_showDropdown && _predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _predictions.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, i) {
                final p = _predictions[i];
                return InkWell(
                  onTap: () => _selectPrediction(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: AppColors.gold, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.mainText,
                                style: GoogleFonts.inter(color: AppColors.cream, fontSize: 13.5, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (p.secondaryText.isNotEmpty)
                                Text(
                                  p.secondaryText,
                                  style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 11.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
