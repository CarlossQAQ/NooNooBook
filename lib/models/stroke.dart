import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

enum StrokeType { pen, highlighter }

/// Represents one complete or in-progress pen stroke.
/// Points list is mutable for performance during active drawing.
class Stroke {
  final List<PointVector> points;
  final Color color;
  final double size;
  final StrokeType type;
  final int pageIndex;

  Stroke({
    required this.points,
    required this.color,
    this.size = 6.0,
    this.type = StrokeType.pen,
    this.pageIndex = 0,
  });

  /// Add a point in-place (no copy) for performance during drawing
  void addPoint(PointVector point) {
    points.add(point);
  }
}
