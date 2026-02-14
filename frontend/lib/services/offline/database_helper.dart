import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

/// Singleton DatabaseHelper for local Sqflite database.
/// Mirrors the remote MariaDB schema with additional sync management fields.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const int _dbVersion = 1;
  static const String _dbName = 'faculty_attendance_local.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    final batch = db.batch();

    // DEPARTMENTS
    batch.execute('''
      CREATE TABLE IF NOT EXISTS departments (
        DepartmentID INTEGER PRIMARY KEY,
        DepartmentName TEXT NOT NULL,
        DepartmentHead TEXT,
        DepartmentDean TEXT,
        CreatedAt TEXT,
        UpdatedAt TEXT,
        isSynced INTEGER DEFAULT 0,
        localCreatedAt TEXT,
        localUpdatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1
      )
    ''');

    // FACULTIES
    batch.execute('''
      CREATE TABLE IF NOT EXISTS faculties (
        FacultyID TEXT PRIMARY KEY,
        FacultyName TEXT NOT NULL,
        DepartmentID INTEGER NOT NULL,
        Position TEXT NOT NULL,
        EmploymentStatus TEXT NOT NULL,
        ContactInformation TEXT,
        CreatedAt TEXT,
        UpdatedAt TEXT,
        isSynced INTEGER DEFAULT 0,
        localCreatedAt TEXT,
        localUpdatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        FOREIGN KEY (DepartmentID) REFERENCES departments(DepartmentID)
      )
    ''');

    // USERACCOUNTS
    batch.execute('''
      CREATE TABLE IF NOT EXISTS useraccounts (
        UserID INTEGER PRIMARY KEY,
        Username TEXT NOT NULL UNIQUE,
        Password TEXT NOT NULL,
        Role TEXT NOT NULL,
        FacultyID TEXT,
        IsActive INTEGER DEFAULT 1,
        CreatedAt TEXT,
        UpdatedAt TEXT,
        isSynced INTEGER DEFAULT 0,
        localCreatedAt TEXT,
        localUpdatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        FOREIGN KEY (FacultyID) REFERENCES faculties(FacultyID)
      )
    ''');

    // ROOMS
    batch.execute('''
      CREATE TABLE IF NOT EXISTS rooms (
        RoomID INTEGER PRIMARY KEY,
        RoomName TEXT NOT NULL,
        Building TEXT NOT NULL,
        Capacity INTEGER,
        CreatedAt TEXT,
        UpdatedAt TEXT,
        isSynced INTEGER DEFAULT 0,
        localCreatedAt TEXT,
        localUpdatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1
      )
    ''');

    // SUBJECTS
    batch.execute('''
      CREATE TABLE IF NOT EXISTS subjects (
        SubjectID INTEGER PRIMARY KEY,
        SubjectName TEXT NOT NULL,
        CourseCode TEXT NOT NULL,
        Units INTEGER NOT NULL,
        DepartmentID INTEGER NOT NULL,
        CreatedAt TEXT,
        UpdatedAt TEXT,
        isSynced INTEGER DEFAULT 0,
        localCreatedAt TEXT,
        localUpdatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        FOREIGN KEY (DepartmentID) REFERENCES departments(DepartmentID)
      )
    ''');

    // SCHEDULES
    batch.execute('''
      CREATE TABLE IF NOT EXISTS schedules (
        ScheduleID INTEGER PRIMARY KEY,
        FacultyID TEXT NOT NULL,
        SubjectID INTEGER NOT NULL,
        RoomID INTEGER NOT NULL,
        DayOfWeek TEXT NOT NULL,
        StartTime TEXT NOT NULL,
        EndTime TEXT NOT NULL,
        CreatedAt TEXT,
        UpdatedAt TEXT,
        isSynced INTEGER DEFAULT 0,
        localCreatedAt TEXT,
        localUpdatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        FOREIGN KEY (FacultyID) REFERENCES faculties(FacultyID),
        FOREIGN KEY (SubjectID) REFERENCES subjects(SubjectID),
        FOREIGN KEY (RoomID) REFERENCES rooms(RoomID)
      )
    ''');

    // ATTENDANCEDEVICES
    batch.execute('''
      CREATE TABLE IF NOT EXISTS attendancedevices (
        DeviceID INTEGER PRIMARY KEY,
        DeviceType TEXT NOT NULL,
        Location TEXT NOT NULL,
        RoomID INTEGER,
        Status TEXT DEFAULT 'Active',
        CreatedAt TEXT,
        UpdatedAt TEXT,
        isSynced INTEGER DEFAULT 0,
        localCreatedAt TEXT,
        localUpdatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        FOREIGN KEY (RoomID) REFERENCES rooms(RoomID)
      )
    ''');

    // ATTENDANCES
    batch.execute('''
      CREATE TABLE IF NOT EXISTS attendances (
        AttendanceID INTEGER PRIMARY KEY AUTOINCREMENT,
        FacultyID TEXT NOT NULL,
        DeviceID INTEGER,
        ScheduleID INTEGER,
        Date TEXT NOT NULL,
        DayOfWeek TEXT NOT NULL,
        TimeIn TEXT,
        TimeOut TEXT,
        AttendanceStatus TEXT NOT NULL,
        Remarks TEXT,
        CreatedAt TEXT,
        UpdatedAt TEXT,
        isSynced INTEGER DEFAULT 0,
        localCreatedAt TEXT,
        localUpdatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        remoteId INTEGER,
        FOREIGN KEY (FacultyID) REFERENCES faculties(FacultyID),
        FOREIGN KEY (DeviceID) REFERENCES attendancedevices(DeviceID),
        FOREIGN KEY (ScheduleID) REFERENCES schedules(ScheduleID)
      )
    ''');

    // SYNC_LOG - tracks last sync timestamps
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tableName TEXT NOT NULL,
        lastPullAt TEXT,
        lastPushAt TEXT,
        recordCount INTEGER DEFAULT 0
      )
    ''');

    // Indexes for performance
    batch.execute('CREATE INDEX IF NOT EXISTS idx_attendances_date ON attendances(Date)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_attendances_faculty ON attendances(FacultyID)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_attendances_synced ON attendances(isSynced)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_schedules_faculty ON schedules(FacultyID)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_schedules_day ON schedules(DayOfWeek)');
    batch.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_unique ON attendances(FacultyID, Date, ScheduleID) WHERE deletedAt IS NULL');

    await batch.commit(noResult: true);

    // Initialize sync_log entries
    final tables = ['departments', 'faculties', 'useraccounts', 'rooms', 'subjects', 'schedules', 'attendancedevices', 'attendances'];
    for (final table in tables) {
      await db.insert('sync_log', {'tableName': table});
    }

    debugPrint('[DatabaseHelper] Local database created with all tables');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DatabaseHelper] Upgrading database from v$oldVersion to v$newVersion');
    // Future migrations go here
  }

  /// Get all unsynced records from a table
  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String table) async {
    final db = await database;
    return db.query(table, where: 'isSynced = 0 AND deletedAt IS NULL');
  }

  /// Mark records as synced
  Future<void> markAsSynced(String table, String primaryKey, dynamic id) async {
    final db = await database;
    await db.update(
      table,
      {'isSynced': 1, 'localUpdatedAt': DateTime.now().toIso8601String()},
      where: '$primaryKey = ?',
      whereArgs: [id],
    );
  }

  /// Upsert a record (insert or update on conflict)
  Future<void> upsert(String table, Map<String, dynamic> data, String primaryKey) async {
    final db = await database;
    final id = data[primaryKey];
    if (id == null) {
      await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      final existing = await db.query(table, where: '$primaryKey = ?', whereArgs: [id]);
      if (existing.isEmpty) {
        await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await db.update(table, data, where: '$primaryKey = ?', whereArgs: [id]);
      }
    }
  }

  /// Bulk upsert with transaction
  Future<void> bulkUpsert(String table, List<Map<String, dynamic>> records, String primaryKey) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final record in records) {
        final id = record[primaryKey];
        if (id == null) {
          await txn.insert(table, record, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          final existing = await txn.query(table, where: '$primaryKey = ?', whereArgs: [id]);
          if (existing.isEmpty) {
            await txn.insert(table, record, conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            await txn.update(table, record, where: '$primaryKey = ?', whereArgs: [id]);
          }
        }
      }
    });
  }

  /// Get last sync timestamp for a table
  Future<String?> getLastPullTimestamp(String table) async {
    final db = await database;
    final result = await db.query('sync_log', where: 'tableName = ?', whereArgs: [table]);
    if (result.isNotEmpty) {
      return result.first['lastPullAt'] as String?;
    }
    return null;
  }

  /// Update last sync timestamp
  Future<void> updateLastPullTimestamp(String table) async {
    final db = await database;
    await db.update(
      'sync_log',
      {'lastPullAt': DateTime.now().toIso8601String()},
      where: 'tableName = ?',
      whereArgs: [table],
    );
  }

  Future<void> updateLastPushTimestamp(String table) async {
    final db = await database;
    await db.update(
      'sync_log',
      {'lastPushAt': DateTime.now().toIso8601String()},
      where: 'tableName = ?',
      whereArgs: [table],
    );
  }

  /// Clear all data (for logout or reset)
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('attendances');
      await txn.delete('attendancedevices');
      await txn.delete('schedules');
      await txn.delete('subjects');
      await txn.delete('rooms');
      await txn.delete('useraccounts');
      await txn.delete('faculties');
      await txn.delete('departments');
      await txn.execute("UPDATE sync_log SET lastPullAt = NULL, lastPushAt = NULL, recordCount = 0");
    });
    debugPrint('[DatabaseHelper] All local data cleared');
  }

  /// Close the database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
