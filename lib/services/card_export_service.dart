import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CardExportService {
  static Future<void> captureAndShareCard({
    required GlobalKey boundaryKey,
    required String playerName,
    String? customMessage,
  }) async {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('RepaintBoundary context not found');

    await Future.delayed(const Duration(milliseconds: 60));
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Image encoding error');

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/card_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')],
      text: customMessage ?? 'Карточка игрока $playerName! ⚽🔥',
    ));
  }
}
