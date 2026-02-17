import 'package:flutter/foundation.dart';

class AppConfig {
  // API Base URL configuration
  // - For web: use localhost
  // - For Android emulator: use 10.0.2.2 (maps to host machine's localhost)
  // - For iOS simulator: use localhost
  // - For physical device: use your machine's IP address
  
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api/index.php';
    } else {
      // For real mobile devices, use your computer's IP address
      //return 'http://192.168.0.6:8000/api/index.php';
      return 'http://10.5.15.59:8000/api/index.php';
    }
  }

  // App name
  static const String appName = 'Faculty Attendance System';
  
  // Grace period for late attendance (in minutes)
  static const int gracePeriodMinutes = 10;
  
  // Token storage key
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}
