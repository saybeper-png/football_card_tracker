// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

@immutable
class PhotoCropMeta {
  final double scale;
  final double dx;
  final double dy;

  const PhotoCropMeta({this.scale = 1.0, this.dx = 0.0, this.dy = 0.0});

  factory PhotoCropMeta.fromMatrix4(Matrix4 matrix) {
    final translation = matrix.getTranslation();
    final scale = matrix.getMaxScaleOnAxis();
    return PhotoCropMeta(scale: scale, dx: translation.x, dy: translation.y);
  }

  Matrix4 toMatrix4() => Matrix4.identity()..translate(dx, dy)..scale(scale, scale, 1.0);

  factory PhotoCropMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const PhotoCropMeta();
    return PhotoCropMeta(
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      dx: (json['dx'] as num?)?.toDouble() ?? 0.0,
      dy: (json['dy'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'scale': scale, 'dx': dx, 'dy': dy};
}
