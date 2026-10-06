import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class GallerySaverService {
  static Future<bool> saveImageToGallery({required Uint8List bytes, required String fileName}) async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      final s = await Permission.photosAddOnly.request();
      if (!s.isGranted && !s.isLimited) return false;
    }
    final result = await ImageGallerySaverPlus.saveImage(bytes, quality: 100, name: fileName, isReturnImagePathOfIOS: true);
    return result is Map && result['isSuccess'] == true;
  }
}