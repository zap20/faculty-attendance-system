import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'offline/network_service.dart';
import 'offline/database_helper.dart';

class DataService {
  static final NetworkService _network = NetworkService();
  static final DatabaseHelper _db = DatabaseHelper();

  /// Safe wrapper: try API first, fall back to local Sqflite query (mobile only)
  static Future<List<T>> _safeList<T>(
    Future<List<T>> Function() apiFetcher,
    String name, {
    Future<List<T>> Function()? offlineFallback,
  }) async {
    // On web, Sqflite is not available — skip offline fallback
    final canFallback = !kIsWeb && offlineFallback != null;

    // If offline, go straight to local DB
    if (!_network.isOnline && canFallback) {
      debugPrint('[DataService] $name: OFFLINE — reading from Sqflite');
      try {
        return await offlineFallback();
      } catch (e) {
        debugPrint('[DataService] $name offline fallback error: $e');
        return [];
      }
    }

    try {
      return await apiFetcher();
    } catch (e) {
      debugPrint('[DataService] $name API failed: $e');
      // Try local DB fallback (mobile only)
      if (canFallback) {
        debugPrint('[DataService] $name: falling back to Sqflite');
        try {
          return await offlineFallback();
        } catch (e2) {
          debugPrint('[DataService] $name offline fallback also failed: $e2');
        }
      }
      return [];
    }
  }

  /// Safe wrapper for maps: try API first, fall back to local DB (mobile only)
  static Future<Map<String, dynamic>> _safeMap(
    Future<Map<String, dynamic>> Function() apiFetcher,
    String name, {
    Future<Map<String, dynamic>> Function()? offlineFallback,
  }) async {
    final canFallback = !kIsWeb && offlineFallback != null;

    if (!_network.isOnline && canFallback) {
      debugPrint('[DataService] $name: OFFLINE — reading from Sqflite');
      try {
        return await offlineFallback();
      } catch (e) {
        debugPrint('[DataService] $name offline fallback error: $e');
        return {};
      }
    }

    try {
      return await apiFetcher();
    } catch (e) {
      debugPrint('[DataService] $name API failed: $e');
      if (canFallback) {
        debugPrint('[DataService] $name: falling back to Sqflite');
        try {
          return await offlineFallback();
        } catch (e2) {
          debugPrint('[DataService] $name offline fallback also failed: $e2');
        }
      }
      return {};
    }
  }

  // Departments
  static Future<List<DepartmentModel>> getDepartments() async {
    return _safeList(() async {
      final response = await ApiService.get('/departments');
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => DepartmentModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getDepartments', offlineFallback: () async {
      final db = await _db.database;
      final rows = await db.query('departments', where: 'deletedAt IS NULL');
      return rows.map((r) => DepartmentModel.fromJson(r)).toList();
    });
  }

  static Future<List<ScheduleModel>> getSchedulesByFacultyId({String? facultyId}) async {
    return _safeList(() async {
      final queryParams = <String, String>{};
      if (facultyId != null && facultyId.isNotEmpty) queryParams['facultyId'] = facultyId;

      final response = await ApiService.get('/schedules', queryParams: queryParams);
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => ScheduleModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getSchedulesByFacultyId', offlineFallback: () async {
      final db = await _db.database;
      final where = <String>['s.deletedAt IS NULL'];
      final args = <dynamic>[];
      if (facultyId != null && facultyId.isNotEmpty) { where.add('s.FacultyID = ?'); args.add(facultyId); }
      final rows = await db.rawQuery('''
        SELECT s.*, f.FacultyName, sub.SubjectName, sub.CourseCode, r.RoomName, r.Building
        FROM schedules s
        LEFT JOIN faculties f ON s.FacultyID = f.FacultyID
        LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
        LEFT JOIN rooms r ON s.RoomID = r.RoomID
        WHERE ${where.join(' AND ')}
        ORDER BY s.DayOfWeek, s.StartTime
      ''', args);
      return rows.map((r) => ScheduleModel.fromJson(r)).toList();
    });
  }

  static Future<DepartmentModel> createDepartment(Map<String, dynamic> data) async {
    final response = await ApiService.post('/departments', body: data);
    return DepartmentModel.fromJson(response['data']);
  }

  static Future<DepartmentModel> updateDepartment(int id, Map<String, dynamic> data) async {
    final response = await ApiService.put('/departments/$id', body: data);
    return DepartmentModel.fromJson(response['data']);
  }

  static Future<void> deleteDepartment(int id) async {
    await ApiService.delete('/departments/$id');
  }

  // Faculties
  static Future<List<FacultyModel>> getFaculties() async {
    return _safeList(() async {
      final response = await ApiService.get('/faculties');
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => FacultyModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getFaculties', offlineFallback: () async {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        SELECT f.*, d.DepartmentName
        FROM faculties f
        LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
        WHERE f.deletedAt IS NULL
      ''');
      return rows.map((r) => FacultyModel.fromJson(r)).toList();
    });
  }

  static Future<FacultyModel> createFaculty(Map<String, dynamic> data) async {
    final response = await ApiService.post('/faculties', body: data);
    return FacultyModel.fromJson(response['data']);
  }

  static Future<FacultyModel> updateFaculty(int id, Map<String, dynamic> data) async {
    final response = await ApiService.put('/faculties/$id', body: data);
    return FacultyModel.fromJson(response['data']);
  }

  static Future<void> deleteFaculty(int id) async {
    await ApiService.delete('/faculties/$id');
  }

  static Future<List<FacultyModel>> getMyDepartmentFaculties() async {
    return _safeList(() async {
      final response = await ApiService.get('/faculties/my-department');
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => FacultyModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getMyDepartmentFaculties', offlineFallback: () async {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        SELECT f.*, d.DepartmentName
        FROM faculties f
        LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
        WHERE f.deletedAt IS NULL
      ''');
      return rows.map((r) => FacultyModel.fromJson(r)).toList();
    });
  }

  // Subjects
  static Future<List<SubjectModel>> getSubjects({int? departmentId}) async {
    return _safeList(() async {
      final queryParams = <String, String>{};
      if (departmentId != null) queryParams['departmentId'] = departmentId.toString();
      
      final response = await ApiService.get('/subjects', queryParams: queryParams);
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => SubjectModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getSubjects', offlineFallback: () async {
      final db = await _db.database;
      final where = <String>['s.deletedAt IS NULL'];
      final args = <dynamic>[];
      if (departmentId != null) { where.add('s.DepartmentID = ?'); args.add(departmentId); }
      final rows = await db.rawQuery('''
        SELECT s.*, d.DepartmentName
        FROM subjects s
        LEFT JOIN departments d ON s.DepartmentID = d.DepartmentID
        WHERE ${where.join(' AND ')}
      ''', args);
      return rows.map((r) => SubjectModel.fromJson(r)).toList();
    });
  }

  static Future<SubjectModel> createSubject(Map<String, dynamic> data) async {
    final response = await ApiService.post('/subjects', body: data);
    return SubjectModel.fromJson(response['data']);
  }

  static Future<SubjectModel> updateSubject(int id, Map<String, dynamic> data) async {
    final response = await ApiService.put('/subjects/$id', body: data);
    return SubjectModel.fromJson(response['data']);
  }

  static Future<void> deleteSubject(int id) async {
    await ApiService.delete('/subjects/$id');
  }

  // Rooms
  static Future<List<RoomModel>> getRooms() async {
    return _safeList(() async {
      final response = await ApiService.get('/rooms');
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => RoomModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getRooms', offlineFallback: () async {
      final db = await _db.database;
      final rows = await db.query('rooms', where: 'deletedAt IS NULL');
      return rows.map((r) => RoomModel.fromJson(r)).toList();
    });
  }

  static Future<RoomModel> createRoom(Map<String, dynamic> data) async {
    final response = await ApiService.post('/rooms', body: data);
    return RoomModel.fromJson(response['data']);
  }

  static Future<RoomModel> updateRoom(int id, Map<String, dynamic> data) async {
    final response = await ApiService.put('/rooms/$id', body: data);
    return RoomModel.fromJson(response['data']);
  }

  static Future<void> deleteRoom(int id) async {
    await ApiService.delete('/rooms/$id');
  }

  // Schedules
  static Future<List<ScheduleModel>> getSchedules({int? facultyId}) async {
    return _safeList(() async {
      final queryParams = <String, String>{};
      if (facultyId != null) queryParams['facultyId'] = facultyId.toString();
      
      final response = await ApiService.get('/schedules', queryParams: queryParams);
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => ScheduleModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getSchedules', offlineFallback: () async {
      final db = await _db.database;
      final where = <String>['s.deletedAt IS NULL'];
      final args = <dynamic>[];
      if (facultyId != null) { where.add('s.FacultyID = ?'); args.add(facultyId); }
      final rows = await db.rawQuery('''
        SELECT s.*, f.FacultyName, sub.SubjectName, sub.CourseCode, r.RoomName, r.Building
        FROM schedules s
        LEFT JOIN faculties f ON s.FacultyID = f.FacultyID
        LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
        LEFT JOIN rooms r ON s.RoomID = r.RoomID
        WHERE ${where.join(' AND ')}
        ORDER BY s.DayOfWeek, s.StartTime
      ''', args);
      return rows.map((r) => ScheduleModel.fromJson(r)).toList();
    });
  }

  static Future<ScheduleModel> createSchedule(Map<String, dynamic> data) async {
    final response = await ApiService.post('/schedules', body: data);
    return ScheduleModel.fromJson(response['data']);
  }

  static Future<ScheduleModel> updateSchedule(int id, Map<String, dynamic> data) async {
    final response = await ApiService.put('/schedules/$id', body: data);
    return ScheduleModel.fromJson(response['data']);
  }

  static Future<void> deleteSchedule(int id) async {
    await ApiService.delete('/schedules/$id');
  }

  // Devices
  static Future<List<DeviceModel>> getDevices({int? roomId}) async {
    return _safeList(() async {
      final queryParams = <String, String>{};
      if (roomId != null) queryParams['roomId'] = roomId.toString();
      
      final response = await ApiService.get('/devices', queryParams: queryParams);
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => DeviceModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getDevices', offlineFallback: () async {
      final db = await _db.database;
      final where = <String>['d.deletedAt IS NULL'];
      final args = <dynamic>[];
      if (roomId != null) { where.add('d.RoomID = ?'); args.add(roomId); }
      final rows = await db.rawQuery('''
        SELECT d.*, r.RoomName, r.Building
        FROM attendancedevices d
        LEFT JOIN rooms r ON d.RoomID = r.RoomID
        WHERE ${where.join(' AND ')}
      ''', args);
      return rows.map((r) => DeviceModel.fromJson(r)).toList();
    });
  }

  static Future<DeviceModel> createDevice(Map<String, dynamic> data) async {
    final response = await ApiService.post('/devices', body: data);
    return DeviceModel.fromJson(response['data']);
  }

  static Future<DeviceModel> updateDevice(int id, Map<String, dynamic> data) async {
    final response = await ApiService.put('/devices/$id', body: data);
    return DeviceModel.fromJson(response['data']);
  }

  static Future<void> deleteDevice(int id) async {
    await ApiService.delete('/devices/$id');
  }

  // Reports
  static Future<Map<String, dynamic>> getDashboard() async {
    return _safeMap(() async {
      final response = await ApiService.get('/reports/dashboard');
      return response['data'] ?? {};
    }, 'getDashboard', offlineFallback: () async {
      final db = await _db.database;
      final today = DateTime.now().toIso8601String().split('T')[0];
      final totalFaculty = (await db.rawQuery('SELECT COUNT(*) as c FROM faculties WHERE deletedAt IS NULL')).first['c'] ?? 0;
      final totalDept = (await db.rawQuery('SELECT COUNT(*) as c FROM departments WHERE deletedAt IS NULL')).first['c'] ?? 0;
      final todayAtt = (await db.rawQuery('SELECT COUNT(*) as c FROM attendances WHERE Date = ? AND deletedAt IS NULL', [today])).first['c'] ?? 0;
      return {
        'totalFaculty': totalFaculty,
        'totalDepartments': totalDept,
        'todayAttendance': todayAtt,
        'offline': true,
      };
    });
  }

  static Future<Map<String, dynamic>> getSummary({String? date, int? departmentId}) async {
    return _safeMap(() async {
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date;
      if (departmentId != null) queryParams['departmentId'] = departmentId.toString();
      
      final response = await ApiService.get('/reports/summary', queryParams: queryParams);
      return response['data'] ?? {};
    }, 'getSummary');
  }

  static Future<Map<String, dynamic>> getDepartmentReport({
    required int departmentId,
    String? from,
    String? to,
  }) async {
    return _safeMap(() async {
      final queryParams = <String, String>{
        'departmentId': departmentId.toString(),
      };
      if (from != null) queryParams['from'] = from;
      if (to != null) queryParams['to'] = to;
      
      final response = await ApiService.get('/reports/department', queryParams: queryParams);
      return response['data'] ?? {};
    }, 'getDepartmentReport');
  }

  // Attendance - QR Scanner methods
  static Future<Map<String, dynamic>> recordAttendanceByQR(String qrCode) async {
    // Get current date and time
    final now = DateTime.now();
    final attendanceDate = now.toIso8601String().split('T')[0]; // YYYY-MM-DD format
    
    // Calculate day of week for the attendance date (not current time)
    final attendanceDateTime = DateTime.parse(attendanceDate);
    final dayMap = {
      1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 
      5: 'Friday', 6: 'Saturday', 7: 'Sunday'
    };
    final dayOfWeek = dayMap[attendanceDateTime.weekday] ?? '';
    
    final requestData = {
      'qr_code': qrCode,
      'day_of_week': dayOfWeek,
      'scan_date': attendanceDate,
      'scan_time': now.toIso8601String(), // Full timestamp
    };
    
    final response = await ApiService.post('/attendance/qr', body: requestData);
    
    return response;
  }

  static Future<List<AttendanceModel>> getTodayAttendance() async {
    return _safeList(() async {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await ApiService.get('/attendance', queryParams: {'date': today});
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => AttendanceModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getTodayAttendance', offlineFallback: () async {
      final db = await _db.database;
      final today = DateTime.now().toIso8601String().split('T')[0];
      final rows = await db.rawQuery('''
        SELECT a.*, f.FacultyName, f.DepartmentID,
               s.SubjectID, sub.SubjectName, sub.CourseCode,
               r.RoomName, r.Building
        FROM attendances a
        LEFT JOIN faculties f ON a.FacultyID = f.FacultyID
        LEFT JOIN schedules s ON a.ScheduleID = s.ScheduleID
        LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
        LEFT JOIN rooms r ON s.RoomID = r.RoomID
        WHERE a.Date = ? AND a.deletedAt IS NULL
        ORDER BY a.TimeIn
      ''', [today]);
      return rows.map((r) => AttendanceModel.fromJson(r)).toList();
    });
  }

  static Future<Map<String, dynamic>> getAttendanceReport(DateTime startDate, DateTime endDate) async {
    return _safeMap(() async {
      final from = startDate.toIso8601String().split('T')[0];
      final to = endDate.toIso8601String().split('T')[0];
      final response = await ApiService.get('/reports/summary', queryParams: {
        'from': from,
        'to': to,
      });
      return response['data'] ?? {};
    }, 'getAttendanceReport');
  }

  static Future<Map<String, dynamic>> getDepartmentHeadDashboardSummary({String? date}) async {
    return _safeMap(() async {
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date;

      final response = await ApiService.get('/reports/summary', queryParams: queryParams);
      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) return {};

    final summary = (data['summary'] as Map?) ?? {};
    final totalFaculty = data['totalFaculty'] ?? 0;

    final present = summary['totalPresent'] ?? 0;
    final onTime = summary['onTime'] ?? 0;
    final late = summary['late'] ?? 0;
    final noSchedule = summary['noSchedule'] ?? 0;
    final wrongRoom = summary['wrongRoom'] ?? 0;
    final absent = summary['absent'] ?? 0;

    return {
      'date': data['date'] ?? date,
      'departmentId': data['departmentId'],
      'kpis': {
        'totalFaculty': totalFaculty,
        'presentToday': present,
        'onTimeToday': onTime,
        'lateToday': late,
        'noScheduleToday': noSchedule,
        'wrongRoomToday': wrongRoom,
        'absentToday': absent,
      },
      'statusBreakdownToday': [
        {'status': 'Present', 'count': onTime},
        {'status': 'Late', 'count': late},
        {'status': 'No Schedule', 'count': noSchedule},
        {'status': 'Wrong Room', 'count': wrongRoom},
      ],
    };
    }, 'getDepartmentHeadDashboardSummary');
  }

  static Future<Map<String, dynamic>> getDepartmentHeadAnalytics({
    String? from,
    String? to,
  }) async {
    return _safeMap(() async {
      final queryParams = <String, String>{};
      if (from != null) queryParams['from'] = from;
      if (to != null) queryParams['to'] = to;
      final response = await ApiService.get('/department-head/analytics', queryParams: queryParams);
      return response['data'] ?? {};
    }, 'getDepartmentHeadAnalytics');
  }

  static Future<List<FacultyModel>> getDepartmentHeadFaculties() async {
    return _safeList(() async {
      final response = await ApiService.get('/department-head/faculties');
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => FacultyModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getDepartmentHeadFaculties', offlineFallback: () async {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        SELECT f.*, d.DepartmentName
        FROM faculties f
        LEFT JOIN departments d ON f.DepartmentID = d.DepartmentID
        WHERE f.deletedAt IS NULL
      ''');
      return rows.map((r) => FacultyModel.fromJson(r)).toList();
    });
  }

  static Future<Map<String, dynamic>> createDepartmentHeadFaculty(Map<String, dynamic> data) async {
    final response = await ApiService.post('/department-head/faculties', body: data);
    return response['data'] ?? {};
  }

  static Future<List<ScheduleModel>> getDepartmentHeadSchedules({String? facultyId}) async {
    return _safeList(() async {
      final queryParams = <String, String>{};
      if (facultyId != null && facultyId.isNotEmpty) queryParams['facultyId'] = facultyId;
      final response = await ApiService.get('/department-head/schedules', queryParams: queryParams);
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => ScheduleModel.fromJson(json))
            .toList();
      }
      return [];
    }, 'getDepartmentHeadSchedules', offlineFallback: () async {
      final db = await _db.database;
      final where = <String>['s.deletedAt IS NULL'];
      final args = <dynamic>[];
      if (facultyId != null && facultyId.isNotEmpty) { where.add('s.FacultyID = ?'); args.add(facultyId); }
      final rows = await db.rawQuery('''
        SELECT s.*, f.FacultyName, sub.SubjectName, sub.CourseCode, r.RoomName, r.Building
        FROM schedules s
        LEFT JOIN faculties f ON s.FacultyID = f.FacultyID
        LEFT JOIN subjects sub ON s.SubjectID = sub.SubjectID
        LEFT JOIN rooms r ON s.RoomID = r.RoomID
        WHERE ${where.join(' AND ')}
        ORDER BY s.DayOfWeek, s.StartTime
      ''', args);
      return rows.map((r) => ScheduleModel.fromJson(r)).toList();
    });
  }

  static Future<ScheduleModel> createDepartmentHeadSchedule(Map<String, dynamic> data) async {
    final response = await ApiService.post('/schedules', body: data);
    return ScheduleModel.fromJson(response['data']);
  }

  static Future<ScheduleModel> updateDepartmentHeadSchedule(int id, Map<String, dynamic> data) async {
    final response = await ApiService.put('/schedules/$id', body: data);
    return ScheduleModel.fromJson(response['data']);
  }

  static Future<void> deleteDepartmentHeadSchedule(int id) async {
    await ApiService.delete('/schedules/$id');
  }
}
