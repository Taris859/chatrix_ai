import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class RazorpayService {
  static final RazorpayService _instance = RazorpayService._internal();
  factory RazorpayService() => _instance;
  RazorpayService._internal();

  /// Fetch live backend payment config (keys & prices) dynamically
  Future<Map<String, dynamic>?> fetchConfig() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.backendBaseUrl}/config'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print("RazorpayService config load error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("RazorpayService config load exception: $e");
    }
    return null;
  }

  /// Create a secure order on Razorpay through our FastAPI backend server.
  /// [amountPaise] should be in paise (e.g. ₹399 = 39900 paise).
  Future<Map<String, dynamic>?> createOrder({
    required String userId,
    required int amountPaise,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/create_order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amountPaise,
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print("RazorpayService order creation error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("RazorpayService order creation exception: $e");
    }
    return null;
  }

  /// Securely verify payment signature on our FastAPI backend.
  Future<bool> verifyPayment({
    required String userId,
    required String paymentId,
    required String orderId,
    required String signature,
    String? email,
    String? planName,
    double? amount,
    String? expiry,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/verify_payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'payment_id': paymentId,
          'order_id': orderId,
          'signature': signature,
          if (email != null) 'email': email,
          if (planName != null) 'plan_name': planName,
          if (amount != null) 'amount': amount,
          if (expiry != null) 'expiry': expiry,
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['verified'] == true;
      } else {
        print("RazorpayService payment verification error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("RazorpayService payment verification exception: $e");
    }
    return false;
  }

  /// Securely verify and apply promo code on our FastAPI backend.
  Future<Map<String, dynamic>?> applyPromo({
    required String userId,
    required String code,
    String? email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/apply_promo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'code': code,
          if (email != null) 'email': email,
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print("RazorpayService promo application error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("RazorpayService promo application exception: $e");
    }
    return null;
  }

  /// Verify a PayPal payment transaction ID on our FastAPI backend.
  /// Returns true ONLY if the backend confirms the transaction is valid and
  /// matches the expected amount for the selected plan.
  Future<bool> verifyPaypalPayment({
    required String userId,
    required String transactionId,
    required String planId,
    required double amountUSD,
    String? email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/verify_paypal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'transaction_id': transactionId.trim(),
          'plan_id': planId,
          'amount_usd': amountUSD,
          if (email != null) 'email': email,
        }),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['verified'] == true;
      } else {
        print("PayPal verification error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("PayPal verification exception: $e");
    }
    return false;
  }
}
