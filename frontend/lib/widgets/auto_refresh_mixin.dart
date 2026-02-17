import 'dart:async';
import 'package:flutter/widgets.dart';
import '../services/api_service.dart';

/// Mixin that provides change-detection refresh for dashboard screens.
/// Instead of refreshing every N seconds, it polls a lightweight endpoint
/// (`/sync/last-updated`) and only triggers a full data refresh when the
/// server reports that data has actually changed.
///
/// Usage:
/// 1. Add `with AutoRefreshMixin` to your State class
/// 2. Call `startAutoRefresh(callback)` in initState
/// 3. Call `stopAutoRefresh()` in dispose
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  Timer? _autoRefreshTimer;
  String? _lastKnownTimestamp;
  bool _isChecking = false;

  /// How often to check for changes (lightweight poll).
  static const Duration defaultCheckInterval = Duration(seconds: 10);

  /// Start change-detection polling. [onRefresh] is called only when new data
  /// is detected on the server.
  void startAutoRefresh(VoidCallback onRefresh, {Duration? interval}) {
    stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(
      interval ?? defaultCheckInterval,
      (_) => _checkForChanges(onRefresh),
    );
  }

  /// Stop polling.
  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Poll `/sync/last-updated` and compare timestamps.
  Future<void> _checkForChanges(VoidCallback onRefresh) async {
    if (!mounted || _isChecking) return;
    if (!ApiService.hasToken) return;

    _isChecking = true;
    try {
      final response = await ApiService.get('/sync/last-updated');
      final serverTimestamp = response['data']?['attendances']?.toString();

      if (serverTimestamp != null && serverTimestamp != _lastKnownTimestamp) {
        if (_lastKnownTimestamp != null) {
          // Timestamp changed → new data exists, trigger refresh
          debugPrint('[AutoRefresh] Data changed: $_lastKnownTimestamp → $serverTimestamp');
          if (mounted) onRefresh();
        }
        _lastKnownTimestamp = serverTimestamp;
      }
    } catch (_) {
      // Silently ignore — network errors, auth issues, etc.
    } finally {
      _isChecking = false;
    }
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
