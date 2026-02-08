class SubjectModel {
  final int subjectId;
  final String subjectName;
  final String courseCode;
  final int units;
  final int departmentId;
  final String? departmentName;

  SubjectModel({
    required this.subjectId,
    required this.subjectName,
    required this.courseCode,
    required this.units,
    required this.departmentId,
    this.departmentName,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      subjectId: json['SubjectID'] ?? 0,
      subjectName: json['SubjectName'] ?? '',
      courseCode: json['CourseCode'] ?? '',
      units: json['Units'] ?? 0,
      departmentId: json['DepartmentID'] ?? 0,
      departmentName: json['DepartmentName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SubjectName': subjectName,
      'CourseCode': courseCode,
      'Units': units,
      'DepartmentID': departmentId,
    };
  }
}
