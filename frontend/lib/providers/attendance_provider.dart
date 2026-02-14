import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/offline/repository_provider.dart';

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
      final repo = RepositoryProvider();
      
      // Load schedules and attendance using smart repository with fallback
      _todaySchedules = await repo.smartExecute(
        (r) => r.getSchedules(),
        operationName: 'GetSchedules',
      );
      _todayAttendances = await repo.smartExecute(
        (r) => r.getTodayAttendance(),
        operationName: 'GetTodayAttendance',
      );
      
      // Set date info
      final now = DateTime.now();
      _todayDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      _dayOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][now.weekday - 1];

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load data: ${e.toString()}';
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
      final repo = RepositoryProvider();
      final result = await repo.smartExecute(
        (r) => r.timeIn(deviceId: deviceId),
        operationName: 'TimeIn',
      );
      
      final status = result['data']?['status'] ?? 'Recorded';
      final isOffline = result['data']?['offline'] == true;
      
      _successMessage = 'Time in recorded: $status${isOffline ? ' (offline)' : ''}';
      
      // Reload today's data
      await loadTodayData();
      return true;
    } catch (e) {
      _error = 'Failed to record time in: ${e.toString()}';
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
      final repo = RepositoryProvider();
      final result = await repo.smartExecute(
        (r) => r.timeOut(deviceId: deviceId),
        operationName: 'TimeOut',
      );
      
      final isOffline = result['data']?['offline'] == true;
      _successMessage = 'Time out recorded successfully${isOffline ? ' (offline)' : ''}';
      
      // Reload today's data
      await loadTodayData();
      return true;
    } catch (e) {
      _error = 'Failed to record time out: ${e.toString()}';
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
      final repo = RepositoryProvider();
      _historyAttendances = await repo.smartExecute(
        (r) => r.getAttendanceHistory(from: from, to: to),
        operationName: 'GetHistory',
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load history: ${e.toString()}';
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
