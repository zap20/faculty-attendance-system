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

  bool get isAdmin => role == 'Admin';
  bool get isAttendanceOfficer => role == 'AttendanceOfficer';
  bool get isFaculty => role == 'Faculty';
  bool get isDepartmentHead => role == 'DepartmentHead';
  bool get canManage => isAdmin || isAttendanceOfficer;
}
