import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_routes.dart';
import '../core/theme.dart';
import '../core/widgets/narrow_body.dart';
import '../data/auth_provider.dart';
import '../data/driver_model.dart';

class DriverApplicationScreen extends StatefulWidget {
  const DriverApplicationScreen({super.key});

  @override
  State<DriverApplicationScreen> createState() =>
      _DriverApplicationScreenState();
}

class _DriverApplicationScreenState extends State<DriverApplicationScreen> {
  int _step = 0;
  bool _loading = false;
  String? _error;

  // Step 1 — personal
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _idCtrl = TextEditingController();

  // Step 2 — licence
  final _licenceCtrl = TextEditingController();

  // Step 3 — vehicle
  String _vehicleType = 'Motorbike';
  final _vehicleRegCtrl = TextEditingController();

  static const _vehicleTypes = ['Motorbike', 'Car', 'Bicycle', 'Scooter'];

  bool get _step0Valid =>
      _nameCtrl.text.trim().length >= 2 &&
      _phoneCtrl.text.trim().length >= 9 &&
      _emailCtrl.text.trim().contains('@') &&
      _idCtrl.text.trim().length >= 6;

  bool get _step1Valid => _licenceCtrl.text.trim().length >= 4;

  bool get _step2Valid => _vehicleRegCtrl.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _idCtrl,
        _licenceCtrl, _vehicleRegCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _idCtrl,
        _licenceCtrl, _vehicleRegCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    setState(() { _error = null; _step++; });
  }

  Future<void> _submit() async {
    if (!_step2Valid || _loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      await DriverService.submitApplication(
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        idNumber: _idCtrl.text,
        licenceNumber: _licenceCtrl.text,
        vehicleType: _vehicleType,
        vehicleReg: _vehicleRegCtrl.text,
      );
      if (mounted) context.go(AppRoutes.driverPending);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) context.go(AppRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NarrowBody(
        child: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Driver Application',
                      style: GoogleFonts.inter(
                        color: AppColors.cream,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _signOut,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: AppColors.creamMuted, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            // ── Step indicator ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: _StepIndicator(current: _step, total: 3,
                labels: const ['Personal', 'Licence', 'Vehicle']),
            ),
            // ── Form ──────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: [_buildStep0, _buildStep1, _buildStep2][_step](),
              ),
            ),
            // ── Error ─────────────────────────────────────────────────────
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(_error!,
                    style: GoogleFonts.inter(
                        color: Colors.redAccent, fontSize: 13)),
              ),
            // ── Action button ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _buildActionButton(),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStep0() => Column(
    children: [
      _Field(label: 'Full Name', controller: _nameCtrl,
          hint: 'As it appears on your ID'),
      const SizedBox(height: 16),
      _Field(label: 'Phone Number', controller: _phoneCtrl,
          hint: '0821234567', keyboardType: TextInputType.phone),
      const SizedBox(height: 16),
      _Field(label: 'Email Address', controller: _emailCtrl,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _Field(label: 'SA ID Number', controller: _idCtrl,
          hint: '9001015009087', keyboardType: TextInputType.number),
    ],
  );

  Widget _buildStep1() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Field(label: 'Driver\'s Licence Number', controller: _licenceCtrl,
          hint: 'e.g. 730101 5009 087'),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Document upload will be available in a future update.',
                style: GoogleFonts.inter(
                    color: AppColors.creamMuted, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildStep2() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Vehicle Type',
          style: GoogleFonts.inter(
              color: AppColors.creamMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _vehicleTypes.map((type) {
          final selected = _vehicleType == type;
          return GestureDetector(
            onTap: () => setState(() => _vehicleType = type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.divider,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(type,
                  style: GoogleFonts.inter(
                    color: selected ? AppColors.gold : AppColors.creamMuted,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      _Field(label: 'Vehicle Registration', controller: _vehicleRegCtrl,
          hint: 'e.g. GP 123-456'),
    ],
  );

  Widget _buildActionButton() {
    final canProceed = [_step0Valid, _step1Valid, _step2Valid][_step];
    final isLast = _step == 2;
    return GestureDetector(
      onTap: canProceed && !_loading
          ? (isLast ? _submit : _next)
          : null,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: canProceed ? AppColors.gold : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.background),
              )
            : Text(
                isLast ? 'Submit Application' : 'Next',
                style: GoogleFonts.inter(
                  color: AppColors.background,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator(
      {required this.current, required this.total, required this.labels});

  final int current;
  final int total;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total * 2 - 1, (i) {
        if (i.isOdd) {
          // connector line
          final stepIndex = (i - 1) ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: stepIndex < current
                  ? AppColors.gold
                  : AppColors.divider,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final done = stepIndex < current;
        final active = stepIndex == current;
        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: done || active ? AppColors.gold : AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done || active ? AppColors.gold : AppColors.divider,
                ),
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.background, size: 16)
                  : Text('${stepIndex + 1}',
                      style: GoogleFonts.inter(
                        color: active
                            ? AppColors.background
                            : AppColors.creamMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
            ),
            const SizedBox(height: 4),
            Text(labels[stepIndex],
                style: GoogleFonts.inter(
                  color: done || active
                      ? AppColors.gold
                      : AppColors.creamMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                )),
          ],
        );
      }),
    );
  }
}

// ── Reusable form field ────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.creamMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
