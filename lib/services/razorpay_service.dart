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
      );
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
      );
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
        }),
      );
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
}
