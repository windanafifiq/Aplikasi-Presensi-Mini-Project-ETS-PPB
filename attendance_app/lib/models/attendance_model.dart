class AttendanceModel {
  final String id;
  final String userId;
  final String userName;
  final String nrp;
  final String sessionId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final double latitude;
  final double longitude;
  final String status; // "checked_in" / "completed" / "auto_checkout"

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.nrp,
    required this.sessionId,
    required this.checkInTime,
    this.checkOutTime,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      nrp: map['nrp'] ?? '',
      sessionId: map['sessionId'] ?? '',
      checkInTime: (map['checkInTime'] as dynamic).toDate(),
      checkOutTime: map['checkOutTime'] != null
          ? (map['checkOutTime'] as dynamic).toDate()
          : null,
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      status: map['status'] ?? 'checked_in',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'nrp': nrp,
      'sessionId': sessionId,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
    };
  }
}