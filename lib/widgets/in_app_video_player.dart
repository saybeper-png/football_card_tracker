import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class InAppVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const InAppVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<InAppVideoPlayer> createState() => _InAppVideoPlayerState();
}

class _InAppVideoPlayerState extends State<InAppVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isMuted = false;
  double? _activeSlowdown;
  String? _error;
  bool _isFullScreenActive = false;
  Key _playerViewKey = UniqueKey();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _startVideo(widget.videoUrl);
  }

  Future<void> _startVideo(String url) async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);

      try {
        await controller.setVolume(1.0);
        await controller.play();
        _isMuted = false;
      } catch (_) {
        await controller.setVolume(0.0);
        await controller.play();
        _isMuted = true;
      }

      if (_activeSlowdown != null) {
        await controller.setPlaybackSpeed(1.0 / _activeSlowdown!);
      }

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Файл не найден или недоступен');
      }
    }
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _setSlowdown(double factor) {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      if (_activeSlowdown == factor) {
        _activeSlowdown = null;
        controller.setPlaybackSpeed(1.0);
      } else {
        _activeSlowdown = factor;
        controller.setPlaybackSpeed(1.0 / factor);
      }
    });
  }

  void _openFullScreen() async {
    final controller = _controller;
    if (!_isInitialized || controller == null) return;

    setState(() {
      _isFullScreenActive = true;
    });

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (ctx, anim1, anim2) => _FullScreenPlayerPage(
          controller: controller,
          initialMuted: _isMuted,
          initialSlowdown: _activeSlowdown,
          onMuteToggled: (muted) {
            if (mounted) setState(() => _isMuted = muted);
          },
          onSlowdownChanged: (factor) {
            if (mounted) _setSlowdown(factor);
          },
        ),
        transitionsBuilder: (ctx, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
      ),
    );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    if (!mounted) return;

    final currentPos = controller.value.position;
    final isPlayingOnExit = controller.value.isPlaying;

    setState(() {
      _isFullScreenActive = false;
      _playerViewKey = UniqueKey();
    });

    await controller.seekTo(currentPos);
    if (isPlayingOnExit) {
      await controller.play();
    }
  }

  /// Универсальный метод: захват с камеры (camera) или выбор из медиатеки (gallery)
  Future<void> _pickVideoAndAnalyze(ImageSource source) async {
    bool isDialogShowing = false;
    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
        preferredCameraDevice: CameraDevice.rear,
      );

      if (video == null) return; // Пользователь отменил выбор

      if (!mounted) return;

      isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFCCFF00), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFFCCFF00)),
                const SizedBox(height: 20),
                Text(
                  source == ImageSource.camera
                      ? 'АНАЛИЗ ЗАПИСИ С КАМЕРЫ'
                      : 'АНАЛИЗ ВИДЕО ИЗ ГАЛЕРЕИ',
                  style: const TextStyle(
                    color: Color(0xFFCCFF00),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Загружаем дубль в облако и сверяем углы...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );

      final bytes = await video.readAsBytes();
      final ext = video.name.contains('.') ? video.name.split('.').last : 'mp4';
      final fileName = 'submission_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = 'submissions/$fileName';

      final supabase = Supabase.instance.client;
      await supabase.storage.from('drills').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: video.mimeType ?? 'video/mp4',
          upsert: true,
        ),
      );

      if (!mounted) return;
      if (isDialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }

      _showAnalysisResultDialog();
    } catch (e) {
      if (!mounted) return;
      if (isDialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Ошибка загрузки: $e'),
        ),
      );
    }
  }

  void _showAnalysisResultDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFCCFF00), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFCCFF00),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'ДУБЛЬ ПРИНЯТ!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Техника выполнения:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('92 / 100', style: TextStyle(color: Color(0xFFCCFF00), fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Разбор лучшей попытки:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _buildCheckItem('Наклон корпуса 45° на старте', true),
            _buildCheckItem('Амплитуда работы рук и баланс', true),
            _buildCheckItem('Мощный толчок стопой вперед', true),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFF00).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚡ +75 XP начислено за отличную технику!',
                style: TextStyle(color: Color(0xFFCCFF00), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCCFF00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ПРИНЯТЬ', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  static Widget _buildCheckItem(String text, bool ok, {String? warning}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: ok ? const Color(0xFFCCFF00) : Colors.amberAccent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ],
          ),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text('• $warning', style: const TextStyle(color: Colors.amberAccent, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Окно видеоплеера
        Container(
          height: 390,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFCCFF00).withValues(alpha: 0.6),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCCFF00).withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isInitialized && controller != null && !_isFullScreenActive) ...[
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(
                      controller,
                      key: _playerViewKey,
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () {
                    setState(() {
                      controller.value.isPlaying
                          ? controller.pause()
                          : controller.play();
                    });
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: controller.value.isPlaying ? 0.0 : 0.85,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 56,
                            color: Color(0xFFCCFF00),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 12,
                  left: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openFullScreen,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFCCFF00),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          color: Color(0xFFCCFF00),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 12,
                  child: SlowMoCirclesWidget(
                    activeSlowdown: _activeSlowdown,
                    onSelectSlowdown: _setSlowdown,
                  ),
                ),

                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleMute,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isMuted ? Colors.white30 : const Color(0xFFCCFF00),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: _isMuted ? Colors.white60 : const Color(0xFFCCFF00),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 8,
                  left: 10,
                  right: 10,
                  child: InteractiveVideoTimeline(controller: controller),
                ),
              ] else if (_isFullScreenActive) ...[
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFCCFF00),
                    ),
                  ),
                ),
              ] else if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.amberAccent, size: 42),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFCCFF00)),
                    SizedBox(height: 14),
                    Text(
                      'Загрузка упражнения...',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 1. КНОПКА СЪЕМКИ С КАМЕРЫ (в реальном времени)
        _buildUploadOptionCard(
          icon: Icons.videocam_rounded,
          title: 'СНЯТЬ СВОЁ ВЫПОЛНЕНИЕ НА КАМЕРУ',
          subtitle: 'Запись попытки прямо сейчас (до 30 сек)',
          onTap: () => _pickVideoAndAnalyze(ImageSource.camera),
          isAccent: true,
        ),

        const SizedBox(height: 8),

        // 2. КНОПКА ЗАГРУЗКИ ИЗ ГАЛЕРЕИ (готовый удачный дубль)
        _buildUploadOptionCard(
          icon: Icons.photo_library_rounded,
          title: 'ПРИКРЕПИТЬ ИЗ ГАЛЕРЕИ / МЕДИАТЕКИ',
          subtitle: 'Выбрать лучший получившийся дубль из альбома',
          onTap: () => _pickVideoAndAnalyze(ImageSource.gallery),
          isAccent: false,
        ),
      ],
    );
  }

  Widget _buildUploadOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isAccent,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isAccent
              ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
              : const [Color(0xFF141622), Color(0xFF0D0E15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isAccent
              ? const Color(0xFFCCFF00)
              : Colors.white.withValues(alpha: 0.25),
          width: isAccent ? 1.5 : 1.2,
        ),
        boxShadow: isAccent
            ? [
                BoxShadow(
                  color: const Color(0xFFCCFF00).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isAccent ? const Color(0xFFCCFF00) : Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isAccent ? Colors.black : const Color(0xFFCCFF00),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isAccent ? const Color(0xFFCCFF00) : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isAccent ? const Color(0xFFCCFF00) : Colors.white38,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SlowMoCirclesWidget extends StatelessWidget {
  final double? activeSlowdown;
  final ValueChanged<double> onSelectSlowdown;

  const SlowMoCirclesWidget({
    super.key,
    required this.activeSlowdown,
    required this.onSelectSlowdown,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      {'factor': 1.5, 'label': '1,5x'},
      {'factor': 2.0, 'label': '2x'},
      {'factor': 2.5, 'label': '2,5x'},
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final factor = opt['factor'] as double;
        final label = opt['label'] as String;
        final isActive = activeSlowdown == factor;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelectSlowdown(factor),
              borderRadius: BorderRadius.circular(30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? const Color(0xFFCCFF00)
                      : Colors.black.withValues(alpha: 0.75),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFCCFF00)
                        : Colors.white30,
                    width: 1.4,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFFCCFF00).withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.black : Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class InteractiveVideoTimeline extends StatefulWidget {
  final VideoPlayerController controller;

  const InteractiveVideoTimeline({super.key, required this.controller});

  @override
  State<InteractiveVideoTimeline> createState() => _InteractiveVideoTimelineState();
}

class _InteractiveVideoTimelineState extends State<InteractiveVideoTimeline> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final duration = value.duration;
        final position = value.position;
        final totalMs = duration.inMilliseconds.toDouble();
        final currentMs = position.inMilliseconds.toDouble().clamp(0.0, totalMs > 0 ? totalMs : 1.0);

        final sliderValue = _isDragging
            ? _dragValue
            : (totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0);

        final isPlaying = value.isPlaying;
        final isBuffering = value.isBuffering;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFCCFF00).withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  isPlaying ? widget.controller.pause() : widget.controller.play();
                },
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: const Color(0xFFCCFF00),
                  size: 24,
                ),
              ),
              const SizedBox(width: 6),

              Text(
                _formatDuration(position),
                style: const TextStyle(
                  color: Color(0xFFCCFF00),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),

              Expanded(
                child: SizedBox(
                  height: 28,
                  child: SliderTheme(
                    data: const SliderThemeData(
                      trackHeight: 3.5,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: Color(0xFFCCFF00),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Color(0xFFCCFF00),
                      overlayColor: Color(0x33CCFF00),
                    ),
                    child: Slider(
                      value: sliderValue,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        setState(() {
                          _isDragging = true;
                          _dragValue = val;
                        });
                      },
                      onChangeEnd: (val) {
                        final targetMs = (val * totalMs).round();
                        widget.controller.seekTo(Duration(milliseconds: targetMs));
                        setState(() {
                          _isDragging = false;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              Text(
                _formatDuration(duration),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isBuffering
                      ? Colors.orange.withValues(alpha: 0.2)
                      : (isPlaying ? const Color(0xFFCCFF00).withValues(alpha: 0.15) : Colors.white10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isBuffering
                        ? Colors.orange
                        : (isPlaying ? const Color(0xFFCCFF00) : Colors.white24),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBuffering
                            ? Colors.orange
                            : (isPlaying ? const Color(0xFFCCFF00) : Colors.white38),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBuffering ? 'БУФЕР' : (isPlaying ? 'PLAY' : 'ПАУЗА'),
                      style: TextStyle(
                        color: isBuffering
                            ? Colors.orange
                            : (isPlaying ? const Color(0xFFCCFF00) : Colors.white60),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FullScreenPlayerPage extends StatefulWidget {
  final VideoPlayerController controller;
  final bool initialMuted;
  final double? initialSlowdown;
  final ValueChanged<bool> onMuteToggled;
  final ValueChanged<double> onSlowdownChanged;

  const _FullScreenPlayerPage({
    required this.controller,
    required this.initialMuted,
    required this.initialSlowdown,
    required this.onMuteToggled,
    required this.onSlowdownChanged,
  });

  @override
  State<_FullScreenPlayerPage> createState() => _FullScreenPlayerPageState();
}

class _FullScreenPlayerPageState extends State<_FullScreenPlayerPage> {
  late bool _isMuted;
  double? _slowdown;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.initialMuted;
    _slowdown = widget.initialSlowdown;
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      widget.controller.setVolume(_isMuted ? 0.0 : 1.0);
      widget.onMuteToggled(_isMuted);
    });
  }

  void _setSlowdown(double factor) {
    setState(() {
      if (_slowdown == factor) {
        _slowdown = null;
        widget.controller.setPlaybackSpeed(1.0);
      } else {
        _slowdown = factor;
        widget.controller.setPlaybackSpeed(1.0 / factor);
      }
      widget.onSlowdownChanged(factor);
    });
  }

  void _togglePlayPause() {
    setState(() {
      widget.controller.value.isPlaying
          ? widget.controller.pause()
          : widget.controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio,
                  child: VideoPlayer(
                    widget.controller,
                    key: const ValueKey('fullscreen_video_element'),
                  ),
                ),
              ),

              if (_showControls)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 64,
                        color: const Color(0xFFCCFF00),
                      ),
                    ),
                  ),
                ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                top: _showControls ? 16 : -180,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFCCFF00),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.fullscreen_exit_rounded,
                            color: Color(0xFFCCFF00),
                            size: 24,
                          ),
                        ),
                      ),
                    ),

                    SlowMoCirclesWidget(
                      activeSlowdown: _slowdown,
                      onSelectSlowdown: _setSlowdown,
                    ),

                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleMute,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isMuted ? Colors.white30 : const Color(0xFFCCFF00),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: _isMuted ? Colors.white60 : const Color(0xFFCCFF00),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                bottom: _showControls ? 16 : -80,
                left: 16,
                right: 16,
                child: InteractiveVideoTimeline(controller: widget.controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
