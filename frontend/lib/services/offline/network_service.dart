import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../api_service.dart';

/// Monitors network connectivity and provides online/offline status.
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  bool _isOnline = kIsWeb ? true : false;
  bool _initialized = false;

  /// Stream of connectivity changes (true = online, false = offline)
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  /// Current online status
  bool get isOnline => _isOnline;

  /// Initialize the network service and start listening
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // On web, always online — offline-first only applies to mobile
    if (kIsWeb) {
      _isOnline = true;
      debugPrint('[NetworkService] Web platform — always ONLINE');
      return;
    }

    // Check initial status
    _isOnline = await checkConnection();
    debugPrint('[NetworkService] Initial status: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    // Listen for changes
    _connectivity.onConnectivityChanged.listen((result) async {
      final hasConnectivity = result != ConnectivityResult.none;
      if (hasConnectivity) {
        // Verify actual internet access by pinging the API
        _isOnline = await _verifyInternetAccess();
      } else {
        _isOnline = false;
      }
      _connectionController.add(_isOnline);
      debugPrint('[NetworkService] Connection changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
    });
  }

  /// Check if device has actual internet connectivity
  Future<bool> checkConnection() async {
    if (kIsWeb) return true;
    try {
      final result = await _connectivity.checkConnectivity();
      final hasConnectivity = result != ConnectivityResult.none;
      if (!hasConnectivity) return false;
      return await _verifyInternetAccess();
    } catch (e) {
      debugPrint('[NetworkService] Error checking connection: $e');
      return false;
    }
  }

  /// Verify actual internet access by hitting the API health endpoint
  Future<bool> _verifyInternetAccess() async {
    try {
      await ApiService.get('/health').timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Force offline mode (called when network errors are detected)
  void markOffline() {
    if (kIsWeb) return; // Web is always online
    if (_isOnline) {
      _isOnline = false;
      _connectionController.add(false);
      debugPrint('[NetworkService] Forced OFFLINE due to network error');
    }
  }

  void dispose() {
    _connectionController.close();
  }
}
