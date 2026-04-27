import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // === USER CRUD ===
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<void> updateProfilePhoto(String uid, String photoUrl) async {
    await _db.collection('users').doc(uid).update({'photoUrl': photoUrl});
  }

  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, uid);
  }

  Stream<List<UserModel>> getAllMahasiswa() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'mahasiswa')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // === ATTENDANCE CRUD ===
  Future<void> addAttendance(AttendanceModel attendance) async {
    await _db.collection('attendance').add(attendance.toMap());
  }

  Future<void> checkOut(String attendanceId) async {
    await _db.collection('attendance').doc(attendanceId).update({
      'checkOutTime': DateTime.now(),
      'status': 'completed',
    });
  }

  Future<void> autoCheckout(String attendanceId, DateTime endTime) async {
    await _db.collection('attendance').doc(attendanceId).update({
      'checkOutTime': endTime,
      'status': 'auto_checkout',
    });
  }

  Stream<List<AttendanceModel>> getAttendanceByUser(String userId) {
    return _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .orderBy('checkInTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AttendanceModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<AttendanceModel?> getActiveAttendance(
      String userId, String sessionId) async {
    final snap = await _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .where('sessionId', isEqualTo: sessionId)
        .where('status', isEqualTo: 'checked_in')
        .get();
    if (snap.docs.isEmpty) return null;
    return AttendanceModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  Future<bool> hasAttendedSession(String userId, String sessionId) async {
    final snap = await _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .where('sessionId', isEqualTo: sessionId)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<List<AttendanceModel>> getCheckedInAttendances(
      String sessionId) async {
    final snap = await _db
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .where('status', isEqualTo: 'checked_in')
        .get();
    return snap.docs
        .map((doc) => AttendanceModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Stream<List<AttendanceModel>> getAttendanceBySession(String sessionId) {
    return _db
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('checkInTime')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AttendanceModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> deleteAttendance(String id) async {
    await _db.collection('attendance').doc(id).delete();
  }

  // === SESSION CRUD ===
  Future<void> createSession(Map<String, dynamic> sessionData) async {
    await _db.collection('sessions').add(sessionData);
  }

  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final snap = await _db
        .collection('sessions')
        .where('sessionId', isEqualTo: sessionId)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  Stream<List<Map<String, dynamic>>> getAllSessions() {
    return _db
        .collection('sessions')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Future<void> deleteSession(String id) async {
    await _db.collection('sessions').doc(id).delete();
  }
}