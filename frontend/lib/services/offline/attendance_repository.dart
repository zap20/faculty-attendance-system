import '../../models/attendance_model.dart';
import '../../models/schedule_model.dart';

/// Abstract repository interface for attendance operations.
/// Both online and offline implementations conform to this contract.
abstract class AttendanceRepository {
  /// Record time-in for a faculty member
  Future<Map<String, dynamic>> timeIn({
    required int deviceId,
    String? scanDate,
    String? scanTime,
  });

  /// Record time-out for a faculty member
  Future<Map<String, dynamic>> timeOut({
    required int deviceId,
  });

  /// Record attendance via QR code (officer use)
  Future<Map<String, dynamic>> recordByQR({
    required String qrCode,
    String? scanDate,
    String? scanTime,
  });

  /// Get today's attendance for current faculty
  Future<List<AttendanceModel>> getTodayAttendance();

  /// Get attendance history with filters
  Future<List<AttendanceModel>> getAttendanceHistory({
    String? from,
    String? to,
    String? facultyId,
    String? departmentId,
    String? status,
  });

  /// Get all schedules
  Future<List<ScheduleModel>> getSchedules({String? facultyId});

  /// Update attendance status (officer use)
  Future<Map<String, dynamic>> updateAttendanceStatus({
    required String action,
    required String facultyId,
    required String date,
    int? scheduleId,
    String? remarks,
    String? timeOut,
    String? status,
  });

  /// Mark auto-absent
  Future<Map<String, dynamic>> autoAbsent({
    String? date,
    String? cutoffTime,
  });
}
