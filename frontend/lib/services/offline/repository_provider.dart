import 'dart:io';
import 'package:flutter/foundation.dart';
import 'attendance_repository.dart';
import 'online_attendance_repository.dart';
import 'offline_attendance_repository.dart';
import 'network_service.dart';

/// Provides the correct repository based on connectivity status.
/// Implements smart fallback: tries online first, falls back to offline on failure.
class RepositoryProvider {
  static final RepositoryProvider _instance = RepositoryProvider._internal();
  factory RepositoryProvider() => _instance;
  RepositoryProvider._internal();

  final OnlineAttendanceRepository _onlineRepo = OnlineAttendanceRepository();
  final OfflineAttendanceRepository _offlineRepo = OfflineAttendanceRepository();
  final NetworkService _networkService = NetworkService();

  /// Get the appropriate repository based on current connectivity
  AttendanceRepository get repository {
    return _networkService.isOnline ? _onlineRepo : _offlineRepo;
  }

  /// Online repository (direct access)
  OnlineAttendanceRepository get online => _onlineRepo;

  /// Offline repository (direct access)
  OfflineAttendanceRepository get offline => _offlineRepo;

  /// Check if an error is a network-related error
  bool _isNetworkError(dynamic e) {
    final msg = e.toString().toLowerCase();
    return e is SocketException ||
        msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('connection failed') ||
        msg.contains('network is unreachable') ||
        msg.contains('no route to host') ||
        msg.contains('connection reset') ||
        msg.contains('timed out') ||
        msg.contains('errno=101') ||
        msg.contains('errno=111') ||
        msg.contains('clientexception');
  }

  /// Smart execution: try online first, fall back to offline on failure
  Future<T> smartExecute<T>(
    Future<T> Function(AttendanceRepository repo) action, {
    String? operationName,
  }) async {
    // Always try offline first if we know we're offline
    if (!_networkService.isOnline) {
      debugPrint('[RepoProvider] ${operationName ?? 'Operation'} using OFFLINE (no connection)');
      return await action(_offlineRepo);
    }

    // Online: try API with fallback
    try {
      final result = await action(_onlineRepo)
          .timeout(const Duration(seconds: 10));
      debugPrint('[RepoProvider] ${operationName ?? 'Operation'} completed ONLINE');
      return result;
    } catch (e) {
      debugPrint('[RepoProvider] Online failed for ${operationName ?? 'operation'}: $e');

      // If it's a network error, mark as offline for subsequent calls
      if (_isNetworkError(e)) {
        _networkService.markOffline();
        debugPrint('[RepoProvider] Marked as OFFLINE due to network error');
      }

      debugPrint('[RepoProvider] Falling back to OFFLINE');
      try {
        final result = await action(_offlineRepo);
        debugPrint('[RepoProvider] ${operationName ?? 'Operation'} completed OFFLINE (fallback)');
        return result;
      } catch (offlineError) {
        debugPrint('[RepoProvider] Offline fallback also failed: $offlineError');
        rethrow;
      }
    }
  }
}
