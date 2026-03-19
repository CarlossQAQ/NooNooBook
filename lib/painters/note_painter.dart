import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import '../models/stroke.dart';

/// Converts a perfect_freehand outline (List<Offset>) into a Flutter Path.
Path _outlineToPath(List<Offset> outline) {
  final path = Path();
  if (outline.isEmpty) return path;

  path.moveTo(outline.first.dx, outline.first.dy);
  for (int i = 1; i < outline.length - 1; i++) {
    final curr = outline[i];
    final next = outline[i + 1];
    path.quadraticBezierTo(
      curr.dx, curr.dy,
      (curr.dx + next.dx) / 2, (curr.dy + next.dy) / 2,
    );
  }
  path.close();
  return path;
}

/// CustomPainter that renders strokes with normalized coordinates (0~1).
/// The `size` parameter from paint() is used to scale back to actual pixels.
class NotePainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? activeStroke;

  const NotePainter({
    required this.strokes,
    this.activeStroke,
  });

  void _paintStroke(Canvas canvas, Stroke stroke, Size canvasSize) {
    if (stroke.points.isEmpty) return;

    // 把归一化坐标 (0~1) 还原为实际像素坐标
    final scaledPoints = stroke.points.map((p) =>
        PointVector(p.x * canvasSize.width, p.y * canvasSize.height)
    ).toList();

    final isHighlighter = stroke.type == StrokeType.highlighter;

    // 笔触大小也需要按页面宽度缩放
    final scaledSize = stroke.size * canvasSize.width / 400;

    final options = StrokeOptions(
      size: scaledSize,
      thinning: isHighlighter ? 0.0 : 0.55,
      smoothing: isHighlighter ? 0.7 : 0.5,
      streamline: isHighlighter ? 0.7 : 0.5,
      simulatePressure: !isHighlighter,
      isComplete: true,
    );

    final outline = getStroke(scaledPoints, options: options);
    final path = _outlineToPath(outline);

    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..blendMode = isHighlighter ? BlendMode.multiply : BlendMode.srcOver;

    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke, size);
    }
    if (activeStroke != null) {
      _paintStroke(canvas, activeStroke!, size);
    }
  }

  @override
  bool shouldRepaint(NotePainter oldDelegate) {
    // 活跃笔迹中使用 in-place mutation，必须始终重绘
    if (activeStroke != null) return true;
    return oldDelegate.strokes.length != strokes.length;
  }
}
