class UserModel {
  final String uid;
  final String name;
  final String nrp;
  final String department;
  final String role;
  final String? photoUrl;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.nrp,
    required this.department,
    required this.role,
    this.photoUrl,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      nrp: map['nrp'] ?? '',
      department: map['department'] ?? '',
      role: map['role'] ?? 'mahasiswa',
      photoUrl: map['photoUrl'],
      createdAt: (map['createdAt'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nrp': nrp,
      'department': department,
      'role': role,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
    };
  }
}