class UserModel {
  final int userId;
  final String username;
  final String role;
  final String? facultyId;
  final String? facultyName;
  final int? departmentId;
  final String? departmentName;
  final bool isActive;

  UserModel({
    required this.userId,
    required this.username,
    required this.role,
    this.facultyId,
    this.facultyName,
    this.departmentId,
    this.departmentName,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? json['UserID'] ?? 0,
      username: json['username'] ?? json['Username'] ?? '',
      role: json['role'] ?? json['Role'] ?? '',
      facultyId: json['facultyId']?.toString() ?? json['FacultyID']?.toString(),
      facultyName: json['facultyName'] ?? json['FacultyName'],
      departmentId: json['departmentId'] ?? json['DepartmentID'],
      departmentName: json['departmentName'] ?? json['DepartmentName'],
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'role': role,
      'facultyId': facultyId,
      'facultyName': facultyName,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'isActive': isActive,
    };
  }

  String get _normalizedRole => role.trim().toLowerCase();

  bool get isAdmin => _normalizedRole == 'admin';
  bool get isAttendanceOfficer => _normalizedRole == 'attendanceofficer' || _normalizedRole == 'attendance officer';
  bool get isFaculty => _normalizedRole == 'faculty';
  bool get isDepartmentHead => _normalizedRole == 'departmenthead' || _normalizedRole == 'department head';
  bool get canManage => isAdmin || isAttendanceOfficer;
}
