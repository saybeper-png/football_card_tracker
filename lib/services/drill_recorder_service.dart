import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DrillRecorderService {
  static final ImagePicker _picker = ImagePicker();

  /// Запись видео норматива и загрузка в Supabase
  static Future<void> recordAndSubmitDrill({
    required BuildContext context,
    required String drillId,
    required String drillTitle,
    required List<String> techniqueRules,
    required List<String> commonMistakes,
  }) async {
    try {
      // 1. Открываем нативную камеру телефона (iOS Safari / Android Chrome)
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15),
        preferredCameraDevice: CameraDevice.rear,
      );

      if (video == null) return; // Съемка отменена

      if (!context.mounted) return;

      // 2. Индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFCCFF00), width: 1.5),
          ),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFCCFF00)),
                SizedBox(height: 16),
                Text(
                  'ОБРАБОТКА НОРМАТИВА',
                  style: TextStyle(
                    color: Color(0xFFCCFF00),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Загружаем видео и сверяем технику...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );

      // 3. Читаем байты
      final bytes = await video.readAsBytes();
      final ext = video.name.contains('.') ? video.name.split('.').last : 'mp4';
      final fileName = 'sub_${drillId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = 'submissions/$fileName';

      // 4. Отправляем в Supabase Storage (бакет drills)
      final supabase = Supabase.instance.client;
      await supabase.storage.from('drills').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: video.mimeType ?? 'video/mp4',
          upsert: true,
        ),
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Закрываем диалог

      // 5. Показываем результат
      _showSuccessDialog(context, drillTitle);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Ошибка загрузки видео: $e'),
        ),
      );
    }
  }

  static void _showSuccessDialog(BuildContext context, String drillTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFCCFF00), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFFCCFF00)),
            SizedBox(width: 8),
            Text('Видео принято!', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Норматив "$drillTitle" успешно сохранен в облаке и отправлен на разбор техники.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCCFF00),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ОТЛИЧНО', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
