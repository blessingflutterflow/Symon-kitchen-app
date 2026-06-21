import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme.dart';

/// Loads the Paystack hosted checkout page in a WebView and detects
/// success / cancel / failure redirects.
class PaymentWebViewScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;

  const PaymentWebViewScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false;

  // URL fragments that signal the end of the Yoco checkout flow
  static const _successPaths = ['/payment/success', '/payment/done'];
  static const _cancelPaths = ['/payment/cancel', '/payment/cancelled', '/payment/failed'];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: _handleNavigation,
      ))
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  NavigationDecision _handleNavigation(NavigationRequest req) {
    final url = req.url.toLowerCase();

    final isSuccess = _successPaths.any((p) => url.contains(p));
    if (isSuccess && !_finished) {
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(PaymentResult.success);
      });
      return NavigationDecision.prevent;
    }

    final isCancel = _cancelPaths.any((p) => url.contains(p));
    if (isCancel && !_finished) {
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(PaymentResult.cancelled);
      });
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  Future<bool> _onWillPop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Cancel payment?', style: GoogleFonts.inter(
          color: AppColors.cream,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        )),
        content: Text(
          'Your payment is not complete. Are you sure you want to go back?',
          style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Stay', style: GoogleFonts.inter(color: AppColors.cream)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Leave', style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && mounted) Navigator.of(context).pop(PaymentResult.cancelled);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: GestureDetector(
            onTap: () async {
              final canPop = await _onWillPop();
              if (canPop && mounted) Navigator.of(context).pop(PaymentResult.cancelled);
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded, color: AppColors.cream, size: 20),
            ),
          ),
          title: Text(
            'Secure Payment',
            style: GoogleFonts.inter(
              color: AppColors.cream,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.divider),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              Container(
                color: AppColors.background,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: AppColors.gold),
              ),
          ],
        ),
      ),
    );
  }
}

/// Result returned by [PaymentWebViewScreen] after the user completes or cancels payment.
class PaymentResult {
  final bool _success;

  const PaymentResult._(this._success);

  static const success = PaymentResult._(true);
  static const cancelled = PaymentResult._(false);

  bool get isSuccess => _success;
  bool get isCancelled => !_success;
}
