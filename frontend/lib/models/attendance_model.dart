class AttendanceModel {
  final int attendanceId;
  final String facultyId;
  final String? facultyName;
  final int? departmentId;
  final String? departmentName;
  final int? deviceId;
  final String? deviceType;
  final String? deviceLocation;
  final int? scheduleId;
  final int? subjectId;
  final String? subjectName;
  final String? courseCode;
  final String? roomName;
  final String? building;
  final String date;
  final String? dayOfWeek;
  final String? timeIn;
  final String? timeOut;
  final String attendanceStatus;
  final String? remarks;

  AttendanceModel({
    required this.attendanceId,
    required this.facultyId,
    this.facultyName,
    this.departmentId,
    this.departmentName,
    this.deviceId,
    this.deviceType,
    this.deviceLocation,
    this.scheduleId,
    this.subjectId,
    this.subjectName,
    this.courseCode,
    this.roomName,
    this.building,
    required this.date,
    this.dayOfWeek,
    this.timeIn,
    this.timeOut,
    required this.attendanceStatus,
    this.remarks,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      attendanceId: json['AttendanceID'] ?? 0,
      facultyId: json['FacultyID']?.toString() ?? '',
      facultyName: json['FacultyName'],
      departmentId: json['DepartmentID'],
      departmentName: json['DepartmentName'],
      deviceId: json['DeviceID'],
      deviceType: json['DeviceType'],
      deviceLocation: json['DeviceLocation'],
      scheduleId: json['ScheduleID'],
      subjectId: json['SubjectID'],
      subjectName: json['SubjectName'],
      courseCode: json['CourseCode'],
      roomName: json['RoomName'],
      building: json['Building'],
      date: json['Date'] ?? '',
      dayOfWeek: json['DayOfWeek'],
      timeIn: json['TimeIn'],
      timeOut: json['TimeOut'],
      attendanceStatus: json['AttendanceStatus'] ?? '',
      remarks: json['Remarks'],
    );
  }

  bool get isPresent => attendanceStatus == 'Present';
  bool get isLate => attendanceStatus == 'Late';
  bool get hasTimedOut => timeOut != null;

  String get statusColor {
    switch (attendanceStatus) {
      case 'Present':
        return 'green';
      case 'Late':
        return 'orange';
      case 'Wrong Room':
        return 'red';
      case 'No Schedule':
        return 'grey';
      default:
        return 'grey';
    }
  }
}
