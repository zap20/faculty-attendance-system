import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/attendance_service.dart';
import '../services/api_service.dart';

class AttendanceProvider with ChangeNotifier {
  List<ScheduleModel> _todaySchedules = [];
  List<AttendanceModel> _todayAttendances = [];
  List<AttendanceModel> _historyAttendances = [];
  String _todayDate = '';
  String _dayOfWeek = '';
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  List<ScheduleModel> get todaySchedules => _todaySchedules;
  List<AttendanceModel> get todayAttendances => _todayAttendances;
  List<AttendanceModel> get historyAttendances => _historyAttendances;
  String get todayDate => _todayDate;
  String get dayOfWeek => _dayOfWeek;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get successMessage => _successMessage;

  // Load today's data (schedules and attendance)
  Future<void> loadTodayData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load schedules
      final scheduleData = await AttendanceService.getTodaySchedules();
      _todayDate = scheduleData['date'] ?? '';
      _dayOfWeek = scheduleData['dayOfWeek'] ?? '';
      _todaySchedules = scheduleData['schedules'] as List<ScheduleModel>;

      // Load today's attendance
      final attendanceData = await AttendanceService.getTodayAttendance();
      _todayAttendances = attendanceData['attendances'] as List<AttendanceModel>;

      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load data';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Time in
  Future<bool> timeIn(int deviceId) async {
    _isLoading = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await AttendanceService.timeIn(deviceId);
      final attendance = result['attendance'];
      final status = attendance?['AttendanceStatus'] ?? 'Unknown';
      
      _successMessage = 'Time in recorded: $status';
      
      // Reload today's data
      await loadTodayData();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to record time in';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Time out
  Future<bool> timeOut(int deviceId) async {
    _isLoading = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      await AttendanceService.timeOut(deviceId);
      _successMessage = 'Time out recorded successfully';
      
      // Reload today's data
      await loadTodayData();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to record time out';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load attendance history
  Future<void> loadHistory({String? from, String? to}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await AttendanceService.getHistory(from: from, to: to);
      _historyAttendances = data['attendances'] as List<AttendanceModel>;
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load history';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if there's an open attendance (timed in but not out)
  bool get hasOpenAttendance {
    return _todayAttendances.any((a) => !a.hasTimedOut);
  }

  // Get open attendance
  AttendanceModel? get openAttendance {
    try {
      return _todayAttendances.firstWhere((a) => !a.hasTimedOut);
    } catch (_) {
      return null;
    }
  }

  // Clear messages
  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }
}
