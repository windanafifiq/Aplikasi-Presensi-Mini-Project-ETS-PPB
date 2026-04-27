import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import '../../services/local_database_service.dart';


class ScanScreen extends StatefulWidget {
  final UserModel userModel;
  const ScanScreen({super.key, required this.userModel});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  final _notificationService = NotificationService();
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isProcessing = false;
  String _statusMessage = 'Arahkan kamera ke QR Code sesi';

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    setState(() { _isProcessing = true; _statusMessage = 'Memproses...'; });
    _scannerController.stop();
    await _processAttendance(barcode!.rawValue!);
  }

  void _showManualInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Input Session ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session ID',
            hintText: 'Contoh: sesi-001',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                setState(() { _isProcessing = true; _statusMessage = 'Memproses...'; });
                _scannerController.stop();
                _processAttendance(controller.text.trim());
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _processAttendance(String sessionId) async {
    try {
      final session = await _firestoreService.getSession(sessionId);
      if (session == null) { _showResult(false, 'Sesi tidak ditemukan'); return; }

      final now = DateTime.now();
      final startTime = (session['startTime'] as dynamic).toDate() as DateTime;
      final endTime = (session['endTime'] as dynamic).toDate() as DateTime;
      if (now.isBefore(startTime) || now.isAfter(endTime)) {
        _showResult(false, 'Di luar jam presensi\n${_fmt(startTime)} - ${_fmt(endTime)}');
        return;
      }

      final position = await _locationService.getCurrentPosition();
      if (position == null) { _showResult(false, 'Tidak dapat mengakses GPS'); return; }
      if (!_locationService.isWithinCampus(position.latitude, position.longitude)) {
        final dist = _locationService.getDistance(position.latitude, position.longitude);
        await _notificationService.showLocationError();
        _showResult(false, 'Di luar radius kampus\n${dist.toStringAsFixed(0)}m dari gedung TI');
        return;
      }

      final alreadyAttended = await _firestoreService.hasAttendedSession(
          widget.userModel.uid, sessionId);
      if (alreadyAttended) { _showResult(false, 'Kamu sudah check in di sesi ini'); return; }

      final attendance = AttendanceModel(
        id: '',
        userId: widget.userModel.uid,
        userName: widget.userModel.name,
        nrp: widget.userModel.nrp,
        sessionId: sessionId,
        checkInTime: now,
        latitude: position.latitude,
        longitude: position.longitude,
        status: 'checked_in',
      );

      // Simpan ke Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('attendance')
          .add(attendance.toMap());

      // Pastikan user ada di SQLite dulu
      await LocalDatabaseService().insertUser({
        'uid': widget.userModel.uid,
        'name': widget.userModel.name,
        'nrp': widget.userModel.nrp,
        'department': widget.userModel.department,
        'role': widget.userModel.role,
        'createdAt': DateTime.now().toString(),
      });

      // Pastikan session ada di SQLite dulu
      await LocalDatabaseService().insertSession({
        'sessionId': sessionId,
        'startTime': startTime,
        'endTime': endTime,
        'createdAt': DateTime.now(),
      });

      // Baru insert attendance ke SQLite
      await LocalDatabaseService().insertAttendance({
        'attendanceId': docRef.id,
        'userId': widget.userModel.uid,
        'userName': widget.userModel.name,
        'nrp': widget.userModel.nrp,
        'sessionId': sessionId,
        'checkInTime': attendance.checkInTime.toString(),
        'checkOutTime': null,
        'status': attendance.status,
      });

      await _notificationService.showAttendanceSuccess(
          widget.userModel.name, sessionId);
      _showResult(true, 'Check in berhasil!\nSesi: $sessionId');
    } catch (e) {
      _showResult(false, 'Error: $e');
    }
  }

  void _showResult(bool success, String message) {
    if (!mounted) return;
    setState(() => _statusMessage = message);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red),
          const Gap(8),
          Text(success ? 'Check In Berhasil!' : 'Gagal'),
        ]),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (success) {
                Navigator.pop(context);
              } else { setState(() => _isProcessing = false); _scannerController.start(); }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() { _scannerController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Presensi'),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on_outlined), onPressed: () => _scannerController.toggleTorch()),
          IconButton(icon: const Icon(Icons.keyboard_outlined), onPressed: _showManualInputDialog),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 65,
            child: MobileScanner(controller: _scannerController, onDetect: _onDetect),
          ),
          Expanded(
            flex: 35,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isProcessing ? Colors.orange.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isProcessing ? Icons.hourglass_top_rounded : Icons.qr_code_2_rounded,
                      size: 32,
                      color: _isProcessing ? Colors.orange : color,
                    ),
                  ),
                  const Gap(10),
                  Text(_statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  const Gap(10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.keyboard_outlined, size: 16),
                    label: const Text('Input Manual', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _showManualInputDialog,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}