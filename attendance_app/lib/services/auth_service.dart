import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kredensial admin yang sudah ditentukan
  static const String adminEmail = 'admin@ti.its.ac.id';
  static const String adminPassword = 'admin123';

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Seed admin account — dipanggil saat app start
  Future<void> seedAdminIfNotExists() async {
    try {
      // Coba login sebagai admin
      await _auth.signInWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );
      // Kalau berhasil, admin sudah ada, logout lagi
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        // Admin belum ada, buat baru
        try {
          final credential = await _auth.createUserWithEmailAndPassword(
            email: adminEmail,
            password: adminPassword,
          );
          await _firestore.collection('users').doc(credential.user!.uid).set({
            'name': 'Admin TI ITS',
            'nrp': '000000000',
            'department': 'Teknik Informatika',
            'role': 'admin',
            'createdAt': DateTime.now(),
          });
          await _auth.signOut();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<UserModel?> register({
    required String email,
    required String password,
    required String name,
    required String nrp,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = UserModel(
      uid: credential.user!.uid,
      name: name,
      nrp: nrp,
      department: 'Teknik Informatika',
      role: 'mahasiswa',
      createdAt: DateTime.now(),
    );
    await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .set(user.toMap());
    return user;
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async => await _auth.signOut();

  Future<UserModel?> getCurrentUserData() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, uid);
  }
}