class DeviceModel {
  final int deviceId;
  final String deviceType;
  final String location;
  final int? roomId;
  final String? roomName;
  final String? building;
  final String status;

  DeviceModel({
    required this.deviceId,
    required this.deviceType,
    required this.location,
    this.roomId,
    this.roomName,
    this.building,
    required this.status,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      deviceId: json['DeviceID'] ?? 0,
      deviceType: json['DeviceType'] ?? '',
      location: json['Location'] ?? '',
      roomId: json['RoomID'],
      roomName: json['RoomName'],
      building: json['Building'],
      status: json['Status'] ?? 'Inactive',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DeviceType': deviceType,
      'Location': location,
      'RoomID': roomId,
      'Status': status,
    };
  }

  bool get isActive => status == 'Active';
}
