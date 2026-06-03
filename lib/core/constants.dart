import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  /// Base URL of your secure FastAPI backend server.
  /// 
  /// During local development:
  /// - Android emulator redirects localhost to 10.0.2.2.
  /// - Web and iOS use localhost (127.0.0.1).
  /// 
  /// IMPORTANT: Before launching tomorrow, replace this with your deployed production
  /// backend server URL (e.g. 'https://chatrix-soul-engine.herokuapp.com').
  static const String customBackendUrl = ''; // Put your production backend URL here if deployed

  static String get backendBaseUrl {
    if (customBackendUrl.isNotEmpty) {
      return customBackendUrl;
    }
    
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {}
    
    return 'http://localhost:8000';
  }
}
