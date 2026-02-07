class RoomModel {
  final int roomId;
  final String roomName;
  final String building;
  final int? capacity;
  final int? deviceCount;

  RoomModel({
    required this.roomId,
    required this.roomName,
    required this.building,
    this.capacity,
    this.deviceCount,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      roomId: json['RoomID'] ?? 0,
      roomName: json['RoomName'] ?? '',
      building: json['Building'] ?? '',
      capacity: json['Capacity'],
      deviceCount: json['DeviceCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'RoomName': roomName,
      'Building': building,
      'Capacity': capacity,
    };
  }

  String get fullName => '$roomName - $building';
}
