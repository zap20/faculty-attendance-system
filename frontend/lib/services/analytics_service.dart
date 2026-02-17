import 'api_service.dart';

/// API client for Admin Analytics endpoints
class AnalyticsService {
  static Future<Map<String, dynamic>> getSummary({
    String? from,
    String? to,
    int? departmentId,
    String? facultyId,
    int? subjectId,
    int? roomId,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (departmentId != null) params['department_id'] = '$departmentId';
    if (facultyId != null) params['faculty_id'] = facultyId;
    if (subjectId != null) params['subject_id'] = '$subjectId';
    if (roomId != null) params['room_id'] = '$roomId';

    final response = await ApiService.get('/admin-analytics/summary', queryParams: params);
    return response['data'] ?? {};
  }

  static Future<List<Map<String, dynamic>>> getDepartmentComparison({
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await ApiService.get('/admin-analytics/department-comparison', queryParams: params);
    final data = response['data'] ?? {};
    return List<Map<String, dynamic>>.from(data['departments'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> getDepartmentRanking({
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await ApiService.get('/admin-analytics/department-ranking', queryParams: params);
    final data = response['data'] ?? {};
    return List<Map<String, dynamic>>.from(data['rankings'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> getAttendanceTrend({
    String? from,
    String? to,
    int? departmentId,
    String? facultyId,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (departmentId != null) params['department_id'] = '$departmentId';
    if (facultyId != null) params['faculty_id'] = facultyId;

    final response = await ApiService.get('/admin-analytics/attendance-trend', queryParams: params);
    final data = response['data'] ?? {};
    return List<Map<String, dynamic>>.from(data['trend'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> getExceptionHeatmap({
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await ApiService.get('/admin-analytics/exception-heatmap', queryParams: params);
    final data = response['data'] ?? {};
    return List<Map<String, dynamic>>.from(data['heatmap'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> getRoomUtilization({
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await ApiService.get('/admin-analytics/room-utilization', queryParams: params);
    final data = response['data'] ?? {};
    return List<Map<String, dynamic>>.from(data['rooms'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> getFacultyPerformance({
    String? from,
    String? to,
    int? departmentId,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (departmentId != null) params['department_id'] = '$departmentId';

    final response = await ApiService.get('/admin-analytics/faculty-performance', queryParams: params);
    final data = response['data'] ?? {};
    return List<Map<String, dynamic>>.from(data['faculty'] ?? []);
  }
}
