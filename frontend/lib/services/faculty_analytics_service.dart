import 'api_service.dart';

/// API client for Faculty Dashboard endpoints
class FacultyAnalyticsService {
  static Future<Map<String, dynamic>> getDashboardSummary({
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await ApiService.get('/faculty/dashboard-summary', queryParams: params);
    return response['data'] ?? {};
  }

  static Future<Map<String, dynamic>> getSchedule() async {
    final response = await ApiService.get('/faculty/schedule');
    return response['data'] ?? {};
  }

  static Future<List<Map<String, dynamic>>> getAttendance({
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await ApiService.get('/faculty/attendance', queryParams: params);
    final data = response['data'] ?? {};
    return List<Map<String, dynamic>>.from(data['attendance'] ?? []);
  }

  static Future<Map<String, dynamic>> getAnalyticsSummary({
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await ApiService.get('/faculty/analytics-summary', queryParams: params);
    return response['data'] ?? {};
  }

  static Future<List<Map<String, dynamic>>> getAttendanceTrend({
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await ApiService.get('/faculty/attendance-trend', queryParams: params);
    final data = response['data'] ?? {};
    return List<Map<String, dynamic>>.from(data['trend'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> getStatusBreakdown({
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await ApiService.get('/faculty/status-breakdown', queryParams: params);
    final data = response['data'] ?? {};
    return List<Map<String, dynamic>>.from(data['breakdown'] ?? []);
  }
}
