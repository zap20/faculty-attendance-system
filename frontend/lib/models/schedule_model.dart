class ScheduleModel {
  final int scheduleId;
  final String facultyId;
  final String? facultyName;
  final int subjectId;
  final String? subjectName;
  final String? courseCode;
  final int roomId;
  final String? roomName;
  final String? building;
  final String dayOfWeek;
  final String startTime;
  final String endTime;

  ScheduleModel({
    required this.scheduleId,
    required this.facultyId,
    this.facultyName,
    required this.subjectId,
    this.subjectName,
    this.courseCode,
    required this.roomId,
    this.roomName,
    this.building,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      scheduleId: json['ScheduleID'] ?? 0,
      facultyId: json['FacultyID']?.toString() ?? '',
      facultyName: json['FacultyName'],
      subjectId: json['SubjectID'] ?? 0,
      subjectName: json['SubjectName'],
      courseCode: json['CourseCode'],
      roomId: json['RoomID'] ?? 0,
      roomName: json['RoomName'],
      building: json['Building'],
      dayOfWeek: json['DayOfWeek'] ?? '',
      startTime: json['StartTime'] ?? '',
      endTime: json['EndTime'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'FacultyID': facultyId,
      'SubjectID': subjectId,
      'RoomID': roomId,
      'DayOfWeek': dayOfWeek,
      'StartTime': startTime,
      'EndTime': endTime,
    };
  }

  String get timeRange => '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  
  String get roomInfo => roomName != null ? '$roomName ($building)' : '';

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $period';
  }
}
