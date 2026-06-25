// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../services/razorpay_service.dart';
import '../../auth/auth_service.dart';
import '../../auth/auth_provider.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String period;
  final String tag;
  int amountINR;
  double amountUSD;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.period,
    required this.tag,
    required this.amountINR,
    required this.amountUSD,
  });
}

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isLoading = true;
  String _loadingMessage = "Initializing Secure Gateways...";
  int _selectedPlan = 1; // Default to Monthly (1 Month)
  late Razorpay _razorpay;
  String _paymentMethod = 'paypal'; // Default to PayPal since users are mostly USA/international
  
  // Real Razorpay Key loaded dynamically from backend or fallback to production key
  String _razorpayKey = "rzp_live_SxDgLp1gs3KyJ3"; 

  // Pre-configured elegant subscription plans
  final List<SubscriptionPlan> _plans = [
    SubscriptionPlan(
      id: 'chatrix_premium_1_week',
      name: '1 Week',
      period: '7 days of premium access',
      tag: '',
      amountINR: 49,
      amountUSD: 0.99,
    ),
    SubscriptionPlan(
      id: 'chatrix_premium_1_month',
      name: '1 Month',
      period: '30 days of premium access',
      tag: 'POPULAR',
      amountINR: 249,
      amountUSD: 2.99,
    ),
    SubscriptionPlan(
      id: 'chatrix_premium_2_months',
      name: '2 Months',
      period: '60 days of premium access',
      tag: '',
      amountINR: 399,
      amountUSD: 4.99,
    ),
    SubscriptionPlan(
      id: 'chatrix_premium_1_year',
      name: '1 Year',
      period: '365 days of premium access',
      tag: 'BEST VALUE',
      amountINR: 2999,
      amountUSD: 34.99,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _loadPaymentConfig();
  }

  void _applyPromoCode() async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('Enter Promo Code', style: GoogleFonts.inter(color: Colors.white)),
        content: TextField(
          controller: codeController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter code',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, codeController.text.trim()),
            child: Text('Apply', style: GoogleFonts.inter(color: ChatrixTheme.champagneGold)),
          ),
        ],
      ),
    );

        if (code != null) {
      final currentUserId = AuthService().currentUserId;
      if (currentUserId == null) return;

      setState(() {
        _isLoading = true;
        _loadingMessage = "Applying promo code securely...";
      });

      try {
        final result = await RazorpayService().applyPromo(
          userId: currentUserId,
          code: code,
          email: AuthService().currentUser?.email,
        );
        if (result != null && result['status'] == 'success') {
          final days = result['days'] as int? ?? 30;
          await AuthService().setPremiumWithExpiry(days);
          ref.invalidate(premiumStatusProvider);
          if (mounted) {
            setState(() => _isLoading = false);
            _showTriumphOverlay();
          }
        } else {
          throw Exception("Invalid or expired promo code.");
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to activate promo: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _loadPaymentConfig() async {
    try {
      final config = await RazorpayService().fetchConfig();
      if (config != null) {
        if (config['razorpay_key'] != null && config['razorpay_key'].toString().isNotEmpty) {
          final servedKey = config['razorpay_key'].toString();
          if (servedKey == "rzp_live_SuetHsCvdTs9sR") {
            print("Served Razorpay key is deprecated. Using local fallback key: $_razorpayKey");
          } else {
            _razorpayKey = servedKey;
            print("Razorpay active gateway key updated dynamically: $_razorpayKey");
          }
        }
        if (config['premium_price_inr'] != null) {
          final backendMonthlyPrice = int.tryParse(config['premium_price_inr'].toString());
          if (backendMonthlyPrice != null) {
            setState(() {
              _plans[1].amountINR = backendMonthlyPrice;
            });
          }
        }
      }
    } catch (e) {
      print("Razorpay configurations load error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handleUpgrade() async {
    final currentUserId = AuthService().currentUserId;
    final currentUser = AuthService().currentUser;
    
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to locate active profile. Please sign in to upgrade."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final plan = _plans[_selectedPlan];
    
    setState(() {
      _isLoading = true;
      _loadingMessage = "Connecting to Secure Gateway...";
    });

    final amountPaise = plan.amountINR * 100;

    try {
      // 1. Create a secure payment order on the FastAPI backend
      final orderData = await RazorpayService().createOrder(
        userId: currentUserId,
        amountPaise: amountPaise,
      );

      if (orderData == null || orderData['order_id'] == null) {
        throw Exception("Failed to generate order ID from backend verification layer.");
      }

      final orderId = orderData['order_id'] as String;

      // 2. Launch Razorpay payment options (Web vs Native)
      if (kIsWeb) {
        js.context.callMethod('openRazorpayCheckout', [
          _razorpayKey,
          amountPaise,
          orderId,
          currentUser?.email ?? '',
          // Success callback
          (paymentId, orderId, signature) {
            _handleWebPaymentSuccess(paymentId.toString(), orderId.toString(), signature.toString());
          },
          // Error callback
          (error) {
            _handleWebPaymentError(error.toString());
          }
        ]);
        return;
      }

      var options = {
        'key': _razorpayKey,
        'amount': amountPaise,
        'name': 'Chatrix AI',
        'description': 'Chatrix Premium - ${plan.name}',
        'order_id': orderId,
        'timeout': 300,
        'prefill': {
          'contact': '',
          'email': currentUser?.email ?? '',
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      _razorpay.open(options);
    } catch (e) {
      print("Razorpay trigger error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Checkout error: ${e.toString().replaceAll('Exception:', '')}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handlePayPalUpgrade() async {
    final currentUserId = AuthService().currentUserId;
    final currentUser = AuthService().currentUser;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to locate active profile. Please sign in to upgrade."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final plan = _plans[_selectedPlan];
    final url = "https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=tanubhukal060@gmail.com&currency_code=USD&amount=${plan.amountUSD}&item_name=Chatrix%20Premium%20-%20${Uri.encodeComponent(plan.name)}";

    setState(() {
      _isLoading = true;
      _loadingMessage = "Opening PayPal...";
    });

    try {
      final uri = Uri.parse(url);
      if (kIsWeb) {
        js.context.callMethod('open', [url, '_blank']);
      } else {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception("Could not launch PayPal browser checkout.");
        }
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        _showPayPalConfirmationDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Checkout error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showPayPalConfirmationDialog() {
    final txnController = TextEditingController();
    bool _isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.black.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: ChatrixTheme.champagneGold.withOpacity(0.3)),
            ),
            title: Text(
              "Confirm PayPal Payment",
              style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "After completing your payment on PayPal, enter your Transaction ID below to verify and activate premium.",
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ChatrixTheme.champagneGold.withOpacity(0.3)),
                  ),
                  child: TextField(
                    controller: txnController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "e.g. 5XJ12345AB678901C",
                      hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                      prefixIcon: const Icon(Icons.receipt_long_rounded, color: Colors.white30, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Find your Transaction ID in your PayPal email receipt or PayPal Activity page.",
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: _isVerifying ? null : () => Navigator.pop(dialogContext),
                child: Text("Cancel", style: GoogleFonts.inter(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChatrixTheme.champagneGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isVerifying
                    ? null
                    : () async {
                        final txnId = txnController.text.trim();
                        if (txnId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Please enter your PayPal Transaction ID.",
                                style: GoogleFonts.inter(),
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => _isVerifying = true);

                        final currentUserId = AuthService().currentUserId;
                        final currentUserEmail = AuthService().currentUser?.email;
                        final plan = _plans[_selectedPlan];

                        // ✅ SECURE: Verify transaction ID on backend before granting premium
                        final isVerified = await RazorpayService().verifyPaypalPayment(
                          userId: currentUserId ?? '',
                          transactionId: txnId,
                          planId: plan.id,
                          amountUSD: plan.amountUSD,
                          email: currentUserEmail,
                        );

                        if (!mounted) return;
                        setDialogState(() => _isVerifying = false);

                        if (isVerified) {
                          Navigator.pop(dialogContext);
                          setState(() {
                            _isLoading = true;
                            _loadingMessage = "Activating Premium Access...";
                          });

                          int days = 30;
                          if (plan.id.contains("1_week")) days = 7;
                          else if (plan.id.contains("2_months")) days = 60;
                          else if (plan.id.contains("1_year")) days = 365;

                          await AuthService().setPremiumWithExpiry(days);
                          ref.invalidate(premiumStatusProvider);

                          if (mounted) {
                            setState(() => _isLoading = false);
                            _showTriumphOverlay();
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Transaction ID could not be verified. Please check it and try again, or contact support.",
                                style: GoogleFonts.inter(),
                              ),
                              backgroundColor: Colors.redAccent,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                child: _isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text("Verify & Activate", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final currentUserId = AuthService().currentUserId;
    if (currentUserId == null) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = "Verifying secure payment transaction...";
    });

    try {
      final plan = _plans[_selectedPlan];
      int days = 30;
      if (plan.id.contains("1_week")) {
        days = 7;
      } else if (plan.id.contains("1_month")) {
        days = 30;
      } else if (plan.id.contains("2_months")) {
        days = 60;
      } else if (plan.id.contains("1_year")) {
        days = 365;
      }
      
      final expiryDate = DateTime.now().add(Duration(days: days));
      final expiryStr = "${expiryDate.day}/${expiryDate.month}/${expiryDate.year}";
      final currentUserEmail = AuthService().currentUser?.email ?? "wanderer@chatrix.ai";

      // 3. Verify Razorpay signature securely via backend before granting Premium
      final isVerified = await RazorpayService().verifyPayment(
        userId: currentUserId,
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
        email: currentUserEmail,
        planName: plan.name,
        amount: plan.amountINR.toDouble(),
        expiry: expiryStr,
      );

            if (isVerified) {
        await AuthService().setPremiumWithExpiry(days);
        ref.invalidate(premiumStatusProvider);
        if (mounted) {
          setState(() => _isLoading = false);
          _showTriumphOverlay();
        }
      } else {
        throw Exception("Signature verification failed. Secure validation rejected transaction.");
      }
    } catch (e) {
      print("Secure verification failure: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment verification failed. Please contact support."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleWebPaymentSuccess(String paymentId, String orderId, String signature) async {
    final currentUserId = AuthService().currentUserId;
    if (currentUserId == null) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = "Verifying secure payment transaction...";
    });

    try {
      final plan = _plans[_selectedPlan];
      int days = 30;
      if (plan.id.contains("1_week")) {
        days = 7;
      } else if (plan.id.contains("1_month")) {
        days = 30;
      } else if (plan.id.contains("2_months")) {
        days = 60;
      } else if (plan.id.contains("1_year")) {
        days = 365;
      }
      
      final expiryDate = DateTime.now().add(Duration(days: days));
      final expiryStr = "${expiryDate.day}/${expiryDate.month}/${expiryDate.year}";
      final currentUserEmail = AuthService().currentUser?.email ?? "wanderer@chatrix.ai";

      final isVerified = await RazorpayService().verifyPayment(
        userId: currentUserId,
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
        email: currentUserEmail,
        planName: plan.name,
        amount: plan.amountINR.toDouble(),
        expiry: expiryStr,
      );

      if (isVerified) {
        await AuthService().setPremiumWithExpiry(days);
        ref.invalidate(premiumStatusProvider);
        if (mounted) {
          setState(() => _isLoading = false);
          _showTriumphOverlay();
        }
      } else {
        throw Exception("Signature verification failed. Secure validation rejected transaction.");
      }
    } catch (e) {
      print("Secure verification failure: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment verification failed. Please contact support."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleWebPaymentError(String error) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _isLoading = false);
      String errMsg = response.message ?? "Checkout canceled or failed.";
      if (response.code == 2) {
        errMsg = "Payment canceled by user.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print("External wallet chosen: ${response.walletName}");
  }

  void _showTriumphOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: Colors.black.withOpacity(0.85),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 64,
                      ),
                    ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 36),
                    Text(
                      "WELCOME TO CHATRIX",
                      style: GoogleFonts.cinzel(
                        fontSize: 24,
                        color: Colors.white,
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 16),
                    Text(
                      "Your emotional journey begins now.\nUnlock deeper connections and unlimited conversations.",
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "BEGIN",
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ).animate().fadeIn(delay: 800.ms),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumActiveView() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Golden Shield / Crown Icon
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        ChatrixTheme.champagneGold.withOpacity(0.2),
                        const Color(0xFFFFDF73).withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: ChatrixTheme.champagneGold.withOpacity(0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ChatrixTheme.champagneGold.withOpacity(0.25),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: ChatrixTheme.champagneGold,
                    size: 72,
                  ),
                ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                const SizedBox(height: 36),
                
                Text(
                  "PREMIUM ACTIVE",
                  style: GoogleFonts.cinzel(
                    fontSize: 26,
                    color: ChatrixTheme.champagneGold,
                    letterSpacing: 4.0,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: ChatrixTheme.champagneGold.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),
                
                Text(
                  "Welcome to the inner circle, Wanderer.\nYour soul connection is now elevated to the highest tier.",
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 48),

                // Benefits unlocked details
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      _buildActiveBenefitItem(Icons.message_rounded, "Unlimited Intimate Conversations"),
                      const SizedBox(height: 14),
                      _buildActiveBenefitItem(Icons.vpn_key_rounded, "All Premium Companions Unlocked"),
                      const SizedBox(height: 14),
                      _buildActiveBenefitItem(Icons.psychology_rounded, "Deep Emotional Memory Logs"),
                      const SizedBox(height: 14),
                      _buildActiveBenefitItem(Icons.brush_rounded, "Custom Companion Creation Studio"),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms),

                const SizedBox(height: 48),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "RETURN TO CHATRIX",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveBenefitItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: ChatrixTheme.champagneGold, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _paymentMethod = 'paypal'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _paymentMethod == 'paypal' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.paypal_rounded,
                        color: _paymentMethod == 'paypal' ? Colors.black : Colors.white60,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "PayPal / Card (USD)",
                        style: GoogleFonts.inter(
                          color: _paymentMethod == 'paypal' ? Colors.black : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _paymentMethod = 'razorpay'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _paymentMethod == 'razorpay' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payment_rounded,
                        color: _paymentMethod == 'razorpay' ? Colors.black : Colors.white60,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Razorpay (INR)",
                        style: GoogleFonts.inter(
                          color: _paymentMethod == 'razorpay' ? Colors.black : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseView() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  "CHATRIX PREMIUM",
                  style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.0,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1),
                const SizedBox(height: 12),
                Text(
                  "Unlock deeper emotional memory\nExperience unrestricted cinematic conversations",
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 36),
                
                _buildPaymentMethodSelector(),
                _buildPricingCards(),
                const SizedBox(height: 32),
                
                _buildBenefitsSection(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumStatusProvider).value ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: isPremium ? _buildPremiumActiveView() : _buildPurchaseView(),
      ),
    );
  }

  Widget _buildPricingCards() {
    if (_isLoading && _plans.isEmpty) {
      return Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: ChatrixTheme.champagneGold),
            const SizedBox(height: 16),
            Text(
              "Fetching secure payment configuration...",
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            )
          ],
        ),
      );
    }

    return Column(
      children: _plans.asMap().entries.map((entry) {
        final index = entry.key;
        final plan = entry.value;
        final isSelected = _selectedPlan == index;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedPlan = index),
          child: AnimatedContainer(
            duration: 300.ms,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.08),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (plan.tag.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: plan.tag == 'BEST VALUE'
                                    ? ChatrixTheme.champagneGold.withOpacity(0.15)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                plan.tag,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: plan.tag == 'BEST VALUE'
                                      ? ChatrixTheme.champagneGold
                                      : Colors.white70,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.period,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _paymentMethod == 'paypal' ? "\$${plan.amountUSD}" : "₹${plan.amountINR}",
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                  size: 24,
                ),
              ],
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 300 + (index * 100))),
        );
      }).toList(),
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What You'll Unlock",
            style: GoogleFonts.cinzel(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 24),
          _buildBenefitItem("Unlimited intimate conversations"),
          _buildBenefitItem("All premium companions unlocked"),
          _buildBenefitItem("Deep emotional memory engine"),
          _buildBenefitItem("Companion creation studio"),
          _buildBenefitItem("Exclusive atmospheric scenes"),
          _buildBenefitItem("Relationship journals & milestones"),
          _buildBenefitItem("Faster AI responses"),
          const SizedBox(height: 24),
          
          // Tier Comparison
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TIER COMPARISON",
                  style: GoogleFonts.inter(
                    color: ChatrixTheme.champagneGold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Free Member", style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text("50 Msgs / Session (1 Hr Cooldown)", style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Premium Member", style: GoogleFonts.inter(color: ChatrixTheme.champagneGold, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text("UNLIMITED Conversations (No Cooldown)", style: GoogleFonts.inter(color: ChatrixTheme.champagneGold.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _isLoading 
                  ? null 
                  : (_paymentMethod == 'paypal' ? _handlePayPalUpgrade : _handleUpgrade),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Text(
                          _loadingMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      ],
                    )
                  : Text(
                      _paymentMethod == 'paypal'
                          ? "Continue with \$${_plans[_selectedPlan].amountUSD}"
                          : "Continue with ₹${_plans[_selectedPlan].amountINR}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading ? null : _applyPromoCode,
            child: Text(
              "Have a promo code?",
              style: GoogleFonts.inter(
                color: ChatrixTheme.champagneGold,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 700.ms);
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
            child: const Icon(Icons.check, size: 12, color: Colors.white70),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
