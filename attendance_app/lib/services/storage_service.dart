import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class StorageService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImageFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  Future<File?> pickImageFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  // Compress + convert ke Base64
  Future<String?> fileToBase64(File file) async {
    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 256,
        minHeight: 256,
        quality: 60,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) return null;
      return base64Encode(compressed);
    } catch (e) {
      return null;
    }
  }
}