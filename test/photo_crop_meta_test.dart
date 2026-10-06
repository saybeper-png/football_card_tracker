// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_card_tracker/models/photo_crop_meta.dart';

void main() {
  test('Сериализация Matrix4 в JSON и обратное восстановление', () {
    final matrix = Matrix4.identity()..translate(20.0, -10.0)..scale(1.8, 1.8, 1.0);
    final meta = PhotoCropMeta.fromMatrix4(matrix);
    final json = meta.toJson();

    expect(json['scale'], closeTo(1.8, 0.0001));
    expect(json['dx'], closeTo(20.0, 0.0001));
    expect(json['dy'], closeTo(-10.0, 0.0001));

    final restoredMeta = PhotoCropMeta.fromJson(json);
    expect(restoredMeta.scale, closeTo(1.8, 0.0001));
  });
}
