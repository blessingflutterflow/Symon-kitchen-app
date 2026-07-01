import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_routes.dart';
import '../core/theme.dart';
import '../core/widgets/narrow_body.dart';
import '../data/auth_provider.dart';
import '../data/driver_model.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  static const _vehicleTypes = ['Motorbike', 'Car', 'Bicycle', 'Scooter'];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _vehicleRegCtrl = TextEditingController();
  String _vehicleType = _vehicleTypes.first;

  bool _initialized = false;
  bool _saving = false;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _vehicleRegCtrl]) {
      c.addListener(() => setState(() => _saved = false));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _vehicleRegCtrl.dispose();
    super.dispose();
  }

  void _populate(DriverModel driver) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = driver.name;
    _phoneCtrl.text = driver.phone;
    _emailCtrl.text = driver.email;
    _vehicleRegCtrl.text = driver.vehicleReg;
    _vehicleType = _vehicleTypes.contains(driver.vehicleType)
        ? driver.vehicleType
        : _vehicleTypes.first;
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().contains('@') &&
      _vehicleRegCtrl.text.trim().isNotEmpty;

  Future<void> _save(String uid) async {
    if (_saving || !_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    try {
      await DriverService.updateProfile(
        uid: uid,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        vehicleType: _vehicleType,
        vehicleReg: _vehicleRegCtrl.text,
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _saved = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _signOut() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await DriverService.setOnline(uid, false);
    await AuthService.signOut();
    if (mounted) context.go(AppRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myDriverProfileProvider);

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
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.cream,
              size: 20,
            ),
          ),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.inter(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: NarrowBody(
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.creamMuted),
              ),
            ),
          ),
          data: (driver) {
            if (driver == null) return const SizedBox.shrink();
            _populate(driver);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                            color: AppColors.gold,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          driver.name.isNotEmpty ? driver.name : 'Driver',
                          style: GoogleFonts.inter(
                            color: AppColors.cream,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _SectionLabel('Personal details'),
                  const SizedBox(height: 12),
                  _Field(label: 'Full Name', controller: _nameCtrl),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Phone Number',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Email Address',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('Vehicle'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _vehicleTypes.map((type) {
                      final selected = _vehicleType == type;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _vehicleType = type;
                          _saved = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.gold.withValues(alpha: 0.15)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppColors.gold
                                  : AppColors.divider,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            type,
                            style: GoogleFonts.inter(
                              color: selected
                                  ? AppColors.gold
                                  : AppColors.creamMuted,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Vehicle Registration',
                    controller: _vehicleRegCtrl,
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('Verification'),
                  const SizedBox(height: 12),
                  _ReadOnlyRow(
                      label: driver.idType == 'passport'
                          ? 'Passport Number'
                          : 'SA ID Number',
                      value: driver.idNumber),
                  const SizedBox(height: 10),
                  _ReadOnlyRow(
                    label: "Driver's Licence Number",
                    value: driver.licenceNumber,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contact support to update your verification details.',
                    style: GoogleFonts.inter(
                      color: AppColors.creamMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: GoogleFonts.inter(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (_saved)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Profile updated.',
                        style: GoogleFonts.inter(
                          color: Colors.greenAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: _canSave ? () => _save(driver.uid) : null,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: _canSave
                            ? AppColors.gold
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.background,
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.inter(
                                color: AppColors.background,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _signOut,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Sign out',
                            style: GoogleFonts.inter(
                              color: Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        color: AppColors.gold,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.creamMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(color: AppColors.cream, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.creamMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : '—',
            style: GoogleFonts.inter(color: AppColors.cream, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
