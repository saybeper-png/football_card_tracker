import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tactical_analysis_model.dart';
import '../widgets/pitch_radar_widget.dart';
import '../widgets/telestration_canvas_widget.dart';

class TacticalMatchHubScreen extends StatefulWidget {
  final String matchTitle;
  final String videoUrl;
  final bool isCoachRole;

  const TacticalMatchHubScreen({
    super.key,
    this.matchTitle = 'Академия vs Динамо U-11',
    this.videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    this.isCoachRole = true,
  });

  @override
  State<TacticalMatchHubScreen> createState() => _TacticalMatchHubScreenState();
}

class _TacticalMatchHubScreenState extends State<TacticalMatchHubScreen> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isVideoPaused = true;
  bool _isTelestrationActive = false;

  TacticalEvent? _selectedEvent;
  List<TacticalEvent> _events = [];
  List<TelestrationElement> _currentTelestrations = [];

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initDemoEvents();
    _initVideo();
  }

  void _initDemoEvents() {
    _events = [
      TacticalEvent(
        id: '1',
        matchId: 'demo_match',
        eventType: 'pressing',
        title: 'Взрывной отбор у бровки',
        coachComment: 'Отличный наклон корпуса! Держи дистанцию до приема.',
        rating: 5,
        startMs: 4000,
        endMs: 9000,
        freezeFrameMs: 6000,
        pitchX: 0.28,
        pitchY: 0.18,
        telestrations: [
          TelestrationElement(
            tool: TelestrationTool.arrow,
            points: const [Offset(0.25, 0.45), Offset(0.48, 0.52)],
            color: const Color(0xFFCCFF00),
            strokeWidth: 4.0,
          ),
          TelestrationElement(
            tool: TelestrationTool.spotlight,
            points: const [Offset(0.48, 0.52), Offset(0.55, 0.52)],
            color: const Color(0xFF38BDF8),
            strokeWidth: 3.0,
          ),
        ],
      ),
      TacticalEvent(
        id: '2',
        matchId: 'demo_match',
        eventType: 'shot',
        title: 'Удар в створ ворот с ходу',
        coachComment: 'Хороший разбег, опорную ногу ближе к мячу.',
        rating: 4,
        startMs: 14000,
        endMs: 20000,
        freezeFrameMs: 17000,
        pitchX: 0.85,
        pitchY: 0.48,
        telestrations: [],
      ),
      TacticalEvent(
        id: '3',
        matchId: 'demo_match',
        eventType: 'turnover_lost',
        title: 'Потеря при выходе из обороны',
        coachComment: 'Нужно было отдать пас в касание на свободный фланг.',
        rating: 3,
        startMs: 26000,
        endMs: 32000,
        freezeFrameMs: 28000,
        pitchX: 0.35,
        pitchY: 0.72,
        telestrations: [],
      ),
    ];

    _selectedEvent = _events.first;
    _currentTelestrations = List.from(_events.first.telestrations);
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(false);

      controller.addListener(() {
        if (mounted) {
          final isPlaying = controller.value.isPlaying;
          if (_isVideoPaused == isPlaying) {
            setState(() {
              _isVideoPaused = !isPlaying;
            });
          }
        }
      });

      setState(() {
        _isInitialized = true;
      });
    } catch (_) {}
  }

  void _onEventSelected(TacticalEvent event) {
    setState(() {
      _selectedEvent = event;
      _currentTelestrations = List.from(event.telestrations);
      _isTelestrationActive = event.telestrations.isNotEmpty;
    });

    if (_videoController != null && _isInitialized) {
      _videoController!.seekTo(Duration(milliseconds: event.startMs));
      _videoController!.play();
    }
  }

  void _togglePlayPause() {
    final controller = _videoController;
    if (controller == null || !_isInitialized) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _isVideoPaused = true;
      } else {
        controller.play();
        _isVideoPaused = false;
        _isTelestrationActive = false;
      }
    });
  }

  void _toggleFreezeFrameAnalysis() {
    final controller = _videoController;
    if (controller == null || !_isInitialized) return;

    controller.pause();
    setState(() {
      _isVideoPaused = true;
      _isTelestrationActive = true;
    });
  }

  Future<void> _saveTelestrationsToSupabase(String eventId, List<TelestrationElement> updated) async {
    setState(() {
      _currentTelestrations = List.from(updated);
      if (_selectedEvent != null) {
        final idx = _events.indexWhere((e) => e.id == _selectedEvent!.id);
        if (idx != -1) {
          _events[idx] = TacticalEvent(
            id: _selectedEvent!.id,
            matchId: _selectedEvent!.matchId,
            eventType: _selectedEvent!.eventType,
            title: _selectedEvent!.title,
            coachComment: _selectedEvent!.coachComment,
            rating: _selectedEvent!.rating,
            startMs: _selectedEvent!.startMs,
            endMs: _selectedEvent!.endMs,
            freezeFrameMs: _selectedEvent!.freezeFrameMs,
            pitchX: _selectedEvent!.pitchX,
            pitchY: _selectedEvent!.pitchY,
            telestrations: updated,
          );
        }
      }
    });

    try {
      await supabase.from('tactical_events').update({
        'telestration_data': updated.map((e) => e.toJson()).toList(),
      }).eq('id', eventId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final isEditable = widget.isCoachRole && _isVideoPaused && _isTelestrationActive;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14161F),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.matchTitle.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              widget.isCoachRole ? 'РЕЖИМ ТРЕНЕРА: РАЗБОР И ТЕЛЕСТРАЦИЯ' : 'ПРОСМОТР РАЗБОРА МАТЧА',
              style: const TextStyle(fontSize: 9, color: Color(0xFFCCFF00), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isEditable ? const Color(0xFFCCFF00) : Colors.white12,
                  width: isEditable ? 2.0 : 1.0,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isInitialized && controller != null
                  ? TelestrationCanvasWidget(
                      isEditable: isEditable,
                      initialElements: _currentTelestrations,
                      onElementsChanged: (updatedList) {
                        if (_selectedEvent != null) {
                          _saveTelestrationsToSupabase(_selectedEvent!.id, updatedList);
                        }
                      },
                      child: GestureDetector(
                        onTap: _togglePlayPause,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: controller.value.aspectRatio,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Color(0xFFCCFF00)),
                    ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    _isVideoPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: const Color(0xFFCCFF00),
                    size: 32,
                  ),
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTelestrationActive
                          ? const Color(0xFFCCFF00)
                          : const Color(0xFF1E293B),
                      foregroundColor: _isTelestrationActive ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      Icons.draw_rounded,
                      size: 18,
                      color: _isTelestrationActive ? Colors.black : const Color(0xFFCCFF00),
                    ),
                    label: Text(
                      _isTelestrationActive ? 'РИСОВАНИЕ ВКЛЮЧЕНО' : 'СТОП-КАДР И РАЗБОР',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                    onPressed: _toggleFreezeFrameAnalysis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text(
              'ТАКТИЧЕСКИЙ РАДАР ПОЛЯ (ТОЧКИ СОБЫТИЙ)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            PitchRadarWidget(
              events: _events,
              selectedEvent: _selectedEvent,
              onEventSelected: _onEventSelected,
              isCoachMode: false,
            ),

            const SizedBox(height: 16),

            const Text(
              'ЭПИЗОДЫ МАТЧА ДЛЯ РАЗБОРА',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            ..._events.map((ev) {
              final isSel = _selectedEvent?.id == ev.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF1E293B) : const Color(0xFF14161F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel ? const Color(0xFFCCFF00) : Colors.white10,
                    width: isSel ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: isSel ? const Color(0xFFCCFF00) : Colors.white12,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: isSel ? Colors.black : Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    ev.title,
                    style: TextStyle(
                      color: isSel ? const Color(0xFFCCFF00) : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: Text(
                    ev.coachComment ?? '',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                  trailing: Text(
                    '★ ${ev.rating}/5',
                    style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onTap: () => _onEventSelected(ev),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
