// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/player_card_hub_model.dart';
import '../models/card_skin_theme.dart';
import 'dynamic_player_card.dart';
import 'hexagon_radar_chart.dart';

class TiltCardWrapper extends StatefulWidget {
  final Widget child;
  final double maxTiltAngle;
  final BorderRadius borderRadius;

  const TiltCardWrapper({
    super.key,
    required this.child,
    this.maxTiltAngle = 0.24,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  State<TiltCardWrapper> createState() => _TiltCardWrapperState();
}

class _TiltCardWrapperState extends State<TiltCardWrapper> {
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final dx = (details.localPosition.dx / size.width) - 0.5;
    final dy = (details.localPosition.dy / size.height) - 0.5;
    setState(() {
      _tiltX = -dy * widget.maxTiltAngle;
      _tiltY = dx * widget.maxTiltAngle;
    });
  }

  void _resetTilt() {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanUpdate: (d) => _onPanUpdate(d, size),
          onPanEnd: (_) => _resetTilt(),
          onPanCancel: () => _resetTilt(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..rotateX(_tiltX)
              ..rotateY(_tiltY),
            transformAlignment: Alignment.center,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class FlippablePlayerCard extends StatefulWidget {
  final PlayerCardHubModel model;
  final CardSkinTheme skin;
  final double width;

  const FlippablePlayerCard({
    super.key,
    required this.model,
    required this.skin,
    this.width = 280,
  });

  @override
  State<FlippablePlayerCard> createState() => _FlippablePlayerCardState();
}

class _FlippablePlayerCardState extends State<FlippablePlayerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _animation;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _animation = CurvedAnimation(
        parent: _flipController, curve: Curves.easeInOutCubicEmphasized);
    _animation.addListener(() {
      if ((_animation.value - 0.5).abs() < 0.05)
        HapticFeedback.selectionClick();
    });
    _animation.addStatusListener((s) {
      if (s == AnimationStatus.completed) _showFront = false;
      if (s == AnimationStatus.dismissed) _showFront = true;
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_flipController.isAnimating) return;
    if (_showFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final angle = _animation.value * math.pi;
          final isBack = angle > (math.pi / 2);

          Widget face = !isBack
              ? DynamicPlayerCard(
                  model: widget.model, skin: widget.skin, width: widget.width)
              : Transform(
                  transform: Matrix4.rotationY(math.pi),
                  alignment: Alignment.center,
                  child: _buildBackFace(),
                );

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..rotateY(angle),
            child: face,
          );
        },
      ),
    );
  }

  Widget _buildBackFace() {
    return Container(
      width: widget.width,
      height: widget.width * 1.55,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141310),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.skin.innerBorderColor, width: 1.5),
      ),
      child: Column(
        children: [
          Text('АТРИБУТЫ КАРТОЧКИ',
              style: TextStyle(
                  color: widget.skin.secondaryTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
          const Spacer(),
          HexagonRadarChart(
              attributes: widget.model.cardStats.attributes,
              size: widget.width * 0.75,
              primaryColor: widget.skin.primaryTextColor),
          const Spacer(),
          Text('Нажмите для возврата',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
        ],
      ),
    );
  }
}

