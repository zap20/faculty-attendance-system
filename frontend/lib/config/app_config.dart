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
      // For mobile devices, use the deployed Hostinger URL
      return 'https://mintcream-mosquito-931374.hostingersite.com/api/index.php';
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
