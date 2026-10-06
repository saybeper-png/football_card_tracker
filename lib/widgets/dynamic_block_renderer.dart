import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DynamicBlockRenderer extends StatelessWidget {
  final List<Map<String, dynamic>> blocks;

  const DynamicBlockRenderer({super.key, required this.blocks});

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'В этой вкладке пока нет блоков.\nДобавьте их через панель администратора ⚙️',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: blocks.length,
      itemBuilder: (ctx, i) {
        final block = blocks[i];
        final type = block['type'] as String? ?? 'notice';

        switch (type) {
          case 'banner':
            return _buildHeroBanner(block);
          case 'notice':
            return _buildCoachNotice(block);
          case 'video_card':
            return _buildVideoCard(context, block);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  // Неоновый баннер в стиле EA Sports FC Mobile
  Widget _buildHeroBanner(Map<String, dynamic> b) {
    final title = b['title'] as String? ?? 'Заголовок баннера';
    final subtitle = b['subtitle'] as String? ?? '';
    final tag = b['tag'] as String? ?? 'ИНФОРМАЦИЯ';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2838), Color(0xFF101520)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCCFF00).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCCFF00).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform(
            transform: Matrix4.skewX(-0.15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFF00),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag.toUpperCase(),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
          ],
        ],
      ),
    );
  }

  // Сообщение/установка от тренера
  Widget _buildCoachNotice(Map<String, dynamic> b) {
    final title = b['title'] as String? ?? 'Заметка';
    final body = b['body'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('📋', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Видео-урок
  Widget _buildVideoCard(BuildContext context, Map<String, dynamic> b) {
    final title = b['title'] as String? ?? 'Видеоурок';
    final duration = b['duration'] as String? ?? '3 мин';
    final url = b['url'] as String? ?? 'https://youtube.com';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE50914).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFE50914), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('Длительность: $duration', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Colors.white30, size: 16),
          ],
        ),
      ),
    );
  }
}
