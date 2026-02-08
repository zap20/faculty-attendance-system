import '../models/attendance_model.dart';
import '../models/schedule_model.dart';
import 'api_service.dart';

class AttendanceService {
  // Get attendance records with filters
  static Future<List<AttendanceModel>> getAttendance({
    String? from,
    String? to,
    int? departmentId,
    int? facultyId,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (from != null) queryParams['from'] = from;
    if (to != null) queryParams['to'] = to;
    if (departmentId != null) queryParams['departmentId'] = departmentId.toString();
    if (facultyId != null) queryParams['facultyId'] = facultyId.toString();
    if (status != null) queryParams['status'] = status;

    final response = await ApiService.get('/attendance', queryParams: queryParams);
    if (response['success'] == true && response['data'] != null) {
      return (response['data'] as List)
          .map((json) => AttendanceModel.fromJson(json))
          .toList();
    }
    return [];
  }

  // Get today's attendance for current faculty
  static Future<Map<String, dynamic>> getTodayAttendance() async {
    final response = await ApiService.get('/attendance/today');
    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      return {
        'date': data['date'],
        'attendances': (data['attendances'] as List)
            .map((json) => AttendanceModel.fromJson(json))
            .toList(),
      };
    }
    return {'date': '', 'attendances': []};
  }

  // Get today's schedules for current faculty
  static Future<Map<String, dynamic>> getTodaySchedules() async {
    final response = await ApiService.get('/schedules/today');
    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      return {
        'date': data['date'],
        'dayOfWeek': data['dayOfWeek'],
        'schedules': (data['schedules'] as List)
            .map((json) => ScheduleModel.fromJson(json))
            .toList(),
      };
    }
    return {'date': '', 'dayOfWeek': '', 'schedules': []};
  }

  // Time in
  static Future<Map<String, dynamic>> timeIn(int deviceId) async {
    final response = await ApiService.post('/attendance/timein', body: {
      'deviceId': deviceId,
    });
    return response['data'] ?? {};
  }

  // Time out
  static Future<Map<String, dynamic>> timeOut(int deviceId) async {
    final response = await ApiService.post('/attendance/timeout', body: {
      'deviceId': deviceId,
    });
    return response['data'] ?? {};
  }

  // Get attendance history
  static Future<Map<String, dynamic>> getHistory({String? from, String? to}) async {
    final queryParams = <String, String>{};
    if (from != null) queryParams['from'] = from;
    if (to != null) queryParams['to'] = to;

    final response = await ApiService.get('/attendance/history', queryParams: queryParams);
    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      return {
        'from': data['from'],
        'to': data['to'],
        'attendances': (data['attendances'] as List)
            .map((json) => AttendanceModel.fromJson(json))
            .toList(),
      };
    }
    return {'from': '', 'to': '', 'attendances': []};
  }
}
