import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_routes.dart';
import '../core/theme.dart';
import '../data/restaurant_model.dart';
import 'widgets/places_autocomplete_field.dart';

/// Lets a restaurant owner create or edit their restaurant profile —
/// name, branch, address, cuisine tags, delivery details and a cover photo.
class RestaurantOnboardingScreen extends StatefulWidget {
  const RestaurantOnboardingScreen({super.key, this.existing});

  /// When editing an already-created restaurant, its current data.
  final RestaurantModel? existing;

  @override
  State<RestaurantOnboardingScreen> createState() => _RestaurantOnboardingScreenState();
}

class _RestaurantOnboardingScreenState extends State<RestaurantOnboardingScreen> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _branchCtrl = TextEditingController(text: widget.existing?.branch ?? '');
  late final _addressCtrl = TextEditingController(text: widget.existing?.address ?? '');
  late final _tagsCtrl = TextEditingController(text: widget.existing?.tags ?? '');
  late final _minOrderCtrl = TextEditingController(
    text: widget.existing?.minOrder.replaceFirst('R', '') ?? '80',
  );

  late String _deliveryTime = widget.existing?.deliveryTime ?? _deliveryTimes.first;

  late final Map<String, DayHours> _hours = widget.existing != null
      ? Map<String, DayHours>.from(widget.existing!.operatingHours)
      : defaultOperatingHours();

  double? _lat;
  double? _lng;

  Uint8List? _pickedImageBytes;
  String? _existingImageUrl;

  bool _saving = false;
  String? _error;

  static const _deliveryTimes = [
    '15–25 min', '20–30 min', '25–35 min', '30–40 min', '30–45 min', '45–60 min',
  ];

  @override
  void initState() {
    super.initState();
    _existingImageUrl = widget.existing?.coverImageUrl;
    _lat = widget.existing?.lat;
    _lng = widget.existing?.lng;
  }

  bool get _isEditing => widget.existing != null;

  bool get _valid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _branchCtrl.text.trim().isNotEmpty &&
      _addressCtrl.text.trim().isNotEmpty &&
      _tagsCtrl.text.trim().isNotEmpty &&
      _minOrderCtrl.text.trim().isNotEmpty;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImageBytes = bytes;
      _existingImageUrl = null;
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(
              color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.gold),
              title: Text('Choose from gallery',
                  style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14)),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.gold),
              title: Text('Take a photo',
                  style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14)),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_valid || _saving) {
      setState(() => _error = 'Please fill in all the fields above.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      String? coverImageUrl = _existingImageUrl;
      if (_pickedImageBytes != null) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        coverImageUrl = await uploadRestaurantImage(_pickedImageBytes!, uid);
        coverImageUrl ??= _existingImageUrl;
      }

      await RestaurantService.saveRestaurant(
        existingId: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        branch: _branchCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        tags: _tagsCtrl.text.trim(),
        deliveryTime: _deliveryTime,
        minOrder: 'R${_minOrderCtrl.text.trim()}',
        coverImageUrl: coverImageUrl,
        lat: _lat,
        lng: _lng,
        operatingHours: _hours,
      );

      if (!mounted) return;
      context.go(AppRoutes.restaurantPortal);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your restaurant. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _branchCtrl.dispose();
    _addressCtrl.dispose();
    _tagsCtrl.dispose();
    _minOrderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.cream, size: 20),
          ),
        ),
        title: Text(
          _isEditing ? 'Edit Restaurant' : 'Create Your Restaurant',
          style: GoogleFonts.inter(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell customers about your restaurant',
                style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              _buildPhotoPicker(),
              const SizedBox(height: 24),
              _Field(label: 'Restaurant name', controller: _nameCtrl, hint: "e.g. Symon's Kitchin"),
              const SizedBox(height: 16),
              _Field(label: 'Branch', controller: _branchCtrl, hint: 'e.g. Berea'),
              const SizedBox(height: 16),
              PlacesAutocompleteField(
                label: 'Address',
                hint: 'Start typing your address…',
                controller: _addressCtrl,
                onPlaceSelected: (details) {
                  setState(() {
                    _addressCtrl.text = details.formattedAddress;
                    _lat = details.lat;
                    _lng = details.lng;
                  });
                },
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Cuisine tags',
                controller: _tagsCtrl,
                hint: 'e.g. African · Grills · Home Cooked',
              ),
              const SizedBox(height: 16),
              _buildDeliveryTimeDropdown(),
              const SizedBox(height: 16),
              _Field(
                label: 'Minimum order (R)',
                controller: _minOrderCtrl,
                hint: 'e.g. 80',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              _buildOperatingHoursSection(),
              const SizedBox(height: 28),
              if (_error != null) ...[
                Text(_error!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: _saving ? null : _submit,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.background),
                        )
                      : Text(
                          _isEditing ? 'Save Changes' : 'Create Restaurant',
                          style: GoogleFonts.inter(
                            color: AppColors.background,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          image: _pickedImageBytes != null
              ? DecorationImage(image: MemoryImage(_pickedImageBytes!), fit: BoxFit.cover)
              : (_existingImageUrl != null
                  ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                  : null),
        ),
        child: (_pickedImageBytes == null && _existingImageUrl == null)
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: AppColors.gold, size: 28),
                  const SizedBox(height: 10),
                  Text(
                    'Add a cover photo',
                    style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Change photo',
                    style: GoogleFonts.inter(color: AppColors.cream, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDeliveryTimeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estimated delivery time',
            style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _deliveryTime,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.creamMuted),
              style: GoogleFonts.inter(color: AppColors.cream, fontSize: 15),
              items: _deliveryTimes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (value) => setState(() => _deliveryTime = value ?? _deliveryTime),
            ),
          ),
        ),
      ],
    );
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _copyMondayToAllDays() {
    setState(() {
      final monday = _hours['Mon']!;
      for (final day in kWeekdays) {
        _hours[day] = monday;
      }
    });
  }

  Future<void> _pickTime(String day, {required bool isOpenTime}) async {
    final current = _hours[day]!;
    final initial = _parseTime(isOpenTime ? current.openTime : current.closeTime);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      _hours[day] = DayHours(
        isOpen: current.isOpen,
        openTime: isOpenTime ? _formatTime24(picked) : current.openTime,
        closeTime: isOpenTime ? current.closeTime : _formatTime24(picked),
      );
    });
  }

  Widget _buildOperatingHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Operating Hours',
                  style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            GestureDetector(
              onTap: _copyMondayToAllDays,
              child: Text('Copy Monday to all days',
                  style: GoogleFonts.inter(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...kWeekdays.map(_buildDayRow),
      ],
    );
  }

  Widget _buildDayRow(String day) {
    final hours = _hours[day]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kWeekdayLabels[day]!,
                    style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Switch(
                value: hours.isOpen,
                activeThumbColor: AppColors.gold,
                onChanged: (value) => setState(() => _hours[day] = DayHours(
                      isOpen: value,
                      openTime: hours.openTime,
                      closeTime: hours.closeTime,
                    )),
              ),
            ],
          ),
          if (hours.isOpen)
            Row(
              children: [
                Expanded(child: _buildTimeChip(day, hours.openTime, isOpenTime: true)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('to', style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12)),
                ),
                Expanded(child: _buildTimeChip(day, hours.closeTime, isOpenTime: false)),
              ],
            )
          else
            Text('Closed all day', style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String day, String time, {required bool isOpenTime}) {
    return GestureDetector(
      onTap: () => _pickTime(day, isOpenTime: isOpenTime),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          MaterialLocalizations.of(context).formatTimeOfDay(_parseTime(time)),
          style: GoogleFonts.inter(color: AppColors.cream, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(color: AppColors.cream, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.creamMuted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
}
