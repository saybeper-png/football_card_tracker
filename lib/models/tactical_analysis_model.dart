import 'package:flutter/material.dart';

/// Инструменты рисования тренера поверх видеокадра
enum TelestrationTool {
  arrow,      // Стрелка вектора атаки / направления передачи
  spotlight,  // Подсветка игрока прожектором с затемнением фона
  circle,     // Зона опеки / свободное пространство
  freehand,   // Произвольная линия от руки
}

/// Графический элемент телестрации
/// Координаты точек (x, y) нормализованы от 0.0 до 1.0
class TelestrationElement {
  final TelestrationTool tool;
  final List<Offset> points; // Координаты в диапазоне [0.0 - 1.0]
  final Color color;
  final double strokeWidth;
  final String? label;

  TelestrationElement({
    required this.tool,
    required this.points,
    required this.color,
    this.strokeWidth = 3.0,
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'tool': tool.name,
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'color': color.toARGB32(),
    'strokeWidth': strokeWidth,
    'label': label,
  };

  factory TelestrationElement.fromJson(Map<String, dynamic> json) {
    return TelestrationElement(
      tool: TelestrationTool.values.firstWhere(
        (t) => t.name == json['tool'],
        orElse: () => TelestrationTool.arrow,
      ),
      points: ((json['points'] as List?) ?? [])
          .map((p) => Offset(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ))
          .toList(),
      color: Color((json['color'] as num?)?.toInt() ?? 0xFFCCFF00),
      strokeWidth: ((json['strokeWidth'] as num?) ?? 3.0).toDouble(),
      label: json['label'] as String?,
    );
  }
}

/// Тактическое событие матча на таймлайне
class TacticalEvent {
  final String id;
  final String matchId;
  final String? playerId;
  final String eventType; // 'shot', 'key_pass', 'pressing', 'turnover', 'duel'
  final String title;
  final String? coachComment;
  final int rating; // Оценка от 1 до 5
  
  // Временные рамки эпизода (в миллисекундах)
  final int startMs;
  final int endMs;
  final int freezeFrameMs; // Точный момент паузы для разбора телестрации

  // Координаты на 2D-радаре поля [0.0 - 1.0]
  final double pitchX;
  final double pitchY;

  // Список рисунков поверх стоп-кадра
  final List<TelestrationElement> telestrations;

  TacticalEvent({
    required this.id,
    required this.matchId,
    this.playerId,
    required this.eventType,
    required this.title,
    this.coachComment,
    this.rating = 5,
    required this.startMs,
    required this.endMs,
    required this.freezeFrameMs,
    required this.pitchX,
    required this.pitchY,
    this.telestrations = const [],
  });

  factory TacticalEvent.fromJson(Map<String, dynamic> json) {
    final rawTelestrations = json['telestration_data'];
    List<TelestrationElement> parsedTelestrations = [];
    
    if (rawTelestrations is List) {
      parsedTelestrations = rawTelestrations
          .map((e) => TelestrationElement.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return TacticalEvent(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      playerId: json['player_id'] as String?,
      eventType: json['event_type'] as String? ?? 'tactical_note',
      title: json['title'] as String? ?? 'Эпизод матча',
      coachComment: json['coach_comment'] as String?,
      rating: ((json['rating'] as num?) ?? 5).toInt(),
      startMs: ((json['start_ms'] as num?) ?? 0).toInt(),
      endMs: ((json['end_ms'] as num?) ?? 0).toInt(),
      freezeFrameMs: ((json['freeze_frame_ms'] as num?) ?? 0).toInt(),
      pitchX: ((json['pitch_x'] as num?) ?? 0.5).toDouble(),
      pitchY: ((json['pitch_y'] as num?) ?? 0.5).toDouble(),
      telestrations: parsedTelestrations,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'match_id': matchId,
    'player_id': playerId,
    'event_type': eventType,
    'title': title,
    'coach_comment': coachComment,
    'rating': rating,
    'start_ms': startMs,
    'end_ms': endMs,
    'freeze_frame_ms': freezeFrameMs,
    'pitch_x': pitchX,
    'pitch_y': pitchY,
    'telestration_data': telestrations.map((t) => t.toJson()).toList(),
  };
}

/// Модель матча
class TacticalMatch {
  final String id;
  final String title;
  final String videoUrl;
  final int durationMs;
  final String teamHome;
  final String teamAway;

  TacticalMatch({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.durationMs,
    required this.teamHome,
    required this.teamAway,
  });

  factory TacticalMatch.fromJson(Map<String, dynamic> json) {
    return TacticalMatch(
      id: json['id'] as String,
      title: json['title'] as String,
      videoUrl: json['video_url'] as String,
      durationMs: ((json['duration_ms'] as num?) ?? 0).toInt(),
      teamHome: json['team_home'] as String? ?? 'Хозяева',
      teamAway: json['team_away'] as String? ?? 'Гости',
    );
  }
}
