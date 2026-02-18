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
      // Refresh pending count before push
      await _updatePendingCount();
      debugPrint('[SyncService] Pending before push: $_pendingCount');

      final pushCount = await _pushPhase();
      debugPrint('[SyncService] Push phase complete: $pushCount records pushed');
      final pullCount = await _pullPhase();
      debugPrint('[SyncService] Pull phase complete: $pullCount records pulled');
      await _updatePendingCount();

      _status = SyncStatus.success;
      _lastMessage = 'Synced: pushed $pushCount, pulled $pullCount records';
      if (_pendingCount > 0) {
        _lastMessage += ' ($_pendingCount still pending)';
      }
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

    // Diagnostic: dump ALL attendance records to understand the state
    try {
      final db = await _db.database;
      final allRecords = await db.rawQuery('SELECT AttendanceID, FacultyID, Date, ScheduleID, AttendanceStatus, isSynced, remoteId, deletedAt FROM attendances');
      debugPrint('[SyncService] === ALL ATTENDANCE RECORDS (${allRecords.length}) ===');
      for (final r in allRecords) {
        debugPrint('[SyncService]   id=${r['AttendanceID']}, faculty=${r['FacultyID']}, date=${r['Date']}, sched=${r['ScheduleID']}, status=${r['AttendanceStatus']}, synced=${r['isSynced']}, remote=${r['remoteId']}, deleted=${r['deletedAt']}');
      }
      final unsyncedRaw = await db.rawQuery('SELECT * FROM attendances WHERE isSynced = 0 AND deletedAt IS NULL');
      debugPrint('[SyncService] === UNSYNCED RAW QUERY: ${unsyncedRaw.length} records ===');
      for (final r in unsyncedRaw) {
        debugPrint('[SyncService]   UNSYNCED: id=${r['AttendanceID']}, faculty=${r['FacultyID']}, date=${r['Date']}, status=${r['AttendanceStatus']}');
      }
    } catch (e) {
      debugPrint('[SyncService] Diagnostic query failed: $e');
    }

    // Only push attendance records (other tables are server-managed)
    final unsyncedAttendances = await _db.getUnsyncedRecords('attendances');
    debugPrint('[SyncService] Found ${unsyncedAttendances.length} unsynced attendance records');
    if (unsyncedAttendances.isEmpty) return 0;

    // Log each record for debugging
    for (final r in unsyncedAttendances) {
      debugPrint('[SyncService] Unsynced record: id=${r['AttendanceID']}, faculty=${r['FacultyID']}, date=${r['Date']}, schedule=${r['ScheduleID']}, status=${r['AttendanceStatus']}, isSynced=${r['isSynced']}');
    }

    final pushData = unsyncedAttendances.map((r) => LocalAttendance.toApiJson(r)).toList();
    debugPrint('[SyncService] Push payload: $pushData');

    try {
      final response = await ApiService.post('/sync/push', body: {
        'table': 'attendances',
        'records': pushData,
      });

      debugPrint('[SyncService] Push response: $response');

      final results = response['data'];
      if (results is Map) {
        // Log any errors from the server
        if (results['errors'] is List && (results['errors'] as List).isNotEmpty) {
          debugPrint('[SyncService] Push errors from server: ${results['errors']}');
        }

        if (results['synced'] is List) {
          final syncedIds = (results['synced'] as List).cast<Map<String, dynamic>>();
          debugPrint('[SyncService] Server synced ${syncedIds.length} records');
          final db = await _db.database;

          await db.transaction((txn) async {
            for (final item in syncedIds) {
              final localId = item['localId'];
              final remoteId = item['remoteId'];
              debugPrint('[SyncService] Marking synced: localId=$localId, remoteId=$remoteId');
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
        } else {
          debugPrint('[SyncService] No synced list in response data: $results');
        }
      } else {
        debugPrint('[SyncService] Unexpected response data type: ${results.runtimeType}');
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

        // For attendances, match by remoteId to avoid colliding with local auto-increment IDs
        if (config.tableName == 'attendances') {
          final remoteAttId = remoteMap['AttendanceID'];
          if (remoteAttId == null) continue;

          // Check if we already have this server record (by remoteId)
          final existingByRemote = await txn.query(
            'attendances',
            where: 'remoteId = ?',
            whereArgs: [remoteAttId],
          );

          if (existingByRemote.isNotEmpty) {
            final localRow = existingByRemote.first;
            final localSynced = (localRow['isSynced'] as int?) ?? 1;

            // Don't overwrite local unsynced changes
            if (localSynced == 0) {
              debugPrint('[SyncService] Skipping pull for attendance remoteId=$remoteAttId — local has unsynced changes');
              continue;
            }

            // Update existing synced record
            localMap['remoteId'] = remoteAttId;
            await txn.update('attendances', localMap,
              where: 'AttendanceID = ?',
              whereArgs: [localRow['AttendanceID']],
            );
          } else {
            // Check if there's a local unsynced record for the same composite key
            final facultyId = remoteMap['FacultyID'];
            final date = remoteMap['Date'];
            final scheduleId = remoteMap['ScheduleID'];

            if (facultyId != null && date != null && scheduleId != null) {
              final existingLocal = await txn.query(
                'attendances',
                where: 'FacultyID = ? AND Date = ? AND ScheduleID = ? AND deletedAt IS NULL',
                whereArgs: [facultyId, date, scheduleId],
              );

              if (existingLocal.isNotEmpty) {
                // Record exists locally for same composite key — update it with server data and mark synced
                final localRow = existingLocal.first;
                localMap['remoteId'] = remoteAttId;
                localMap['isSynced'] = 1;
                await txn.update('attendances', localMap,
                  where: 'AttendanceID = ?',
                  whereArgs: [localRow['AttendanceID']],
                );
                debugPrint('[SyncService] Updated local attendance (${localRow['AttendanceID']}) with server data, remoteId=$remoteAttId');
                count++;
                continue;
              }
            }

            // New record from server — insert with remoteId
            localMap['remoteId'] = remoteAttId;
            // Remove AttendanceID to let SQLite auto-increment
            localMap.remove('AttendanceID');
            await txn.insert('attendances', localMap, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
          count++;
          continue;
        }

        // Non-attendance tables: match by primary key as before
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
            await txn.update(config.tableName, localMap, where: '$pk = ?', whereArgs: [id]);
          }
        } else {
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

  /// Diagnose pending records — returns details about what's stuck
  Future<List<Map<String, dynamic>>> getPendingDetails() async {
    try {
      return await _db.getUnsyncedRecords('attendances');
    } catch (e) {
      debugPrint('[SyncService] Error getting pending details: $e');
      return [];
    }
  }

  /// Clear all stuck pending records by marking them as synced.
  /// Use this when records are stuck and can't be pushed (e.g. orphaned records).
  Future<int> clearStuckPending() async {
    try {
      final db = await _db.database;
      final count = await db.update(
        'attendances',
        {'isSynced': 1, 'localUpdatedAt': DateTime.now().toIso8601String()},
        where: 'isSynced = 0 AND deletedAt IS NULL',
      );
      await _updatePendingCount();
      debugPrint('[SyncService] Cleared $count stuck pending records');
      return count;
    } catch (e) {
      debugPrint('[SyncService] Error clearing stuck pending: $e');
      return 0;
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
