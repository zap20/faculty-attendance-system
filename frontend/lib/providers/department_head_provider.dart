import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/data_service.dart';

class DepartmentHeadProvider with ChangeNotifier {
  bool _loadingDashboard = false;
  bool _loadingAnalytics = false;
  bool _loadingFaculties = false;
  bool _loadingSchedules = false;

  Map<String, dynamic> _dashboardSummary = {};
  Map<String, dynamic> _analytics = {};
  List<FacultyModel> _faculties = [];
  List<ScheduleModel> _schedules = [];

  bool get loadingDashboard => _loadingDashboard;
  bool get loadingAnalytics => _loadingAnalytics;
  bool get loadingFaculties => _loadingFaculties;
  bool get loadingSchedules => _loadingSchedules;

  Map<String, dynamic> get dashboardSummary => _dashboardSummary;
  Map<String, dynamic> get analytics => _analytics;
  List<FacultyModel> get faculties => _faculties;
  List<ScheduleModel> get schedules => _schedules;

  Future<void> loadDashboardSummary({String? date}) async {
    _loadingDashboard = true;
    notifyListeners();

    try {
      _dashboardSummary = await DataService.getDepartmentHeadDashboardSummary(date: date);
    } finally {
      _loadingDashboard = false;
      notifyListeners();
    }
  }

  Future<void> loadAnalytics({String? from, String? to}) async {
    _loadingAnalytics = true;
    notifyListeners();

    try {
      _analytics = await DataService.getDepartmentHeadAnalytics(
        from: from,
        to: to,
      );
    } finally {
      _loadingAnalytics = false;
      notifyListeners();
    }
  }

  Future<void> loadFaculties() async {
    _loadingFaculties = true;
    notifyListeners();

    try {
      _faculties = await DataService.getFaculties();
    } finally {
      _loadingFaculties = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createFaculty({
    required String facultyName,
    required String position,
    required String employmentStatus,
    String? contactInformation,
    required String username,
    String? tempPassword,
  }) async {
    final result = await DataService.createDepartmentHeadFaculty({
      'facultyName': facultyName,
      'position': position,
      'employmentStatus': employmentStatus,
      'contactInformation': contactInformation,
      'username': username,
      'tempPassword': tempPassword,
    });

    await loadFaculties();
    return result;
  }

  Future<void> loadSchedules({String? facultyId}) async {
    _loadingSchedules = true;
    notifyListeners();

    try {
      _schedules = await DataService.getSchedulesByFacultyId(facultyId: facultyId);
    } finally {
      _loadingSchedules = false;
      notifyListeners();
    }
  }

  Future<void> createSchedule(Map<String, dynamic> data) async {
    await DataService.createDepartmentHeadSchedule(data);
    await loadSchedules();
  }

  Future<void> updateSchedule(int id, Map<String, dynamic> data) async {
    await DataService.updateDepartmentHeadSchedule(id, data);
    await loadSchedules();
  }

  Future<void> deleteSchedule(int id) async {
    await DataService.deleteDepartmentHeadSchedule(id);
    await loadSchedules();
  }
}
