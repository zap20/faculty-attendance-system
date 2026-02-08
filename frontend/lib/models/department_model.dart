class DepartmentModel {
  final int departmentId;
  final String departmentName;
  final String? departmentHead;
  final String? departmentDean;
  final int? facultyCount;
  final int? subjectCount;

  DepartmentModel({
    required this.departmentId,
    required this.departmentName,
    this.departmentHead,
    this.departmentDean,
    this.facultyCount,
    this.subjectCount,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      departmentId: json['DepartmentID'] ?? 0,
      departmentName: json['DepartmentName'] ?? '',
      departmentHead: json['DepartmentHead'],
      departmentDean: json['DepartmentDean'],
      facultyCount: json['FacultyCount'],
      subjectCount: json['SubjectCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DepartmentName': departmentName,
      'DepartmentHead': departmentHead,
      'DepartmentDean': departmentDean,
    };
  }
}
