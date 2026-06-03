import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/theme.dart';
import '../../services/razorpay_service.dart';
import '../../auth/auth_service.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String period;
  final String tag;
  int amountINR;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.period,
    required this.tag,
    required this.amountINR,
  });
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  String _loadingMessage = "Initializing Secure Gateways...";
  int _selectedPlan = 1; // Default to Monthly (1 Month)
  late Razorpay _razorpay;
  
  // Real Razorpay Key loaded dynamically from backend or fallback to production key
  String _razorpayKey = "rzp_live_SuetHsCvdTs9sR"; 

  // Pre-configured elegant subscription plans
  final List<SubscriptionPlan> _plans = [
    SubscriptionPlan(
      id: 'chatrix_premium_1_week',
      name: '1 Week',
      period: '7 days of premium access',
      tag: '',
      amountINR: 49,
    ),
    SubscriptionPlan(
      id: 'chatrix_premium_1_month',
      name: '1 Month',
      period: '30 days of premium access',
      tag: 'POPULAR',
      amountINR: 249,
    ),
    SubscriptionPlan(
      id: 'chatrix_premium_2_months',
      name: '2 Months',
      period: '60 days of premium access',
      tag: '',
      amountINR: 399,
    ),
    SubscriptionPlan(
      id: 'chatrix_premium_1_year',
      name: '1 Year',
      period: '365 days of premium access',
      tag: 'BEST VALUE',
      amountINR: 2999,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _loadPaymentConfig();
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
          _razorpayKey = config['razorpay_key'];
          print("Razorpay active gateway key updated dynamically: $_razorpayKey");
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

      // 2. Launch Razorpay payment options
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

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final currentUserId = AuthService().currentUserId;
    if (currentUserId == null) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = "Verifying secure payment transaction...";
    });

    try {
      // 3. Verify Razorpay signature securely via backend before granting Premium
      final isVerified = await RazorpayService().verifyPayment(
        userId: currentUserId,
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
      );

      if (isVerified) {
        // Upgrade Premium entitlement in Cloud Firestore
        await AuthService().setPremium(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
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
                    const SizedBox(height: 48),
                    
                    _buildPricingCards(),
                    const SizedBox(height: 48),
                    
                    _buildBenefitsSection(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            )
          ],
        ),
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
                  "₹${plan.amountINR}",
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
          _buildBenefitItem("Voice features (coming soon)"),
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
              onPressed: _isLoading ? null : _handleUpgrade,
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
                      "Continue with ₹${_plans[_selectedPlan].amountINR}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
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
