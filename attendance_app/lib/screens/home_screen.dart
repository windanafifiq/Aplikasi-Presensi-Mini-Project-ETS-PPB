import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import 'attendance/scan_screen.dart';
import 'attendance/history_screen.dart';
import 'profile_screen.dart';
import '../services/local_database_service.dart';

class HomeScreen extends StatefulWidget {
  final UserModel userModel;
  const HomeScreen({super.key, required this.userModel});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  int _currentIndex = 0;
  AttendanceModel? _activeAttendance;

  @override
  void initState() {
    super.initState();
    _syncAndLoad();
  }

  Future<void> _syncAndLoad() async {
    // Sync sesi dari Firestore ke SQLite
    final sessions = await _firestoreService.getAllSessions().first;
    await LocalDatabaseService().syncSessions(sessions);
    // Cek active attendance
    await _checkActiveAttendance();
  }

  Future<void> _checkActiveAttendance() async {
    // Cek semua sesi aktif saat ini
    final sessions = await _firestoreService.getAllSessions().first;
    final now = DateTime.now();
    for (final session in sessions) {
      final start = (session['startTime'] as dynamic).toDate() as DateTime;
      final end = (session['endTime'] as dynamic).toDate() as DateTime;
      if (now.isAfter(start) && now.isBefore(end)) {
        final active = await _firestoreService.getActiveAttendance(
            widget.userModel.uid, session['sessionId']);
        if (active != null) {
          setState(() {
            _activeAttendance = active;
          });
          return;
        }
      }
    }
  }

  Future<void> _checkout() async {
    if (_activeAttendance == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Check Out'),
        content: Text('Check out dari sesi ${_activeAttendance!.sessionId}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _firestoreService.checkOut(_activeAttendance!.id);
              setState(() {
                _activeAttendance = null;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Check out berhasil!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Check Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboard(),
      const HistoryScreen(),
      ProfileScreen(user: widget.userModel),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final color = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Halo, ${widget.userModel.name.split(' ').first}! 👋',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text('NRP: ${widget.userModel.nrp}',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async => await _authService.logout(),
                ),
              ],
            ),
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('📚 Teknik Informatika ITS',
                  style: TextStyle(color: color, fontWeight: FontWeight.w500)),
            ),
            const Gap(24),

            // Active attendance banner
            if (_activeAttendance != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const Gap(8),
                        Text('Sedang Check In',
                            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Gap(4),
                    Text('Sesi: ${_activeAttendance!.sessionId}',
                        style: TextStyle(color: Colors.green.shade600)),
                    const Gap(12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Check Out Sekarang'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: _checkout,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24),
            ],

            // Scan Button
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => ScanScreen(userModel: widget.userModel)));
                _checkActiveAttendance(); // refresh setelah scan
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 64, color: Colors.white),
                    const Gap(12),
                    const Text('Scan Presensi', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Gap(4),
                    Text('Tap untuk scan QR Code', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ),
            const Gap(24),

            // Info Cards
            Row(
              children: [
                Expanded(child: _infoCard(Icons.location_on_outlined, 'Lokasi', 'Gedung TI ITS', Colors.orange)),
                const Gap(12),
                Expanded(child: _infoCard(Icons.school_outlined, 'Dept', 'Teknik Informatika', Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Gap(8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}