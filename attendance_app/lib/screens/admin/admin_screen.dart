import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _sessionIdController = TextEditingController();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute);
  String? _generatedSessionId;
  bool _isLoading = false;
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sessionIdController.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    if (_sessionIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session ID tidak boleh kosong'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, _startTime.hour, _startTime.minute);
      final end = DateTime(now.year, now.month, now.day, _endTime.hour, _endTime.minute);
      await _firestoreService.createSession({
        'sessionId': _sessionIdController.text.trim(),
        'startTime': start,
        'endTime': end,
        'createdAt': now,
      });
      setState(() => _generatedSessionId = _sessionIdController.text.trim());
      _sessionIdController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _autoCheckoutAll(String sessionId) async {
    final snap = await _firestoreService.getAllSessions().first;
    final session = snap.firstWhere((s) => s['sessionId'] == sessionId, orElse: () => {});
    if (session.isEmpty) return;
    final endTime = (session['endTime'] as dynamic).toDate() as DateTime;
    final checkedIn = await _firestoreService.getCheckedInAttendances(sessionId);
    for (final a in checkedIn) {
      await _firestoreService.autoCheckout(a.id, endTime);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto checkout ${checkedIn.length} mahasiswa'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked != null) {
      setState(() { if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      } });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await _authService.logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'Buat Sesi'),
            Tab(icon: Icon(Icons.people), text: 'Data Presensi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCreateSession(), _buildAttendanceData()],
      ),
    );
  }

  Widget _buildCreateSession() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Buat Sesi Presensi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Gap(20),
          TextField(
            controller: _sessionIdController,
            decoration: InputDecoration(
              labelText: 'Session ID',
              hintText: 'Contoh: alpro-2024-001',
              prefixIcon: const Icon(Icons.key_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Gap(16),
          Row(children: [
            Expanded(child: _timeTile('Mulai', _startTime, () => _pickTime(true))),
            const Gap(12),
            Expanded(child: _timeTile('Selesai', _endTime, () => _pickTime(false))),
          ]),
          const Gap(20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Buat Sesi & Generate QR'),
              onPressed: _isLoading ? null : _createSession,
            ),
          ),

          if (_generatedSessionId != null) ...[
            const Gap(32),
            const Divider(),
            const Gap(16),
            Center(
              child: Column(
                children: [
                  Text('QR Sesi: $_generatedSessionId',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Gap(4),
                  Text('${_startTime.format(context)} - ${_endTime.format(context)}',
                      style: TextStyle(color: Colors.grey[600])),
                  const Gap(16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: QrImageView(data: _generatedSessionId!, version: QrVersions.auto, size: 220),
                  ),
                  const Gap(8),
                  Text('Tunjukkan QR ini ke mahasiswa',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
          ],

          const Gap(32),
          Text('Semua Sesi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Gap(12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestoreService.getAllSessions(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final sessions = snapshot.data!;
              if (sessions.isEmpty) return Text('Belum ada sesi', style: TextStyle(color: Colors.grey[500]));
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const Gap(8),
                itemBuilder: (context, i) {
                  final s = sessions[i];
                  final start = (s['startTime'] as dynamic).toDate() as DateTime;
                  final end = (s['endTime'] as dynamic).toDate() as DateTime;
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.qr_code),
                      title: Text(s['sessionId'] ?? '-', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${_fmtTime(start)} - ${_fmtTime(end)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code_2, color: Colors.blue),
                            onPressed: () => setState(() => _generatedSessionId = s['sessionId']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async => await _firestoreService.deleteSession(s['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceData() {
    return Column(
      children: [
        // Pilih sesi
        Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestoreService.getAllSessions(),
            builder: (context, snapshot) {
              final sessions = snapshot.data ?? [];
              return DropdownButtonFormField<String>(
                initialValue: _selectedSessionId,
                decoration: InputDecoration(
                  labelText: 'Pilih Sesi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.list_alt),
                ),
                items: sessions.map((s) => DropdownMenuItem(
                  value: s['sessionId'] as String,
                  child: Text(s['sessionId'] as String),
                )).toList(),
                onChanged: (val) => setState(() => _selectedSessionId = val),
              );
            },
          ),
        ),

        if (_selectedSessionId != null) ...[
          // Auto checkout button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.timer_off_outlined),
                label: const Text('Auto Checkout Semua'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                onPressed: () => _autoCheckoutAll(_selectedSessionId!),
              ),
            ),
          ),
          const Gap(8),

          // Tabel presensi
          Expanded(
            child: StreamBuilder<List<AttendanceModel>>(
              stream: _firestoreService.getAttendanceBySession(_selectedSessionId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) {
                  return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                      const Gap(8),
                      Text('Belum ada presensi', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Gap(8),
                  itemBuilder: (context, i) {
                    final a = list[i];
                    final statusColor = a.status == 'completed'
                        ? Colors.green
                        : a.status == 'auto_checkout'
                            ? Colors.orange
                            : Colors.blue;
                    final statusLabel = a.status == 'completed'
                        ? 'Completed'
                        : a.status == 'auto_checkout'
                            ? 'Auto CO'
                            : 'Check In';

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Foto profil mahasiswa
                            FutureBuilder<UserModel?>(
                              future: FirestoreService().getUser(a.userId),
                              builder: (context, userSnap) {
                                final photoData = userSnap.data?.photoUrl;
                                ImageProvider? imageProvider;
                                if (photoData != null && photoData.isNotEmpty) {
                                  try {
                                    imageProvider = MemoryImage(base64Decode(photoData));
                                  } catch (_) {}
                                }
                                return CircleAvatar(
                                  radius: 24,
                                  backgroundColor: statusColor.withValues(alpha: 0.1),
                                  backgroundImage: imageProvider,
                                  child: imageProvider == null
                                      ? Text(
                                          a.userName.isNotEmpty ? a.userName[0].toUpperCase() : '?',
                                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                );
                              },
                            ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(a.nrp, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  Text('CI: ${_fmtFull(a.checkInTime)}', style: const TextStyle(fontSize: 11)),
                                  if (a.checkOutTime != null)
                                    Text('CO: ${_fmtFull(a.checkOutTime!)}', style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(statusLabel,
                                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ] else
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined, size: 48, color: Colors.grey[400]),
                  const Gap(8),
                  Text('Pilih sesi untuk melihat data', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const Gap(4),
            Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtFull(DateTime dt) =>
      '${dt.day}/${dt.month} ${_fmtTime(dt)}';
}