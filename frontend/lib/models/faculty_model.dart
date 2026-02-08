class FacultyModel {
  final String facultyId;
  final String facultyName;
  final int departmentId;
  final String? departmentName;
  final String position;
  final String employmentStatus;
  final String? contactInformation;

  FacultyModel({
    required this.facultyId,
    required this.facultyName,
    required this.departmentId,
    this.departmentName,
    required this.position,
    required this.employmentStatus,
    this.contactInformation,
  });

  factory FacultyModel.fromJson(Map<String, dynamic> json) {
    return FacultyModel(
      facultyId: json['FacultyID']?.toString() ?? '',
      facultyName: json['FacultyName'] ?? '',
      departmentId: json['DepartmentID'] ?? 0,
      departmentName: json['DepartmentName'],
      position: json['Position'] ?? '',
      employmentStatus: json['EmploymentStatus'] ?? '',
      contactInformation: json['ContactInformation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'FacultyName': facultyName,
      'DepartmentID': departmentId,
      'Position': position,
      'EmploymentStatus': employmentStatus,
      'ContactInformation': contactInformation,
    };
  }
}
