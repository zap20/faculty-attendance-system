import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'network_service.dart';
import 'sync_service.dart';

/// Initializes all offline-first services on app startup.
/// Call [OfflineInitializer.initialize()] early in main() or after login.
class OfflineInitializer {
  static bool _initialized = false;

  /// Initialize the offline-first architecture.
  /// Safe to call multiple times — only runs once.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final stopwatch = Stopwatch()..start();

    // 1. Initialize local database
    try {
      debugPrint('[Offline] Initializing local database...');
      final db = DatabaseHelper();
      await db.database; // triggers creation if needed
      debugPrint('[Offline] Local database ready');
    } catch (e) {
      debugPrint('[Offline] Database init failed (non-fatal): $e');
    }

    // 2. Initialize network service
    try {
      debugPrint('[Offline] Initializing network service...');
      final network = NetworkService();
      await network.initialize();
      debugPrint('[Offline] Network service ready: ${network.isOnline ? "ONLINE" : "OFFLINE"}');

      // 3. Initialize sync service
      debugPrint('[Offline] Initializing sync service...');
      final sync = SyncService();
      sync.initialize();

      // 4. If online, trigger initial sync in background
      if (network.isOnline) {
        debugPrint('[Offline] Online — triggering initial sync...');
        sync.syncAll(); // fire-and-forget
      } else {
        debugPrint('[Offline] Offline — will sync when connection is available');
      }
    } catch (e) {
      debugPrint('[Offline] Network/sync init failed (non-fatal): $e');
    }

    stopwatch.stop();
    debugPrint('[Offline] Initialization complete in ${stopwatch.elapsedMilliseconds}ms');
  }

  /// Check if offline services are initialized
  static bool get isInitialized => _initialized;
}
