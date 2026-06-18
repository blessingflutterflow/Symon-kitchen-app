import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_routes.dart';
import '../core/theme.dart';
import '../core/widgets/narrow_body.dart';
import '../data/auth_provider.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;

  bool get _valid => _nameController.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  Future<void> _continue() async {
    if (!_valid || _loading) return;
    setState(() => _loading = true);
    await AuthService.saveName(_nameController.text);
    if (!mounted) return;
    setState(() => _loading = false);
    context.go(AppRoutes.authRole);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NarrowBody(
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What should we call you?',
                style: GoogleFonts.inter(
                  color: AppColors.cream,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This is the name we\'ll use on your orders.',
                style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 14),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameController,
                style: GoogleFonts.inter(color: AppColors.cream, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Your name',
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
              const Spacer(),
              GestureDetector(
                onTap: _valid && !_loading ? _continue : null,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _valid ? AppColors.gold : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.background,
                          ),
                        )
                      : Text(
                          'Continue',
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
      ),
    );
  }
}
