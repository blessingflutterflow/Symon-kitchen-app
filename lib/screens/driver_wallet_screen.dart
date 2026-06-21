import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../core/widgets/narrow_body.dart';
import '../data/driver_model.dart';
import '../data/order_provider.dart';

// South African banks with their Paystack bank codes
const _saBanks = [
  {'name': 'ABSA', 'code': '632005'},
  {'name': 'African Bank', 'code': '430000'},
  {'name': 'Capitec Bank', 'code': '470010'},
  {'name': 'Discovery Bank', 'code': '679000'},
  {'name': 'FNB', 'code': '250655'},
  {'name': 'Investec', 'code': '580105'},
  {'name': 'Nedbank', 'code': '198765'},
  {'name': 'Standard Bank', 'code': '051001'},
  {'name': 'TymeBank', 'code': '678910'},
];

class DriverWalletScreen extends ConsumerWidget {
  const DriverWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(myDeliveryHistoryProvider);
    final payoutsAsync = ref.watch(myPayoutsProvider);
    final profileAsync = ref.watch(myDriverProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NarrowBody(
        child: SafeArea(
          child: historyAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(err.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppColors.creamMuted)),
              ),
            ),
            data: (history) {
              final totalEarned =
                  history.fold<double>(0, (sum, o) => sum + o.deliveryFee);
              final payouts = payoutsAsync.valueOrNull ?? const <DriverPayout>[];
              final paidOut = payouts
                  .where((p) => p.status == 'success')
                  .fold<double>(0, (sum, p) => sum + p.amountRands);
              final driver = profileAsync.valueOrNull;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              color: AppColors.gold, size: 26),
                          const SizedBox(width: 12),
                          Text('My Wallet',
                              style: GoogleFonts.inter(
                                color: AppColors.cream,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              )),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _BalanceCard(
                        totalEarned: totalEarned,
                        deliveries: history.length,
                        paidOut: paidOut,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _BankAccountSection(driver: driver),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _PayoutInfoNote(hasBank: driver?.hasBankAccount ?? false),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                      child: Text('Payout History',
                          style: GoogleFonts.inter(
                            color: AppColors.cream,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                  ),
                  if (payouts.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptyPayouts(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverList.separated(
                        itemCount: payouts.length,
                        separatorBuilder: (context, i) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _PayoutRow(payout: payouts[i]),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.totalEarned,
    required this.deliveries,
    required this.paidOut,
  });

  final double totalEarned;
  final int deliveries;
  final double paidOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gold, AppColors.goldLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Earned',
              style: GoogleFonts.inter(
                color: AppColors.background.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          Text('R ${totalEarned.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                color: AppColors.background,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  icon: Icons.local_shipping_rounded,
                  label: 'Deliveries',
                  value: '$deliveries',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  icon: Icons.check_circle_rounded,
                  label: 'Paid Out',
                  value: 'R ${paidOut.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.background.withValues(alpha: 0.7), size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.inter(
                color: AppColors.background,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              )),
          Text(label,
              style: GoogleFonts.inter(
                color: AppColors.background.withValues(alpha: 0.7),
                fontSize: 11,
              )),
        ],
      ),
    );
  }
}

/// Explains how the driver gets paid — automatic per delivery.
class _PayoutInfoNote extends StatelessWidget {
  const _PayoutInfoNote({required this.hasBank});
  final bool hasBank;

  @override
  Widget build(BuildContext context) {
    final color = hasBank ? AppColors.gold : const Color(0xFFFF9B21);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(hasBank ? Icons.bolt_rounded : Icons.info_outline_rounded,
              color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasBank
                  ? 'Your delivery fee is paid automatically to your bank after each completed delivery.'
                  : 'Add your bank account below to receive automatic payouts after each delivery.',
              style: GoogleFonts.inter(
                  color: AppColors.cream, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// Bank account section — shows existing account or an "Add Bank Account" form
// with Paystack validation before saving.
class _BankAccountSection extends StatefulWidget {
  const _BankAccountSection({required this.driver});
  final DriverModel? driver;

  @override
  State<_BankAccountSection> createState() => _BankAccountSectionState();
}

class _BankAccountSectionState extends State<_BankAccountSection> {
  bool _showForm = false;
  bool _verifying = false;
  bool _saving = false;
  String? _verifiedName;
  String? _verifyError;

  final _accountNumberCtrl = TextEditingController();
  String _selectedBankCode = _saBanks.first['code']!;
  String _selectedBankName = _saBanks.first['name']!;

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final accNum = _accountNumberCtrl.text.trim();
    if (accNum.isEmpty) return;
    setState(() {
      _verifying = true;
      _verifyError = null;
      _verifiedName = null;
    });
    try {
      final name = await DriverService.resolveBankAccount(
        accountNumber: accNum,
        bankCode: _selectedBankCode,
      );
      if (mounted) setState(() { _verifiedName = name; _verifying = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _verifyError = 'Could not verify this account. Check the number and bank.';
        });
      }
    }
  }

  Future<void> _save() async {
    final accNum = _accountNumberCtrl.text.trim();
    final name = _verifiedName;
    if (accNum.isEmpty || name == null) return;
    setState(() => _saving = true);
    try {
      await DriverService.registerBankAccount(
        accountNumber: accNum,
        bankCode: _selectedBankCode,
        bankName: _selectedBankName,
        accountName: name,
      );
      if (mounted) {
        setState(() {
          _showForm = false;
          _saving = false;
          _verifiedName = null;
          _accountNumberCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save bank account: $e'),
          backgroundColor: const Color(0xFFFF5252),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    if (driver == null) return const SizedBox.shrink();

    // Already has a bank account, and not editing
    if (driver.hasBankAccount && !_showForm) {
      final acc = driver.bankAccountNumber ?? '';
      final last4 = acc.length > 4 ? acc.substring(acc.length - 4) : acc;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_rounded,
                  color: Colors.greenAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.bankName ?? 'Bank Account',
                      style: GoogleFonts.inter(
                          color: AppColors.cream,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text('•••• $last4',
                      style: GoogleFonts.inter(
                          color: AppColors.creamMuted, fontSize: 12)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() { _showForm = true; _verifiedName = null; }),
              child: Text('Change',
                  style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    // Add / update bank account form (with validation)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded,
                  color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(driver.hasBankAccount ? 'Update Bank Account' : 'Add Bank Account',
                  style: GoogleFonts.inter(
                      color: AppColors.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Bank',
              style: GoogleFonts.inter(
                  color: AppColors.creamMuted, fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBankCode,
                dropdownColor: AppColors.surface,
                isExpanded: true,
                items: _saBanks.map((b) => DropdownMenuItem(
                  value: b['code'],
                  child: Text(b['name']!,
                      style: GoogleFonts.inter(
                          color: AppColors.cream, fontSize: 13)),
                )).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final bank = _saBanks.firstWhere((b) => b['code'] == v);
                  setState(() {
                    _selectedBankCode = v;
                    _selectedBankName = bank['name']!;
                    _verifiedName = null; // bank changed → re-verify
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Account Number',
              style: GoogleFonts.inter(
                  color: AppColors.creamMuted, fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _accountNumberCtrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14),
            onChanged: (_) {
              if (_verifiedName != null || _verifyError != null) {
                setState(() { _verifiedName = null; _verifyError = null; });
              }
            },
            decoration: InputDecoration(
              hintText: 'e.g. 1234567890',
              hintStyle:
                  GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.divider)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),

          // Verified name banner
          if (_verifiedName != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Verified: ${_verifiedName!}',
                        style: GoogleFonts.inter(
                            color: AppColors.cream,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          if (_verifyError != null) ...[
            const SizedBox(height: 10),
            Text(_verifyError!,
                style: GoogleFonts.inter(
                    color: const Color(0xFFFF5252), fontSize: 12)),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              if (driver.hasBankAccount) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _showForm = false;
                      _verifiedName = null;
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.creamMuted,
                      side: BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Verify button (until verified), then Save button
              Expanded(
                child: _verifiedName == null
                    ? ElevatedButton(
                        onPressed: _verifying ? null : _verify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.background,
                          foregroundColor: AppColors.gold,
                          side: BorderSide(color: AppColors.gold),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _verifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.gold))
                            : Text('Verify Account',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700)),
                      )
                    : ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.background,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.background))
                            : Text('Save Bank Account',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700)),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.payout});
  final DriverPayout payout;

  ({Color color, String label, IconData icon}) get _statusStyle {
    switch (payout.status) {
      case 'success':
        return (color: Colors.greenAccent, label: 'Paid', icon: Icons.check_circle_rounded);
      case 'pending':
        return (color: const Color(0xFFFF9B21), label: 'Pending', icon: Icons.schedule_rounded);
      case 'recipient_missing':
        return (color: const Color(0xFFFF5252), label: 'Add bank', icon: Icons.error_outline_rounded);
      default:
        return (color: const Color(0xFFFF5252), label: 'Failed', icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery Payout',
                    style: GoogleFonts.inter(
                      color: AppColors.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(payout.createdAt != null ? _formatDate(payout.createdAt!) : '—',
                    style: GoogleFonts.inter(
                        color: AppColors.creamMuted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('R ${payout.amountRands.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: AppColors.cream,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 2),
              Text(s.label,
                  style: GoogleFonts.inter(
                      color: s.color, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_months[local.month - 1]} ${local.day}, $hour:$minute';
}

class _EmptyPayouts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_rounded,
                color: AppColors.creamMuted, size: 28),
            const SizedBox(height: 12),
            Text('No payouts yet',
                style: GoogleFonts.inter(
                    color: AppColors.cream,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Payouts appear here automatically after each delivery.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.creamMuted, fontSize: 12, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
