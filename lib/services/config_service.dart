import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  /// Fetch live backend config (keys & settings) dynamically
  Future<Map<String, dynamic>?> fetchConfig() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.backendBaseUrl}/config'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print("ConfigService load error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("ConfigService load exception: $e");
    }
    return null;
  }
}
