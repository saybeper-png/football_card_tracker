import 'dart:convert';
import 'package:http/http.dart' as http;

class YoutubeStreamResolver {
  // Список проверенных зеркал Piped API
  static const List<String> _instances = [
    'https://pipedapi.kavin.rocks',
    'https://api.piped.privacydev.net',
    'https://pipedapi.leptons.xyz',
    'https://piped-api.lunar.icu',
    'https://api.piped.projectsegfau.lt',
  ];

  /// Извлекает 11-значный ID видео из любой ссылки YouTube
  static String extractVideoId(String input) {
    final clean = input.trim();
    if (!clean.contains('/') && !clean.contains('.') && clean.length == 11) {
      return clean;
    }
    final regExp = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|shorts\/|live\/)|&v=)([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(clean);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return clean;
  }

  /// Получает прямую MP4 / HLS ссылку на видеопоток
  static Future<String?> resolve(String urlOrId) async {
    final trimmed = urlOrId.trim();

    // Если уже передан прямой видеофайл (.mp4)
    if (trimmed.startsWith('http') && (trimmed.endsWith('.mp4') || trimmed.contains('.mp4?'))) {
      return trimmed;
    }

    final videoId = extractVideoId(trimmed);

    // Опрашиваем зеркала по очереди
    for (final instance in _instances) {
      try {
        final uri = Uri.parse('$instance/streams/$videoId');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // 1. Ищем прогрессивный MP4 с совмещенным звуком (videoOnly == false)
          final videoStreams = data['videoStreams'] as List<dynamic>?;
          if (videoStreams != null && videoStreams.isNotEmpty) {
            final directMp4 = videoStreams.firstWhere(
              (s) =>
                  s['videoOnly'] == false &&
                  (s['format'] == 'MPEG_4' || (s['mimeType'] as String? ?? '').contains('mp4')),
              orElse: () => null,
            );

            if (directMp4 != null && directMp4['url'] != null) {
              return directMp4['url'] as String;
            }
          }

          // 2. Если отдельного MP4 со звуком нет — берем HLS поток
          final hls = data['hls'] as String?;
          if (hls != null && hls.isNotEmpty) {
            return hls;
          }

          // 3. Fallback: первый доступный видеопоток
          if (videoStreams != null && videoStreams.isNotEmpty) {
            return videoStreams.first['url'] as String?;
          }
        }
      } catch (_) {
        // Если зеркало не ответило, переходим к следующему
        continue;
      }
    }

    return null;
  }
}
