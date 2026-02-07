import '../models/models.dart';
import 'api_service.dart';

class DataService {
  // Departments
  static Future<List<DepartmentModel>> getDepartments() async {
    final response = await ApiService.get('/departments');
    if (response['success'] == true && response['data'] != null) {
      return (response['data'] as List)
          .map((json) => DepartmentModel.fromJson(json))
          .toList();
    }
    return [];
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
    final response = await ApiService.get('/faculties');
    if (response['success'] == true && response['data'] != null) {
      return (response['data'] as List)
          .map((json) => FacultyModel.fromJson(json))
          .toList();
    }
    return [];
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

  // Subjects
  static Future<List<SubjectModel>> getSubjects({int? departmentId}) async {
    final queryParams = <String, String>{};
    if (departmentId != null) queryParams['departmentId'] = departmentId.toString();
    
    final response = await ApiService.get('/subjects', queryParams: queryParams);
    if (response['success'] == true && response['data'] != null) {
      return (response['data'] as List)
          .map((json) => SubjectModel.fromJson(json))
          .toList();
    }
    return [];
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
    final response = await ApiService.get('/rooms');
    if (response['success'] == true && response['data'] != null) {
      return (response['data'] as List)
          .map((json) => RoomModel.fromJson(json))
          .toList();
    }
    return [];
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
    final queryParams = <String, String>{};
    if (facultyId != null) queryParams['facultyId'] = facultyId.toString();
    
    final response = await ApiService.get('/schedules', queryParams: queryParams);
    if (response['success'] == true && response['data'] != null) {
      return (response['data'] as List)
          .map((json) => ScheduleModel.fromJson(json))
          .toList();
    }
    return [];
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
    final queryParams = <String, String>{};
    if (roomId != null) queryParams['roomId'] = roomId.toString();
    
    final response = await ApiService.get('/devices', queryParams: queryParams);
    if (response['success'] == true && response['data'] != null) {
      return (response['data'] as List)
          .map((json) => DeviceModel.fromJson(json))
          .toList();
    }
    return [];
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
    final response = await ApiService.get('/reports/dashboard');
    return response['data'] ?? {};
  }

  static Future<Map<String, dynamic>> getSummary({String? date, int? departmentId}) async {
    final queryParams = <String, String>{};
    if (date != null) queryParams['date'] = date;
    if (departmentId != null) queryParams['departmentId'] = departmentId.toString();
    
    final response = await ApiService.get('/reports/summary', queryParams: queryParams);
    return response['data'] ?? {};
  }

  static Future<Map<String, dynamic>> getDepartmentReport({
    required int departmentId,
    String? from,
    String? to,
  }) async {
    final queryParams = <String, String>{
      'departmentId': departmentId.toString(),
    };
    if (from != null) queryParams['from'] = from;
    if (to != null) queryParams['to'] = to;
    
    final response = await ApiService.get('/reports/department', queryParams: queryParams);
    return response['data'] ?? {};
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
    final today = DateTime.now().toIso8601String().split('T')[0];
    final response = await ApiService.get('/attendance', queryParams: {'date': today});
    if (response['success'] == true && response['data'] != null) {
      return (response['data'] as List)
          .map((json) => AttendanceModel.fromJson(json))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> getAttendanceReport(DateTime startDate, DateTime endDate) async {
    final from = startDate.toIso8601String().split('T')[0];
    final to = endDate.toIso8601String().split('T')[0];
    final response = await ApiService.get('/reports/summary', queryParams: {
      'from': from,
      'to': to,
    });
    return response['data'] ?? {};
  }
}
