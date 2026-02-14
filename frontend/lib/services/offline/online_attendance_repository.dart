import '../../models/attendance_model.dart';
import '../../models/schedule_model.dart';
import '../api_service.dart';
import 'attendance_repository.dart';

/// Online implementation — delegates all calls to the REST API (MariaDB).
class OnlineAttendanceRepository implements AttendanceRepository {
  @override
  Future<Map<String, dynamic>> timeIn({
    required int deviceId,
    String? scanDate,
    String? scanTime,
  }) async {
    final body = <String, dynamic>{'deviceId': deviceId};
    if (scanDate != null) body['scan_date'] = scanDate;
    if (scanTime != null) body['scan_time'] = scanTime;
    return await ApiService.post('/attendance/timein', body: body);
  }

  @override
  Future<Map<String, dynamic>> timeOut({required int deviceId}) async {
    return await ApiService.post('/attendance/timeout', body: {'deviceId': deviceId});
  }

  @override
  Future<Map<String, dynamic>> recordByQR({
    required String qrCode,
    String? scanDate,
    String? scanTime,
  }) async {
    final body = <String, dynamic>{'qr_code': qrCode};
    if (scanDate != null) body['scan_date'] = scanDate;
    if (scanTime != null) body['scan_time'] = scanTime;
    return await ApiService.post('/attendance/qr', body: body);
  }

  @override
  Future<List<AttendanceModel>> getTodayAttendance() async {
    final response = await ApiService.get('/attendance/today');
    final data = response['data'];
    final list = (data['attendances'] as List?) ?? [];
    return list.map((e) => AttendanceModel.fromJson(e)).toList();
  }

  @override
  Future<List<AttendanceModel>> getAttendanceHistory({
    String? from,
    String? to,
    String? facultyId,
    String? departmentId,
    String? status,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (facultyId != null) params['facultyId'] = facultyId;
    if (departmentId != null) params['departmentId'] = departmentId;
    if (status != null) params['status'] = status;

    final response = await ApiService.get('/attendance', queryParams: params.isNotEmpty ? params : null);
    final list = (response['data'] as List?) ?? [];
    return list.map((e) => AttendanceModel.fromJson(e)).toList();
  }

  @override
  Future<List<ScheduleModel>> getSchedules({String? facultyId}) async {
    final params = <String, String>{};
    if (facultyId != null) params['facultyId'] = facultyId;
    final response = await ApiService.get('/schedules', queryParams: params.isNotEmpty ? params : null);
    final list = (response['data'] as List?) ?? [];
    return list.map((e) => ScheduleModel.fromJson(e)).toList();
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
    final body = <String, dynamic>{
      'action': action,
      'facultyId': facultyId,
      'date': date,
    };
    if (scheduleId != null) body['scheduleId'] = scheduleId;
    if (remarks != null) body['remarks'] = remarks;
    if (timeOut != null) body['timeOut'] = timeOut;
    if (status != null) body['status'] = status;
    return await ApiService.put('/attendance/update-status', body: body);
  }

  @override
  Future<Map<String, dynamic>> autoAbsent({String? date, String? cutoffTime}) async {
    final body = <String, dynamic>{};
    if (date != null) body['date'] = date;
    if (cutoffTime != null) body['cutoff_time'] = cutoffTime;
    return await ApiService.post('/attendance/auto-absent', body: body);
  }
}
