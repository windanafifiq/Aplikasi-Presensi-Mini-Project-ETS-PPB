import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/attendance_model.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final uid = authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Presensi')),
      body: StreamBuilder<List<AttendanceModel>>(
        stream: firestoreService.getAttendanceByUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const Gap(12),
                  Text('Belum ada riwayat presensi',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Gap(8),
            itemBuilder: (context, i) {
              final item = list[i];
              final statusColor = item.status == 'completed'
                  ? Colors.green
                  : item.status == 'auto_checkout'
                      ? Colors.orange
                      : Colors.blue;
              final statusLabel = item.status == 'completed'
                  ? 'Completed'
                  : item.status == 'auto_checkout'
                      ? 'Auto Checkout'
                      : 'Check In';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.1),
                        child: Icon(
                          item.status == 'completed' ? Icons.check_circle
                              : item.status == 'auto_checkout' ? Icons.timer_off
                              : Icons.login,
                          color: statusColor,
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sesi: ${item.sessionId}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Gap(2),
                            Row(children: [
                              const Icon(Icons.login, size: 12, color: Colors.grey),
                              const Gap(4),
                              Text('CI: ${_formatDate(item.checkInTime)}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ]),
                            if (item.checkOutTime != null)
                              Row(children: [
                                const Icon(Icons.logout, size: 12, color: Colors.grey),
                                const Gap(4),
                                Text('CO: ${_formatDate(item.checkOutTime!)}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ]),
                            Row(children: [
                              const Icon(Icons.location_on, size: 12, color: Colors.grey),
                              const Gap(4),
                              Text(
                                '${item.latitude.toStringAsFixed(4)}, ${item.longitude.toStringAsFixed(4)}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              ),
                            ]),
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
                            style: TextStyle(
                                color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${dt.day} ${months[dt.month - 1]}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}