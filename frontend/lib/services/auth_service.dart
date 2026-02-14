import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await ApiService.post('/auth/login', body: {
      'username': username,
      'password': password,
    });

    if (response['success'] == true && response['data'] != null) {
      final token = response['data']['token'];
      final userData = response['data']['user'];

      // Save token and user data
      await _saveToken(token);
      await _saveUserData(userData);
      
      // Set token for API calls
      ApiService.setToken(token);

      return response['data'];
    }

    throw ApiException(response['message'] ?? 'Login failed');
  }

  static Future<void> logout() async {
    try {
      await ApiService.post('/auth/logout');
    } catch (_) {
      // Ignore errors on logout
    }
    
    await _clearAuth();
    ApiService.setToken(null);
  }

  static Future<UserModel?> getCurrentUser() async {
    final response = await ApiService.get('/me');
    if (response['success'] == true && response['data'] != null) {
      return UserModel.fromJson(response['data']);
    }
    return null;
  }

  static Future<void> changePassword(String currentPassword, String newPassword) async {
    await ApiService.put('/auth/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  // Token management
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.tokenKey, token);
  }

  static Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.tokenKey);
  }

  static Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.userKey, json.encode(userData));
  }

  static Future<UserModel?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(AppConfig.userKey);
    if (userData != null) {
      return UserModel.fromJson(json.decode(userData));
    }
    return null;
  }

  static Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.tokenKey);
    await prefs.remove(AppConfig.userKey);
  }

  /// Save user data for offline session (no token needed)
  static Future<void> saveOfflineSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.userKey, json.encode(user.toJson()));
    // Set a placeholder token so isLoggedIn() returns true
    if (prefs.getString(AppConfig.tokenKey) == null) {
      await prefs.setString(AppConfig.tokenKey, 'offline_session');
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getStoredToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> initializeAuth() async {
    final token = await getStoredToken();
    if (token != null) {
      ApiService.setToken(token);
    }
  }
}
