import 'package:flutter/foundation.dart';
import '../../models/attendance_model.dart';
import '../../models/schedule_model.dart';
import 'attendance_repository.dart';
import 'database_helper.dart';
import 'local_models.dart';

/// Offline implementation — all operations go to local Sqflite database.
/// Records are marked isSynced=0 and will be pushed when connectivity returns.
class OfflineAttendanceRepository implements AttendanceRepository {
  final DatabaseHelper _db = DatabaseHelper();

  @override
  Future<Map<String, dynamic>> timeIn({
    required int deviceId,
    String? scanDate,
    String? scanTime,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final date = scanDate ?? now.toIso8601String().split('T')[0];
    final time = scanTime ?? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    // Get the current user's faculty ID from local useraccounts
    final users = await db.query('useraccounts', limit: 1);
    if (users.isEmpty) {
      throw Exception('No local user found. Please sync first while online.');
    }
    final facultyId = users.first['FacultyID']?.toString() ?? '';
    if (facultyId.isEmpty) {
      throw Exception('No faculty profile associated with this account');
    }

    // Calculate day of week
    final dateObj = DateTime.parse(date);
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayOfWeek = days[dateObj.weekday - 1];

    // Find matching schedule
    final schedules = await db.query(
      'schedules',
      where: 'FacultyID = ? AND DayOfWeek = ? AND deletedAt IS NULL',
      whereArgs: [facultyId, dayOfWeek],
    );

    int? scheduleId;
    String status = 'Present';
    String remarks = 'Recorded offline';

    if (schedules.isEmpty) {
      status = 'No Schedule';
      remarks = 'No schedule found (offline)';
    } else {
      // Find the schedule that matches current time
      for (final s in schedules) {
        final startTime = s['StartTime']?.toString() ?? '';
        final endTime = s['EndTime']?.toString() ?? '';
        if (_isTimeInRange(time, startTime, endTime)) {
          scheduleId = s['ScheduleID'] as int?;
          // Check if late (30 min grace)
          if (_isLate(time, startTime, 30)) {
            status = 'Late';
            remarks = 'Arrived late (offline)';
          }
          break;
        }
      }
      if (scheduleId == null) {
        // No matching schedule for this time
        status = 'No Schedule';
        remarks = 'No matching schedule for current time (offline)';
      }
    }

    // Check for duplicate
    if (scheduleId != null) {
      final existing = await db.query(
        'attendances',
        where: 'FacultyID = ? AND ScheduleID = ? AND Date = ? AND deletedAt IS NULL',
        whereArgs: [facultyId, scheduleId, date],
      );
      if (existing.isNotEmpty) {
        throw Exception('Attendance already recorded for this schedule');
      }
    }

    final record = LocalAttendance.toOfflineMap(
      facultyId: facultyId,
      deviceId: deviceId,
      scheduleId: scheduleId,
      date: date,
      dayOfWeek: dayOfWeek,
      timeIn: time,
      attendanceStatus: status,
      remarks: remarks,
    );

    final id = await db.insert('attendances', record);
    debugPrint('[OfflineRepo] TimeIn recorded locally, id=$id, status=$status');

    return {
      'success': true,
      'message': 'Time in recorded offline',
      'data': {'attendanceId': id, 'status': status, 'offline': true},
    };
  }

  @override
  Future<Map<String, dynamic>> timeOut({required int deviceId}) async {
    final db = await _db.database;
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final users = await db.query('useraccounts', limit: 1);
    if (users.isEmpty) throw Exception('No local user found');
    final facultyId = users.first['FacultyID']?.toString() ?? '';

    // Find open attendance (has TimeIn but no TimeOut)
    final open = await db.query(
      'attendances',
      where: 'FacultyID = ? AND Date = ? AND TimeIn IS NOT NULL AND TimeOut IS NULL AND deletedAt IS NULL',
      whereArgs: [facultyId, today],
      orderBy: 'TimeIn DESC',
      limit: 1,
    );

    if (open.isEmpty) {
      throw Exception('No open attendance record found');
    }

    final attendanceId = open.first['AttendanceID'];
    await db.update(
      'attendances',
      {
        'TimeOut': time,
        'isSynced': 0,
        'localUpdatedAt': now.toIso8601String(),
        'version': ((open.first['version'] as int?) ?? 1) + 1,
      },
      where: 'AttendanceID = ?',
      whereArgs: [attendanceId],
    );

    debugPrint('[OfflineRepo] TimeOut recorded locally, id=$attendanceId');
    return {
      'success': true,
      'message': 'Time out recorded offline',
      'data': {'attendanceId': attendanceId, 'timeOut': time, 'offline': true},
    };
  }

  @override
  Future<Map<String, dynamic>> recordByQR({
    required String qrCode,
    String? scanDate,
    String? scanTime,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final date = scanDate ?? now.toIso8601String().split('T')[0];
    final time = scanTime ?? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    // Find faculty by ID or employee number
    var faculty = await db.query('faculties', where: 'FacultyID = ?', whereArgs: [qrCode]);
    if (faculty.isEmpty) {
      throw Exception('Faculty not found locally for QR: $qrCode. Sync required.');
    }

    final facultyId = faculty.first['FacultyID']?.toString() ?? '';
    final dateObj = DateTime.parse(date);
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayOfWeek = days[dateObj.weekday - 1];

    // Check for open attendance (toggle time-in / time-out)
    final open = await db.query(
      'attendances',
      where: 'FacultyID = ? AND Date = ? AND TimeIn IS NOT NULL AND TimeOut IS NULL AND deletedAt IS NULL',
      whereArgs: [facultyId, date],
      orderBy: 'TimeIn DESC',
      limit: 1,
    );

    if (open.isNotEmpty) {
      // Time out
      final attendanceId = open.first['AttendanceID'];
      await db.update(
        'attendances',
        {
          'TimeOut': time,
          'isSynced': 0,
          'localUpdatedAt': now.toIso8601String(),
          'version': ((open.first['version'] as int?) ?? 1) + 1,
        },
        where: 'AttendanceID = ?',
        whereArgs: [attendanceId],
      );
      return {
        'success': true,
        'message': 'Time out recorded offline (QR)',
        'data': {'action': 'timeout', 'attendanceId': attendanceId, 'offline': true},
      };
    }

    // Time in — find schedule
    final schedules = await db.query(
      'schedules',
      where: 'FacultyID = ? AND DayOfWeek = ? AND deletedAt IS NULL',
      whereArgs: [facultyId, dayOfWeek],
    );

    int? scheduleId;
    String status = 'Present';
    String remarks = 'QR scan (offline)';

    for (final s in schedules) {
      final startTime = s['StartTime']?.toString() ?? '';
      final endTime = s['EndTime']?.toString() ?? '';
      if (_isTimeInRange(time, startTime, endTime)) {
        scheduleId = s['ScheduleID'] as int?;
        if (_isLate(time, startTime, 30)) {
          status = 'Late';
          remarks = 'Arrived late via QR (offline)';
        }
        break;
      }
    }

    if (scheduleId == null) {
      return {
        'success': true,
        'message': 'No schedule found for this time',
        'data': {'action': 'no_schedule', 'inserted': false, 'offline': true},
      };
    }

    final record = LocalAttendance.toOfflineMap(
      facultyId: facultyId,
      scheduleId: scheduleId,
      date: date,
      dayOfWeek: dayOfWeek,
      timeIn: time,
      attendanceStatus: status,
      remarks: remarks,
    );

    final id = await db.insert('attendances', record);
    return {
      'success': true,
      'message': 'Time in recorded offline (QR)',
      'data': {'action': 'timein', 'attendanceId': id, 'offline': true},
    };
  }

  @override
  Future<List<AttendanceModel>> getTodayAttendance() async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    final users = await db.query('useraccounts', limit: 1);
    final facultyId = users.isNotEmpty
        ? users.first['FacultyID']?.toString()
        : null;
    final hasFacultyId = facultyId != null && facultyId.isNotEmpty && facultyId != 'null';

    // Officers/admins (no FacultyID) see all attendance; faculty sees only their own
    final where = hasFacultyId
        ? 'a.FacultyID = ? AND a.Date = ? AND a.deletedAt IS NULL'
        : 'a.Date = ? AND a.deletedAt IS NULL';
    final args = hasFacultyId ? [facultyId, today] : [today];

    final results = await db.rawQuery('''
      SELECT a.*,
             f.FacultyName, f.DepartmentID,
             s.SubjectID, sub.SubjectName, sub.CourseCode,
             r.RoomName, r.Building
      FROM attendances a
      LEFT JOIN faculties f ON a.FacultyID = f.FacultyID
      LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
      LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
      LEFT JOIN rooms r ON s.RoomID = r.RoomID
      WHERE $where
      ORDER BY a.TimeIn
    ''', args);

    return results.map((r) => AttendanceModel.fromJson(r)).toList();
  }

  @override
  Future<List<AttendanceModel>> getAttendanceHistory({
    String? from,
    String? to,
    String? facultyId,
    String? departmentId,
    String? status,
  }) async {
    final db = await _db.database;
    final where = <String>['a.deletedAt IS NULL'];
    final args = <dynamic>[];

    if (from != null) { where.add('a.Date >= ?'); args.add(from); }
    if (to != null) { where.add('a.Date <= ?'); args.add(to); }
    if (facultyId != null) { where.add('a.FacultyID = ?'); args.add(facultyId); }
    if (departmentId != null) { where.add('f.DepartmentID = ?'); args.add(departmentId); }
    if (status != null) { where.add('a.AttendanceStatus = ?'); args.add(status); }

    final results = await db.rawQuery('''
      SELECT a.*,
             f.FacultyName, f.DepartmentID,
             s.SubjectID, sub.SubjectName, sub.CourseCode,
             r.RoomName, r.Building
      FROM attendances a
      LEFT JOIN faculties f ON a.FacultyID = f.FacultyID
      LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
      LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
      LEFT JOIN rooms r ON s.RoomID = r.RoomID
      WHERE ${where.join(' AND ')}
      ORDER BY a.Date DESC, a.TimeIn DESC
    ''', args);

    return results.map((r) => AttendanceModel.fromJson(r)).toList();
  }

  @override
  Future<List<ScheduleModel>> getSchedules({String? facultyId}) async {
    final db = await _db.database;
    final where = <String>['s.deletedAt IS NULL'];
    final args = <dynamic>[];

    if (facultyId != null) { where.add('s.FacultyID = ?'); args.add(facultyId); }

    final results = await db.rawQuery('''
      SELECT s.*,
             f.FacultyName,
             sub.SubjectName, sub.CourseCode,
             r.RoomName, r.Building
      FROM schedules s
      LEFT JOIN faculties f ON s.FacultyID = f.FacultyID
      LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
      LEFT JOIN rooms r ON s.RoomID = r.RoomID
      WHERE ${where.join(' AND ')}
      ORDER BY s.DayOfWeek, s.StartTime
    ''', args);

    return results.map((r) => ScheduleModel.fromJson(r)).toList();
  }

  @override
  Future<Map<String, dynamic>> updateAttendanceStatus({
    required String action,
    required String facultyId,
    required String date,
    int? scheduleId,
    String? remarks,
    String? timeOut,
    String? status,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();

    if (action == 'absent') {
      if (scheduleId == null) throw Exception('scheduleId required for absent');

      final existing = await db.query(
        'attendances',
        where: 'FacultyID = ? AND ScheduleID = ? AND Date = ? AND deletedAt IS NULL',
        whereArgs: [facultyId, scheduleId, date],
      );

      if (existing.isNotEmpty) {
        await db.update(
          'attendances',
          {
            'AttendanceStatus': 'Absent',
            'TimeIn': null,
            'TimeOut': null,
            'Remarks': remarks ?? 'Marked absent offline',
            'isSynced': 0,
            'localUpdatedAt': now,
            'version': ((existing.first['version'] as int?) ?? 1) + 1,
          },
          where: 'AttendanceID = ?',
          whereArgs: [existing.first['AttendanceID']],
        );
      } else {
        final dateObj = DateTime.parse(date);
        final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final dayOfWeek = days[dateObj.weekday - 1];

        await db.insert('attendances', LocalAttendance.toOfflineMap(
          facultyId: facultyId,
          scheduleId: scheduleId,
          date: date,
          dayOfWeek: dayOfWeek,
          attendanceStatus: 'Absent',
          remarks: remarks ?? 'Marked absent offline',
        ));
      }
      return {'success': true, 'message': 'Marked absent offline', 'data': {'action': 'absent', 'offline': true}};

    } else if (action == 'early_out') {
      final earlyTime = timeOut ?? now.split('T')[1].split('.')[0];
      final where = scheduleId != null
          ? 'FacultyID = ? AND Date = ? AND ScheduleID = ? AND TimeIn IS NOT NULL AND deletedAt IS NULL'
          : 'FacultyID = ? AND Date = ? AND TimeIn IS NOT NULL AND TimeOut IS NULL AND deletedAt IS NULL';
      final args = scheduleId != null ? [facultyId, date, scheduleId] : [facultyId, date];

      final count = await db.update(
        'attendances',
        {
          'TimeOut': earlyTime,
          'Remarks': '${remarks ?? ''} | Early out offline',
          'isSynced': 0,
          'localUpdatedAt': now,
        },
        where: where,
        whereArgs: args,
      );

      if (count == 0) throw Exception('No open attendance record found');
      return {'success': true, 'message': 'Early out recorded offline', 'data': {'action': 'early_out', 'offline': true}};

    } else if (action == 'update_status') {
      if (status == null) throw Exception('status required');
      final where = scheduleId != null
          ? 'FacultyID = ? AND Date = ? AND ScheduleID = ? AND deletedAt IS NULL'
          : 'FacultyID = ? AND Date = ? AND deletedAt IS NULL';
      final args = scheduleId != null ? [facultyId, date, scheduleId] : [facultyId, date];

      final updates = <String, dynamic>{
        'AttendanceStatus': status,
        'isSynced': 0,
        'localUpdatedAt': now,
      };
      if (remarks != null) updates['Remarks'] = remarks;

      await db.update('attendances', updates, where: where, whereArgs: args);
      return {'success': true, 'message': 'Status updated offline', 'data': {'action': 'update_status', 'offline': true}};
    }

    throw Exception('Invalid action: $action');
  }

  @override
  Future<Map<String, dynamic>> autoAbsent({String? date, String? cutoffTime}) async {
    final db = await _db.database;
    final now = DateTime.now();
    final targetDate = date ?? now.toIso8601String().split('T')[0];
    final dateObj = DateTime.parse(targetDate);
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayOfWeek = days[dateObj.weekday - 1];

    // Find all schedules for this day that don't have attendance
    final schedules = await db.rawQuery('''
      SELECT s.ScheduleID, s.FacultyID, s.EndTime
      FROM schedules s
      WHERE s.DayOfWeek = ? AND s.deletedAt IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM attendances a
          WHERE a.FacultyID = s.FacultyID AND a.ScheduleID = s.ScheduleID AND a.Date = ? AND a.deletedAt IS NULL
        )
    ''', [dayOfWeek, targetDate]);

    int inserted = 0;
    for (final s in schedules) {
      await db.insert('attendances', LocalAttendance.toOfflineMap(
        facultyId: s['FacultyID']?.toString() ?? '',
        scheduleId: s['ScheduleID'] as int?,
        date: targetDate,
        dayOfWeek: dayOfWeek,
        attendanceStatus: 'Absent',
        remarks: 'Auto-marked absent (offline)',
      ));
      inserted++;
    }

    return {
      'success': true,
      'message': 'Auto-absent completed offline',
      'data': {'inserted': inserted, 'date': targetDate, 'offline': true},
    };
  }

  // ─── Helper methods ──────────────────────────────────────────────

  bool _isTimeInRange(String current, String start, String end) {
    final c = _timeToMinutes(current);
    final s = _timeToMinutes(start);
    final e = _timeToMinutes(end);
    // Allow 30 min before start and until end
    return c >= (s - 30) && c <= e;
  }

  bool _isLate(String current, String start, int graceMinutes) {
    final c = _timeToMinutes(current);
    final s = _timeToMinutes(start);
    return c > (s + graceMinutes);
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
}
