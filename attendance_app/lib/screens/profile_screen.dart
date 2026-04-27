import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? user;
  const ProfileScreen({super.key, this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _nrpController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  File? _selectedImage;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user?.name ?? '';
    _nrpController.text = widget.user?.nrp ?? '';
    _currentPhotoUrl = widget.user?.photoUrl;
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Ganti Foto Profil',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Gap(16),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.camera_alt)),
                title: const Text('Ambil dari Kamera'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUpload(fromCamera: true);
                },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.photo_library)),
                title: const Text('Pilih dari Galeri'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUpload(fromCamera: false);
                },
              ),
              if (_currentPhotoUrl != null)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  title: const Text('Hapus Foto', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deletePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload({required bool fromCamera}) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    final file = fromCamera
        ? await _storageService.pickImageFromCamera()
        : await _storageService.pickImageFromGallery();
    if (file == null) return;

    setState(() { _isUploadingPhoto = true; _selectedImage = file; });

    try {
      final base64Str = await _storageService.fileToBase64(file);
      if (base64Str != null) {
        await _firestoreService.updateProfilePhoto(uid, base64Str);
        setState(() => _currentPhotoUrl = base64Str);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal upload foto: $e'), backgroundColor: Colors.red),
      );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      await _firestoreService.updateProfilePhoto(uid, '');
      setState(() { _currentPhotoUrl = null; _selectedImage = null; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil dihapus'), backgroundColor: Colors.orange),
      );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      await _firestoreService.updateUser(uid, {
        'name': _nameController.text.trim(),
        'nrp': _nrpController.text.trim(),
      });
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui'), backgroundColor: Colors.green),
      );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
      );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildAvatar(Color color) {
    final size = 96.0;

    ImageProvider? imageProvider;
    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(_currentPhotoUrl!));
      } catch (_) {}
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: color.withValues(alpha: 0.1),
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Text(
                  (widget.user?.name.isNotEmpty == true)
                      ? widget.user!.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontSize: 40, color: color, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        if (_isUploadingPhoto)
          Positioned.fill(
            child: CircleAvatar(
              radius: size / 2,
              backgroundColor: Colors.black38,
              child: const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
          ),
        Positioned(
          bottom: 0, right: 0,
          child: GestureDetector(
            onTap: _isUploadingPhoto ? null : _showPhotoOptions,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildAvatar(color),
            const Gap(16),
            Text(widget.user?.name ?? '-',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(widget.user?.department ?? 'Teknik Informatika',
                style: TextStyle(color: Colors.grey[600])),
            const Gap(32),
            if (_isEditing) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Gap(16),
              TextField(
                controller: _nrpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'NRP',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Simpan Perubahan'),
                ),
              ),
            ] else ...[
              _infoTile(Icons.badge_outlined, 'NRP', widget.user?.nrp ?? '-'),
              _infoTile(Icons.school_outlined, 'Departemen', widget.user?.department ?? 'Teknik Informatika'),
              _infoTile(Icons.email_outlined, 'Email', _authService.currentUser?.email ?? '-'),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async => await _authService.logout(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const Gap(12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}