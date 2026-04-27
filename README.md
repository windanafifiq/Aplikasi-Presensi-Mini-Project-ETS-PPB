# Aplikasi Presensi — Smart Classroom Attendance

**Nama:** Winda Nafiqih Irawan  
**NRP:** 5025231065  
**Kelas:** PPB-E  
**Project:** Aplikasi-Presensi  
**Link Demo Aplikasi + Penjelasan:** [https://youtu.be/ruijNY2A_-c](https://youtu.be/ruijNY2A_-c)  

---

## Deskripsi

Aplikasi presensi mahasiswa berbasis Flutter untuk jurusan Teknik Informatika ITS. Mahasiswa melakukan check in dengan scan QR Code yang divalidasi menggunakan GPS (radius kampus) dan waktu sesi. Admin dapat membuat sesi, melihat data presensi, dan melakukan auto checkout.

---

## Fitur Utama

- **Firebase Authentication** — Login & Register dengan role admin/mahasiswa
- **CRUD Relational Database (SQLite)** — 3 tabel saling berelasi: `users`, `sessions`, `attendance_cache` dengan primary key, foreign key, dan JOIN query
- **Storing Data Firebase (Firestore)** — Semua data disync ke cloud Firestore
- **QR Code Scanner** — Check in dengan scan QR menggunakan kamera HP
- **Validasi GPS** — Presensi hanya bisa dilakukan dalam radius 300m dari gedung TI ITS
- **Notifikasi** — Local notification saat check in berhasil/gagal
- **Check In & Check Out** — Dengan mekanisme auto checkout saat sesi berakhir
- **Foto Profil** — Upload foto profil menggunakan kamera atau galeri (disimpan sebagai Base64 di Firestore)

---

## Teknologi

- Flutter (Dart)
- Firebase Authentication
- Cloud Firestore
- SQLite (sqflite) — Relational Database lokal
- Geolocator
- Mobile Scanner
- Flutter Local Notifications
- Image Picker + Flutter Image Compress

---

## Struktur Project

```
lib/
├── main.dart                        # Entry point, inisialisasi Firebase & SQLite, routing role
├── firebase_options.dart            # Konfigurasi Firebase (auto-generated)
├── models/
│   ├── user_model.dart              # Model data user (nama, NRP, role, foto)
│   └── attendance_model.dart        # Model data presensi (checkIn, checkOut, status)
├── services/
│   ├── auth_service.dart            # Firebase Auth + seed admin + sync SQLite
│   ├── firestore_service.dart       # CRUD Firestore (user, sesi, presensi) + sync SQLite
│   ├── local_database_service.dart  # CRUD SQLite — relational database (3 tabel + FK + JOIN)
│   ├── location_service.dart        # Validasi GPS radius kampus
│   ├── notification_service.dart    # Local notification
│   └── storage_service.dart         # Kompresi & konversi foto ke Base64
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart        # Halaman login
│   │   └── register_screen.dart     # Halaman register mahasiswa
│   ├── admin/
│   │   └── admin_screen.dart        # Panel admin (buat sesi, lihat presensi)
│   ├── attendance/
│   │   ├── scan_screen.dart         # Scan QR + flow presensi lengkap + sync SQLite
│   │   └── history_screen.dart      # Riwayat presensi mahasiswa
│   ├── home_screen.dart             # Dashboard mahasiswa + checkout
│   └── profile_screen.dart          # Profil + edit data + foto
```

---

## Setup & Instalasi

### Prasyarat

- Flutter SDK (>= 3.0)
- Android Studio / VS Code
- Akun Firebase
- Android device / emulator (API 21+)

### 1. Clone Repository

```bash
git clone https://github.com/username/Aplikasi-Presensi-Mini-Project-ETS-PPB.git
cd Aplikasi-Presensi-Mini-Project-ETS-PPB/attendance_app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Setup Firebase

1. Buka [Firebase Console](https://console.firebase.google.com)
2. Buat project baru
3. Aktifkan **Authentication** → Sign-in method → **Email/Password**
4. Aktifkan **Firestore Database** → Start in test mode → region `asia-southeast2`
5. Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```
6. Jalankan konfigurasi:
```bash
flutterfire configure
```
Ini akan membuat file `lib/firebase_options.dart` secara otomatis.

### 4. Firestore Composite Index

Buat composite index berikut di Firebase Console → Firestore → Indexes:

| Collection | Field 1 | Field 2 | Field 3 |
|---|---|---|---|
| attendance | sessionId ↑ | checkInTime ↑ | — |
| attendance | userId ↑ | checkInTime ↓ | — |
| attendance | userId ↑ | sessionId ↑ | status ↑ |
| sessions | startTime ↓ | — | — |

### 5. Jalankan Aplikasi

```bash
flutter run
```

---

## Akun Default

Akun admin di-seed otomatis saat pertama kali app dijalankan:

| Role | Email | Password |
|---|---|---|
| Admin | admin@ti.its.ac.id | admin123 |
| Mahasiswa | Daftar via Register | — |

---

## Penjelasan Kode Penting

### 1. Auto Seed Admin (`auth_service.dart`)
Saat app start, sistem otomatis membuat akun admin jika belum ada tanpa perlu mendaftar manual.

```dart
Future<void> seedAdminIfNotExists() async {
  try {
    await _auth.signInWithEmailAndPassword(
      email: adminEmail, password: adminPassword);
    await _auth.signOut();
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: adminEmail, password: adminPassword);
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'role': 'admin', ...
      });
      await _auth.signOut();
    }
  }
}
```

### 2. Role-based Routing (`main.dart`)
Setelah login, app otomatis mengarahkan ke halaman admin atau mahasiswa berdasarkan field `role` di Firestore.

```dart
if (user.isAdmin) return const AdminScreen();
return HomeScreen(userModel: user);
```

### 3. Relational Database — SQLite (`local_database_service.dart`)
Tiga tabel saling berelasi menggunakan primary key dan foreign key. Tabel `attendance_cache` memiliki dua foreign key ke `users` dan `sessions` dengan CASCADE delete.

```sql
CREATE TABLE attendance_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  attendanceId TEXT NOT NULL UNIQUE,
  userId TEXT NOT NULL,
  sessionId TEXT NOT NULL,
  ...
  FOREIGN KEY (userId) REFERENCES users (uid) ON DELETE CASCADE,
  FOREIGN KEY (sessionId) REFERENCES sessions (sessionId) ON DELETE CASCADE
)
```

JOIN 3 tabel untuk laporan presensi lengkap:

```sql
SELECT ac.*, u.name, u.nrp, s.startTime, s.endTime
FROM attendance_cache ac
INNER JOIN users u ON ac.userId = u.uid
INNER JOIN sessions s ON ac.sessionId = s.sessionId
WHERE ac.sessionId = ?
```

### 4. Validasi GPS (`location_service.dart`)
Presensi hanya bisa dilakukan dalam radius 300 meter dari koordinat gedung Teknik Informatika ITS.

```dart
static const double itLatitude = -7.282540;
static const double itLongitude = 112.794680;
static const double allowedRadiusMeters = 300;

bool isWithinCampus(double lat, double lng) {
  final distance = Geolocator.distanceBetween(
    itLatitude, itLongitude, lat, lng,
  );
  return distance <= allowedRadiusMeters;
}
```

### 5. Flow Presensi (`scan_screen.dart`)
5 validasi berjalan berurutan saat QR di-scan. Jika salah satu gagal, proses berhenti dan menampilkan pesan error.

```dart
// 1. Cek sesi valid
final session = await _firestoreService.getSession(sessionId);

// 2. Cek waktu dalam rentang sesi
if (now.isBefore(startTime) || now.isAfter(endTime)) { ... }

// 3. Cek GPS dalam radius kampus
if (!_locationService.isWithinCampus(lat, lng)) { ... }

// 4. Cek sudah pernah check in
final alreadyAttended = await _firestoreService.hasAttendedSession(...);

// 5. Simpan ke Firestore + SQLite + kirim notifikasi
await FirebaseFirestore.instance.collection('attendance').add(...);
await LocalDatabaseService().insertAttendance(...);
await _notificationService.showAttendanceSuccess(...);
```

### 6. Check Out & Auto Checkout (`firestore_service.dart`)
Manual checkout menghasilkan status `completed`. Jika lupa checkout, admin bisa trigger auto checkout yang menggunakan waktu `endTime` sesi.

```dart
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
```

### 7. Foto Profil Base64 (`storage_service.dart`)
Solusi tanpa Firebase Storage — foto dikompresi lalu dikonversi ke Base64 dan disimpan langsung di Firestore.

```dart
Future<String?> fileToBase64(File file) async {
  final compressed = await FlutterImageCompress.compressWithFile(
    file.absolute.path,
    minWidth: 256, minHeight: 256, quality: 60,
  );
  return base64Encode(compressed!);
}
```

---

## Arsitektur Data

### SQLite — Relational Database Lokal

```
users                        sessions
─────────────────────        ─────────────────────
id (PK)                      id (PK)
uid (UNIQUE)    ◄──┐         sessionId (UNIQUE) ◄──┐
name               │         startTime              │
nrp                │         endTime                │
department         │         createdAt              │
role               │                                │
createdAt          │                                │
                   │                                │
                   └──────────────┐  ───────────────┘
                                  ▼
                         attendance_cache
                         ──────────────────────────
                         id (PK)
                         attendanceId (UNIQUE)
                         userId (FK → users.uid)
                         sessionId (FK → sessions.sessionId)
                         userName
                         nrp
                         checkInTime
                         checkOutTime
                         status
```

### Firestore — Cloud Storage

```
firestore/
├── users/{uid}
│   ├── name, nrp, department, role
│   ├── photoUrl (Base64)
│   └── createdAt
├── sessions/{docId}
│   ├── sessionId, startTime, endTime
│   └── createdAt
└── attendance/{docId}
    ├── userId, userName, nrp, sessionId
    ├── checkInTime, checkOutTime
    ├── latitude, longitude
    └── status: "checked_in" / "completed" / "auto_checkout"
```

---

## Kriteria ETS

| Kriteria | Implementasi |
|---|---|
| CRUD + Relational Database | SQLite dengan 3 tabel (users, sessions, attendance_cache), primary key, foreign key, CASCADE delete, dan INNER JOIN 3 tabel |
| Firebase Authentication | Login, Register, Logout dengan role admin/mahasiswa, auto-seed admin |
| Storing Data in Firebase | Semua data tersimpan dan disync di Cloud Firestore |
| Notifications | Local notification saat check in berhasil & gagal lokasi |
| Smartphone Resource | Kamera (QR Scanner) + GPS (validasi radius 300m kampus TI ITS) |