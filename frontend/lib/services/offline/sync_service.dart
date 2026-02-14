import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../api_service.dart';
import 'database_helper.dart';
import 'local_models.dart';
import 'network_service.dart';

/// Sync status for UI feedback
enum SyncStatus { idle, syncing, success, error }

/// Handles bidirectional sync between local Sqflite and remote MariaDB.
/// Push phase: send unsynced local records to server.
/// Pull phase: fetch remote updates since last sync.
/// Conflict resolution: last-write-wins based on UpdatedAt timestamp.
class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final NetworkService _network = NetworkService();

  SyncStatus _status = SyncStatus.idle;
  String _lastMessage = '';
  int _pendingCount = 0;
  Timer? _periodicTimer;
  bool _isSyncing = false;

  SyncStatus get status => _status;
  String get lastMessage => _lastMessage;
  int get pendingCount => _pendingCount;
  bool get isSyncing => _isSyncing;

  /// Initialize sync service: listen for connectivity changes, start periodic sync
  void initialize() {
    // Sync when connection is restored
    _network.onConnectionChanged.listen((isOnline) {
      if (isOnline) {
        debugPrint('[SyncService] Connection restored — triggering sync');
        syncAll();
      }
    });

    // Periodic sync every 5 minutes
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_network.isOnline && !_isSyncing) {
        debugPrint('[SyncService] Periodic sync triggered');
        syncAll();
      }
    });

    // Count pending items
    _updatePendingCount();
  }

  /// Full sync: push local changes, then pull remote updates
  Future<void> syncAll() async {
    if (_isSyncing) {
      debugPrint('[SyncService] Sync already in progress, skipping');
      return;
    }
    if (!_network.isOnline) {
      _lastMessage = 'No internet connection';
      notifyListeners();
      return;
    }

    // Don't sync if no auth token is set
    if (!ApiService.hasToken) {
      debugPrint('[SyncService] No auth token — skipping sync (not logged in yet)');
      return;
    }

    _isSyncing = true;
    _status = SyncStatus.syncing;
    _lastMessage = 'Syncing...';
    notifyListeners();

    try {
      final pushCount = await _pushPhase();
      debugPrint('[SyncService] Push phase complete: $pushCount records pushed');
      final pullCount = await _pullPhase();
      debugPrint('[SyncService] Pull phase complete: $pullCount records pulled');
      await _updatePendingCount();

      _status = SyncStatus.success;
      _lastMessage = 'Synced: pushed $pushCount, pulled $pullCount records';
      debugPrint('[SyncService] $_lastMessage');
    } catch (e, stackTrace) {
      _status = SyncStatus.error;
      _lastMessage = 'Sync error: $e';
      debugPrint('[SyncService] $_lastMessage');
      debugPrint('[SyncService] Stack: $stackTrace');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── PUSH PHASE ─────────────────────────────────────────────────

  Future<int> _pushPhase() async {
    int totalPushed = 0;

    // Only push attendance records (other tables are server-managed)
    final unsyncedAttendances = await _db.getUnsyncedRecords('attendances');
    if (unsyncedAttendances.isEmpty) return 0;

    debugPrint('[SyncService] Pushing ${unsyncedAttendances.length} attendance records');

    final pushData = unsyncedAttendances.map((r) => LocalAttendance.toApiJson(r)).toList();

    try {
      final response = await ApiService.post('/sync/push', body: {
        'table': 'attendances',
        'records': pushData,
      });

      final results = response['data'];
      if (results is Map && results['synced'] is List) {
        final syncedIds = (results['synced'] as List).cast<Map<String, dynamic>>();
        final db = await _db.database;

        await db.transaction((txn) async {
          for (final item in syncedIds) {
            final localId = item['localId'];
            final remoteId = item['remoteId'];
            if (localId != null) {
              await txn.update(
                'attendances',
                {
                  'isSynced': 1,
                  'remoteId': remoteId,
                  'localUpdatedAt': DateTime.now().toIso8601String(),
                },
                where: 'AttendanceID = ?',
                whereArgs: [localId],
              );
              totalPushed++;
            }
          }
        });
      }

      await _db.updateLastPushTimestamp('attendances');
    } catch (e) {
      debugPrint('[SyncService] Push failed: $e');
      rethrow;
    }

    return totalPushed;
  }

  // ─── PULL PHASE ─────────────────────────────────────────────────

  Future<int> _pullPhase() async {
    int totalPulled = 0;

    // Pull reference tables first (in dependency order), then attendances
    for (final config in SyncTableConfig.allTables) {
      try {
        final count = await _pullTable(config);
        totalPulled += count;
      } catch (e) {
        debugPrint('[SyncService] Pull failed for ${config.tableName}: $e');
        // Continue with other tables
      }
    }

    return totalPulled;
  }

  Future<int> _pullTable(SyncTableConfig config, {bool fullPull = false}) async {
    final lastSync = fullPull ? null : await _db.getLastPullTimestamp(config.tableName);

    final params = <String, String>{
      'table': config.tableName,
    };
    if (lastSync != null) params['since'] = lastSync;

    final response = await ApiService.get('/sync/pull', queryParams: params);
    final records = (response['data']?['records'] as List?) ?? [];

    if (records.isEmpty) return 0;

    debugPrint('[SyncService] Pulling ${records.length} records for ${config.tableName}');

    final db = await _db.database;
    int count = 0;

    await db.transaction((txn) async {
      for (final record in records) {
        final remoteMap = record as Map<String, dynamic>;
        final localMap = config.toMap(remoteMap, synced: true);
        final pk = config.primaryKey;
        final id = remoteMap[pk] ?? localMap[pk];

        if (id == null) continue;

        // Check for conflict
        final existing = await txn.query(
          config.tableName,
          where: '$pk = ?',
          whereArgs: [id],
        );

        if (existing.isNotEmpty) {
          final localRow = existing.first;
          final localUpdated = localRow['localUpdatedAt']?.toString();
          final remoteUpdated = remoteMap['UpdatedAt']?.toString();
          final localSynced = (localRow['isSynced'] as int?) ?? 1;

          // Conflict resolution: if local has unsynced changes, compare timestamps
          if (localSynced == 0 && localUpdated != null && remoteUpdated != null) {
            final localTime = DateTime.tryParse(localUpdated);
            final remoteTime = DateTime.tryParse(remoteUpdated);
            if (localTime != null && remoteTime != null && localTime.isAfter(remoteTime)) {
              // Local wins — skip this remote record
              debugPrint('[SyncService] Conflict: local wins for ${config.tableName}.$pk=$id');
              continue;
            }
          }

          // Handle soft deletes
          if (remoteMap['deletedAt'] != null) {
            await txn.update(
              config.tableName,
              {'deletedAt': remoteMap['deletedAt'], 'isSynced': 1},
              where: '$pk = ?',
              whereArgs: [id],
            );
          } else {
            // Remote wins or no conflict
            await txn.update(config.tableName, localMap, where: '$pk = ?', whereArgs: [id]);
          }
        } else {
          // New record from server
          if (config.tableName == 'attendances') {
            localMap['remoteId'] = remoteMap['AttendanceID'];
          }
          await txn.insert(config.tableName, localMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        count++;
      }
    });

    await _db.updateLastPullTimestamp(config.tableName);
    return count;
  }

  // ─── Helpers ────────────────────────────────────────────────────

  Future<void> _updatePendingCount() async {
    try {
      final records = await _db.getUnsyncedRecords('attendances');
      _pendingCount = records.length;
      notifyListeners();
    } catch (e) {
      debugPrint('[SyncService] Error counting pending: $e');
    }
  }

  /// Pull ALL data from MySQL into Sqflite (ignores timestamps, gets everything)
  Future<void> pullAllData() async {
    if (!_network.isOnline) {
      _lastMessage = 'Cannot pull data offline';
      notifyListeners();
      return;
    }
    if (!ApiService.hasToken) {
      debugPrint('[SyncService] No auth token — skipping pullAllData');
      return;
    }

    _isSyncing = true;
    _status = SyncStatus.syncing;
    _lastMessage = 'Pulling all data from server...';
    notifyListeners();

    try {
      int totalPulled = 0;
      for (final config in SyncTableConfig.allTables) {
        try {
          final count = await _pullTable(config, fullPull: true);
          debugPrint('[SyncService] Full pull ${config.tableName}: $count records');
          totalPulled += count;
        } catch (e) {
          debugPrint('[SyncService] Full pull failed for ${config.tableName}: $e');
        }
      }

      _status = SyncStatus.success;
      _lastMessage = 'Pulled $totalPulled records from server';
      debugPrint('[SyncService] $_lastMessage');
    } catch (e, stackTrace) {
      _status = SyncStatus.error;
      _lastMessage = 'Pull error: $e';
      debugPrint('[SyncService] $_lastMessage');
      debugPrint('[SyncService] Stack: $stackTrace');
    } finally {
      _isSyncing = false;
      await _updatePendingCount();
      notifyListeners();
    }
  }

  /// Force a full re-sync (clear local and pull everything)
  Future<void> fullResync() async {
    if (!_network.isOnline) {
      _lastMessage = 'Cannot resync offline';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _status = SyncStatus.syncing;
    _lastMessage = 'Full resync in progress...';
    notifyListeners();

    try {
      // Push any unsynced data first
      await _pushPhase();

      // Clear local data
      await _db.clearAll();

      // Pull everything fresh
      final count = await _pullPhase();

      _status = SyncStatus.success;
      _lastMessage = 'Full resync complete: $count records pulled';
    } catch (e) {
      _status = SyncStatus.error;
      _lastMessage = 'Resync error: $e';
    } finally {
      _isSyncing = false;
      await _updatePendingCount();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
