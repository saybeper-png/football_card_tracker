import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/tactical_analysis_model.dart';

class TelestrationCanvasWidget extends StatefulWidget {
  final List<TelestrationElement> initialElements;
  final ValueChanged<List<TelestrationElement>>? onElementsChanged;
  final bool isEditable;
  final Widget? child;

  const TelestrationCanvasWidget({
    super.key,
    this.initialElements = const [],
    this.onElementsChanged,
    this.isEditable = false,
    this.child,
  });

  @override
  State<TelestrationCanvasWidget> createState() => _TelestrationCanvasWidgetState();
}

class _TelestrationCanvasWidgetState extends State<TelestrationCanvasWidget> {
  late List<TelestrationElement> _elements;
  TelestrationTool _currentTool = TelestrationTool.arrow;
  Color _currentColor = const Color(0xFFCCFF00);
  List<Offset> _activePoints = [];

  final List<Color> _availableColors = const [
    Color(0xFFCCFF00),
    Color(0xFF38BDF8),
    Color(0xFFFFB703),
    Color(0xFFEF4444),
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _elements = List.from(widget.initialElements);
  }

  @override
  void didUpdateWidget(covariant TelestrationCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialElements != oldWidget.initialElements) {
      _elements = List.from(widget.initialElements);
    }
  }

  void _notifyChange() {
    widget.onElementsChanged?.call(List.unmodifiable(_elements));
  }

  void _undo() {
    if (_elements.isNotEmpty) {
      setState(() {
        _elements.removeLast();
      });
      _notifyChange();
    }
  }

  void _clearAll() {
    if (_elements.isNotEmpty) {
      setState(() {
        _elements.clear();
      });
      _notifyChange();
    }
  }

  void _onPanStart(DragStartDetails details, Size size) {
    if (!widget.isEditable) return;
    final normX = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
    final normY = (details.localPosition.dy / size.height).clamp(0.0, 1.0);

    setState(() {
      _activePoints = [Offset(normX, normY)];
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (!widget.isEditable || _activePoints.isEmpty) return;
    final normX = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
    final normY = (details.localPosition.dy / size.height).clamp(0.0, 1.0);
    final newPoint = Offset(normX, normY);

    setState(() {
      if (_currentTool == TelestrationTool.freehand) {
        _activePoints.add(newPoint);
      } else {
        if (_activePoints.length > 1) {
          _activePoints[1] = newPoint;
        } else {
          _activePoints.add(newPoint);
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isEditable || _activePoints.isEmpty) return;

    if (_activePoints.length >= 2 || _currentTool == TelestrationTool.spotlight) {
      final newElem = TelestrationElement(
        tool: _currentTool,
        points: List.from(_activePoints),
        color: _currentColor,
        strokeWidth: 3.5,
      );

      setState(() {
        _elements.add(newElem);
        _activePoints = [];
      });
      _notifyChange();
    } else {
      setState(() {
        _activePoints = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            if (widget.child != null) Positioned.fill(child: widget.child!),

            Positioned.fill(
              child: CustomPaint(
                size: canvasSize,
                painter: _TelestrationPainter(
                  elements: _elements,
                  activeElement: _activePoints.isNotEmpty
                      ? TelestrationElement(
                          tool: _currentTool,
                          points: _activePoints,
                          color: _currentColor,
                          strokeWidth: 3.5,
                        )
                      : null,
                ),
              ),
            ),

            if (widget.isEditable)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (d) => _onPanStart(d, canvasSize),
                  onPanUpdate: (d) => _onPanUpdate(d, canvasSize),
                  onPanEnd: _onPanEnd,
                ),
              ),

            if (widget.isEditable)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _buildToolbar(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCCFF00).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolBtn(TelestrationTool.arrow, Icons.arrow_outward_rounded, 'Стрелка'),
            const SizedBox(width: 4),
            _buildToolBtn(TelestrationTool.spotlight, Icons.highlight_rounded, 'Прожектор'),
            const SizedBox(width: 4),
            _buildToolBtn(TelestrationTool.circle, Icons.circle_outlined, 'Зона'),
            const SizedBox(width: 4),
            _buildToolBtn(TelestrationTool.freehand, Icons.edit_rounded, 'Кисть'),

            const SizedBox(width: 10),
            Container(width: 1, height: 24, color: Colors.white24),
            const SizedBox(width: 10),

            ..._availableColors.map((color) {
              final isSelected = _currentColor == color;
              return GestureDetector(
                onTap: () => setState(() => _currentColor = color),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.black45,
                      width: isSelected ? 2.2 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.8),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),

            const SizedBox(width: 10),
            Container(width: 1, height: 24, color: Colors.white24),
            const SizedBox(width: 10),

            IconButton(
              icon: const Icon(Icons.undo_rounded, size: 20, color: Colors.white70),
              tooltip: 'Отменить действие',
              onPressed: _undo,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: Color(0xFFEF4444)),
              tooltip: 'Очистить холст',
              onPressed: _clearAll,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolBtn(TelestrationTool tool, IconData icon, String tooltip) {
    final isSelected = _currentTool == tool;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _currentTool = tool),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFCCFF00) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black : Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                tooltip,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelestrationPainter extends CustomPainter {
  final List<TelestrationElement> elements;
  final TelestrationElement? activeElement;

  _TelestrationPainter({
    required this.elements,
    this.activeElement,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final elem in elements) {
      _drawElement(canvas, size, elem);
    }
    if (activeElement != null) {
      _drawElement(canvas, size, activeElement!);
    }
  }

  void _drawElement(Canvas canvas, Size size, TelestrationElement elem) {
    if (elem.points.isEmpty) return;

    final paint = Paint()
      ..color = elem.color
      ..strokeWidth = elem.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    switch (elem.tool) {
      case TelestrationTool.arrow:
        if (elem.points.length < 2) return;
        final start = Offset(elem.points.first.dx * w, elem.points.first.dy * h);
        final end = Offset(elem.points.last.dx * w, elem.points.last.dy * h);

        canvas.drawLine(start, end, paint);

        final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
        const arrowLength = 18.0;
        const arrowAngle = math.pi / 6;

        final path = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(
            end.dx - arrowLength * math.cos(angle - arrowAngle),
            end.dy - arrowLength * math.sin(angle - arrowAngle),
          )
          ..lineTo(
            end.dx - (arrowLength * 0.6) * math.cos(angle),
            end.dy - (arrowLength * 0.6) * math.sin(angle),
          )
          ..lineTo(
            end.dx - arrowLength * math.cos(angle + arrowAngle),
            end.dy - arrowLength * math.sin(angle + arrowAngle),
          )
          ..close();

        final fillPaint = Paint()
          ..color = elem.color
          ..style = PaintingStyle.fill;

        canvas.drawPath(path, fillPaint);
        break;

      case TelestrationTool.spotlight:
        final center = Offset(elem.points.first.dx * w, elem.points.first.dy * h);
        double radius = 50.0;
        if (elem.points.length >= 2) {
          final edge = Offset(elem.points.last.dx * w, elem.points.last.dy * h);
          radius = (edge - center).distance.clamp(25.0, 150.0);
        }

        final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, w, h));
        final holePath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
        final darkPath = Path.combine(PathOperation.difference, bgPath, holePath);

        canvas.drawPath(
          darkPath,
          Paint()..color = Colors.black.withValues(alpha: 0.55),
        );

        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = elem.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        break;

      case TelestrationTool.circle:
        if (elem.points.length < 2) return;
        final p1 = Offset(elem.points.first.dx * w, elem.points.first.dy * h);
        final p2 = Offset(elem.points.last.dx * w, elem.points.last.dy * h);
        final rect = Rect.fromPoints(p1, p2);

        canvas.drawOval(
          rect,
          Paint()
            ..color = elem.color.withValues(alpha: 0.2)
            ..style = PaintingStyle.fill,
        );

        canvas.drawOval(rect, paint);
        break;

      case TelestrationTool.freehand:
        if (elem.points.length < 2) return;
        final path = Path();
        path.moveTo(elem.points.first.dx * w, elem.points.first.dy * h);

        for (int i = 1; i < elem.points.length; i++) {
          path.lineTo(elem.points[i].dx * w, elem.points[i].dy * h);
        }

        canvas.drawPath(path, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TelestrationPainter oldDelegate) => true;
}
