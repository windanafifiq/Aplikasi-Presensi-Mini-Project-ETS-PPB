import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance_app.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('PRAGMA foreign_keys = ON');

        // Tabel users
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uid TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            nrp TEXT NOT NULL,
            department TEXT NOT NULL,
            role TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');

        // Tabel sessions
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sessionId TEXT NOT NULL UNIQUE,
            startTime TEXT NOT NULL,
            endTime TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');

        // Tabel attendance_cache — FK ke users DAN sessions
        await db.execute('''
          CREATE TABLE attendance_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            attendanceId TEXT NOT NULL UNIQUE,
            userId TEXT NOT NULL,
            userName TEXT NOT NULL,
            nrp TEXT NOT NULL,
            sessionId TEXT NOT NULL,
            checkInTime TEXT NOT NULL,
            checkOutTime TEXT,
            status TEXT NOT NULL,
            FOREIGN KEY (userId) REFERENCES users (uid)
              ON DELETE CASCADE,
            FOREIGN KEY (sessionId) REFERENCES sessions (sessionId)
              ON DELETE CASCADE
          )
        ''');
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // =====================
  // CRUD USERS
  // =====================

  Future<void> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert(
      'users',
      user,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users');
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'users',
      data,
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<void> deleteUser(String uid) async {
    final db = await database;
    await db.delete(
      'users',
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  // =====================
  // CRUD SESSIONS
  // =====================

  Future<void> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    await db.insert(
      'sessions',
      {
        'sessionId': session['sessionId'],
        'startTime': session['startTime'].toString(),
        'endTime': session['endTime'].toString(),
        'createdAt': DateTime.now().toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final db = await database;
    return await db.query('sessions', orderBy: 'createdAt DESC');
  }

  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final db = await database;
    final result = await db.query(
      'sessions',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
    if (result.isEmpty) return null;
    return result.first;
  }

  Future<void> updateSession(String sessionId, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'sessions',
      data,
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete(
      'sessions',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  // =====================
  // CRUD ATTENDANCE CACHE
  // =====================

  Future<void> insertAttendance(Map<String, dynamic> attendance) async {
    final db = await database;
    await db.insert(
      'attendance_cache',
      attendance,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAttendanceByUser(String userId) async {
    final db = await database;
    return await db.query(
      'attendance_cache',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'checkInTime DESC',
    );
  }

  // JOIN attendance + sessions
  Future<List<Map<String, dynamic>>> getAttendanceWithSession(
      String sessionId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        ac.*,
        s.startTime as sessionStart,
        s.endTime as sessionEnd
      FROM attendance_cache ac
      INNER JOIN sessions s ON ac.sessionId = s.sessionId
      WHERE ac.sessionId = ?
      ORDER BY ac.checkInTime ASC
    ''', [sessionId]);
  }

  // JOIN 3 tabel: attendance + users + sessions
  Future<List<Map<String, dynamic>>> getFullAttendanceReport(
      String sessionId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        ac.attendanceId,
        ac.checkInTime,
        ac.checkOutTime,
        ac.status,
        u.name as mahasiswaName,
        u.nrp as mahasiswaNrp,
        u.department,
        s.sessionId,
        s.startTime as sessionStart,
        s.endTime as sessionEnd
      FROM attendance_cache ac
      INNER JOIN users u ON ac.userId = u.uid
      INNER JOIN sessions s ON ac.sessionId = s.sessionId
      WHERE ac.sessionId = ?
      ORDER BY ac.checkInTime ASC
    ''', [sessionId]);
  }

  Future<void> updateCheckout(String attendanceId, String checkOutTime,
      String status) async {
    final db = await database;
    await db.update(
      'attendance_cache',
      {'checkOutTime': checkOutTime, 'status': status},
      where: 'attendanceId = ?',
      whereArgs: [attendanceId],
    );
  }

  Future<void> deleteAttendance(String attendanceId) async {
    final db = await database;
    await db.delete(
      'attendance_cache',
      where: 'attendanceId = ?',
      whereArgs: [attendanceId],
    );
  }

  // =====================
  // SYNC HELPERS
  // =====================

  Future<void> syncSessions(List<Map<String, dynamic>> firestoreSessions) async {
    for (final session in firestoreSessions) {
      await insertSession(session);
    }
  }

  Future<void> closeDB() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}