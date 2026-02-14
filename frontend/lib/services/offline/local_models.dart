/// Extension methods and helpers for converting existing models to/from
/// Sqflite-compatible Maps with sync management fields.

class SyncFields {
  static const String isSynced = 'isSynced';
  static const String localCreatedAt = 'localCreatedAt';
  static const String localUpdatedAt = 'localUpdatedAt';
  static const String deletedAt = 'deletedAt';
  static const String version = 'version';

  static Map<String, dynamic> defaults() => {
    isSynced: 0,
    localCreatedAt: DateTime.now().toIso8601String(),
    localUpdatedAt: DateTime.now().toIso8601String(),
    deletedAt: null,
    version: 1,
  };

  static Map<String, dynamic> synced() => {
    isSynced: 1,
    localUpdatedAt: DateTime.now().toIso8601String(),
  };
}

// ─── Department ──────────────────────────────────────────────────────

class LocalDepartment {
  static const String tableName = 'departments';
  static const String primaryKey = 'DepartmentID';

  static Map<String, dynamic> toMap(Map<String, dynamic> json, {bool synced = true}) {
    return {
      'DepartmentID': json['DepartmentID'],
      'DepartmentName': json['DepartmentName'],
      'DepartmentHead': json['DepartmentHead'],
      'DepartmentDean': json['DepartmentDean'],
      'CreatedAt': json['CreatedAt'],
      'UpdatedAt': json['UpdatedAt'],
      ...synced ? SyncFields.synced() : SyncFields.defaults(),
    };
  }

  static Map<String, dynamic> toApiJson(Map<String, dynamic> row) {
    return {
      'DepartmentID': row['DepartmentID'],
      'DepartmentName': row['DepartmentName'],
      'DepartmentHead': row['DepartmentHead'],
      'DepartmentDean': row['DepartmentDean'],
    };
  }
}

// ─── Faculty ─────────────────────────────────────────────────────────

class LocalFaculty {
  static const String tableName = 'faculties';
  static const String primaryKey = 'FacultyID';

  static Map<String, dynamic> toMap(Map<String, dynamic> json, {bool synced = true}) {
    return {
      'FacultyID': json['FacultyID']?.toString(),
      'FacultyName': json['FacultyName'],
      'DepartmentID': json['DepartmentID'],
      'Position': json['Position'],
      'EmploymentStatus': json['EmploymentStatus'],
      'ContactInformation': json['ContactInformation'],
      'CreatedAt': json['CreatedAt'],
      'UpdatedAt': json['UpdatedAt'],
      ...synced ? SyncFields.synced() : SyncFields.defaults(),
    };
  }

  static Map<String, dynamic> toApiJson(Map<String, dynamic> row) {
    return {
      'FacultyID': row['FacultyID'],
      'FacultyName': row['FacultyName'],
      'DepartmentID': row['DepartmentID'],
      'Position': row['Position'],
      'EmploymentStatus': row['EmploymentStatus'],
      'ContactInformation': row['ContactInformation'],
    };
  }
}

// ─── UserAccount ─────────────────────────────────────────────────────

class LocalUserAccount {
  static const String tableName = 'useraccounts';
  static const String primaryKey = 'UserID';

  static Map<String, dynamic> toMap(Map<String, dynamic> json, {bool synced = true}) {
    return {
      'UserID': json['UserID'] ?? json['userId'],
      'Username': json['Username'] ?? json['username'],
      'Password': json['Password'] ?? '',
      'Role': json['Role'] ?? json['role'],
      'FacultyID': json['FacultyID']?.toString() ?? json['facultyId']?.toString(),
      'IsActive': (json['IsActive'] ?? json['isActive'] ?? true) == true ? 1 : 0,
      'CreatedAt': json['CreatedAt'],
      'UpdatedAt': json['UpdatedAt'],
      ...synced ? SyncFields.synced() : SyncFields.defaults(),
    };
  }
}

// ─── Room ────────────────────────────────────────────────────────────

class LocalRoom {
  static const String tableName = 'rooms';
  static const String primaryKey = 'RoomID';

  static Map<String, dynamic> toMap(Map<String, dynamic> json, {bool synced = true}) {
    return {
      'RoomID': json['RoomID'],
      'RoomName': json['RoomName'],
      'Building': json['Building'],
      'Capacity': json['Capacity'],
      'CreatedAt': json['CreatedAt'],
      'UpdatedAt': json['UpdatedAt'],
      ...synced ? SyncFields.synced() : SyncFields.defaults(),
    };
  }

  static Map<String, dynamic> toApiJson(Map<String, dynamic> row) {
    return {
      'RoomID': row['RoomID'],
      'RoomName': row['RoomName'],
      'Building': row['Building'],
      'Capacity': row['Capacity'],
    };
  }
}

// ─── Subject ─────────────────────────────────────────────────────────

class LocalSubject {
  static const String tableName = 'subjects';
  static const String primaryKey = 'SubjectID';

  static Map<String, dynamic> toMap(Map<String, dynamic> json, {bool synced = true}) {
    return {
      'SubjectID': json['SubjectID'],
      'SubjectName': json['SubjectName'],
      'CourseCode': json['CourseCode'],
      'Units': json['Units'],
      'DepartmentID': json['DepartmentID'],
      'CreatedAt': json['CreatedAt'],
      'UpdatedAt': json['UpdatedAt'],
      ...synced ? SyncFields.synced() : SyncFields.defaults(),
    };
  }

  static Map<String, dynamic> toApiJson(Map<String, dynamic> row) {
    return {
      'SubjectID': row['SubjectID'],
      'SubjectName': row['SubjectName'],
      'CourseCode': row['CourseCode'],
      'Units': row['Units'],
      'DepartmentID': row['DepartmentID'],
    };
  }
}

// ─── Schedule ────────────────────────────────────────────────────────

class LocalSchedule {
  static const String tableName = 'schedules';
  static const String primaryKey = 'ScheduleID';

  static Map<String, dynamic> toMap(Map<String, dynamic> json, {bool synced = true}) {
    return {
      'ScheduleID': json['ScheduleID'],
      'FacultyID': json['FacultyID']?.toString(),
      'SubjectID': json['SubjectID'],
      'RoomID': json['RoomID'],
      'DayOfWeek': json['DayOfWeek'],
      'StartTime': json['StartTime'],
      'EndTime': json['EndTime'],
      'CreatedAt': json['CreatedAt'],
      'UpdatedAt': json['UpdatedAt'],
      ...synced ? SyncFields.synced() : SyncFields.defaults(),
    };
  }

  static Map<String, dynamic> toApiJson(Map<String, dynamic> row) {
    return {
      'ScheduleID': row['ScheduleID'],
      'FacultyID': row['FacultyID'],
      'SubjectID': row['SubjectID'],
      'RoomID': row['RoomID'],
      'DayOfWeek': row['DayOfWeek'],
      'StartTime': row['StartTime'],
      'EndTime': row['EndTime'],
    };
  }
}

// ─── AttendanceDevice ────────────────────────────────────────────────

class LocalDevice {
  static const String tableName = 'attendancedevices';
  static const String primaryKey = 'DeviceID';

  static Map<String, dynamic> toMap(Map<String, dynamic> json, {bool synced = true}) {
    return {
      'DeviceID': json['DeviceID'],
      'DeviceType': json['DeviceType'],
      'Location': json['Location'],
      'RoomID': json['RoomID'],
      'Status': json['Status'],
      'CreatedAt': json['CreatedAt'],
      'UpdatedAt': json['UpdatedAt'],
      ...synced ? SyncFields.synced() : SyncFields.defaults(),
    };
  }

  static Map<String, dynamic> toApiJson(Map<String, dynamic> row) {
    return {
      'DeviceID': row['DeviceID'],
      'DeviceType': row['DeviceType'],
      'Location': row['Location'],
      'RoomID': row['RoomID'],
      'Status': row['Status'],
    };
  }
}

// ─── Attendance ──────────────────────────────────────────────────────

class LocalAttendance {
  static const String tableName = 'attendances';
  static const String primaryKey = 'AttendanceID';

  static Map<String, dynamic> toMap(Map<String, dynamic> json, {bool synced = true}) {
    final map = <String, dynamic>{
      'FacultyID': json['FacultyID']?.toString(),
      'DeviceID': json['DeviceID'],
      'ScheduleID': json['ScheduleID'],
      'Date': json['Date'],
      'DayOfWeek': json['DayOfWeek'],
      'TimeIn': json['TimeIn'],
      'TimeOut': json['TimeOut'],
      'AttendanceStatus': json['AttendanceStatus'],
      'Remarks': json['Remarks'],
      'CreatedAt': json['CreatedAt'],
      'UpdatedAt': json['UpdatedAt'],
      'remoteId': json['AttendanceID'],
      ...synced ? SyncFields.synced() : SyncFields.defaults(),
    };
    // For pulled records, use AttendanceID as the local PK
    if (json['AttendanceID'] != null) {
      map['AttendanceID'] = json['AttendanceID'];
    }
    return map;
  }

  /// Convert for offline-created attendance (no remote ID yet)
  static Map<String, dynamic> toOfflineMap({
    required String facultyId,
    int? deviceId,
    int? scheduleId,
    required String date,
    required String dayOfWeek,
    String? timeIn,
    String? timeOut,
    required String attendanceStatus,
    String? remarks,
  }) {
    final now = DateTime.now().toIso8601String();
    return {
      'FacultyID': facultyId,
      'DeviceID': deviceId,
      'ScheduleID': scheduleId,
      'Date': date,
      'DayOfWeek': dayOfWeek,
      'TimeIn': timeIn,
      'TimeOut': timeOut,
      'AttendanceStatus': attendanceStatus,
      'Remarks': remarks,
      'CreatedAt': now,
      'UpdatedAt': now,
      'remoteId': null,
      'isSynced': 0,
      'localCreatedAt': now,
      'localUpdatedAt': now,
      'deletedAt': null,
      'version': 1,
    };
  }

  static Map<String, dynamic> toApiJson(Map<String, dynamic> row) {
    return {
      'AttendanceID': row['remoteId'],
      'localId': row['AttendanceID'],
      'FacultyID': row['FacultyID'],
      'DeviceID': row['DeviceID'],
      'ScheduleID': row['ScheduleID'],
      'Date': row['Date'],
      'DayOfWeek': row['DayOfWeek'],
      'TimeIn': row['TimeIn'],
      'TimeOut': row['TimeOut'],
      'AttendanceStatus': row['AttendanceStatus'],
      'Remarks': row['Remarks'],
      'version': row['version'],
    };
  }
}

/// Table metadata for sync ordering (respects foreign key dependencies)
class SyncTableConfig {
  final String tableName;
  final String primaryKey;
  final Map<String, dynamic> Function(Map<String, dynamic>, {bool synced}) toMap;
  final Map<String, dynamic> Function(Map<String, dynamic>) toApiJson;

  const SyncTableConfig({
    required this.tableName,
    required this.primaryKey,
    required this.toMap,
    required this.toApiJson,
  });

  /// Tables in dependency order (parents first)
  static final List<SyncTableConfig> allTables = [
    SyncTableConfig(tableName: 'departments', primaryKey: 'DepartmentID', toMap: LocalDepartment.toMap, toApiJson: LocalDepartment.toApiJson),
    SyncTableConfig(tableName: 'faculties', primaryKey: 'FacultyID', toMap: LocalFaculty.toMap, toApiJson: LocalFaculty.toApiJson),
    SyncTableConfig(tableName: 'rooms', primaryKey: 'RoomID', toMap: LocalRoom.toMap, toApiJson: LocalRoom.toApiJson),
    SyncTableConfig(tableName: 'subjects', primaryKey: 'SubjectID', toMap: LocalSubject.toMap, toApiJson: LocalSubject.toApiJson),
    SyncTableConfig(tableName: 'schedules', primaryKey: 'ScheduleID', toMap: LocalSchedule.toMap, toApiJson: LocalSchedule.toApiJson),
    SyncTableConfig(tableName: 'attendancedevices', primaryKey: 'DeviceID', toMap: LocalDevice.toMap, toApiJson: LocalDevice.toApiJson),
    SyncTableConfig(tableName: 'attendances', primaryKey: 'AttendanceID', toMap: LocalAttendance.toMap, toApiJson: LocalAttendance.toApiJson),
  ];
}
