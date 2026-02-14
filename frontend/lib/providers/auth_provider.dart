import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/offline/network_service.dart';
import '../services/offline/database_helper.dart';
import '../services/offline/sync_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _error;
  bool _isOfflineSession = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isOfflineSession => _isOfflineSession;

  // Initialize auth state from stored token
  Future<void> initialize() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await AuthService.initializeAuth();
      final isLoggedIn = await AuthService.isLoggedIn();
      
      if (isLoggedIn) {
        _user = await AuthService.getStoredUser();
        if (_user != null) {
          final network = NetworkService();
          if (network.isOnline) {
            // Online: verify token is still valid
            try {
              _user = await AuthService.getCurrentUser();
              _status = AuthStatus.authenticated;
              _isOfflineSession = false;
            } on ApiException catch (_) {
              // Token invalid (server rejected) — clear auth
              debugPrint('[Auth] Token rejected by server, logging out');
              await AuthService.logout();
              _user = null;
              _status = AuthStatus.unauthenticated;
            } catch (e) {
              // Network error — treat as offline, keep user logged in
              debugPrint('[Auth] Network error during verify, treating as offline: $e');
              _status = AuthStatus.authenticated;
              _isOfflineSession = true;
            }
          } else {
            // Offline: trust stored user data
            _status = AuthStatus.authenticated;
            _isOfflineSession = true;
            debugPrint('[Auth] Offline session restored for ${_user!.username}');
          }
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = e.toString();
    }
    
    notifyListeners();
  }

  // Login — tries online first, falls back to local credentials
  Future<bool> login(String username, String password) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    // Try online login first
    try {
      final data = await AuthService.login(username, password);
      _user = UserModel.fromJson(data['user']);
      _status = AuthStatus.authenticated;
      _isOfflineSession = false;

      // Save credentials locally for offline login
      await _saveLocalCredentials(username, password, _user!);

      // Pull ALL data from MySQL to local Sqflite (fire-and-forget)
      if (!kIsWeb) {
        SyncService().pullAllData();
      }

      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // Server responded with an error (wrong password, etc.)
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      // Network error — try offline login
      debugPrint('[Auth] Online login failed: $e — trying offline...');
      return await _offlineLogin(username, password);
    }
  }

  // Offline login using locally stored credentials
  Future<bool> _offlineLogin(String username, String password) async {
    try {
      final db = DatabaseHelper();
      final database = await db.database;
      final passwordHash = _hashPassword(password);

      debugPrint('[Auth] Attempting offline login for $username');
      debugPrint('[Auth] Password hash: ${passwordHash.substring(0, 8)}...');

      // First check if user exists at all
      final allUsers = await database.query(
        'useraccounts',
        where: 'Username = ?',
        whereArgs: [username],
      );
      debugPrint('[Auth] Found ${allUsers.length} user(s) with username=$username');

      if (allUsers.isEmpty) {
        _error = 'No offline credentials found. Login online first to enable offline access.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      // Now check with password
      final results = await database.query(
        'useraccounts',
        where: 'Username = ? AND Password = ? AND IsActive = 1',
        whereArgs: [username, passwordHash],
      );
      debugPrint('[Auth] Password match results: ${results.length}');

      if (results.isNotEmpty) {
        final row = results.first;
        _user = UserModel(
          userId: int.tryParse(row['UserID']?.toString() ?? '') ?? 0,
          username: row['Username']?.toString() ?? username,
          role: row['Role']?.toString() ?? 'Officer',
          facultyId: row['FacultyID']?.toString(),
          departmentId: int.tryParse(row['DepartmentID']?.toString() ?? ''),
          isActive: true,
        );

        // Save to SharedPreferences so initialize() works next time
        await AuthService.saveOfflineSession(_user!);

        _status = AuthStatus.authenticated;
        _isOfflineSession = true;
        _error = null;
        debugPrint('[Auth] Offline login successful for $username (role=${_user!.role})');
        notifyListeners();
        return true;
      } else {
        // User exists but password doesn't match
        final storedHash = allUsers.first['Password']?.toString() ?? '';
        debugPrint('[Auth] Stored hash: ${storedHash.substring(0, 8.clamp(0, storedHash.length))}...');
        _error = 'Invalid password for offline login.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[Auth] Offline login error: $e');
      _error = 'Offline login failed: $e';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Save credentials locally for offline login
  Future<void> _saveLocalCredentials(String username, String password, UserModel user) async {
    try {
      final db = DatabaseHelper();
      final database = await db.database;
      final passwordHash = _hashPassword(password);

      await database.rawInsert('''
        INSERT OR REPLACE INTO useraccounts 
        (UserID, Username, Password, Role, FacultyID, IsActive, isSynced, localUpdatedAt)
        VALUES (?, ?, ?, ?, ?, 1, 1, ?)
      ''', [
        user.userId,
        username,
        passwordHash,
        user.role,
        user.facultyId,
        DateTime.now().toIso8601String(),
      ]);
      debugPrint('[Auth] Local credentials saved for $username');
    } catch (e) {
      debugPrint('[Auth] Failed to save local credentials: $e');
    }
  }

  // Simple password hashing for local storage
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // Logout
  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    _isOfflineSession = false;
    notifyListeners();
  }

  // Change password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      await AuthService.changePassword(currentPassword, newPassword);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to change password';
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
